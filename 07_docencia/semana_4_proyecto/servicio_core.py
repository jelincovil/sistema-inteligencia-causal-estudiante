"""servicio_core.py — [BLOQUE 6, min 115–140] El servicio: respuesta y abstención.

Se completa en vivo: la carga del bundle champion y la consulta con soporte.
"""
from __future__ import annotations

import json

from rutas import REGISTRO

_cache: dict = {}


def _cargar() -> dict:
    """Lee la versión champion (una vez): estimacion + tarjeta del bundle."""
    # TODO-19 (el bundle viaja): leer el alias champion, cargar estimacion.json
    # y tarjeta.json de esa versión y cachearlos en _cache["bundle"].
    # Pista: el servicio NO lee los CSV: solo los artefactos del registro.
    raise NotImplementedError("TODO-19 pendiente de completar")


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
        "efecto": round(e["ate_ols"], 1),
        "unidad": "USD de 1978",
        "ic95": [round(x, 1) for x in e["ic95"]],
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
    # TODO-20 (la abstención y el estrato): para cada covariable del perfil
    # fuera de su rango [lo, hi] del train, juntar el motivo; si hay alguno,
    # devolver {"estado": "abstencion", "motivo": ..., "version": ...} SIN
    # ningún número. Si no hay: el efecto del ESTRATO declarado en la tarjeta
    # (estimacion["estratos"]["hojas"][str(int(perfil.get("nodegree", 1)))])
    # con efecto, ic95, "que_cubre_el_ic", la nota de heterogeneidad y la
    # versión — no el efecto poblacional.
    raise NotImplementedError("TODO-20 pendiente de completar")


def efecto_lista_de_prueba() -> list[str]:
    """Auxiliar para el humo: las rutas que la prueba de humo ejercita."""
    return ["/salud", "/efecto", "/consulta"]
