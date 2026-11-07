"""estimacion.py — [BLOQUE 3, min 35–60] El efecto con incertidumbre + diagnósticos.

Se completa en vivo: ate_ols, propensity, ess_kish, smd y la trampa.
"""
from __future__ import annotations

import json

import numpy as np
from scipy.optimize import minimize

from datos import EsquemaCausal, leer
from rutas import ARTEFACTOS

SEMILLA = 4242


def ate_ols(col: dict, esquema: EsquemaCausal, extra=None) -> dict:
    """ATE por OLS con los controles del esquema (+ columna trampa opcional)."""
    n = len(col[esquema.tratamiento])
    D, Y = col[esquema.tratamiento], col[esquema.resultado]
    columnas = [col[c] for c in esquema.covariables] + (
        [extra["valores"]] if extra else [])
    M = np.column_stack([np.ones(n), D, *columnas])
    # TODO-4 (el efecto): lstsq para beta; residuo; sigma2; y el SE del
    # coeficiente del tratamiento = sqrt(sigma2 * (M'M)^-1_[1,1]).
    # Pista: beta[1] es el ATE; devolver {"ate", "se", "ic"} con ic = ate ± 1.96*se.
    raise NotImplementedError("TODO-4 pendiente de completar")


def propensity(X: np.ndarray, D: np.ndarray) -> np.ndarray:
    """Logística por máxima verosimilitud (BFGS, covariables estandarizadas)."""
    Z = (X - X.mean(0)) / X.std(0)
    # TODO-5 (soporte): minimizar la negativa de la log-verosimilitud binaria:
    # nll(w) = sum(logaddexp(0, eta) - D*eta) con eta = Z @ w[1:] + w[0].
    # Pista: minimize(nll, np.zeros(p+1), method="BFGS"); devolver sigmoid(eta).
    raise NotImplementedError("TODO-5 pendiente de completar")


def ess_kish(D: np.ndarray, e: np.ndarray) -> float:
    """Tamaño efectivo de la ponderación IPW: ESS = (sum w)^2 / sum w^2."""
    # TODO-6 (ESS): w_i = 1/e si D=1, 1/(1-e) si D=0 (clip de e a [1e-6, 1-1e-6]).
    raise NotImplementedError("TODO-6 pendiente de completar")


def smd(v: np.ndarray, D: np.ndarray) -> float:
    """Diferencia media estandarizada: tratados vs controles (Cap. 7)."""
    # TODO-7 (balance): (media_t - media_c) / sqrt((var_t + var_c)/2).
    raise NotImplementedError("TODO-7 pendiente de completar")


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
    # TODO-21 (la innovación): para cada fold f —
    #   1. máscara m = todas las unidades menos f (entrenamiento del fold)
    #   2. b1 = _ajustar_lineal(X[Dtr==1], Y[Dtr==1]); b0 = ... (Dtr==0)  [outcome por brazo]
    #   3. mu1[f], mu0[f] = predicción lineal de X[f] con b1 / b0
    #   4. e[f] = _propensity_fit(X[m], D[m])(X[f])
    # luego: e = clip(e, 0.05, 0.95) [trimming declarado];
    #        score = mu1 - mu0 + D*(Y-mu1)/e - (1-D)*(Y-mu0)/(1-e)
    #        ate = media, se = std/raíz(n); devolver {"ate","se","ic","scores"}.
    raise NotImplementedError("TODO-21 pendiente de completar")


def estratos_nodegree(score: np.ndarray, col: dict, esquema: EsquemaCausal) -> dict:
    """Un solo corte de heterogeneidad, pre-declarado en la tarjeta.

    No es un CATE: es la media de scores AIPW de cada estrato, con su IC.
    """
    # TODO-22 (el estrato): para nodegree = 1 ("sin título") y 0 ("con título"):
    # media de scores del grupo, se = std/raíz(n_grupo), ic = media ± 1.96*se.
    # Devolver {"variable": "nodegree", "regla": ..., "hojas": {valor: {...}}}.
    raise NotImplementedError("TODO-22 pendiente de completar")


def trampa_score_post(col: dict, esquema: EsquemaCausal) -> dict:
    """Columna derivada del resultado: 'score de éxito' calculado con re78."""
    g = np.random.default_rng(SEMILLA)
    D, Y = col[esquema.tratamiento], col[esquema.resultado]
    # TODO-8 (la trampa, Cap. 6): score = 0.6*Y + 0.4*D + ruido(0, 500, n);
    # llamar a ate_ols con extra={"valores": score} y devolver el resultado.
    raise NotImplementedError("TODO-8 pendiente de completar")


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

    return {
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
