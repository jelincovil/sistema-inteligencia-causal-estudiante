# Eval cap10 — Qini/Uplift OOS

**DGP:** tau(x)=0.3+1.2*x0, n_tr 1500 n_te 1000, semilla 20260710
**Métrica:** valor IPW OOS, Qini vs aleatorio
**Pass:** política tau>0 valor > aleatorio +0.3 y Qini>0.1 OOS
**Fail:** valor in-sample > OOS (leakage) → C-12 falla
