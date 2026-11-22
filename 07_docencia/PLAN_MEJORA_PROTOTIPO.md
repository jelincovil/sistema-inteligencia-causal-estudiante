# Plan de mejora del prototipo «Puente» (`prototipo_ml_causal`)

Origen: revisión de los capítulos 10 (ortogonalidad de Neyman, cross-fitting) y 11 (DML-PLR/IRM) del libro *Sistema de Inteligencia Causal* y de la sesión express `SESION_DML_40MIN` (raíz del repo). Objetivo: incorporar esos resultados al prototipo **sin cambiar su alcance**, alineado con los objetivos de aprendizaje del sílabo (`01_silabo`, sección 3.2, objetivos 1–7).

Principio rector: el prototipo ya implementa AIPW con cross-fitting, ESS de Kish, trimming declarado, cobertura Monte Carlo, puerta y abstención. Lo nuevo no es un algoritmo: son **puerta, declaración y evidencia**. No se añaden datos con verdad sintética al repo público, ni se promete que la puerta «garantice identificación».

## Contexto

- `07_docencia/prototipo_ml_causal/` es un repo git separado (`github.com/jelincovil/prototipo_ml_causal`) espejado en este monorepo; la rama `semana4/proyecto` mantiene `semana_4_proyecto/` como copia de trabajo.
- Los cambios de código (puntos 1–5) se implementan en el repo del prototipo, con sus pruebas; no como parches sobre la copia del monorepo.
- El punto 6 es de este repo (documentación/enlaces).

## Cambios propuestos (en orden de costo/beneficio)

1. **Puerta por cobertura** — convertir `cobertura.py` en compuerta dura del registro/CI: la promoción de una versión solo se permite si la cobertura de la corrida Monte Carlo cae en un rango declarado (p. ej. [0.90, 0.99]) y el sesgo cumple |bias| < cota. Hoy `artifacts/cobertura.json` es evidencia, no criterio de bloqueo.
   - Objetivos: 3 (evaluación fuera de muestra con Qini/placebos/sensibilidad) y 5 (puerta automática antes de publicar).
2. **Declarar el estimando efectivo tras trimming** — cuando `estimacion.py` recorta ê a [0.05, 0.95], la tarjeta (`registro.py`) debe declarar explícitamente «ATE en población con *overlap*», no ATE poblacional; la puerta valida el campo antes de promover.
   - Objetivos: 5 y 7 (comunicar con supuestos y límites explícitos).
3. **Añadir el brazo «sin cross-fitting» a `cobertura.py`** — AIPW ajustando y prediciendo en la misma muestra, reproduciendo la Tabla 3 del guion (55 % vs 87,5 % de cobertura con boosting) como benchmark reproducible del prototipo.
   - Objetivos: 3 y 6 (falsificación).
4. **Portar el chequeo de invariantes de cross-fitting del cap. 11** (`verificar_cross_fitting`: particiones disjuntas, cada unidad en exactamente un fold de prueba, semilla fija) como test en `pruebas_estimacion.py`.
   - Objetivos: 2 (pipelines sin fuga causal).
5. **Abstención por ESS** — extender la puerta para abstenerse cuando ESS/n cae bajo una cota **declarada como convención** (con el mismo análisis de sensibilidad ±20 % que ya usa el monitor), nunca como verdad universal.
   - Objetivos: 6 (monitorear supuestos observables y falsificables).
6. **Enlazar `SESION_DML_40MIN.pdf` en `prototipo_ml_causal/docs/` y en su README** como «guía del método» del operador: qué firmar al publicar un ATE (y por qué).
   - Objetivos: 7 (comunicación a negocio con supuestos explícitos).

## Fuera de alcance (explícito)

- No incorporar datos con verdad sintética (`interventions.json`, `truth`) al repo público.
- No prometer calibración o identificación garantizada: el monitor y la puerta hacen visibles problemas; no prueban el efecto.
- No añadir CATE / policy learning ahora: pertenece a las semanas S21–S24 del sílabo y diluiría el alcance del prototipo.
- No modificar la separación entre `main` (paquete del estudiante) y `semana4/proyecto` (prototipo docente) sin decisión explícita de la rama.

## Secuencia sugerida

1. Puntos 1 y 4 (los más baratos y verificables; actividad de CI + tests).
2. Puntos 2 y 5 (registro/puerta; requieren decisión de umbrales y textos de tarjeta).
3. Punto 3 (benchmark; revisar semilla y costo de cómputo antes de fijarlo en CI).
4. Punto 6 (documentación; sin código).

## Criterios de aceptación

- CI del prototipo falla si la cobertura de la corrida de referencia sale del rango declarado o si los invariantes de cross-fitting fallan.
- La tarjeta generada por `registro.py` incluye el estimando efectivo cuando hay trimming; la puerta rechaza tarjetas sin él.
- La evidencia conservada (`evidencia/`) se regenera con las nuevas compuertas y sus hashes se actualizan.
- El README del prototipo enlaza la guía del método y declara los límites de la puerta.

## Referencias

- Capítulos 10 y 11 de *Sistema de Inteligencia Causal* (edición 2026), `02_causal AI en produccion/Causal_AI/capitulos/`.
- `SESION_DML_40MIN.typ` / `.pdf` (raíz del repo): guion del profesor, 40 minutos, con las tablas de cobertura y el checklist de 8 puntos.
- Sílabo ECO-490/ECON-540 2026-II, §3 (objetivos y evidencia), `01_silabo/silabo.pdf`.
