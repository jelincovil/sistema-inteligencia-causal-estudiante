"""humo.py — Prueba de humo del servicio (TestClient, sin levantar puerto).

Cubre los tres invariantes del servicio del prototipo:
  1. /efecto devuelve efecto + IC + versión (el bundle viaja).
  2. /consulta fuera del soporte se abstiene SIN ningún número.
  3. Dos llamadas idénticas devuelven exactamente lo mismo.
"""
from __future__ import annotations

from fastapi.testclient import TestClient

from servicio import app

c = TestClient(app)


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

    dentro = {"age": 30, "educ": 10, "black": 1, "hispan": 0,
              "married": 0, "nodegree": 1, "re74": 2000, "re75": 1500}
    r1 = c.post("/consulta", json=dentro)
    j1 = r1.json()
    ok &= r1.status_code == 200 and j1["estado"] == "respuesta"
    print(f"/consulta dentro: {r1.status_code} estado={j1['estado']} efecto={j1.get('efecto')}")

    fuera = dict(dentro, age=99)
    r2 = c.post("/consulta", json=fuera)
    j2 = r2.json()
    ok &= (r2.status_code == 200 and j2["estado"] == "abstencion"
           and "efecto" not in j2)
    print(f"/consulta fuera (age=99): {r2.status_code} estado={j2['estado']} "
          f"motivo={j2['motivo']} (sin número)")

    r3 = c.post("/consulta", json=dentro)
    ok &= r3.json() == j1
    print(f"determinismo: dos llamadas idénticas -> {'iguales' if r3.json() == j1 else 'DISTINTAS'}")

    print("\nHUMO:", "OK" if ok else "FALLÓ")
    return 0 if ok else 1


if __name__ == "__main__":
    raise SystemExit(main())
