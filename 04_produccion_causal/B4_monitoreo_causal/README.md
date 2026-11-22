# B4 — Monitor causal

Calcula señales observables y registra hipótesis/acción de revisión; una alerta no identifica por sí sola confusión.

Ejecuta el componente desde su carpeta y usa únicamente artefactos que hayas generado a partir de datos observados. Si falta el artefacto de entrada, registra `abstención` y vuelve a la etapa anterior. Los comandos de evaluación docente y los autograders no se distribuyen en este repositorio.

KS y PSI se calculan y umbralean por separado; sus cortes son convenciones operativas, no garantías de identificación. Toda métrica requerida debe estar presente, ser finita y respetar su dominio físico. PSI usa cortes por cuantiles de la referencia y, si esta es constante `c`, las regiones `x < c`, `x == c` y `x > c`; las proporciones vacías se recortan con `eps` y PSI = `sum((pn-pr)*log(pn/pr))`. Las muestras vacías o no finitas se rechazan. `src/causalops/diagnosticos.py` comparte esa convención de bins, pero conserva su `eps=1e-4` por compatibilidad (B4 usa `1e-6`). La simulación no inventa un control negativo neutro: sin un `nc_abs_z` medido, la acción es `abstenerse`.
