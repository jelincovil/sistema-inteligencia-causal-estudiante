"""estimacion.py — El efecto con incertidumbre, y los diagnósticos del dato.

Bloque 3 de la clase: OLS con los controles del esquema + IC; diagnóstico de
solapamiento (propensity, ESS de Kish, SMD); y la trampa temporal (score_post)
que vacía el coeficiente. Escribe artifacts/estimacion.json para el registro.
"""
from __future__ import annotations

import json

import numpy as np
from scipy.optimize import minimize

from datos import EsquemaCausal, leer
from rutas import ARTEFACTOS

SEMILLA = 4242


# ------------------------------------------------------------------ estimador

def ate_ols(col: dict, esquema: EsquemaCausal, extra=None) -> dict:
    """ATE por OLS con los controles del esquema (+ opcional una columna trampa)."""
    n = len(col[esquema.tratamiento])
    D, Y = col[esquema.tratamiento], col[esquema.resultado]
    columnas = [col[c] for c in esquema.covariables] + (
        [extra["valores"]] if extra else [])
    M = np.column_stack([np.ones(n), D, *columnas])
    beta, *_ = np.linalg.lstsq(M, Y, rcond=None)
    resid = Y - M @ beta
    s2 = resid @ resid / (n - M.shape[1])
    var = s2 * np.linalg.inv(M.T @ M)[1, 1]
    se = float(np.sqrt(var))
    ate = float(beta[1])
    return {"ate": ate, "se": se, "ic": [ate - 1.96 * se, ate + 1.96 * se]}


# ------------------------------------------------------- diagnóstico de soporte

def propensity(X: np.ndarray, D: np.ndarray) -> np.ndarray:
    """Logística por máxima verosimilitud (BFGS, covariables estandarizadas)."""
    Z = (X - X.mean(0)) / X.std(0)
    def nll(w):
        eta = Z @ w[1:] + w[0]
        return float(np.sum(np.logaddexp(0, eta) - D * eta))
    r = minimize(nll, np.zeros(Z.shape[1] + 1), method="BFGS")
    return 1 / (1 + np.exp(-(Z @ r.x[1:] + r.x[0])))


def ess_kish(D: np.ndarray, e: np.ndarray) -> float:
    """Tamaño efectivo de la ponderación IPW: ESS = (sum w)^2 / sum w^2."""
    w = np.where(D == 1, 1 / np.clip(e, 1e-6, 1), 1 / np.clip(1 - e, 1e-6, 1))
    return float(w.sum() ** 2 / (w ** 2).sum())


def smd(v: np.ndarray, D: np.ndarray) -> float:
    """Diferencia media estandarizada de una covariable, tratados vs controles."""
    t, c = v[D == 1], v[D == 0]
    return float((t.mean() - c.mean()) / np.sqrt((t.var() + c.var()) / 2))



# --------------------------------------------------- AIPW con cross-fitting

def _ajustar_lineal(Xm: np.ndarray, y: np.ndarray) -> np.ndarray:
    M = np.column_stack([np.ones(len(y)), Xm])
    return np.linalg.lstsq(M, y, rcond=None)[0]


def _propensity_fit(Xm: np.ndarray, d: np.ndarray):
    """Logística ajustada en Xm/d; devuelve una función que predice en nuevas filas."""
    med, desv = Xm.mean(0), Xm.std(0)
    Z = (Xm - med) / desv
    def nll(w):
        eta = Z @ w[1:] + w[0]
        return float(np.sum(np.logaddexp(0, eta) - d * eta))
    r = minimize(nll, np.zeros(Xm.shape[1] + 1), method="BFGS")
    def predecir(Xn: np.ndarray) -> np.ndarray:
        Zn = (Xn - med) / desv
        return 1 / (1 + np.exp(-(Zn @ r.x[1:] + r.x[0])))
    return predecir


def aipw_crossfit(col: dict, esquema: EsquemaCausal, k: int = 5) -> dict:
    """ATE doblemente robusto con cross-fitting (el DML del Cap. 9 en miniatura).

    Ningún nuisance ve a la unidad que predice: los folds se ajustan fuera y
    predicen dentro. El score por unidad es la influence function del ATE.
    """
    n = len(col[esquema.tratamiento])
    D, Y = col[esquema.tratamiento], col[esquema.resultado]
    X = np.column_stack([col[c] for c in esquema.covariables])
    g = np.random.default_rng(SEMILLA)
    folds = np.array_split(g.permutation(n), k)
    mu1, mu0, e = np.empty(n), np.empty(n), np.empty(n)
    for f in folds:
        m = np.ones(n, bool)
        m[f] = False
        Xtr, Dtr, Ytr = X[m], D[m], Y[m]
        b1 = _ajustar_lineal(Xtr[Dtr == 1], Ytr[Dtr == 1])
        b0 = _ajustar_lineal(Xtr[Dtr == 0], Ytr[Dtr == 0])
        Mf = np.column_stack([np.ones(len(f)), X[f]])
        mu1[f] = Mf @ b1
        mu0[f] = Mf @ b0
        e[f] = _propensity_fit(Xtr, Dtr)(X[f])
    e = np.clip(e, 0.05, 0.95)  # trimming declarado: estimando = ATE con solape
    score = (mu1 - mu0 + D * (Y - mu1) / e - (1 - D) * (Y - mu0) / (1 - e))
    ate = float(score.mean())
    se = float(score.std(ddof=1) / np.sqrt(n))
    return {"ate": ate, "se": se, "ic": [ate - 1.96 * se, ate + 1.96 * se],
            "scores": score}


def estratos_nodegree(score: np.ndarray, col: dict, esquema: EsquemaCausal) -> dict:
    """Un solo corte de heterogeneidad, pre-declarado en la tarjeta.

    No es un CATE: es la media de scores AIPW de cada estrato, con su IC.
    La regla del corte está en la tarjeta (interpretabilidad y balance del
    train; NO la ganancia de varianza — ver guía del profesor).
    """
    nd = col["nodegree"]
    hojas = {}
    for valor, etiqueta in ((1, "sin título"), (0, "con título")):
        m = nd == valor
        s = score[m]
        se = float(s.std(ddof=1) / np.sqrt(m.sum()))
        hojas[str(valor)] = {
            "etiqueta": etiqueta, "n": int(m.sum()),
            "efecto": float(s.mean()), "se": se,
            "ic": [float(s.mean() - 1.96 * se), float(s.mean() + 1.96 * se)],
        }
    return {"variable": "nodegree",
            "regla": "corte pre-declarado por interpretabilidad; no seleccionado por ganancia",
            "hojas": hojas}


# ------------------------------------------------------------------- la trampa

def trampa_score_post(col: dict, esquema: EsquemaCausal) -> dict:
    """Columna derivada del resultado: 'score de éxito' calculado con re78."""
    g = np.random.default_rng(SEMILLA)
    D, Y = col[esquema.tratamiento], col[esquema.resultado]
    score = 0.6 * Y + 0.4 * D + g.normal(0, 500, len(D))
    return ate_ols(col, esquema, extra={"valores": score})


# ----------------------------------------------------------------------- main

def estimar() -> dict:
    esquema = EsquemaCausal()
    col = leer("train")
    D, Y = col[esquema.tratamiento], col[esquema.resultado]
    X = np.column_stack([col[c] for c in esquema.covariables])

    crude = float(Y[D == 1].mean() - Y[D == 0].mean())
    ajustado = ate_ols(col, esquema)
    trampa = trampa_score_post(col, esquema)
    aipw = aipw_crossfit(col, esquema)
    estratos = estratos_nodegree(aipw["scores"], col, esquema)

    e = propensity(X, D)
    solape = float(((e >= 0.05) & (e <= 0.95)).mean())
    smds = {c: smd(col[c], D) for c in esquema.covariables}

    resultado = {
        "estimando": "ATE de treatment sobre re78 (efecto total)",
        "n": int(len(D)),
        "tratados": int(D.sum()),
        "diferencia_cruda": crude,
        "ate_ols": ajustado["ate"], "se": ajustado["se"], "ic95": ajustado["ic"],
        "estimador_principal": "AIPW con cross-fitting (K=5, nuisances fuera de muestra)",
        "ate_aipw": aipw["ate"], "se_aipw": aipw["se"], "ic_aipw": aipw["ic"],
        "estratos": estratos,
        "ate_trampa_score_post": trampa["ate"],
        "ess": ess_kish(D, e), "ess_sobre_n": ess_kish(D, e) / len(D),
        "rango_e": [float(e.min()), float(e.max())],
        "fraccion_solapamiento": solape,
        "smd_max": max(abs(v) for v in smds.values()),
        "smd_por_covariable": {k: round(v, 3) for k, v in smds.items()},
        "rangos_covariables": {c: [float(col[c].min()), float(col[c].max())]
                               for c in esquema.covariables},
        "semilla": SEMILLA,
    }
    return resultado


if __name__ == "__main__":
    r = estimar()
    ARTEFACTOS.mkdir(exist_ok=True)
    (ARTEFACTOS / "estimacion.json").write_text(
        json.dumps(r, indent=2, ensure_ascii=False))
    print(f"diferencia cruda E[Y|D=1]-E[Y|D=0] = {r['diferencia_cruda']:.1f} USD")
    print(f"ATE OLS (8 controles) = {r['ate_ols']:.1f} | SE = {r['se']:.1f} "
          f"| IC95 = [{r['ic95'][0]:.1f}, {r['ic95'][1]:.1f}]")
    print(f"AIPW cross-fitting K=5 = {r['ate_aipw']:.1f} | SE = {r['se_aipw']:.1f} "
          f"| IC95 = [{r['ic_aipw'][0]:.1f}, {r['ic_aipw'][1]:.1f}]")
    print(f"trampa score_post      = {r['ate_trampa_score_post']:.1f}  "
          "<- el coeficiente se vació")
    for v, h in r["estratos"]["hojas"].items():
        print(f"estrato nodegree={v} ({h['etiqueta']}, n={h['n']}): "
              f"efecto {h['efecto']:.1f} IC95 [{h['ic'][0]:.1f}, {h['ic'][1]:.1f}]")
    print(f"ESS = {r['ess']:.0f} (ESS/n = {r['ess_sobre_n']:.2f}) | "
          f"rango e = [{r['rango_e'][0]:.3f}, {r['rango_e'][1]:.3f}] | "
          f"solapamiento = {r['fraccion_solapamiento']:.0%}")
    print(f"SMD máx = {r['smd_max']:.2f}")
    print("artefacto: artifacts/estimacion.json")
