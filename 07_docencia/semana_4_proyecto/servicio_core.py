"""servicio_core.py — [BLOQUE 6, min 115–140] El servicio: respuesta y abstención.

Se completa en vivo: la carga del bundle champion y la consulta con soporte.
"""
from __future__ import annotations

import json
import math

from rutas import REGISTRO
from registro import champion

_cache: dict = {}


def _cargar() -> dict:
    """Lee la versión champion (una vez): estimacion + tarjeta del bundle."""
    # El bundle viaja: el servicio NO lee los CSV, solo los artefactos con hash.
    if "bundle" not in _cache:
        version = champion()
        carpeta = REGISTRO / version
        _cache["bundle"] = {
            "version": version,
            "estimacion": json.loads((carpeta / "estimacion.json").read_text()),
            "tarjeta": json.loads((carpeta / "tarjeta.json").read_text()),
        }
    return _cache["bundle"]


def salud() -> dict:
    b = _cargar()
    return {"estado": "ok", "version": b["version"],
            "estimando": b["tarjeta"]["estimando"]}


def efecto() -> dict:
    """El efecto poblacional del prototipo, con su incertidumbre y su versión."""
    b = _cargar()
    e = b["estimacion"]
    return {
        "estado": "respuesta",
        "estimando": b["tarjeta"]["estimando"],
        "efecto": round(e["ate_aipw"], 1),
        "unidad": e["unidad"],
        "ic95": [round(x, 1) for x in e["ic_aipw"]],
        "que_cubre_el_ic": "el ATE poblacional (no un efecto individual)",
        "estimador": e["estimador_principal"],
        "poblacion": b["tarjeta"]["poblacion"],
        "version": b["version"],
    }


def consulta(perfil: dict) -> dict:
    """Responde una consulta individual: dentro del soporte, o abstención.

    La abstención es una respuesta de primera clase: no devuelve ningún
    número cuando el perfil cae fuera del rango de entrenamiento de alguna
    covariable (el soporte que la tarjeta declara).
    """
    b = _cargar()
    rangos = b["estimacion"]["rangos_covariables"]
    # Abstención de primera clase: fuera del soporte no se devuelve ningún número.
    motivos = []
    for covariable, (lo, hi) in rangos.items():
        if covariable not in perfil:
            continue
        valor = float(perfil[covariable])
        if valor < lo or valor > hi:
            motivos.append(f"{covariable}={valor:g} fuera de "
                           f"[{round(lo, 4)}, {round(hi, 4)}]")
    if motivos:
        return {"estado": "abstencion", "motivo": "; ".join(motivos),
                "version": b["version"]}

    estratos = b["estimacion"]["estratos"]
    corte = estratos["variable"]
    if corte not in perfil:
        return {"estado": "abstencion",
                "motivo": (f"falta la covariable del corte de heterogeneidad "
                           f"({corte}) para asignar el estrato"),
                "version": b["version"]}
    clave = "1" if float(perfil[corte]) > estratos["umbral"] else "0"
    hoja = estratos["hojas"][clave]
    return {
        "estado": "respuesta",
        "estimando": (f"media del efecto del programa en el estrato "
                      f"{corte}={clave} ({hoja['etiqueta']})"),
        "efecto": round(hoja["efecto"], 1),
        "unidad": b["estimacion"]["unidad"],
        "ic95": [round(x, 1) for x in hoja["ic"]],
        "que_cubre_el_ic": ("la media del efecto en este estrato; NO el ATE "
                            "poblacional ni un efecto individual"),
        "estrato": {"variable": corte, "valor": int(clave),
                    "n": hoja["n"]},
        "nota_heterogeneidad": estratos["nota"],
        "version": b["version"],
    }


def efecto_individual(perfil: dict) -> dict:
    """Efecto esperado para un perfil nuevo, o abstención fuera de soporte.

    Devuelve la proyección lineal del score AIPW sobre las covariables del perfil.
    No es un CATE validado: el IC es condicional al modelo y al ajuste lineal.
    """
    b = _cargar()
    est = b["estimacion"]
    modelo = est.get("modelo_individual")
    if modelo is None:
        return {"estado": "abstencion",
                "motivo": "el bundle de esta versión no trae modelo_individual",
                "version": b["version"]}

    covariables = list(modelo["coeficientes"])
    faltan = [c for c in covariables if c not in perfil]
    if faltan:
        return {"estado": "abstencion",
                "motivo": f"faltan covariables del perfil: {faltan}",
                "version": b["version"]}

    motivos = []
    for covariable, (lo, hi) in est["rangos_covariables"].items():
        valor = float(perfil[covariable])
        if valor < lo or valor > hi:
            motivos.append(f"{covariable}={valor:g} fuera de "
                           f"[{round(lo, 4)}, {round(hi, 4)}]")
    if motivos:
        return {"estado": "abstencion", "motivo": "; ".join(motivos),
                "version": b["version"]}

    z = [(float(perfil[c]) - modelo["medias"][c]) / modelo["desviaciones"][c]
         for c in covariables]
    beta = [modelo["coeficientes"][c] for c in covariables]
    tau = modelo["intercepto"] + sum(bj * zj for bj, zj in zip(beta, z))

    # Varianza de la predicción: z' Cov(beta) z (incluye el intercepto).
    v = [1.0, *z]
    cov = modelo["cov_beta"]
    var = sum(v[i] * cov[i][j] * v[j]
              for i in range(len(v)) for j in range(len(v)))
    se = float(math.sqrt(max(var, 0.0)))

    aviso = None
    if max(abs(zj) for zj in z) > 2.5:
        aviso = ("perfil en el borde del soporte: la proyección lineal extrapola "
                 "y el IC subestima la incertidumbre")

    r2 = float(modelo["r2"])
    discriminacion = ("muy baja" if r2 < 0.05 else
                      "baja" if r2 < 0.15 else "moderada")

    return {
        "estado": "respuesta",
        "estimando": ("efecto esperado del programa para un perfil con estas "
                      "covariables (proyección lineal del score AIPW)"),
        "efecto": round(float(tau), 1),
        "unidad": est["unidad"],
        "ic95": [round(float(tau - 1.96 * se), 1), round(float(tau + 1.96 * se), 1)],
        "que_cubre_el_ic": ("la proyección lineal, condicional a los scores AIPW; "
                            "NO cubre el sesgo de especificación lineal ni es un CATE validado"),
        "ajuste_r2": round(r2, 3),
        "confianza_discriminacion": discriminacion,
        "n_entrenamiento": modelo["n"],
        "aviso": aviso,
        "version": b["version"],
    }


def efecto_lista_de_prueba() -> list[str]:
    """Auxiliar para el humo: las rutas que la prueba de humo ejercita."""
    return ["/salud", "/efecto", "/consulta", "/efecto_individual"]
