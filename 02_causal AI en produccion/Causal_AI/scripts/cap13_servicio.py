#!/usr/bin/env python3
"""Cap. 13 — Servicio y abstención: el bundle viaja, el dato no.

El servicio responde con efecto + IC + versión para perfiles dentro del
soporte, y se abstiene (sin número) fuera del soporte. Determinismo: dos
llamadas idénticas devuelven lo mismo. Semilla 20260713.
"""
import csv
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parents[3]
TRAIN = RAIZ / "data_benchmark_causal" / "causal_benchmark_synthetic" / "datasets" / "real" / "jobs" / "observed_train.csv"

COVS = ["age", "educ", "black", "hispan", "married", "nodegree", "re74", "re75"]


def leer():
    with open(TRAIN) as f:
        filas = list(csv.DictReader(f))
    col = {k: np.array([float(r[k]) for r in filas]) for k in filas[0] if k != "row_id"}
    return col


def ate_ols(col):
    n = len(col["treatment"])
    D, Y = col["treatment"], col["re78"]
    X = np.column_stack([col[c] for c in COVS])
    M = np.column_stack([np.ones(n), D, X])
    beta, *_ = np.linalg.lstsq(M, Y, rcond=None)
    resid = Y - M @ beta
    s2 = resid @ resid / (n - M.shape[1])
    se = float(np.sqrt(s2 * np.linalg.inv(M.T @ M)[1, 1]))
    ate = float(beta[1])
    return ate, se


def construir_servicio(col):
    ate, se = ate_ols(col)
    rangos = {c: (float(col[c].min()), float(col[c].max())) for c in COVS}
    bundle = {
        "version": "v0001",
        "estimando": "ATE de treatment sobre re78 (efecto total)",
        "efecto": round(ate, 1),
        "ic95": [round(ate - 1.96 * se, 1), round(ate + 1.96 * se, 1)],
        "unidad": "USD de 1978",
        "que_cubre_el_ic": "el ATE poblacional (no un efecto individual)",
        "rangos": rangos,
    }
    def consulta(perfil):
        fuera = []
        for c, (lo, hi) in rangos.items():
            if c in perfil and not (lo <= perfil[c] <= hi):
                fuera.append(f"{c}={perfil[c]} fuera de [{lo:.1f}, {hi:.1f}]")
        if fuera:
            return {"estado": "abstencion", "motivo": "; ".join(fuera), "version": bundle["version"]}
        return {
            "estado": "respuesta",
            "estimando": bundle["estimando"],
            "efecto": bundle["efecto"],
            "ic95": bundle["ic95"],
            "unidad": bundle["unidad"],
            "que_cubre_el_ic": bundle["que_cubre_el_ic"],
            "version": bundle["version"],
            "nota": "efecto poblacional del soporte declarado",
        }
    return consulta


def main():
    col = leer()
    consulta = construir_servicio(col)

    dentro = {"age": 30, "educ": 10, "black": 1, "hispan": 0,
              "married": 0, "nodegree": 1, "re74": 2000, "re75": 1500}
    fuera = dict(dentro, age=99)

    print("== servicio causal: respuesta y abstención ==")
    r1 = consulta(dentro)
    print(f"/consulta dentro : estado={r1['estado']} efecto={r1.get('efecto')} ic95={r1.get('ic95')} version={r1['version']}")
    r2 = consulta(fuera)
    print(f"/consulta fuera  : estado={r2['estado']} motivo={r2['motivo']} version={r2['version']}")
    r3 = consulta(dentro)
    print(f"determinismo     : {'iguales' if r1 == r3 else 'DISTINTAS'}")
    print(f"HUMO: {'OK' if r1['estado']=='respuesta' and r2['estado']=='abstencion' and r1==r3 else 'FALLÓ'}")


if __name__ == "__main__":
    main()
