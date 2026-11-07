#!/usr/bin/env python3
"""Cap. 6 — Cuatro tipos de feature y una verdad conocida.

Reproduce el caso canónico de la auditoría de features (contrato C-03):
confusor, collider previo, mediador y medición tardía del resultado.
El R² predictivo mejora a medida que la estimación del efecto se destruye.

DGP (semilla 13, 200 repeticiones, 5 000 unidades, efecto total = 1):
  C, U, A1, A2, eps_* ~ N(0,1) independientes
  B = 0.8 A1 + 0.8 A2 + eps_B                  (collider, pre-tratamiento)
  D = 0.8 C + 0.8 U + 0.8 A1 + eps_D
  M = 0.5 D + eps_M                             (mediador, post)
  Y = 0.7 D + 0.6 M + C + U + 0.8 A2 + eps_Y    (efecto total 0.7 + 0.6*0.5 = 1)
  K = 0.6 D + 0.6 Y + eps_K                     (collider, post)
  P = Y + 0.3 eps_P                             (resultado medido tarde)
"""
import numpy as np

SEMILLA, N, REP = 13, 5_000, 200

ESPECIFICACIONES = [
    ("ninguno",        []),
    ("X_base (C)",     ["C"]),
    ("X_ampliada (C, U)", ["C", "U"]),
    ("+ B (collider)", ["C", "U", "B"]),
    ("+ M (mediador)", ["C", "U", "M"]),
    ("todas (con K y P)", ["C", "U", "B", "M", "K", "P"]),
]

def ajustar(X, y):
    return np.linalg.lstsq(np.column_stack([np.ones(len(y)), X]), y, rcond=None)[0]

def main():
    g = np.random.default_rng(SEMILLA)
    res = {n: [] for n, _ in ESPECIFICACIONES}
    r2s = {n: [] for n, _ in ESPECIFICACIONES}
    for _ in range(REP):
        C, U, A1, A2 = (g.normal(size=N) for _ in range(4))
        eB, eD, eM, eY, eK, eP = (g.normal(size=N) for _ in range(6))
        B = 0.8 * A1 + 0.8 * A2 + eB
        D = 0.8 * C + 0.8 * U + 0.8 * A1 + eD
        M = 0.5 * D + eM
        Y = 0.7 * D + 0.6 * M + C + U + 0.8 * A2 + eY
        K = 0.6 * D + 0.6 * Y + eK
        P = Y + 0.3 * eP
        todas = {"C": C, "U": U, "B": B, "M": M, "K": K, "P": P}
        # mitad para ajustar, mitad para R² fuera de muestra
        m = N // 2
        for nombre, cols in ESPECIFICACIONES:
            X = np.column_stack([D] + [todas[c] for c in cols]) if cols else D[:, None]
            beta = ajustar(X[:m], Y[:m])
            coef = beta[1]
            pred = np.column_stack([np.ones(m), X[m:]]) @ beta
            ssr = ((Y[m:] - pred) ** 2).sum()
            r2 = 1 - ssr / ((Y[m:] - Y[m:].mean()) ** 2).sum()
            res[nombre].append(coef)
            r2s[nombre].append(r2)
    print(f"semilla {SEMILLA}, {N} unidades, {REP} repeticiones (efecto verdadero = 1.00)")
    print(f"{'controles':22s} {'efecto':>7s} {'R² fuera de muestra':>20s}")
    for nombre, _ in ESPECIFICACIONES:
        print(f"{nombre:22s} {np.mean(res[nombre]):7.2f} {np.mean(r2s[nombre]):20.2f}")

if __name__ == "__main__":
    main()
