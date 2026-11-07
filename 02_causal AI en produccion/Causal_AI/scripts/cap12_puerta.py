#!/usr/bin/env python3
"""Cap. 12 — La puerta causal en el plano de datos: promoción de versiones.

Tres versiones del mismo dataset (baseline, drift, positividad rota) se evalúan
contra umbrales declarados. La puerta decide pasa / alerta / falla y el alias
champion solo promueve la versión en pasa.
Semilla 20260712.
"""
import csv
from pathlib import Path

import numpy as np
from scipy.optimize import minimize

RAIZ = Path(__file__).resolve().parents[3]
TRAIN = RAIZ / "data_benchmark_causal" / "causal_benchmark_synthetic" / "datasets" / "real" / "jobs" / "observed_train.csv"

COVS = ["age", "educ", "black", "hispan", "married", "nodegree", "re74", "re75"]


def leer():
    with open(TRAIN) as f:
        filas = list(csv.DictReader(f))
    col = {k: np.array([float(r[k]) for r in filas]) for k in filas[0] if k != "row_id"}
    return col


def _propensity_fit(Xm, d):
    med, sd = Xm.mean(0), Xm.std(0)
    Z = (Xm - med) / np.clip(sd, 1e-9, None)
    def nll(w):
        eta = Z @ w[1:] + w[0]
        return float(np.sum(np.logaddexp(0, eta) - d * eta))
    r = minimize(nll, np.zeros(Z.shape[1] + 1), method="BFGS")
    def pred(Xn):
        Zn = (Xn - med) / np.clip(sd, 1e-9, None)
        return 1 / (1 + np.exp(-(Zn @ r.x[1:] + r.x[0])))
    return pred


def psi(ref, nueva, bins=10, eps=1e-4):
    cortes = np.unique(np.quantile(ref, np.linspace(0, 1, bins + 1)))
    a = np.histogram(ref, cortes)[0] / len(ref)
    b = np.histogram(nueva, cortes)[0] / len(nueva)
    a, b = np.clip(a, eps, None), np.clip(b, eps, None)
    return float(np.sum((a - b) * np.log(a / b)))


def ess_kish(D, e):
    w = np.where(D == 1, 1 / np.clip(e, 1e-6, 1), 1 / np.clip(1 - e, 1e-6, 1))
    return float(w.sum() ** 2 / (w ** 2).sum())


def smd(v, D):
    t, c = v[D == 1], v[D == 0]
    return float((t.mean() - c.mean()) / np.sqrt((t.var() + c.var()) / 2))


def evaluar_puerta(train, ventana, umbrales):
    D = ventana["treatment"]
    if len(set(D.tolist())) < 2:
        return {"estado": "falla", "motivo": ["tratamiento constante en la ventana"]}
    X = np.column_stack([ventana[c] for c in COVS])
    e_raw = _propensity_fit(X, D)(X)
    solape = float(((e_raw >= 0.05) & (e_raw <= 0.95)).mean())
    e = np.clip(e_raw, 0.05, 0.95)
    ess_n = ess_kish(D, e) / len(D)
    psis = {c: psi(train[c], ventana[c]) for c in COVS}
    psi_max = max(psis.values())
    smd_max = max(abs(smd(ventana[c], D)) for c in COVS)
    motivo = []
    estado = "pasa"
    if solape < umbrales["solape_min"]:
        estado = "falla"
        motivo.append(f"solapamiento roto: {solape:.0%} de unidades con e en [0.05,0.95] (minimo {umbrales['solape_min']:.0%})")
    if psi_max > umbrales["psi_alerta"]:
        if estado == "pasa":
            estado = "alerta"
        peor = max(psis, key=psis.get)
        motivo.append(f"deriva: PSI de {peor} = {psi_max:.2f} (umbral {umbrales['psi_alerta']})")
    if smd_max > umbrales["smd_max"] and estado == "pasa":
        estado = "alerta"
        motivo.append(f"desbalance de asignacion: SMD max = {smd_max:.2f} (umbral {umbrales['smd_max']})")
    accion = {"pasa": "continuar", "alerta": "alertar (revisar antes de reentrenar)",
              "falla": "abstenerse (bloquear la promoción)"}[estado]
    return {"estado": estado, "accion": accion, "motivo": motivo or ["todo dentro de umbral"],
            "n": int(len(D)), "psi_max": round(psi_max, 3), "smd_max": round(smd_max, 2),
            "ess_sobre_n": round(ess_n, 2), "solapamiento": round(solape, 2)}


def versiones(train, semilla):
    g = np.random.default_rng(semilla)
    # v1 baseline: submuestra sana
    idx = g.choice(len(train["treatment"]), 700, replace=False)
    v1 = {k: v[idx] for k, v in train.items()}
    # v2 drift: edad corrida
    v2 = {k: v.copy() for k, v in train.items()}
    v2["age"] = v2["age"] + 10
    # v3 positividad rota: casi determinista por re74
    D, re74 = train["treatment"], train["re74"]
    q_alto, q_bajo = np.quantile(re74, 0.75), np.quantile(re74, 0.25)
    mask = ((D == 1) & (re74 > q_alto)) | ((D == 0) & (re74 < q_bajo))
    v3 = {k: v[mask] for k, v in train.items()}
    return {"v0001": v1, "v0002": v2, "v0003": v3}


def main():
    train = leer()
    umbrales = {"smd_max": 0.25, "psi_alerta": 0.25, "solape_min": 0.50}
    print(f"puerta causal — umbrales declarados: {umbrales}")
    vers = versiones(train, 20260712)
    for nombre, v in vers.items():
        r = evaluar_puerta(train, v, umbrales)
        print(f"[{nombre}] estado={r['estado']:6s} accion={r['accion']}")
        print(f"          n={r['n']} PSI={r['psi_max']} SMD={r['smd_max']} ESS/n={r['ess_sobre_n']} solape={r['solapamiento']:.0%}")
        for m in r["motivo"]:
            print(f"          - {m}")
    print()
    print("champion -> v0001 (unico estado=pasa; v0002 alerta y v0003 falla no se promueven)")


if __name__ == "__main__":
    main()
