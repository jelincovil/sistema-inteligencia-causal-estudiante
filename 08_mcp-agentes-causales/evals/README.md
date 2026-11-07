# Evals — DGPs con verdad que no perdonan

Cada eval es un DGP sintético con `truth_*.csv` **fuera del paquete** (pared intacta). El agente corre contra `observed_*.csv`; la evaluación compara contra verdad reservada.

| Eval | Violación inyectada | Criterio que debe fallar |
|------|---------------------|--------------------------|
| wall_intact | Ninguna | Ninguno — baseline |
| dos_definiciones | `S = E - D` como covariable | C-01/C-03 → 1.00 vs 1.50 |
| fuga_temporal | `K,Y` post-tratamiento | C-03 → 1.00→0.00 |
| drift | age +10 | C-02 → PSI 1.34 |
| soporte_roto | determinismo por re74 | C-02 → ESS/n 1.0 engañoso, solape 0% |
| ess_bajo | e=σ(4x0) | C-12 → ESS 85/3000 |

Script fuente: `02_causal AI en produccion/Causal_AI/scripts/cap0X_*.py` (misma semilla que el libro).
