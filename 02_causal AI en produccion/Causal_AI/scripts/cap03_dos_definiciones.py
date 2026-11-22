#!/usr/bin/env python3
"""Cap. 3 — Dos análisis, dos definiciones de X.

El caso canónico del contrato C-01: dos análisis leen la misma tabla y
controlan conjuntos de covariables distintos; uno incluye una variable
(experiencia potencial S = E - D) construida con el tratamiento.

DGP (semilla 11, 200 repeticiones, 5 000 unidades):
  P, E ~ N(0,1) independientes
  D = 0.5 P + eps_D
  Y = D + 0.8 P + 0.5 E + eps_Y        (efecto verdadero: 1)
  S = E - D                            (post-tratamiento)
"""
import numpy as np

SEMILLA, N, REP = 11, 5_000, 200

def ols_beta(X, y):
    return np.linalg.lstsq(X, y, rcond=None)[0]

def main():
    g = np.random.default_rng(SEMILLA)
    est = {"{P, E}": [], "{P, S}": []}
    for _ in range(REP):
        P = g.normal(size=N); E = g.normal(size=N)
        D = 0.5 * P + g.normal(size=N)
        Y = D + 0.8 * P + 0.5 * E + g.normal(size=N)
        S = E - D
        uno = np.ones(N)
        est["{P, E}"].append(ols_beta(np.column_stack([uno, D, P, E]), Y)[1])
        est["{P, S}"].append(ols_beta(np.column_stack([uno, D, P, S]), Y)[1])
    print(f"semilla {SEMILLA}, {N} unidades, {REP} repeticiones (efecto verdadero = 1.00)")
    for k, v in est.items():
        print(f"  controles {k:9s}: efecto estimado {np.mean(v):.2f} (sd entre repeticiones {np.std(v):.2f})")

if __name__ == "__main__":
    main()
