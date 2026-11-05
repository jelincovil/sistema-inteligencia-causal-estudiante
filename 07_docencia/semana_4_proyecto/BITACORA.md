# Bitácora de construcción — «Puente» (semana 4)

Registro del trabajo sobre el kit: qué se hizo, por qué, y la evidencia que lo respalda.
Convención de cada entrada: **qué · por qué · evidencia**.

Este archivo es el complemento del material del curso: `README.md` (mapa del kit),
`ENTREGA.md` (checklist) y `pregunta.md` (estimando declarado) **no se modifican**;
la bitácora registra lo que ocurrió al construirlo.

---

## 1. Estado de partida

| Pieza | Valor |
|---|---|
| Repositorio | `sistema-inteligencia-causal-estudiante-main` |
| Rama de trabajo | `semana4/proyecto` (desde `main`, que sigue a `origin/main`) |
| Commit baseline | `78486ad` — 33 archivos, 6401 líneas |
| Tag anotado | `semana4-kit-original` |
| Manifiesto | `BASELINE.sha256` — 32 archivos |
| Verificación del manifiesto | 32/32 `OK` |
| `git diff semana4-kit-original` | vacío (el árbol **es** el kit distribuido) |
| Arranque del kit | `make verificar` falla con `TODO-1` (correcto) |

Evidencia del estado de arranque:

```text
Esquema C-01: EsquemaCausal(tratamiento='treatment', resultado='re78',
             covariables=('age','educ','black','hispan','married','nodegree','re74','re75'))
  File "datos.py", line 35, in validar
    raise NotImplementedError("TODO-1 pendiente de completar")
NotImplementedError: TODO-1 pendiente de completar
make: *** [verificar] Error 1
```

Copia externa (capa 3 del protocolo): `tar.gz` generado desde el tag,
sha256 `141760578f6bf87ccf744d08284c0fa689eee8d51c3c7a80ba366b92567fbfd1`,
**pendiente de mover** de `/tmp` a `~/backups/` (el sandbox del agente no escribe fuera del proyecto).

Cómo comprobar el baseline en cualquier momento:

```sh
git diff --stat semana4-kit-original          # cambios respecto al original
shasum -a 256 -c BASELINE.sha256              # integridad archivo por archivo
git show semana4-kit-original:07_docencia/semana_4_proyecto/datos.py
```

---

## 2. Entorno

| Componente | Valor |
|---|---|
| Env | `temp_causal_env` (`/opt/homebrew/Caskroom/miniforge/base/envs/temp_causal_env`) |
| Python | 3.13.18 |
| numpy / scipy | 2.3.5 / 1.17.0 |
| fastapi / starlette / uvicorn | 0.115.12 / 0.46.2 / 0.34.0 |
| httpx / matplotlib / ipykernel | 0.28.1 / 3.11.2 / 7.0.0 |

Decisiones:

- **No se crea `.venv` propio**: el env anterior ya cubre `requirements.txt` completo
  (incluido `fastapi`, que es lo único que falta en `causal_env` y en miniforge base).
- **Kernel del notebook**: el `.ipynb` pide `sic-estudiante`, que no está registrado.
  Como las celdas `!make` heredan el `PATH` del kernel, el kernel determina qué
  `python3` ejecuta los scripts. Alias propuesto (un puntero, no una instalación):

```sh
/opt/homebrew/Caskroom/miniforge/base/envs/temp_causal_env/bin/python \
  -m ipykernel install --user --name sic-estudiante \
  --display-name "Python (SIC estudiante)"
```

Ejecutar siempre con ese env al frente del `PATH`:

```sh
PATH=/opt/homebrew/Caskroom/miniforge/base/envs/temp_causal_env/bin:/usr/bin:/bin make verificar
```

---

## 3. Datos del escenario (lo que el kit entrega)

| | `real/jobs` (clase) | `real/ihdp` (entrega) |
|---|---|---|
| Unidades (train / val / test) | 1033 / 344 / 345 | 448 / 149 / 150 |
| Tratados en train | 262 | 191 (42,7 %) |
| Resultado | `re78` (USD 1978) | `outcome` |
| Covariables | 8 | 25 |
| `observed_train.csv` sha256 | `cd5a772e…5d7ae2` (== `splits.json`) | `9af86718…` (== `splits.json`) |
| `truth_*.csv` | no existe (la pared) | no existe (la pared) |

---

## 4. Estado de los bloques

| Bloque | TODOs | Archivo | Estado |
|---|---|---|---|
| 2 · roles y pared | 1, 2, 3 | `datos.py` | cerrado (checkpoint 1 en verde) |
| 3 · efecto e incertidumbre | 4–8, 21, 22 | `estimacion.py` | cerrado (checkpoint 2 en verde) |
| 4 · tarjeta y registro | 9–13 | `registro.py` | cerrado (checkpoint 3 en verde) |
| 5 · ventanas y puerta | 14–18 | `monitor.py` | cerrado (checkpoint 4 en verde) |
| 6 · servicio | 19, 20 | `servicio_core.py` | cerrado (checkpoint 5 en verde) |
| 7 · adaptación | — | esquema, corte, ventanas, umbrales | pendiente |

Cada bloque se cierra cuando su checkpoint coincide con la salida esperada del
notebook **y** queda registrado aquí con su evidencia.

---

## 5. Entradas por bloque

### Bloque 2 — `datos.py` (TODO-1…3)

- **Qué:** `validar` rechaza con tres `if` que nombran la columna culpable (ausente en
  los datos, asignada a más de un rol, tratamiento sin variación); `verificar_splits`
  recomputa el SHA-256 de cada partición y lo compara con `splits.json`;
  `comprobar_pared` traduce el `FileNotFoundError` de `truth_train.csv` en confirmación
  y lanza `RuntimeError` si el archivo apareciera.
- **Por qué:** C-01 exige un rol único por columna; el chequeo de doble rol se hace a
  nivel de **esquema** (`EsquemaCausal.columnas()`), porque el error real es declarar
  `re78` como resultado *y* covariable, o `treatment` como resultado. C-10 exige no
  confiar en lo declarado: el hash se recomputa, no se lee. La pared no es una
  convención: su ausencia se comprueba con código, y si alguien reintroduce la verdad
  en el paquete el programa falla en vez de seguir.
- **Evidencia:** checkpoint 1 idéntico a la salida esperada del notebook (3 hashes `OK`,
  `n = 1033`, `tratados = 262`, pared OK). Pruebas negativas:

```text
columna ausente       -> columna(s) del esquema ausentes en los datos: ['educ','hispan','married','nodegree','re74','re75']
doble rol             -> columna(s) con más de un rol: ['re78']
tratamiento constante -> el tratamiento 'treatment' no varía en los datos
caso válido           -> OK
```

```text
$ make verificar
esquema valida contra observed_train: OK (n = 1033, tratados = 262)
  train        hash OK  (1033 filas, semilla 20240701)
  validation   hash OK  (344 filas, semilla 20240701)
  test         hash OK  (345 filas, semilla 20240701)
  pared OK: truth_train.csv no existe en el paquete (reservado)
```

### Bloque 3 — `estimacion.py` (TODO-4…8, 21, 22)

- **Qué:** OLS con SE clásico (`sigma2 * (M'M)⁻¹[1,1]`); logística por BFGS para el
  propensity; ESS de Kish con `e` recortada a `[1e-6, 1-1e-6]`; SMD con desviación
  común; trampa `score_post` (0,6·Y + 0,4·D + ruido N(0,500)); **AIPW con cross-fitting**
  K=5 (outcome por brazo y propensity ajustados fuera del fold que predicen, trimming
  `[0,05, 0,95]`, score = influence function del ATE); estratos `nodegree` con su IC.
- **Por qué:** dos piernas estimadas fuera de muestra son la exigencia del Cap. 9:
  ningún nuisance ve a la unidad que predice. El trimming es una decisión **declarada**,
  no un ajuste a posteriori. El estrato promedia scores AIPW: es heterogeneidad
  sugerida, no un CATE, y su IC se declara como tal.
- **Evidencia:** salida idéntica a la esperada del notebook:

```text
diferencia cruda = 1600.8 USD
ATE OLS (8 controles) = 1596.0 | SE = 301.6 | IC95 = [1004.8, 2187.3]
AIPW cross-fitting K=5 = 1638.6 | SE = 325.0 | IC95 = [1001.6, 2275.7]
trampa score_post      = 172.4  <- el coeficiente se vació
nodegree=1 (n=568): 1060.1 IC95 [233.1, 1887.2]
nodegree=0 (n=465): 2345.2 IC95 [1356.9, 3333.4]
ESS = 729 (0.71) | rango e = [0.092, 0.530] | solapamiento = 100% | SMD máx = 0.19
```

### Bloque 4 — `registro.py` (TODO-9…13)

- **Qué:** tarjeta con los 7 campos de C-09 (supuestos clasificados
  `observable`/`no_observable`, umbrales 0,25/0,25/0,50, heterogeneidad declarada);
  validación de la tarjeta; manifiesto con `version`, `dataset_sha256`, `puerta` y hash
  de cada JSON; `verificar_integridad` que recomputa; promoción atómica
  (`champion.tmp` → `replace`), que rechaza `falla` y `alerta` sin aceptación explícita.
- **Por qué:** la afirmación publicada se refiere a un sujeto con hash: si el hash no
  coincide, la versión no es la misma. La versión es inmutable (nunca se edita en
  sitio) y la promoción es un rename atómico: no hay estado intermedio.
- **Evidencia:**

```text
registrada v0001 | integridad: OK
mutación detectada: SÍ (hash distinto del manifiesto -> bloqueado)
champion -> v0001
champion resuelve a: v0001
```

### Bloque 5 — `monitor.py` (TODO-14…18)

- **Qué:** PSI con deciles de la referencia como cortes y `clip` en 1e-4; ventana sana
  (submuestra de 700 sin reemplazo); deriva (`age + 10` sobre copia); positividad
  (tratados con `re74 > p75`, controles con `re74 < p25`); puerta con prioridad
  `falla` (soporte) > `alerta` (PSI o balance).
- **Por qué:** el soporte es condición de identificación, no de calidad: si se rompe,
  no hay número que reportar. La deriva y el desbalance son señales de proceso
  (revisar antes de reentrenar), no fallos del estimando. La puerta nombra la
  covariable culpable para que la alerta sea accionable.
- **Evidencia:**

```text
[sana        ] pasa   | PSI máx 0.005 | SMD 0.21 | ESS/n 0.69 | solape 100%
[deriva      ] alerta | PSI máx 1.347 | SMD 0.19 | ESS/n 0.71 | solape 100%
              - deriva: PSI de age = 1.35 (umbral 0.25)
[positividad ] falla  | PSI máx 3.237 | SMD 5.24 | ESS/n 1.0  | solape 0%
              - solapamiento roto: 0% de unidades con e en [0.05, 0.95] (mínimo 50%)
```

### Bloque 6 — `servicio_core.py` (TODO-19…20)

- **Qué:** carga del bundle `champion` (estimación + tarjeta, cacheada, sin leer CSV);
  `/consulta` devuelve el efecto del **estrato** declarado y, fuera del rango de
  entrenamiento de cualquier covariable, se abstiene con HTTP 200 y sin ningún número.
- **Por qué:** abstención de primera clase: «no sé» es una respuesta válida y no un
  error 4xx/5xx. El servicio declara **qué cubre** su intervalo (media del estrato, no
  ATE ni efecto individual) porque el mismo endpoint podría sugerir lo contrario.
- **Corrección fuera de los TODOs (declarada):** `efecto()` servía `ate_ols`/`ic95`
  mientras la tarjeta declara el AIPW como estimador principal y el notebook espera
  `1638.6`. Se cambió a `ate_aipw`/`ic_aipw` y se añadió `estimador` a la respuesta.
  Es el hallazgo 2, resuelto aquí.
- **Evidencia:**

```text
/salud: 200 {'estado': 'ok', 'version': 'v0001', ...}
/efecto: 200 efecto=1638.6 ic95=[1001.6, 2275.7] version=v0001
/consulta dentro: 200 estado=respuesta efecto=1060.1
/consulta fuera (age=99): 200 estado=abstencion motivo=age=99 fuera de [18.0, 54.0] (sin número)
determinismo: dos llamadas idénticas -> iguales
HUMO: OK
```

---

## 6. Hallazgos sobre el kit (a resolver o declarar en la entrega)

1. **La pared tiene un hueco**: `interventions.json` incluye `ate`, `att` y
   `tau_summary` (media, desviación y cuantiles del efecto unitario) en ambos
   escenarios. La verdad poblacional viaja en el paquete: la regla «no se usa para
   estimar ni calibrar» es disciplina declarada, no garantía del sistema de archivos.
2. **`/efecto` publicaba el OLS, no el AIPW**: `estimar()` guarda `ate_ols`/`ic95` y
   `ate_aipw`/`ic_aipw` por separado; `servicio_core.efecto()` devolvía los primeros
   mientras la tarjeta declara el AIPW como principal. **Resuelto** en el bloque 6
   (sirve `ate_aipw`/`ic_aipw` y declara `estimador`); ver evidencia allí.
3. **`smd` del monitor mide balance interno de la ventana**, no deriva contra
   `train`: por eso `deriva` (edad +10 en ambos brazos) solo la detecta el PSI.
4. **ESS/n ≈ 1 no es buena señal** en la ventana `positividad`: con asignación casi
   determinista, los pesos son casi constantes dentro de cada brazo. La señal que
   rompe la puerta es el solapamiento.
5. **`requirements.txt` no cubre la experiencia del notebook** (faltan `matplotlib`
   y `ipykernel`/`jupyter`, que sí usa la celda del gráfico y el kernel).
6. **`verificar_integridad` no se invoca al cargar el bundle**: el servicio confía en
   el `champion` sin recomputar hashes, aunque el discurso del prototipo sea
   «todo se afirma sobre artefactos con hash».
7. **Partes cableadas a `jobs`** al adaptar a `ihdp`: `EsquemaCausal`, el corte de
   `estratos_nodegree`, `ventana_deriva` (`age`), `ventana_positividad` (`re74`),
   `humo.py` (perfil con `age`/`nodegree`/`re74`) y el texto de `/efecto`
   («USD de 1978»).

---

## 7. Reproducción

```sh
# flujo completo (el criterio de la rúbrica)
make demo

# equivalencias si no hay make
python3 datos.py && python3 estimacion.py && python3 registro.py \
  && python3 monitor.py && python3 humo.py
```

`artifacts/` es generado (`make limpiar` lo borra) y se versiona solo al cerrar la
entrega, porque `ENTREGA.md` lo exige.

---

## 8. Adaptación a `real/ihdp` (entrega)

- **Esquema:** _pendiente_ (resultado `outcome`, 25 covariables desde `identification.json`).
- **Corte de heterogeneidad:** _pendiente_ (regla declarada **antes** de mirar efectos).
- **Ventanas:** _pendiente_ (covariable continua de `ihdp`, p. ej. `bw` o `momage`).
- **Umbrales:** _pendiente_ (justificación en dos líneas por umbral).
- **Pregunta y supuestos:** _pendiente_ (mismo formato que `pregunta.md`).
- **Números:** _pendiente_ (tabla de la sección 7 del notebook).
