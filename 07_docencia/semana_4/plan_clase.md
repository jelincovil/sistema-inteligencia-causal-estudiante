# Plan de clase — Prototipo de ML causal en producción local (semana 4)

**Clase en vivo online · 2 h 30 min (150 min) · `real/jobs`, FastAPI, registro local, puerta causal.**

**Objetivo:** al terminar, cada estudiante tiene corriendo en su máquina un servicio local que estima un efecto con incertidumbre, se abstiene fuera del soporte, registra versiones con hash y alias `champion`, y vigila ventanas de producción con una puerta `pasa/alerta/falla` — el esqueleto completo del proyecto final en miniatura, usando solo lo aprendido en los capítulos 1–8.

**Formato:** el profesor codifica en vivo sobre el máster (`kit/`); los estudiantes siguen y ejecutan checkpoints en su copia (`proyecto/proyecto.ipynb` — conductor del proyecto, con los mismos 22 TODOs en los `.py`). Cada bloque cierra con un checkpoint verificable por comando. La solución de referencia (`solucion/`) es material del profesor.

**Lectura del tablero de tiempos:** el minuto indicado es el *deadline de arranque* del bloque. Si al llegar el minuto el checkpoint no está verde, se aplica el recorte marcado en ⏱.

---

## Minuto 0–10 · Arranque: la pregunta antes que el código (Cap. 1)

- (3 min) Objetivo de la clase: construir el **puente** del dato a la decisión. Mostrar el flujo en pizarra: `pregunta → esquema → split → estimación → tarjeta → registro → servicio → monitor`.
- (5 min) Se lee `pregunta.md` en voz alta: pregunta causal, estimando (ATE de `treatment` sobre `re78`), población, supuestos con su clase. **Momento docente:** «la pregunta y el estimando se escriben antes de mirar una sola fila; el resto de la clase solo hace que esto sea computable».
- (2 min) Entorno: venv del curso activado (`python -m ipykernel…` no hace falta hoy), `cd 07_docencia/semana_4/kit`, `make verificar` debe fallar con `NotImplementedError` — **ese es el estado correcto de arranque**.

**Checkpoint 0:** `make verificar` falla con `TODO-1`. Se dice explícitamente: «todo lo que hoy construye el profesor, ustedes lo tienen como TODO en su kit».

---

## Minuto 10–29 · BLOQUE 2 — El contrato de roles y la pared (Caps. 3 y 5) · `datos.py`

- **TODO-1 (4 min, se muestra completo)** `EsquemaCausal.validar`: los tres `if` ya escritos se leen juntos — ausentes, doble rol, tratamiento constante. Se provoca el fallo del renombre de `educ` en vivo.
- **TODO-2 (10 min)** `verificar_splits`: recomputar SHA-256 de las tres particiones contra `splits.json`. **Momento docente:** «el productor declaró los hashes; el consumidor no confía, recomputa».
- **TODO-3 (5 min)** `comprobar_pared`: `truth_train.csv` no existe en el paquete — el `FileNotFoundError` ES la pared.

**⏱ Checkpoint 1 (min 29):** `make verificar` imprime las tres líneas `hash OK` y `pared OK`. Números esperados: n = 1 033, tratados = 262, semilla de split 20240701.

---

## Minuto 29–69 · BLOQUE 3 — El efecto con incertidumbre, ahora doblemente robusto (Caps. 1, 6, 7 y el puente al 9) · `estimacion.py`

- **TODO-4 (8 min)** `ate_ols` — la referencia ingenua: `lstsq` + SE + IC. Matriz a mano en pizarra: `M = [1, D, X]`. La fórmula del SE se dicta.
- **TODO-21 (18 min, LA INNOVACIÓN)** `aipw_crossfit`: el bucle de folds (K = 5, semilla declarada), el outcome por brazo y el propensity ajustados **fuera** del fold que predicen, y el score AIPW por unidad. **Momento docente del día:** «ningún nuisance ve a la unidad que predice — la exigencia número uno del Cap. 9, cumplida en 15 líneas» y «el estimador tiene dos piernas: outcome y propensity; si una cojea, la otra sostiene».
- **TODO-5/6/7 (8 min)** `propensity` (dada), `ess_kish`, `smd`.
- **TODO-22 (5 min)** `estratos_nodegree`: la media de scores por estrato con su IC. La regla del corte está en la tarjeta, **pre-declarada**.
- **TODO-8 (3 min)** `trampa_score_post`: la columna calculada con el resultado — «el score de éxito del programa» que vacía el coeficiente.

**⏱ Checkpoint 2 (min 69):** `make estimar`. Números esperados (verificados):

```
diferencia cruda E[Y|D=1]-E[Y|D=0] = 1600.8 USD
ATE OLS (8 controles) = 1596.0 | SE = 301.6 | IC95 = [1004.8, 2187.3]
AIPW cross-fitting K=5 = 1638.6 | SE = 325.0 | IC95 = [1001.6, 2275.7]
trampa score_post      = 172.4  <- el coeficiente se vació
estrato nodegree=1 (sin título, n=568): efecto 1060.1 IC95 [233.1, 1887.2]
estrato nodegree=0 (con título, n=465): efecto 2345.2 IC95 [1356.9, 3333.4]
ESS = 729 (ESS/n = 0.71) | rango e = [0.092, 0.530] | solapamiento = 100%
SMD máx = 0.19
```

Lectura en voz alta: (1) OLS y AIPW — dos estimadores distintos, misma conclusión: eso es lo que la doble robustez compra en confianza; ambos cubren el ~1 800 de referencia (que no se miró). (2) Los estratos **sugieren** que el programa rinde más en quienes tienen título — pero los intervalos se solapan: heterogeneidad sugerida, no concluyente. El servicio lo dirá con esa letra. (3) La trampa baja el efecto a 172 sin ningún error.

**Recortes:** TODO-5 (propensity de `estimar`) se pega completa; el bloque 2 ya cedió 6 min.

---

## Minuto 69–74 · Descanso (5 min)

---

## Minuto 74–99 · BLOQUE 4 — Tarjeta, registro y champion (Cap. 4) · `registro.py`

- **TODO-9 (8 min)** `construir_tarjeta`: los 7 campos; supuestos con clase `observable`/`no_observable` (adenda de contratos); **umbrales calibrados** (`smd_max` 0.25, `psi_alerta` 0.25, `solape_min` 0.50) — el monitor los consumirá.
- **TODO-10 (3 min)** `validar_tarjeta`.
- **TODO-11 (6 min)** `registrar`: carpeta `vNNNN/` con `estimacion.json`, `tarjeta.json`, `manifest.json` con hashes. Inmutabilidad: registrar crea, nunca sobrescribe.
- **TODO-12/13 (8 min)** `verificar_integridad` y `promover`: `champion.tmp` + `rename` (atómico); puerta `falla` nunca se promueve. Correr `demo_mutacion`: un byte inyectado → hash distinto → bloqueado.

**⏱ Checkpoint 3 (min 90):** `make registrar`:

```
registrada v0001 | integridad: OK
mutación detectada: SÍ (hash distinto del manifiesto -> bloqueado)
champion -> v0001
champion resuelve a: v0001
```

**Momento docente:** «la afirmación publicada se refiere a un sujeto con hash; si la tabla cambia, el enunciado queda huérfano — por eso la versión es inmutable».

**Recorte:** TODO-12 se pega completo; se gana ~4 min.

---

## Minuto 99–124 · BLOQUE 5 — Ventanas y puerta causal (Caps. 2 y 7) · `monitor.py`

- **TODO-14 (8 min)** `psi` (deciles, frecuencias, `sum((a−b)·log(a/b))`).
- **TODO-15/16/17 (7 min)** las tres ventanas: `sana` (submuestra sembrada 4242), `deriva` (edad +10), `positividad` (tratados con `re74` alto, controles con `re74` bajo).
- **TODO-18 (10 min)** `evaluar_ventana`: la puerta — `falla` si el solapamiento cae bajo el mínimo, `alerta` si la deriva o el balance cruzan umbral; cada estado con su **acción de las cinco**.

**⏱ Checkpoint 4 (min 124):** `make ventanas` (salida completa en la guía del profesor). Lo esencial:

```
[sana        ] estado = pasa   | acción: continuar
[deriva      ] estado = alerta | acción: alertar (revisar antes de reentrenar)
              - deriva: PSI de age = 1.35 (umbral 0.25)
[positividad ] estado = falla  | acción: abstenerse (bloquear la promoción)
              - solapamiento roto: 0% de unidades con e en [0.05, 0.95] (mínimo 50%)
```

**Momento docente:** «la señal orienta la revisión; no prueba la causa del cambio» (regla de oro del libro) — y las tres situaciones de la demostración del proyecto final ya están, en miniatura.

**Recorte:** la ventana `sana` se comenta (solo deriva y positividad en vivo); se gana ~5 min.

---

## Minuto 124–146 · BLOQUE 6 — El servicio: abstención y efecto del estrato (Cap. 2 y Parte IV) · `servicio_core.py` + `servicio.py`

- **TODO-19 (6 min)** `_cargar`: el bundle champion — **el servicio no lee CSV**, solo artefactos del registro. «El bundle viaja; los datos no».
- **TODO-20 (12 min)** `consulta`: fuera del rango del train → `abstencion` **sin número**; dentro → **el efecto del estrato** con su IC, qué cubre, la nota de heterogeneidad y la versión. Ya no responde el efecto poblacional: responde el del perfil.
- (4 min) `servicio.py` (FastAPI, ya completo) y `humo.py`.

**⏱ Checkpoint 5 (min 146):** `make humo`:

```
/salud: 200 {'estado': 'ok', 'version': 'v0001', ...}
/efecto: 200 efecto=1638.6 ic95=[1001.6, 2275.7] version=v0001
/consulta dentro: 200 estado=respuesta efecto=1060.1
/consulta fuera (age=99): 200 estado=abstencion motivo=age=99 fuera de [18.0, 54.0] (sin número)
determinismo: dos llamadas idénticas -> iguales
HUMO: OK
```

**Momento docente de cierre del bloque:** `/efecto` responde el poblacional (1 638,6); `/consulta` responde el del estrato (1 060,1 para `nodegree=1`) con la nota que prohíbe el targeting. Dos estimandos distintos en el mismo servicio, cada uno declarando qué cubre su intervalo.

---

## Minuto 146–150 · Cierre: el mapa hacia el proyecto final

- (2 min) `make demo`: el flujo completo en un comando — «esto que acabamos de hacer en 2 h 30 es el esqueleto del 70 % de la nota».
- (2 min) Qué falta para el proyecto (tabla en la guía del profesor): learners no lineales y repeated cross-fitting (Cap. 9 completo), CATE continuo y política, holdout, sensibilidad, comparación predictivo vs causal.
- Tarea (escrita, no se explica en vivo): reproducir el flujo con `real/ihdp` y reportar ATE, IC, ESS/n, estratos y las tres ventanas propias.

---

## Presupuesto de escritura en vivo

| Bloque | TODOs | Líneas nuevas | Riesgo |
|---|---|---|---|
| 2 (`datos.py`) | 1–3 | ~9 | bajo (TODO-1 se muestra) |
| 3 (`estimacion.py`) | 4–8, 21–22 | ~33 | medio-alto (el bucle AIPW es la pieza del día) |
| 4 (`registro.py`) | 9–13 | ~31 | medio (muchas piezas pequeñas) |
| 5 (`monitor.py`) | 14–18 | ~29 | medio (la puerta concentra el mensaje) |
| 6 (`servicio_core.py`) | 19–20 | ~14 | bajo |
| **Total** | **22** | **~120** | realista para 150 min guiados |

## Si la clase se cae a mitad (recuperación)

El estado completo está a un comando: `cd ../solucion && make demo`. Mostrar la salida completa, repasar los cinco checkpoints y cerrar con el mapa del proyecto. **Nunca se improvisa código nuevo por detrás del cronograma.**
