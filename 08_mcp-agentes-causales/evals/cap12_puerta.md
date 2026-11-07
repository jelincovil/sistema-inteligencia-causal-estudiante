# Eval cap12 — Puerta causal: tres versiones, tres estados

**DGP:** `real/jobs` train, semilla 20260712, umbrales tarjeta `smd_max` 0.25, `psi_alerta` 0.25, `solape_min` 0.50.

| Versión | n | PSI | SMD | Solape | Estado |
|---|---|---|---|---|---|
| v0001 sana | 700 | 0.011 | 0.22 | 100% | **pasa** |
| v0002 deriva | 1033 | 1.347 | 0.19 | 100% | **alerta** |
| v0003 positividad | 270 | 3.237 | 5.24 | 0% | **falla** |

**Pass:** v0001 llega a champion, v0002 exige aceptación, v0003 bloquea.
**Fail:** promover v0003 o ajustar umbral post-hoc → C-06 falla.
