"""servicio_core.py — [BLOQUE 6, min 115–140] El servicio: respuesta y abstención.

Se completa en vivo: la carga del bundle champion y la consulta con soporte.
"""
from __future__ import annotations

import json

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
        "unidad": "USD de 1978",
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
            motivos.append(f"{covariable}={valor:g} fuera de [{lo}, {hi}]")
    if motivos:
        return {"estado": "abstencion", "motivo": "; ".join(motivos),
                "version": b["version"]}

    estratos = b["estimacion"]["estratos"]
    clave = str(int(perfil.get("nodegree", 1)))
    hoja = estratos["hojas"][clave]
    return {
        "estado": "respuesta",
        "estimando": (f"media del efecto del programa en el estrato "
                      f"{estratos['variable']}={clave} ({hoja['etiqueta']})"),
        "efecto": round(hoja["efecto"], 1),
        "unidad": "USD de 1978",
        "ic95": [round(x, 1) for x in hoja["ic"]],
        "que_cubre_el_ic": ("la media del efecto en este estrato; NO el ATE "
                            "poblacional ni un efecto individual"),
        "estrato": {"variable": estratos["variable"], "valor": int(clave),
                    "n": hoja["n"]},
        "nota_heterogeneidad": ("los intervalos de los estratos se solapan: "
                                "heterogeneidad sugerida, no concluyente"),
        "version": b["version"],
    }


def efecto_lista_de_prueba() -> list[str]:
    """Auxiliar para el humo: las rutas que la prueba de humo ejercita."""
    return ["/salud", "/efecto", "/consulta"]
