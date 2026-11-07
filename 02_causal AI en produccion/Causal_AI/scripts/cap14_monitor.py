#!/usr/bin/env python3
"""Cap. 14 — Observabilidad de supuestos en producción: las cuatro señales.

DGP con verdad: X1..X3 ~ N(0,1), Z ~ N(0,1) instrumento,
D ~ Bernoulli(sigmoid(X1 + 0.8Z)), Y = 0.5·D + X1 + 0.5·X3 + eps.
Referencia 3000, ventanas 400, 100 réplicas por escenario.

Cuatro señales: (i) drift marginal PSI, (ii) drift del mecanismo (AUC del
propensity de referencia sobre la ventana), (iii) fuerza del instrumento F,
(iv) estabilidad del efecto (contraste z entre dos estimaciones).
Semilla 20260714.
"""
import numpy as np
from scipy import stats
from scipy.optimize import minimize

SEMILLA = 20260714
N_REF, N_WIN, REP = 3000, 400, 100


def sigmoid(z):
    return 1 / (1 + np.exp(-z))


def gen_unidades(n, g, efecto=0.5, regla="x1", instrumento_fuerte=True, shift_x3=0.0):
    X = g.normal(size=(n, 3))
    if shift_x3:
        X[:, 2] += shift_x3
    Z = g.normal(size=n)
    if regla == "x1":
        base = X[:, 0]
    else:
        base = X[:, 1]
    coef_z = 0.8 if instrumento_fuerte else 0.0
    e = sigmoid(base + coef_z * Z)
    D = (g.random(n) < e).astype(int)
    Y = efecto * D + X[:, 0] + 0.5 * X[:, 2] + g.normal(size=n)
    return X, Z, D, Y


# ---------------------------------------------------------------- señal (i)

def psi(ref, nueva, bins=10, eps=1e-6):
    bordes = np.unique(np.quantile(ref, np.linspace(0, 1, bins + 1)))
    bordes[0], bordes[-1] = -np.inf, np.inf
    p = np.histogram(ref, bins=bordes)[0] / len(ref)
    q = np.histogram(nueva, bins=bordes)[0] / len(nueva)
    p, q = np.clip(p, eps, None), np.clip(q, eps, None)
    return float(((p - q) * np.log(p / q)).sum())


def senal_drift_marginal(X_ref, X_win):
    """(i) PSI por covariable; alerta si algún PSI > 0.25."""
    psis = [psi(X_ref[:, j], X_win[:, j]) for j in range(3)]
    return max(psis) > 0.25, max(psis)


# --------------------------------------------------------------- señal (ii)

def _fit_logistic(Xm, d):
    Zm = (Xm - Xm.mean(0)) / np.clip(Xm.std(0), 1e-9, None)
    def nll(w):
        eta = Zm @ w[1:] + w[0]
        return float(np.sum(np.logaddexp(0, eta) - d * eta))
    r = minimize(nll, np.zeros(Zm.shape[1] + 1), method="BFGS")
    med, sd = Xm.mean(0), Xm.std(0)
    def pred(Xn):
        Zn = (Xn - med) / np.clip(sd, 1e-9, None)
        return sigmoid(Zn @ r.x[1:] + r.x[0])
    return pred


def auc(y, s):
    order = np.argsort(s)
    ranks = np.empty(len(s))
    ranks[order] = np.arange(1, len(s) + 1)
    pos = y == 1
    n1, n0 = int(pos.sum()), int((~pos).sum())
    if n1 == 0 or n0 == 0:
        return 0.5
    return float((ranks[pos].sum() - n1 * (n1 + 1) / 2) / (n1 * n0))


def senal_drift_mecanismo(X_ref, D_ref, X_win, D_win, tolerancia=0.10):
    """(ii) AUC del propensity de referencia sobre la ventana; alerta si cae."""
    mitad = len(D_ref) // 2
    pred = _fit_logistic(X_ref[:mitad], D_ref[:mitad])
    auc_ref = auc(D_ref[mitad:], pred(X_ref[mitad:]))
    auc_win = auc(D_win, pred(X_win))
    return (auc_ref - auc_win) > tolerancia, auc_ref, auc_win


# -------------------------------------------------------------- señal (iii)

def senal_fuerza_instrumento(Z_win, D_win, X_win, umbral=10.0):
    """(iii) F de la primera etapa para el instrumento excluido."""
    n = len(D_win)
    W = np.column_stack([np.ones(n), X_win])
    Zfull = np.column_stack([W, Z_win])
    def rss(M):
        b = np.linalg.lstsq(M, D_win, rcond=None)[0]
        return float(((D_win - M @ b) ** 2).sum())
    rss_r, rss_u = rss(W), rss(Zfull)
    f = (rss_r - rss_u) / (rss_u / (n - Zfull.shape[1]))
    return f < umbral, f


# --------------------------------------------------------------- señal (iv)

def _ate_ols(X, D, Y):
    n = len(D)
    M = np.column_stack([np.ones(n), D, X])
    b = np.linalg.lstsq(M, Y, rcond=None)[0]
    r = Y - M @ b
    s2 = r @ r / (n - M.shape[1])
    se = float(np.sqrt(s2 * np.linalg.inv(M.T @ M)[1, 1]))
    return float(b[1]), se


def senal_estabilidad_efecto(X_ref, D_ref, Y_ref, X_win, D_win, Y_win, alpha=0.05):
    """(iv) Contraste z entre el efecto de referencia y el de la ventana."""
    th_ref, se_ref = _ate_ols(X_ref, D_ref, Y_ref)
    th_win, se_win = _ate_ols(X_win, D_win, Y_win)
    z = (th_win - th_ref) / np.sqrt(se_ref**2 + se_win**2)
    p = 2 * (1 - stats.norm.cdf(abs(z)))
    return p < alpha, th_ref, th_win, p


# ------------------------------------------------------------------- main

def main():
    g = np.random.default_rng(SEMILLA)
    X_ref, Z_ref, D_ref, Y_ref = gen_unidades(N_REF, g)
    th_ref, se_ref = _ate_ols(X_ref, D_ref, Y_ref)
    print(f"referencia: n={N_REF}, ATE={th_ref:.3f} SE={se_ref:.3f} (verdad 0.5)")
    print(f"señales sobre {REP} ventanas de {N_WIN} por escenario\n")

    escenarios = [
        ("ninguno", {}),
        ("shift X3 +1 DE", {"shift_x3": 1.0}),
        ("regla X1→X2", {"regla": "x2"}),
        ("instrumento débil", {"instrumento_fuerte": False}),
        ("efecto 0.5→0.1", {"efecto": 0.1}),
    ]
    print(f"{'escenario':22s} {'(i)':>5s} {'(ii)':>5s} {'(iii)':>5s} {'(iv)':>5s}")
    for nombre, kwargs in escenarios:
        c = [0, 0, 0, 0]
        for _ in range(REP):
            Xw, Zw, Dw, Yw = gen_unidades(N_WIN, g, **kwargs)
            a1, _ = senal_drift_marginal(X_ref, Xw)
            a2, _, _ = senal_drift_mecanismo(X_ref, D_ref, Xw, Dw)
            a3, _ = senal_fuerza_instrumento(Zw, Dw, Xw)
            a4, _, _, _ = senal_estabilidad_efecto(X_ref, D_ref, Y_ref, Xw, Dw, Yw)
            c = [c[0] + a1, c[1] + a2, c[2] + a3, c[3] + a4]
        pct = [100 * x / REP for x in c]
        print(f"{nombre:22s} {pct[0]:4.0f}% {pct[1]:4.0f}% {pct[2]:4.0f}% {pct[3]:4.0f}%")


if __name__ == "__main__":
    main()
