# Guía del profesor — Prototipo causal local (semana 4)

Material de docencia. No se distribuye con el kit del estudiante.

## Qué es este prototipo

«Puente»: un servicio causal local mínimo sobre `real/jobs` que ejerce, en 2 h 30, los capítulos 1–8 del libro y deja el esqueleto del proyecto final. Deliberadamente **sin DML** (Cap. 9): el estimador es OLS con controles del esquema, para que el plano de datos sea lo visible. Docker es una demo de 5 min, no un requisito.

## Checklist de preparación

**T‑7 días**
- [ ] Anunciar el material del estudiante: copiar `07_docencia/semana_4/proyecto/` al repositorio de la sesión (o al repo de cada estudiante). El `kit/` queda como tu máster en vivo.
- [ ] Pedir el entorno del curso verificado (`python scripts/doctor_minimo.py`) + `pip install -r 07_docencia/semana_4/proyecto/requirements.txt`.

**T‑1 día (ensayo completo, ~20 min)**
- [ ] `cd solucion && make limpiar && make demo` — el flujo completo debe salir igual que la tabla de números esperados (abajo).
- [ ] `make humo` en el venv del curso (la salida debe decir `HUMO: OK`).
- [ ] Probar recortes: abrir `kit/registro.py` y confirmar que los TODO están numerados como el plan.
- [ ] Docker (si se va a demostrar): `docker build -t puente .` desde `solucion/` y `docker run --rm -p 8000:8000 puente` + `curl localhost:8000/efecto`. Si algo falla, **no se demuestra docker** (es opcional).

**T‑10 min**
- [ ] Compartir pantalla con dos terminales listas: una en `kit/`, otra en `solucion/` (para el estado completo si hay recuperación).
- [ ] Tener abierta la tabla de números esperados (abajo).
- [ ] `make verificar` en el kit: debe fallar con `TODO-1` (estado de arranque correcto).

## Tabla de números esperados (verificada, semillas 4242 y 20240701)

Estos números salen de correr la solución sobre el escenario `real/jobs` tal como está en el repositorio. Si en clase sale algo distinto, es un problema de entorno, no de azar: revisar la partición (los hashes del checkpoint 1 lo dirigen).

### Checkpoint 1 — `make verificar`

```
esquema valida contra observed_train: OK (n = 1033, tratados = 262)
  train        hash OK  (1033 filas, semilla 20240701)
  validation   hash OK  (344 filas, semilla 20240701)
  test         hash OK  (345 filas, semilla 20240701)
  pared OK: truth_train.csv no existe en el paquete (reservado)
```

### Checkpoint 2 — `make estimar`

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

**Puntos para narrar (la innovación es el centro del bloque 3):**
- **OLS y AIPW — dos estimadores distintos, misma conclusión** (1 596 vs 1 638, intervalos casi iguales): eso es lo que la doble robustez compra en confianza. El AIPW tiene dos piernas (outcome y propensity); si una cojea, la otra sostiene. Y ningún nuisance vio a la unidad que predice: la exigencia número uno del Cap. 9, cumplida en 15 líneas.
- Ambos intervalos **cubren** el ~1 800 de referencia del diseño (metadata.json lo declara; no se miró para estimar — la pared).
- **Los estratos son el argumento del servicio nuevo:** 1 060 (sin título) contra 2 345 (con título) — heterogeneidad *sugerida*. Los intervalos **se solapan** ([233, 1887] vs [1357, 3333]): no se afirma targeting con esto solo, y el servicio lo dice con esa letra.
- **Por qué el corte es `nodegree` y no otro:** la regla está pre-declarada en la tarjeta por interpretabilidad y balance. `black` tiene MÁS ganancia de varianza como corte — y elegirla por eso sería segmentar por raza: exactamente la decisión de equidad (Cap. 23 de la edición de método) que no se toma mirando una métrica de ganancia. Decirlo en una frase; no abrir el debate.
- La trampa `score_post` baja el efecto a **172** sin ningún error: la columna que cualquier área de negocio pediría, calculada con el resultado.
- La diferencia cruda (1 600,8) y la ajustada (1 596,0) casi coinciden **en este escenario sintético**: la confusión observable es deliberadamente leve. No vender «el ajuste lo cambia todo»; vender el camino completo con verificaciones.

### Checkpoint 3 — `make registrar`

```
registrada v0001 | integridad: OK
mutación detectada: SÍ (hash distinto del manifiesto -> bloqueado)
champion -> v0001
champion resuelve a: v0001
```

### Checkpoint 4 — `make ventanas`

```
[sana        ] estado = pasa   | acción: continuar
              n=700 | PSI máx = 0.005 | SMD máx = 0.21 | ESS/n = 0.69 | solapamiento = 100%
              - todo dentro de umbral

[deriva      ] estado = alerta | acción: alertar (revisar antes de reentrenar)
              n=1033 | PSI máx = 1.347 | SMD máx = 0.19 | ESS/n = 0.71 | solapamiento = 100%
              - deriva: PSI de age = 1.35 (umbral 0.25)

[positividad ] estado = falla  | acción: abstenerse (bloquear la promoción)
              n=270 | PSI máx = 3.237 | SMD máx = 5.24 | ESS/n = 1.0 | solapamiento = 0%
              - solapamiento roto: 0% de unidades con e en [0.05, 0.95] (mínimo 50%)
              - deriva: PSI de re74 = 3.24 (umbral 0.25)
```

**Puntos para narrar:**
- En `positividad`, el ESS/n = 1.0 **no** es buena señal: con la asignación determinista, las ponderaciones valen ~1 para todos y el ESS no distingue nada. La señal que rompe la puerta es el **solapamiento** (0 % de unidades con `e` en zona). Es exactamente la lección del Cap. 7: ninguna métrica sola basta; se reportan las tres.
- En `deriva` el SMD queda bajo (0.19): la deriva de la edad no desbalancea la asignación — solo cambia la población. Umbrales distintos, preguntas distintas.

### Checkpoint 5 — `make humo`

```
/salud: 200 {'estado': 'ok', 'version': 'v0001', 'estimando': 'ATE de treatment sobre re78 (efecto total)'}
/efecto: 200 efecto=1638.6 ic95=[1001.6, 2275.7] version=v0001
/consulta dentro: 200 estado=respuesta efecto=1060.1
/consulta fuera (age=99): 200 estado=abstencion motivo=age=99 fuera de [18.0, 54.0] (sin número)
determinismo: dos llamadas idénticas -> iguales
HUMO: OK
```

**Puntos para narrar:** (1) la abstención devuelve HTTP 200 — respuesta de primera clase, con el `motivo` nombrando la covariable y el rango. (2) `/efecto` y `/consulta` responden **estimandos distintos**: 1 638,6 (el poblacional, AIPW) contra 1 060,1 (el del estrato `nodegree=1`) — cada uno declara qué cubre su intervalo. Esa distinción, servida, es el salto de valor del prototipo.

## Mapa concepto → capítulo → pieza del prototipo

| Concepto del libro | Cap. | Se materializa en |
|---|---|---|
| Estimando declarado antes de mirar | 1 | `pregunta.md` (se lee en el minuto 0–10) |
| Invariante del plano de datos; cinco acciones | 2 | `monitor.py` (acción por estado) y la abstención del servicio |
| Contrato C-01: roles | 3 | `datos.py` → `EsquemaCausal` |
| Contrato C-09: hash, versión inmutable, champion | 4 | `registro.py` |
| Contrato C-10: split sembrado y la pared | 5 | `datos.py` → `verificar_splits`, `comprobar_pared` |
| Contrato C-03: validez temporal | 6 | la trampa `score_post` de `estimacion.py` |
| Contrato C-02: SMD/PSI/ESS y umbrales calibrados | 7 | `estimacion.py` (SMD, ESS) y `monitor.py` (PSI, puerta) |
| Benchmark como producto; estados de identificación | 8 | todo corre sobre `real/jobs` con sus archivos declarados |

## Fallos comunes y salida rápida

| Síntoma | Causa | Salida |
|---|---|---|
| `ModuleNotFoundError: fastapi` | venv sin activar o sin requisitos | `pip install -r requirements.txt`; no seguir sin esto |
| `make verificar` no falla con TODO | el kit ya fue completado (rehearsal vieja) | `cd kit && git checkout -- .` o re-copiar el kit |
| `FileNotFoundError: champion` en el humo | se saltó el bloque 4 | `cd ../solucion && make registrar` (usa el registro de la solución) — o mejor: recuperación completa (abajo) |
| Hash NO COINCIDE en el checkpoint 1 | alguien tocó los CSV del benchmark | `git status` en la raíz; los CSV no se tocan nunca |
| `RuntimeError: v0001 tiene puerta 'falla'` al promover | se promovió tras una ventana fallida | es el comportamiento correcto — narrarlo, no arreglarlo |
| Puerto 8000 ocupado (`make servir`) | otra instancia viva | `uvicorn servicio:app --port 8001` |
| SMD/PSI distintos en la ventana sana | cambió la semilla o el tamaño | la ventana sana usa semilla 4242 y n=700; son parte del contrato |

## Recuperación (si la clase se cae)

```
cd ../solucion && make demo
```

Salida completa en ~30 s; repasar los cinco checkpoints con la tabla y cerrar con el mapa del proyecto. No se improvisa código nuevo por detrás del cronograma.

## Correspondencia con el proyecto final (cierre)

| Requisito del proyecto (`06_proyecto_final/`) | ¿Se tocó hoy? |
|---|---|
| Pregunta causal + estimando + supuestos | sí — `pregunta.md` |
| Estimación con incertidumbre y objeto declarado | sí — **AIPW con cross-fitting** + IC + «qué cubre el IC», en versión poblacional y de estrato |
| Puerta causal `pasa/alerta/falla` | sí — `monitor.py` |
| Model card con supuestos `observable`/`no_observable` | sí — `tarjeta.json` |
| Registro con hashes y `champion` | sí — `registro.py` |
| Servicio local con abstención fuera de soporte | sí — FastAPI + humo |
| Monitoreo con acción operativa | sí — ventanas + acción de las cinco |
| DML / CATE / política / holdout / sensibilidad | **no** — proyecto (Caps. 9+ del libro) |
| Comparación predictivo vs causal (opcional) | **no** — proyecto |

**Tarea sugerida:** reproducir el flujo completo con `real/ihdp` (448/149/150) y reportar ATE, IC, ESS/n y las tres ventanas propias (umbrales recalibrados por el estudiante, con justificación — Cap. 7).
