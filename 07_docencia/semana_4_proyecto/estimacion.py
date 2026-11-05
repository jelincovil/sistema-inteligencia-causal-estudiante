"""estimacion.py — [BLOQUE 3, min 35–60] El efecto con incertidumbre + diagnósticos.

Se completa en vivo: ate_ols, propensity, ess_kish, smd y la trampa.
"""
from __future__ import annotations

import json

import numpy as np
from scipy.optimize import minimize

from datos import EsquemaCausal, leer
from rutas import ARTEFACTOS, ESCENARIO

SEMILLA = 4242

# Corte de heterogeneidad por escenario: se declara ANTES de mirar los efectos.
CORTES = {
    "real/jobs": {
        "variable": "nodegree", "umbral": 0.5,
        "etiquetas": {"1": "sin título", "0": "con título"},
        "regla": ("corte único por nodegree (título): criterio administrativo y de "
                  "interpretabilidad, declarado antes de mirar los efectos; "
                  "NO elegido por ganancia de varianza"),
    },
    "real/ihdp": {
        "variable": "bw", "umbral": None,  # None -> mediana de la muestra de train
        "etiquetas": {"1": "bw alto (> mediana de train)",
                      "0": "bw bajo (<= mediana de train)"},
        "regla": ("corte único por peso al nacer (bw) en la mediana de train: es el eje "
                  "clínico del IHDP (bajo peso al nacer define la población del estudio), "
                  "declarado antes de mirar los efectos y NO elegido por ganancia de "
                  "varianza; la mediana preserva tamaño en ambas hojas"),
    },
}

UNIDAD = {"real/jobs": "USD de 1978", "real/ihdp": "puntos de test cognitivo"}
ETIQUETA_UNIDAD = {"real/jobs": "USD", "real/ihdp": "puntos"}
# La trampa se escala con la unidad del resultado (no tiene sentido en puntos).
RUIDO_TRAMPA = {"real/jobs": 500.0, "real/ihdp": 1.0}


def ate_ols(col: dict, esquema: EsquemaCausal, extra=None) -> dict:
    """ATE por OLS con los controles del esquema (+ columna trampa opcional)."""
    n = len(col[esquema.tratamiento])
    D, Y = col[esquema.tratamiento], col[esquema.resultado]
    columnas = [col[c] for c in esquema.covariables] + (
        [extra["valores"]] if extra else [])
    M = np.column_stack([np.ones(n), D, *columnas])
    # OLS: el coeficiente del tratamiento es el ATE bajo el modelo lineal.
    beta = np.linalg.lstsq(M, Y, rcond=None)[0]
    residuo = Y - M @ beta
    sigma2 = float(residuo @ residuo / (n - M.shape[1]))
    cov = sigma2 * np.linalg.inv(M.T @ M)
    ate = float(beta[1])
    se = float(np.sqrt(cov[1, 1]))
    return {"ate": ate, "se": se, "ic": [ate - 1.96 * se, ate + 1.96 * se]}


def propensity(X: np.ndarray, D: np.ndarray) -> np.ndarray:
    """Logística por máxima verosimilitud (BFGS, covariables estandarizadas)."""
    Z = (X - X.mean(0)) / X.std(0)
    # Soporte: la logística se ajusta por máxima verosimilitud (BFGS).
    def nll(w):
        eta = Z @ w[1:] + w[0]
        return float(np.sum(np.logaddexp(0, eta) - D * eta))

    r = minimize(nll, np.zeros(Z.shape[1] + 1), method="BFGS")
    eta = Z @ r.x[1:] + r.x[0]
    return 1 / (1 + np.exp(-eta))


def ess_kish(D: np.ndarray, e: np.ndarray) -> float:
    """Tamaño efectivo de la ponderación IPW: ESS = (sum w)^2 / sum w^2."""
    # ESS: cuántas unidades "cuentan" de verdad bajo los pesos IPW.
    e = np.clip(e, 1e-6, 1 - 1e-6)
    w = np.where(D == 1, 1 / e, 1 / (1 - e))
    return float(w.sum() ** 2 / np.sum(w ** 2))


def smd(v: np.ndarray, D: np.ndarray) -> float:
    """Diferencia media estandarizada: tratados vs controles (Cap. 7)."""
    # Balance: la diferencia de medias en unidades de desviación común.
    t, c = v[D == 1], v[D == 0]
    return float((t.mean() - c.mean()) / np.sqrt((t.var() + c.var()) / 2))


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
    for fold in folds:
        # Cross-fitting: ningún nuisance ve a la unidad que predice.
        fuera = np.ones(n, dtype=bool)
        fuera[fold] = False
        dentro = np.zeros(n, dtype=bool)
        dentro[fold] = True
        b1 = _ajustar_lineal(X[fuera & (D == 1)], Y[fuera & (D == 1)])
        b0 = _ajustar_lineal(X[fuera & (D == 0)], Y[fuera & (D == 0)])
        Xf = np.column_stack([np.ones(dentro.sum()), X[dentro]])
        mu1[dentro], mu0[dentro] = Xf @ b1, Xf @ b0
        e[dentro] = _propensity_fit(X[fuera], D[fuera])(X[dentro])

    e = np.clip(e, 0.05, 0.95)  # trimming declarado en la tarjeta
    score = (mu1 - mu0 + D * (Y - mu1) / e - (1 - D) * (Y - mu0) / (1 - e))
    ate = float(score.mean())
    se = float(score.std(ddof=1) / np.sqrt(n))
    return {"ate": ate, "se": se, "ic": [ate - 1.96 * se, ate + 1.96 * se],
            "scores": score}


def estratos_heterogeneidad(score: np.ndarray, col: dict,
                            esquema: EsquemaCausal) -> dict:
    """Un solo corte de heterogeneidad, pre-declarado en la tarjeta.

    No es un CATE: es la media de scores AIPW de cada estrato, con su IC.
    """
    corte = CORTES[ESCENARIO]
    variable = corte["variable"]
    umbral = corte["umbral"]
    if umbral is None:
        umbral = float(np.median(col[variable]))
    grupo = (col[variable] > umbral).astype(int)
    hojas = {}
    for clave in ("1", "0"):
        sel = grupo == int(clave)
        s = score[sel]
        media = float(s.mean())
        se = float(s.std(ddof=1) / np.sqrt(len(s)))
        hojas[clave] = {"etiqueta": corte["etiquetas"][clave], "n": int(sel.sum()),
                        "efecto": media, "se": se,
                        "ic": [media - 1.96 * se, media + 1.96 * se]}
    return {"variable": variable, "umbral": umbral, "regla": corte["regla"],
            "hojas": hojas}


# Alias histórico del kit (real/jobs usaba este nombre).
estratos_nodegree = estratos_heterogeneidad


def trampa_score_post(col: dict, esquema: EsquemaCausal) -> dict:
    """Columna derivada del resultado: 'score de éxito' calculado con re78."""
    g = np.random.default_rng(SEMILLA)
    D, Y = col[esquema.tratamiento], col[esquema.resultado]
    # La trampa: una columna calculada CON el resultado (Cap. 6).
    score = 0.6 * Y + 0.4 * D + g.normal(0, RUIDO_TRAMPA[ESCENARIO], len(Y))
    return ate_ols(col, esquema, extra={"valores": score})


def estimar() -> dict:
    esquema = EsquemaCausal()
    col = leer("train")
    D, Y = col[esquema.tratamiento], col[esquema.resultado]
    X = np.column_stack([col[c] for c in esquema.covariables])

    crude = float(Y[D == 1].mean() - Y[D == 0].mean())
    ajustado = ate_ols(col, esquema)
    trampa = trampa_score_post(col, esquema)
    aipw = aipw_crossfit(col, esquema)
    estratos = estratos_heterogeneidad(aipw["scores"], col, esquema)

    e = propensity(X, D)
    solape = float(((e >= 0.05) & (e <= 0.95)).mean())
    smds = {c: smd(col[c], D) for c in esquema.covariables}

    return {
        "escenario": ESCENARIO,
        "estimando": f"ATE de {esquema.tratamiento} sobre {esquema.resultado} (efecto total)",
        "unidad": UNIDAD[ESCENARIO],
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
    print(f"diferencia cruda E[Y|D=1]-E[Y|D=0] = {r['diferencia_cruda']:.1f} "
          f"{ETIQUETA_UNIDAD[ESCENARIO]}")
    print(f"ATE OLS ({len(EsquemaCausal().covariables)} controles) = {r['ate_ols']:.1f} "
          f"| SE = {r['se']:.1f} "
          f"| IC95 = [{r['ic95'][0]:.1f}, {r['ic95'][1]:.1f}]")
    print(f"AIPW cross-fitting K=5 = {r['ate_aipw']:.1f} | SE = {r['se_aipw']:.1f} "
          f"| IC95 = [{r['ic_aipw'][0]:.1f}, {r['ic_aipw'][1]:.1f}]")
    print(f"trampa score_post      = {r['ate_trampa_score_post']:.1f}  "
          "<- el coeficiente se vació")
    for v, h in r["estratos"]["hojas"].items():
        print(f"estrato {r['estratos']['variable']}={v} "
              f"({h['etiqueta']}, n={h['n']}): "
              f"efecto {h['efecto']:.1f} IC95 [{h['ic'][0]:.1f}, {h['ic'][1]:.1f}]")
    print(f"ESS = {r['ess']:.0f} (ESS/n = {r['ess_sobre_n']:.2f}) | "
          f"rango e = [{r['rango_e'][0]:.3f}, {r['rango_e'][1]:.3f}] | "
          f"solapamiento = {r['fraccion_solapamiento']:.0%}")
    print(f"SMD máx = {r['smd_max']:.2f}")
    print("artefacto: artifacts/estimacion.json")
