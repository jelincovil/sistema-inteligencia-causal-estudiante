# Eval cap14 — Monitoreo: cuatro señales discriminantes

**DGP:** X1..X3 N(0,1), Z instrumento, D~Bernoulli(σ(X1+0.8Z)), Y=0.5D+X1+0.5X3+ε. Ref 3000, ventanas 400, 100 réplicas. Semilla 20260714.

| Cambio | (i) | (ii) | (iii) | (iv) |
|---|---|---|---|---|
| Ninguno | 0% | 0% | 0% | 3% |
| X3 +1 DE | 100% | 0% | 0% | 1% |
| Regla X1→X2 | 0% | 100% | 0% | 3% |
| Instrumento débil | 0% | 0% | 100% | 2% |
| Efecto 0.5→0.1 | 0% | 0% | 0% | 95% |

**Pass:** cada cambio enciende su señal y casi ninguna otra; sin cambio ≤5%.
**Fail:** reajustar propensity en ventana (cambio de regla pasa inadvertido) → C-07 falla.
