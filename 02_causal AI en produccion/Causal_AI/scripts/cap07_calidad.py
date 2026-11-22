#!/usr/bin/env python3
"""Cap. 7 — Calidad de datos para decisiones: balance, deriva y faltantes.

A. Chequeo de balance (caso canónico): 40 covariables, dos mecanismos de
   asignación. El t-test crudo al 5 % marca ~2 desbalances por azar; Holm, ~0;
   y una asignación que depende de X0 activa solo la bandera de X0.
B. Deriva de covariables (PSI y KS) sobre datos reales (real/jobs): la edad
   en el train contra una ventana desplazada +5 años y contra una réplica.
C. Faltantes diferenciales: una tasa de ausenta distinta entre tratados y
   controles no aparece en la SMD; se mide aparte, no dentro de la comparación.
"""
import csv
from pathlib import Path

import numpy as np
from scipy import stats

RAIZ = Path(__file__).resolve().parents[3]
TRAIN = RAIZ / "data_benchmark_causal" / "causal_benchmark_synthetic" / "datasets" / "real" / "jobs" / "observed_train.csv"

def smd(t, c):
    return (t.mean() - c.mean()) / np.sqrt((t.var() + c.var()) / 2)

def holm(p):
    orden = np.sort(p)
    m = len(orden)
    return np.minimum(1.0, np.maximum.accumulate(orden * (m - np.arange(m))))

def psi(ref, nuevo, bins=10, eps=1e-4):
    cortes = np.quantile(ref, np.linspace(0, 1, bins + 1))
    cortes = np.unique(cortes)
    a = np.histogram(ref, cortes)[0] / len(ref)
    b = np.histogram(nuevo, cortes)[0] / len(nuevo)
    a, b = np.clip(a, eps, None), np.clip(b, eps, None)
    return float(np.sum((a - b) * np.log(a / b)))

def main():
    g = np.random.default_rng(20240701)

    # A. Balance y la falacia del p-valor
    print("== A. Cuarenta covariables, dos mecanismos de asignación ==")
    rechazos_crudos, rechazos_holm = [], []
    for _ in range(200):
        X = g.normal(size=(500, 40))
        D = g.random(500) < 0.5
        p = [stats.ttest_ind(X[D, j], X[~D, j], equal_var=False).pvalue for j in range(40)]
        rechazos_crudos.append((np.array(p) < 0.05).sum())
        rechazos_holm.append((holm(np.array(p)) < 0.05).sum())
    print(f"  moneda justa (200 exp. de 500 unidades): "
          f"rechazos t-test 5 % por experimento = {np.mean(rechazos_crudos):.2f} | con Holm = {np.mean(rechazos_holm):.2f}")

    X = g.normal(size=(2000, 40))
    D = g.random(2000) < 1 / (1 + np.exp(-1.2 * X[:, 0]))
    smds = np.array([smd(X[D, j], X[~D, j]) for j in range(40)])
    raz = np.array([X[D, j].var() / X[~D, j].var() for j in range(40)])
    print(f"  asignación ~ sigma(1.2·X0): SMD de X0 = {smds[0]:.2f} | bandera |SMD|>0,25 encendida en "
          f"{(np.abs(smds) > 0.25).sum()} de 40 covariables ({np.argwhere(np.abs(smds) > 0.25).ravel().tolist()})")
    print(f"  razón de varianzas de X0 = {raz[0]:.2f} (dentro de [0,5, 2]: {0.5 <= raz[0] <= 2}) | "
          f"max |SMD| fuera de X0 = {np.abs(smds[1:]).max():.3f}")

    # B. Deriva con datos reales: la edad en real/jobs
    print("\n== B. PSI y KS sobre la edad de real/jobs ==")
    with open(TRAIN) as f:
        filas = list(csv.DictReader(f))
    edad = np.array([float(r["age"]) for r in filas])
    mitad = len(edad) // 2
    ref, ventana = edad[:mitad], edad[mitad:]
    print(f"  réplica honesta (ventana = otra parte del mismo train): PSI {psi(ref, ventana):.3f}, KS {stats.ks_2samp(ref, ventana).statistic:.3f}")
    print(f"  ventana envejecida +5 años: PSI {psi(ref, ventana + 5):.3f}, KS {stats.ks_2samp(ref, ventana + 5).statistic:.3f}")
    print(f"  ventana envejecida +10 años: PSI {psi(ref, ventana + 10):.3f}, KS {stats.ks_2samp(ref, ventana + 10).statistic:.3f}")
    print(f"  (referencia usual: PSI < 0,1 estable; 0,1–0,25 revisar; > 0,25 alertar — umbrales a calibrar por calibración propia)")

    # C. Faltantes diferenciales
    print("\n== C. Lo que la SMD no ve: faltantes por selección ==")
    re75 = np.array([float(r["re75"]) for r in filas])
    d = np.array([int(r["treatment"]) for r in filas]).astype(bool)
    g2 = np.random.default_rng(7)
    falta = (d & (g2.random(len(d)) < 0.30)) | (~d & (g2.random(len(d)) < 0.03))
    v = re75[~falta]
    print(f"  p(falta | tratado) = {falta[d].mean():.2f} | p(falta | control) = {falta[~d].mean():.2f}")
    print(f"  SMD de re75 entre los completos = {abs(smd(v[d[~falta]], v[~d[~falta]])):.3f} (la comparación no lo señala; el diagnóstico aparte sí)")
    print(f"  razón de faltantes tratado/control = {falta[d].mean() / falta[~d].mean():.1f}")

if __name__ == "__main__":
    main()
