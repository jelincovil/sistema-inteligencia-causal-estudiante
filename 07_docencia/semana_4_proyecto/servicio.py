"""servicio.py — FastAPI del prototipo (envoltorio fino de servicio_core).

Arranque:  uvicorn servicio:app --port 8000
Humo:      python humo.py

Cada ruta entrega JSON por defecto y un informe legible con `?formato=texto`.
"""
from __future__ import annotations

from fastapi import FastAPI, Query
from fastapi.responses import PlainTextResponse

import servicio_core as nucleo

app = FastAPI(title="Puente — prototipo causal local (semana 4)")


def _responder(payload: dict, formato: str):
    if formato.lower() in ("texto", "txt", "plain"):
        return PlainTextResponse(nucleo.formatear(payload))
    return payload


@app.get("/salud")
def salud() -> dict:
    return nucleo.salud()


@app.get("/efecto")
def efecto(formato: str = Query("json", description="json | texto")):
    """Efecto poblacional (ATE) con su IC, o su versión legible."""
    return _responder(nucleo.efecto(), formato)


@app.post("/consulta")
def consulta(perfil: dict, formato: str = Query("json", description="json | texto")):
    """Perfil: {age, educ, black, hispan, married, nodegree, re74, re75}."""
    return _responder(nucleo.consulta(perfil), formato)


@app.post("/efecto_individual")
def efecto_individual(perfil: dict,
                      formato: str = Query("json", description="json | texto")):
    """Efecto esperado para un perfil nuevo (proyección lineal del score AIPW).

    Perfil: todas las covariables del escenario. Fuera del soporte de
    entrenamiento responde abstención (HTTP 200, sin número).
    """
    return _responder(nucleo.efecto_individual(perfil), formato)
