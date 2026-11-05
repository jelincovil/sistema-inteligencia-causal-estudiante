"""servicio.py — FastAPI del prototipo (envoltorio fino de servicio_core).

Arranque:  uvicorn servicio:app --port 8000
Humo:      python humo.py
"""
from __future__ import annotations

from fastapi import FastAPI

import servicio_core as nucleo

app = FastAPI(title="Puente — prototipo causal local (semana 4)")


@app.get("/salud")
def salud() -> dict:
    return nucleo.salud()


@app.get("/efecto")
def efecto() -> dict:
    return nucleo.efecto()


@app.post("/consulta")
def consulta(perfil: dict) -> dict:
    """Perfil: {age, educ, black, hispan, married, nodegree, re74, re75}."""
    return nucleo.consulta(perfil)
