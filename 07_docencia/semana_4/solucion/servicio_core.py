"""servicio_core.py — Lógica del servicio, sin FastAPI (así se prueba en cualquier entorno).

Bloque 6 de la clase: la respuesta con estimando + incertidumbre + versión,
la abstención fuera del soporte, y el determinismo (dos llamadas idénticas
devuelven lo mismo).
"""
from __future__ import annotations

import json
from pathlib import Path

from rutas import REGISTRO

_cache: dict = {}


def _cargar() -> dict:
    """Lee la versión champion (una vez): estimacion + tarjeta del bundle."""
    if "bundle" not in _cache:
        v = (REGISTRO / "champion").read_text().strip()
        carpeta = REGISTRO / v
        _cache["bundle"] = {
            "version": v,
            "estimacion": json.loads((carpeta / "estimacion.json").read_text()),
            "tarjeta": json.loads((carpeta / "tarjeta.json").read_text()),
        }
    return _cache["bundle"]


def salud() -> dict:
    b = _cargar()
    return {"estado": "ok", "version": b["version"],
            "estimando": b["tarjeta"]["estimando"]}


def efecto() -> dict:
    """El efecto poblacional del prototipo, con su incertidumbre y su versión.

    Estimador principal: AIPW con cross-fitting (doblemente robusto; el OLS
    queda como referencia en el artefacto, no en la respuesta).
    """
    b = _cargar()
    e = b["estimacion"]
    return {
        "estado": "respuesta",
        "estimando": b["tarjeta"]["estimando"],
        "estimador": e["estimador_principal"],
        "efecto": round(e["ate_aipw"], 1),
        "unidad": "USD de 1978",
        "ic95": [round(x, 1) for x in e["ic_aipw"]],
        "que_cubre_el_ic": "el ATE poblacional (no un efecto individual)",
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
    fuera = []
    for c, (lo, hi) in rangos.items():
        if c in perfil and not (lo <= perfil[c] <= hi):
            fuera.append(f"{c}={perfil[c]} fuera de [{lo:.1f}, {hi:.1f}]")
    if fuera:
        return {"estado": "abstencion",
                "motivo": "; ".join(fuera),
                "version": b["version"]}
    # dentro del soporte: el efecto del estrato declarado en la tarjeta
    est = b["estimacion"]["estratos"]
    hoja = est["hojas"].get(str(int(perfil.get("nodegree", 1))))
    if hoja is None:
        r = efecto()
        r["nota"] = "sin estrato declarado para este perfil"
        return r
    return {
        "estado": "respuesta",
        "estimando": f"efecto del estrato '{hoja['etiqueta']}' (corte por {est['variable']})",
        "estimador": b["estimacion"]["estimador_principal"],
        "efecto": round(hoja["efecto"], 1),
        "unidad": "USD de 1978",
        "ic95": [round(x, 1) for x in hoja["ic"]],
        "que_cubre_el_ic": "la media de scores AIPW del estrato (no un efecto individual)",
        "nota": "heterogeneidad sugerida; los intervalos de los estratos se solapan: "
                "no afirmar targeting con esto solo",
        "version": b["version"],
    }
