#!/usr/bin/env python3
"""Cap. 5 — Particiones sembradas y fuga por selección en el conjunto de prueba.

Parte A: la misma semilla produce la misma partición; otra semilla no.
Parte B: elegir un modelo mirando la prueba infla el desempeño que la
prueba reporta (el número favorito deja de ser una estimación honesta).
"""
import csv
import hashlib
from pathlib import Path

import numpy as np

RAIZ = Path(__file__).resolve().parents[3]
TRAIN = RAIZ / "data_benchmark_causal" / "causal_benchmark_synthetic" / "datasets" / "real" / "jobs" / "observed_train.csv"
SEMILLA, N, P = 20240701, 1722, 8

def partir(semilla):
    g = np.random.default_rng(semilla)
    idx = g.permutation(N)
    return idx[: int(0.6 * N)], idx[int(0.6 * N) : int(0.8 * N)], idx[int(0.8 * N) :]

def huella(particion):
    return hashlib.sha256(np.concatenate(particion).tobytes()).hexdigest()[:16]

def main():
    # Parte A: reproducibilidad
    a1, a2 = partir(SEMILLA), partir(SEMILLA)
    b1 = partir(SEMILLA + 1)
    print("== A. La partición es una función de la semilla ==")
    print(f"  semilla {SEMILLA} dos veces : huella {huella(a1)} == {huella(a2)} -> {huella(a1) == huella(a2)}")
    print(f"  semilla {SEMILLA + 1}        : huella {huella(b1)} -> distinta: {huella(a1) != huella(b1)}")
    tra, val, tes = a1
    print(f"  tamaños: train {len(tra)}, validación {len(val)}, prueba {len(tes)}; sin solape: {len(set(tra) & set(tes)) == 0}")

    # Parte B: selección sobre la prueba
    g = np.random.default_rng(SEMILLA)
    with open(TRAIN) as f:
        filas = list(csv.DictReader(f))
    Y = np.array([float(r["re78"]) for r in filas])
    Xn = g.normal(size=(len(filas), 100))          # 100 covariables de ruido puro
    tr, va, te = partir(len(filas))
    te = np.arange(len(filas))                       # demo: usar TODO como prueba

    def r2(idx, j):
        x = Xn[idx][:, [j]]
        beta, alpha = np.polyfit(x.ravel(), Y[idx], 1)
        pred = alpha + beta * x.ravel()
        ss_res = ((Y[idx] - pred) ** 2).sum()
        return 1 - ss_res / ((Y[idx] - Y[idx].mean()) ** 2).sum()

    r2_test = np.array([r2(te, j) for j in range(100)])
    mejor = int(r2_test.argmax())
    fresco = np.argsort(g.permutation(100))[:20]     # datos nuevos (otro ruido, misma distribución)
    r2_fresco = np.array([r2(te, j) for j in fresco])
    print("\n== B. Elegir mirando la prueba ==")
    print(f"  100 covariables de ruido puro; R² en la prueba: media {r2_test.mean():.4f}, mejor {r2_test.max():.4f} (columna {mejor})")
    print(f"  R² de 20 columnas nuevas, sin elegir: media {r2_fresco.mean():.4f}")
    print(f"  la 'mejor' columna seleccionada en la prueba dice {r2_test.max():.4f}; en datos nuevos, columnas como ella dicen {r2_fresco.mean():.4f}")

if __name__ == "__main__":
    main()
