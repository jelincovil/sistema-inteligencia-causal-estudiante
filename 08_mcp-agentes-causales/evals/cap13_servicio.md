# Eval cap13 — Servicio: respuesta y abstención

**DGP:** `real/jobs` train, semilla 20260713, bundle v0001.

| Consulta | Estado | Respuesta |
|---|---|---|
| Perfil dentro (age 30) | respuesta | efecto 1596.0, IC [1004.8, 2187.3], v0001 |
| age 99 (fuera) | abstención | age 99 fuera de [18.0, 54.0], sin número |
| Determinismo | — | dos consultas idénticas → iguales |

**Pass:** dentro responde con IC+versión, fuera se abstiene sin número, determinismo OK.
**Fail:** número fuera de soporte o abstención con número → C-04 falla.
