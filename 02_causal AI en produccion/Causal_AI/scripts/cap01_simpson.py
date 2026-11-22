#!/usr/bin/env python3
"""Cap. 1 — La reversión de Simpson, con números.

Regenera la tabla del caso canónico del Capítulo 1: mismo hospital,
dos tratamientos; el agregado favorece a A, la estratificación por
gravedad favorece a B en ambos estratos.

DGP (efecto conocido, semilla 7):
  gravedad G ~ Bernoulli(0.72)          (0 = leve, 1 = grave)
  P(A) | leve = 0.90   P(A) | grave = 0.25
  éxito  | leve, A = 0.86   | leve, B = 0.90
  éxito  | grave, A = 0.55  | grave, B = 0.60
"""
import numpy as np

SEMILLA = 7
N = 40_000

def main():
    g = np.random.default_rng(SEMILLA)
    grave = g.random(N) < 0.72
    recibe_a = np.where(grave, g.random(N) < 0.25, g.random(N) < 0.90)
    p_exito = np.where(grave,
                       np.where(recibe_a, 0.55, 0.60),
                       np.where(recibe_a, 0.86, 0.90))
    exito = g.random(N) < p_exito

    def tasa(mask):
        return exito[mask].mean()

    print(f"semilla {SEMILLA}, n = {N}")
    print(f"casos graves: {grave.mean():.2f} | A recibe el {recibe_a.mean():.2f} de los pacientes")
    print()
    print("Tasa de éxito global (agregada):")
    print(f"  tratamiento A: {tasa(recibe_a):.3f}")
    print(f"  tratamiento B: {tasa(~recibe_a):.3f}")
    print()
    print("Tasa de éxito por gravedad (estratificada):")
    for nombre, mask_g in (("leve", ~grave), ("grave", grave)):
        a, b = tasa(recibe_a & mask_g), tasa(~recibe_a & mask_g)
        print(f"  {nombre:5s}: A {a:.3f} vs B {b:.3f}  (B mejor: {b > a})")

if __name__ == "__main__":
    main()
