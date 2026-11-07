#!/usr/bin/env python3
"""Cap. 9 — Lo que DML le exige al dato.

Tres exigencias del estimador, medidas sobre datos con verdad:

A. LEAKAGE: el caso canónico (semilla 21, mismo DGP que la edición de
   método): OLS con controles lineales, DML con boosting sin cross-fitting,
   DML con boosting con cross-fitting (K = 5). La fuga entre folds sesga el
   efecto hacia cero; fuera de muestra se repone.

B. OVERLAP (semilla 20260701): ESS de Kish y trimming de Crump. Un propensity
   muy sesgado concentra la ponderación en pocas unidades, y el trimming
   recupera poder efectivo al precio de cambiar el estimando.

C. NUISANCE (semilla 20260701): outcome mal especificado (lineal sobre una
   forma no lineal pronunciada) deja sesgo en el plug-in; el estimador
   doblemente robusto lo corrige cuando el propensity está bien.
"""
import numpy as np

def boosting(X, y, resto0, iteraciones=50, nu=0.2):
    """Stump boosting mínimo: agrega una regla por iteración."""
    n = len(y)
    pred = resto0.copy()
    reglas = []
    resto = y - pred
    for _ in range(iteraciones):
        j = int(np.argmax([abs(np.cov(X[:, c], resto)[0, 1]) for c in range(X.shape[1])]))
        mejor = (-1, None, None)
        for corte in np.quantile(X[:, j], [0.2, 0.35, 0.5, 0.65, 0.8]):
            m = X[:, j] <= corte
            g0, g1 = resto[m].mean(), resto[~m].mean()
            gan = resto.var() - (resto - np.where(m, g0, g1)).var()
            if gan > mejor[0]:
                mejor = (gan, corte, (g0, g1))
        _, corte, g = mejor
        reglas.append((j, corte, g))
        pred += nu * np.where(X[:, j] <= corte, g[0], g[1])
        resto = y - pred
    def predecir(Xn):
        p = np.full(Xn.shape[0], y.mean()) * 0
        y0 = y.mean()
        base = np.full(Xn.shape[0], 0.0)
        # reconstruye la predicción: media + suma acumulada de reglas
        p = np.full(Xn.shape[0], 0.0) + (resto0.mean() if hasattr(resto0, "mean") else 0)
        # más simple: reconstruir desde 0: pred == resto0 + suma(nu*regla); lo fijo re-construyendo:
        return None
    return reglas, resto0.mean()

def fit_arbol_predict(Xtr, ytr, Xn, max_secuencia=6, nu=1.0):
    """Secuencia de divisiones de una covariable: memoriza cuando hay poco dato por hoja."""
    pred_tr = np.full(len(ytr), ytr.mean())
    reglas = []
    resto = ytr - pred_tr
    for _ in range(max_secuencia):
        j = int(np.argmax([abs(np.cov(Xtr[:, c], resto)[0, 1]) for c in range(Xtr.shape[1])]))
        mejor = (-1, None, None)
        for corte in np.quantile(Xtr[:, j], [0.2, 0.35, 0.5, 0.65, 0.8]):
            m = Xtr[:, j] <= corte
            g0, g1 = resto[m].mean(), resto[~m].mean()
            gan = resto.var() - (resto - np.where(m, g0, g1)).var()
            if gan > mejor[0]:
                mejor = (gan, corte, (g0, g1))
        _, corte, g = mejor
        reglas.append((j, corte, g))
        pred_tr += nu * np.where(Xtr[:, j] <= corte, g[0], g[1])
        resto = ytr - pred_tr
    p = np.full(Xn.shape[0], ytr.mean())
    for j, corte, g in reglas:
        p += nu * np.where(Xn[:, j] <= corte, g[0], g[1])
    return p

def caseA():
    print("== A. Fuga entre folds: el caso canónico del cross-fitting ==")
    g = np.random.default_rng(21)
    n, R = 2_000, 20
    h = lambda X: np.sin(3 * X[:, 0]) + X[:, 1] ** 2
    ols, sin_cf, con_cf = [], [], []
    for _ in range(R):
        X = g.uniform(-1, 1, (n, 5))
        D = h(X) + g.normal(size=n)
        Y = D + 2 * h(X) + g.normal(size=n)
        M = np.column_stack([np.ones(n), D, X])
        ols.append(np.linalg.lstsq(M, Y, rcond=None)[0][1])
        # sin cross-fitting: boosting ajustado y residualizado sobre las mismas 2 000 unidades
        m_hat = fit_arbol_predict(X, D, X)
        l_hat = fit_arbol_predict(X, Y, X)
        v, u = D - m_hat, Y - l_hat
        sin_cf.append((v * u).sum() / (v**2).sum())
        # con cross-fitting K = 5: cada unidad predicha por un modelo que no la vio
        rng = np.random.default_rng(abs(int(g.integers(0, 1e9))))
        folds = np.array_split(rng.permutation(n), 5)
        d_res, y_res = np.empty(n), np.empty(n)
        for f in folds:
            msk = np.ones(n, bool); msk[f] = False
            d_res[f] = D[f] - fit_arbol_predict(X[msk], D[msk], X[f])
            y_res[f] = Y[f] - fit_arbol_predict(X[msk], Y[msk], X[f])
        con_cf.append((d_res * y_res).sum() / (d_res**2).sum())
    print(f"  semilla 21, {n} unidades, {R} repeticiones, caso canónico (efecto = 1)")
    print(f"  OLS con controles lineales: {np.mean(ols):.2f} (sd {np.std(ols):.3f})")
    print(f"  DML con boosting, sin cross-fitting: {np.mean(sin_cf):.2f} (sd {np.std(sin_cf):.3f})")
    print(f"  DML con boosting, con cross-fitting (K = 5): {np.mean(con_cf):.2f} (sd {np.std(con_cf):.3f})")

def caseB():
    print("\n== B. Soporte común: ESS de Kish y el precio del trimming ==")
    g = np.random.default_rng(20260701)
    n = 3_000
    X = g.normal(size=(n, 2))
    e = 1 / (1 + np.exp(-4 * X[:, 0]))
    D = (g.random(n) < e).astype(int)
    w = np.where(D == 1, 1 / e, 1 / (1 - e))
    ess = (w.sum() ** 2) / (w**2).sum()
    print(f"  n = {n:,} | ESS de Kish = {ess:,.0f} | ESS/n = {ess / n:.2f}")
    m = (e >= 0.1) & (e <= 0.9)
    w_t = w[m]
    ess_t = (w_t.sum() ** 2) / (w_t**2).sum()
    print(f"  trimming [0,1, 0,9]: conserva {m.mean():.0%} de la muestra ({m.sum():,}); ESS/n recortado = {ess_t / m.sum():.2f}")
    print(f"  precio del trimming: excluye {1 - m.mean():.1%} de la población ({n - m.sum():,} unidades) — ya no es el ATE completo")

def caseC():
    print("\n== C. El nuisance no es decoración: sesgo y doble robustez ==")
    g = np.random.default_rng(20260701)
    n, R = 2_000, 20
    plugin, dr = [], []
    for _ in range(R):
        X = g.normal(size=(n, 3))
        e = 1 / (1 + np.exp(-0.8 * X[:, 0]))
        D = (g.random(n) < e).astype(int)
        nl = 1.3 * np.sin(2.8 * X[:, 1])
        mu1 = 0.3 + 0.7 * X[:, 0] + nl
        mu0 = 0.7 * X[:, 0] + nl
        Y = np.where(D == 1, mu1, mu0) + g.normal(size=n)
        X1, X0m = X[D == 1], X[D == 0]
        b1 = np.linalg.lstsq(np.column_stack([np.ones(len(X1)), X1[:, 0]]), Y[D == 1], rcond=None)[0]
        b0 = np.linalg.lstsq(np.column_stack([np.ones(len(X0m)), X0m[:, 0]]), Y[D == 0], rcond=None)[0]
        mu1_hat = np.column_stack([np.ones(n), X[:, 0]]) @ b1
        mu0_hat = np.column_stack([np.ones(n), X[:, 0]]) @ b0
        plugin.append((mu1_hat - mu0_hat).mean())
        psi = (mu1_hat - mu0_hat + D * (Y - mu1_hat) / e - (1 - D) * (Y - mu0_hat) / (1 - e))
        dr.append(psi.mean())
    print(f"  efecto verdadero = 0,30; outcome con forma no lineal pronunciada (semilla 20260701)")
    print(f"  plug-in con outcome lineal (mal especificado): ATE = {np.mean(plugin):.2f} (sd {np.std(plugin):.3f})")
    print(f"  doblemente robusto (propensity correcto):     ATE = {np.mean(dr):.2f} (sd {np.std(dr):.3f})")

if __name__ == "__main__":
    caseA()
    caseB()
    caseC()
