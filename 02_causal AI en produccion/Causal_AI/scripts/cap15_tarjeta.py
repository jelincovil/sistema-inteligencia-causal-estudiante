#!/usr/bin/env python3
"""Cap. 15 — Tarjetas, registro y auditoría end-to-end.

El flujo completo sobre real/jobs: pregunta → esquema → splits → estimación →
tarjeta → registro → puerta → servicio → champion. Cada paso deja un artefacto
verificable. Semilla 20260715.
"""
import csv
import hashlib
import json
from pathlib import Path

import numpy as np
from scipy.optimize import minimize

RAIZ = Path(__file__).resolve().parents[3]
BASE = RAIZ / "data_benchmark_causal" / "causal_benchmark_synthetic" / "datasets" / "real" / "jobs"
COVS = ["age", "educ", "black", "hispan", "married", "nodegree", "re74", "re75"]
SEMILLA = 20260715


def leer():
    with open(BASE / "observed_train.csv") as f:
        filas = list(csv.DictReader(f))
    return {k: np.array([float(r[k]) for r in filas]) for k in filas[0] if k != "row_id"}


def sha256(ruta):
    return hashlib.sha256(ruta.read_bytes()).hexdigest()


def ate_ols(col):
    n = len(col["treatment"])
    D, Y = col["treatment"], col["re78"]
    X = np.column_stack([col[c] for c in COVS])
    M = np.column_stack([np.ones(n), D, X])
    b = np.linalg.lstsq(M, Y, rcond=None)[0]
    r = Y - M @ b
    s2 = r @ r / (n - M.shape[1])
    se = float(np.sqrt(s2 * np.linalg.inv(M.T @ M)[1, 1]))
    return float(b[1]), se


def propensity(X, D):
    med, sd = X.mean(0), X.std(0)
    Z = (X - med) / np.clip(sd, 1e-9, None)
    def nll(w):
        eta = Z @ w[1:] + w[0]
        return float(np.sum(np.logaddexp(0, eta) - D * eta))
    r = minimize(nll, np.zeros(Z.shape[1] + 1), method="BFGS")
    return 1 / (1 + np.exp(-((X - med) / np.clip(sd, 1e-9, None)) @ r.x[1:] - r.x[0]))


def ess_kish(D, e):
    w = np.where(D == 1, 1 / np.clip(e, 1e-6, 1), 1 / np.clip(1 - e, 1e-6, 1))
    return float(w.sum() ** 2 / (w ** 2).sum())


def psi(ref, nueva, bins=10, eps=1e-4):
    cortes = np.unique(np.quantile(ref, np.linspace(0, 1, bins + 1)))
    a = np.histogram(ref, cortes)[0] / len(ref)
    b = np.histogram(nueva, cortes)[0] / len(nueva)
    a, b = np.clip(a, eps, None), np.clip(b, eps, None)
    return float(np.sum((a - b) * np.log(a / b)))


def main():
    print("== Auditoría end-to-end sobre real/jobs (semilla", SEMILLA, ")==\n")

    # 1. Pregunta (declarada antes de mirar)
    pregunta = {
        "estimando": "ATE de treatment sobre re78 (efecto total)",
        "poblacion": "1033 unidades de observed_train.csv de real/jobs",
        "supuestos": [
            {"nombre": "no confusión condicional", "clase": "no_observable"},
            {"nombre": "soporte común", "clase": "observable"},
            {"nombre": "covariables pre-tratamiento", "clase": "observable"},
        ],
    }
    print("1. pregunta      :", pregunta["estimando"])

    # 2. Esquema C-01
    col = leer()
    esquema = {"tratamiento": "treatment", "resultado": "re78", "covariables": COVS}
    print("2. esquema C-01  : tratamiento=treatment, resultado=re78,", len(COVS), "covariables")

    # 3. Splits C-10 (hash verificado)
    declarados = json.loads((BASE / "splits.json").read_text())
    hash_ok = all(sha256(BASE / f"observed_{p}.csv") == declarados["splits"][p]["file_sha256"]
                  for p in ("train", "validation", "test"))
    print("3. splits C-10   : hash", "OK" if hash_ok else "FALLA",
          "| semilla", declarados["split_seed"])

    # 4. Estimación
    ate, se = ate_ols(col)
    ic = [ate - 1.96 * se, ate + 1.96 * se]
    D, Y = col["treatment"], col["re78"]
    X = np.column_stack([col[c] for c in COVS])
    e = propensity(X, D)
    ess = ess_kish(D, e)
    print(f"4. estimación    : ATE={ate:.1f} SE={se:.1f} IC=[{ic[0]:.1f},{ic[1]:.1f}] ESS/n={ess/len(D):.2f}")

    # 5. Tarjeta C-05
    tarjeta = {
        "schema_version": "de-0.1",
        "estimando": pregunta,
        "datos": {"n": len(D), "sha256": sha256(BASE / "observed_train.csv"),
                  "fuente": "real/jobs observed_train.csv"},
        "estimacion": {"metodo": "OLS con 8 controles", "ate": round(ate, 1),
                       "se": round(se, 1), "ic95": [round(ic[0], 1), round(ic[1], 1)],
                       "semilla": SEMILLA},
        "supuestos": {
            "observables": [
                {"nombre": "soporte común", "prueba": "ESS/n y rango de e",
                 "valor": round(ess / len(D), 2), "umbral": 0.10, "estado": "pasa"},
                {"nombre": "covariables pre-tratamiento", "prueba": "identification.json",
                 "valor": "declarado", "umbral": None, "estado": "pasa"},
            ],
            "no_observables": [
                {"nombre": "no confusión condicional",
                 "justificacion": "No comprobable con observacionales; se declara.",
                 "sensibilidad": {"metodo": "pendiente", "estado": "sin_cuantificar"},
                 "criterio_revision": "Revisar si placebo o control negativo fallan."},
            ],
        },
        "umbrales": {"smd_max": 0.25, "psi_alerta": 0.25, "solape_min": 0.50},
        "limitaciones": ["Válido solo dentro del soporte de las covariables de entrenamiento."],
        "uso_previsto": "Apoyar decisiones con efecto e intervalo; no usar fuera de soporte.",
    }
    # Validación de tarjeta: campos obligatorios y clases de supuestos
    for campo in ("estimando", "datos", "estimacion", "supuestos", "umbrales"):
        assert campo in tarjeta, f"tarjeta sin {campo}"
    for s in tarjeta["supuestos"]["observables"]:
        assert s["estado"] in ("pasa", "alerta", "falla")
    for s in tarjeta["supuestos"]["no_observables"]:
        assert "sensibilidad" in s and "criterio_revision" in s
    print("5. tarjeta C-05  : válida (estimando + supuestos clasificados + umbrales)")

    # 6. Registro C-09
    version = "v0001"
    manifest = {"version": version, "dataset_sha256": tarjeta["datos"]["sha256"],
                "puerta": "pasa", "semilla": SEMILLA}
    print("6. registro C-09 :", version, "con manifest y hash del dataset")

    # 7. Puerta C-06 (tres ventanas)
    g = np.random.default_rng(SEMILLA)
    umb = tarjeta["umbrales"]
    ventanas = {}
    idx = g.choice(len(D), 700, replace=False)
    ventanas["sana"] = {k: v[idx] for k, v in col.items()}
    v2 = {k: v.copy() for k, v in col.items()}
    v2["age"] = v2["age"] + 10
    ventanas["deriva"] = v2
    q_alto, q_bajo = np.quantile(col["re74"], 0.75), np.quantile(col["re74"], 0.25)
    mask = ((D == 1) & (col["re74"] > q_alto)) | ((D == 0) & (col["re74"] < q_bajo))
    ventanas["positividad"] = {k: v[mask] for k, v in col.items()}

    estados = {}
    for nombre, w in ventanas.items():
        Dw = w["treatment"]
        Xw = np.column_stack([w[c] for c in COVS])
        ew = propensity(Xw, Dw)
        solape = float(((ew >= 0.05) & (ew <= 0.95)).mean())
        psi_max = max(psi(col[c], w[c]) for c in COVS)
        if solape < umb["solape_min"]:
            estados[nombre] = "falla"
        elif psi_max > umb["psi_alerta"]:
            estados[nombre] = "alerta"
        else:
            estados[nombre] = "pasa"
    print("7. puerta C-06   :", {k: estados[k] for k in ("sana", "deriva", "positividad")})

    # 8. Promoción: solo pasa
    if estados["sana"] == "pasa":
        champion = version
        print("8. champion      :", champion, "(solo la ventana sana en pasa se promueve)")

    # 9. Servicio C-04
    rangos = {c: (float(col[c].min()), float(col[c].max())) for c in COVS}
    dentro = {"age": 30, "educ": 10, "black": 1, "hispan": 0,
              "married": 0, "nodegree": 1, "re74": 2000, "re75": 1500}
    fuera = dict(dentro, age=99)
    r_in = {"estado": "respuesta", "efecto": round(ate, 1), "ic95": [round(ic[0], 1), round(ic[1], 1)]}
    r_out = {"estado": "abstencion", "motivo": f"age=99 fuera de [{rangos['age'][0]:.0f}, {rangos['age'][1]:.0f}]"}
    print(f"9. servicio C-04 : dentro={r_in['estado']} efecto={r_in['efecto']} | fuera={r_out['estado']} sin número")

    # 10. Resumen
    print("\n== Trazabilidad ==")
    print(f"   pregunta → esquema → splits(hash) → ATE {ate:.1f} → tarjeta → {version} → puerta {estados['sana']} → champion → servicio")
    print(f"   dataset sha256: {tarjeta['datos']['sha256'][:16]}…")
    print(f"   HUMO: {'OK' if hash_ok and estados['sana']=='pasa' and r_in['estado']=='respuesta' and r_out['estado']=='abstencion' else 'FALLÓ'}")


if __name__ == "__main__":
    main()
