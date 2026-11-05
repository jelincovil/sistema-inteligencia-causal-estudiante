"""humo.py — Prueba de humo del servicio (TestClient, sin levantar puerto).

Cubre los tres invariantes del servicio del prototipo:
  1. /efecto devuelve efecto + IC + versión (el bundle viaja).
  2. /consulta fuera del soporte se abstiene SIN ningún número.
  3. Dos llamadas idénticas devuelven exactamente lo mismo.
"""
from __future__ import annotations

from fastapi.testclient import TestClient

import servicio_core as nucleo
from servicio import app
from rutas import ESCENARIO

c = TestClient(app)

# Perfil dentro del soporte de real/jobs (el del kit). Para otros escenarios se
# construye desde los rangos del bundle: el humo no lee CSV.
PERFIL_JOBS = {"age": 30, "educ": 10, "black": 1, "hispan": 0,
               "married": 0, "nodegree": 1, "re74": 2000, "re75": 1500}
PERFIL_JOBS_FUERA = dict(PERFIL_JOBS, age=99)


def _perfil_desde_bundle(fuera: bool) -> dict:
    b = nucleo._cargar()
    est = b["estimacion"]
    rangos = est["rangos_covariables"]
    corte, umbral = est["estratos"]["variable"], est["estratos"]["umbral"]
    perfil = {c: (lo + hi) / 2 for c, (lo, hi) in rangos.items()}
    perfil[corte] = umbral + (rangos[corte][1] - umbral) / 2
    if fuera:
        primera = next(iter(rangos))
        perfil[primera] = rangos[primera][1] + 1.0
    return perfil


def perfiles() -> tuple[dict, dict]:
    if ESCENARIO == "real/jobs":
        return PERFIL_JOBS, PERFIL_JOBS_FUERA
    return _perfil_desde_bundle(False), _perfil_desde_bundle(True)


def main() -> int:
    ok = True

    r = c.get("/salud")
    ok &= r.status_code == 200 and r.json()["estado"] == "ok"
    print(f"/salud: {r.status_code} {r.json()}")

    r = c.get("/efecto")
    j = r.json()
    ok &= r.status_code == 200 and "efecto" in j and "ic95" in j and "version" in j
    print(f"/efecto: {r.status_code} efecto={j['efecto']} ic95={j['ic95']} "
          f"version={j['version']}")

    dentro, fuera = perfiles()
    r1 = c.post("/consulta", json=dentro)
    j1 = r1.json()
    ok &= r1.status_code == 200 and j1["estado"] == "respuesta"
    print(f"/consulta dentro: {r1.status_code} estado={j1['estado']} efecto={j1.get('efecto')}")

    r2 = c.post("/consulta", json=fuera)
    j2 = r2.json()
    cambiada = next(cov for cov in dentro if dentro[cov] != fuera[cov])
    ok &= (r2.status_code == 200 and j2["estado"] == "abstencion"
           and "efecto" not in j2)
    print(f"/consulta fuera ({cambiada}={fuera[cambiada]:g}): {r2.status_code} "
          f"estado={j2['estado']} motivo={j2['motivo']} (sin número)")

    r3 = c.post("/consulta", json=dentro)
    ok &= r3.json() == j1
    print(f"determinismo: dos llamadas idénticas -> {'iguales' if r3.json() == j1 else 'DISTINTAS'}")

    print("\nHUMO:", "OK" if ok else "FALLÓ")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
