# Eval cap15 — End-to-end: de la pregunta al servicio

**DGP:** `real/jobs` train, semilla 20260715. Traza de 9 pasos:

| Paso | Pieza | Resultado |
|---|---|---|
| 1 | Pregunta | ATE de treatment sobre re78 |
| 2 | Esquema C-01 | 8 covariables |
| 3 | Splits C-10 | hash OK, semilla 20240701 |
| 4 | Estimación | ATE 1596.0 [1004.8, 2187.3] |
| 5 | Tarjeta C-05 | válida con supuestos clasificados |
| 6 | Registro C-09 | v0001 con manifest |
| 7 | Puerta C-06 | sana pasa, deriva alerta, positividad falla |
| 8 | Champion | v0001 (solo pasa) |
| 9 | Servicio C-04 | dentro responde, age 99 abstiene |

**Pass:** traza completa en verde, hash verificable, HUMO OK.
**Fail:** tarjeta sin no observables o registro sin hash → C-05/C-09 falla.
