# Construcción paso a paso — «Puente» (semana 4)

Guía de reproducción desde cero: instalar, verificar, construir los cinco bloques,
adaptar a `ihdp`, generar artefactos auditables y levantar el servicio.
Cada paso indica **el comando**, **la salida esperada** y **qué prueba**.

> Tiempo medido del pipeline completo (verificación + estimación + registro + ventanas +
> humo): **≈ 1,5–2 s**. Lo que lleva tiempo es instalar y leer, no ejecutar.

---

## 0. Requisitos

| Pieza | Versión usada | Nota |
|---|---|---|
| macOS / Linux | — | Probado en macOS arm64 |
| `git` | 2.x | Para el baseline y los tags |
| `make` | cualquiera | Los objetivos son atajos de un comando |
| Python | **3.13** (mínimo 3.10) | `from __future__ import annotations` en todos los módulos |
| Docker | opcional | Solo para empaquetar el servicio |

---

## 1. Instalación del entorno

### 1.1 Crear el entorno

Opción A — `uv` (rápido, sin tocar el Python del sistema):

```sh
cd semana_4_proyecto
uv venv --python 3.13 .venv
uv pip install --python .venv/bin/python -r requirements.txt
```

Opción B — `venv` clásico:

```sh
cd semana_4_proyecto
python3.13 -m venv .venv
. .venv/bin/activate
python -m pip install -r requirements.txt
```

`requirements.txt` cubre lo que el kit **usa de verdad**:

```text
numpy  scipy  fastapi  uvicorn  httpx        # pipeline + servicio
matplotlib                                  # celda del gráfico (§6.1)
ipykernel                                   # kernel del notebook
jupyterlab                                  # `jupyter lab` del LEEME
```

### 1.2 Verificar la instalación

```sh
python -V
python -c "import numpy, scipy, fastapi, matplotlib; print('ok')"
```

Esperado: `Python 3.13.x` y `ok`.

### 1.3 Registrar el kernel del notebook (una vez)

El notebook pide el kernel `sic-estudiante`; sin él, Jupyter abre con otro intérprete y
`!make` ejecutará un `python3` distinto (sin `fastapi`).

```sh
python -m ipykernel install --user --name sic-estudiante \
  --display-name "Python (SIC estudiante)"
jupyter kernelspec list
```

Esperado: aparece `sic-estudiante` apuntando a tu entorno.

> **Importante:** las celdas `!make` heredan el `PATH` del kernel. El kernel **es** el
> entorno del proyecto.

---

## 2. Estructura y primer arranque

### 2.1 Qué es cada archivo

| Archivo | Función |
|---|---|
| `pregunta.md` · `pregunta_ihdp.md` | Estimando declarado **antes** de mirar datos |
| `datos.py` | Esquema de roles (C-01), hashes de splits (C-10), la pared |
| `estimacion.py` | OLS, propensity, ESS, SMD, AIPW con cross-fitting, estratos, trampa |
| `registro.py` | Tarjeta, versión `vNNNN` con manifiesto, `champion` atómico |
| `monitor.py` | PSI, tres ventanas, puerta `pasa / alerta / falla` |
| `servicio_core.py` · `servicio.py` | Bundle cacheado + FastAPI |
| `humo.py` | Smoke test del servicio |
| `rutas.py` | Raíz del repo y escenario (`SIC_ESCENARIO`) |
| `data_benchmark_causal/…/real/{jobs,ihdp}` | Datos observados y metadatos |

### 2.2 Comprobar el contrato de datos

```sh
make verificar      # = python3 datos.py
```

Salida esperada (`real/jobs`):

```text
esquema valida contra observed_train: OK (n = 1033, tratados = 262)
  train        hash OK  (1033 filas, semilla 20240701)
  validation   hash OK  (344 filas, semilla 20240701)
  test         hash OK  (345 filas, semilla 20240701)
  pared OK: truth_train.csv no existe en el paquete (reservado)
```

Qué prueba: cada columna tiene un único rol, los tres splits coinciden con el
`sha256` declarado por el productor, y la verdad del escenario **no está** en el paquete.

> Si trabajas desde el kit original (tag `semana4-kit-original`), este paso **falla** con
> `TODO-1`: es el estado de arranque correcto. La construcción de cada bloque está
> registrada en `BITACORA.md` §5.

---

## 3. Construir el estimador (bloque 3)

```sh
make estimar        # = python3 estimacion.py
```

Salida esperada (`real/jobs`):

```text
diferencia cruda E[Y|D=1]-E[Y|D=0] = 1600.8 USD
ATE OLS (8 controles) = 1596.0 | SE = 301.6 | IC95 = [1004.8, 2187.3]
AIPW cross-fitting K=5 = 1638.6 | SE = 325.0 | IC95 = [1001.6, 2275.7]
trampa score_post      = 172.4  <- el coeficiente se vació
estrato nodegree=1 (sin título, n=568): efecto 1060.1 IC95 [233.1, 1887.2]
estrato nodegree=0 (con título, n=465): efecto 2345.2 IC95 [1356.9, 3333.4]
ESS = 729 (ESS/n = 0.71) | rango e = [0.092, 0.530] | solapamiento = 100%
SMD máx = 0.19
artefacto: artifacts/estimacion.json
```

Qué prueba: dos estimadores independientes coinciden (OLS 1596 vs AIPW 1638); la
trampa `score_post` vacía el coeficiente sin lanzar error (la fuga no penaliza el ajuste);
los estratos se informan con su IC y no como CATE.

Genera: `artifacts/estimacion.json`.

---

## 4. Registrar la versión y el champion (bloque 4)

```sh
make registrar      # = python3 registro.py
```

Salida esperada:

```text
registrada v0001 | integridad: OK
mutación detectada: SÍ (hash distinto del manifiesto -> bloqueado)
champion -> v0001
champion resuelve a: v0001
```

Qué prueba: la tarjeta valida sus siete campos, el manifiesto guarda el hash de cada
JSON, un byte añadido rompe la integridad, y la promoción es un `rename` atómico que
rechaza `falla` y `alerta` sin aceptación explícita.

Genera: `artifacts/registro/v0001/{estimacion,tarjeta,manifest}.json` y
`artifacts/registro/champion`.

---

## 5. Puerta causal sobre ventanas (bloque 5)

```sh
make ventanas       # = python3 monitor.py
```

Salida esperada:

```text
[sana        ] estado = pasa   | acción: continuar
[deriva      ] estado = alerta | acción: alertar (revisar antes de reentrenar)
              - deriva: PSI de age = 1.35 (umbral 0.25)
[positividad ] estado = falla  | acción: abstenerse (bloquear la promoción)
              - solapamiento roto: 0% de unidades con e en [0.05, 0.95] (mínimo 50%)
```

Qué prueba: la puerta distingue tres situaciones distintas y **nombra la señal**.
`positividad` con `ESS/n = 1.0` demuestra que la eficiencia de la ponderación no es
criterio de validez: lo que se rompe es el solapamiento.

---

## 6. Servicio y humo (bloque 6)

### 6.1 Humo sin levantar puerto

```sh
make humo           # = python3 humo.py
```

Esperado:

```text
/salud: 200 {'estado': 'ok', 'version': 'v0001', ...}
/efecto: 200 efecto=1638.6 ic95=[1001.6, 2275.7] version=v0001
/consulta dentro: 200 estado=respuesta efecto=1060.1
/consulta fuera (age=99): 200 estado=abstencion motivo=age=99 fuera de [18.0, 54.0]
determinismo: dos llamadas idénticas -> iguales
HUMO: OK
```

Qué prueba: el bundle viaja (el servicio no lee CSV), la abstención es HTTP **200** y sin
número, y dos llamadas idénticas devuelven lo mismo.

### 6.2 Servicio real

```sh
make servir          # uvicorn servicio:app --port 8000
curl -s localhost:8000/efecto | python -m json.tool
curl -s -X POST localhost:8000/consulta -H "Content-Type: application/json" \
  -d '{"age":99,"educ":10,"black":1,"hispan":0,"married":0,"nodegree":1,"re74":2000,"re75":1500}' \
  | python -m json.tool
```

La segunda llamada responde `{"estado": "abstencion", "motivo": "age=99 fuera de [18.0, 54.0]", ...}`
sin ningún número.

---

## 7. Adaptar el escenario a `ihdp`

El código es **paramétrico por escenario**: no se reescribe, se selecciona.

```sh
make limpiar                                   # borra artifacts (regenerables)
SIC_ESCENARIO=real/ihdp make demo
```

Cambios declarados (detalle y justificación en `BITACORA.md` §8):

| Pieza | `jobs` | `ihdp` |
|---|---|---|
| Resultado | `re78` | `outcome` |
| Covariables | 8 | 25 (`bw … was`) |
| Corte de heterogeneidad | `nodegree` | `bw` en la mediana de train |
| Deriva | `age + 10` | `bw + 1` (covariables estandarizadas) |
| Positividad | `re74` | `bw` (mayor |SMD| de tratamiento) |
| `solape_min` / `smd_max` | 0,50 / 0,25 | 0,30 / 0,50 |
| Trampa (ruido) | 500 USD | 1,0 punto |

Salida esperada (resumen):

```text
esquema valida contra observed_train: OK (n = 448, tratados = 191)
ATE OLS (25 controles) = 4.8 | SE = 0.5 | IC95 = [3.8, 5.8]
AIPW cross-fitting K=5 = 5.2 | SE = 0.6 | IC95 = [3.9, 6.4]
estrato bw=1 (bw alto (> mediana de train), n=224): efecto 7.2 IC95 [5.5, 8.8]
estrato bw=0 (bw bajo (<= mediana de train), n=224): efecto 3.2 IC95 [1.4, 4.9]
[sana] pasa · [deriva] alerta (PSI de bw = 0.88) · [positividad] falla (solape 0%)
/efecto: 200 efecto=5.2 ic95=[3.9, 6.4]
HUMO: OK
```

---

## 8. Auditar los artefactos

```sh
cat artifacts/registro/champion
cat artifacts/registro/v0001/manifest.json
jq -r '.archivos | to_entries[] | "\(.value)  artifacts/registro/v0001/\(.key)"' \
  artifacts/registro/v0001/manifest.json > /tmp/m.sha256
shasum -a 256 -c /tmp/m.sha256
```

Esperado: `champion → v0001`, `dataset_sha256 = 9af86718…` (train de `ihdp`) y dos líneas
`OK`. La versión es inmutable: se audita, no se edita.

---

## 9. Ejecutar el notebook

```sh
jupyter lab proyecto.ipynb     # kernel: "Python (SIC estudiante)"
```

O sin interfaz:

```sh
jupyter nbconvert --to notebook --execute --inplace \
  --ExecutePreprocessor.kernel_name=sic-estudiante proyecto.ipynb
```

Esperado: 13 celdas de código, **0 errores**, 19 salidas, gráfico PNG con los dos
estratos y sus IC.

> Si ejecutas el notebook, los checkpoints corren sobre `jobs` y **sobrescriben** los
> artefactos. Al terminar, restaura el escenario de la entrega:
> `make limpiar && SIC_ESCENARIO=real/ihdp make demo`.

---

## 10. Reproducción final y estado esperado

```sh
git status --short                     # debe estar limpio
make limpiar && SIC_ESCENARIO=real/ihdp make demo
git diff --stat semana4-kit-original   # exactamente lo construido
git tag -l                             # kit-original, ihdp-v1, entrega-v1, final
```

| Verificación | Resultado esperado |
|---|---|
| Pipeline completo | verde en ≈ 1,5–2 s |
| Manifiesto `v0001` | 2/2 `OK` · `dataset_sha256 = 9af86718…` |
| Notebook | 19 salidas, 0 errores |
| TODOs pendientes | 0 |
| Tags | `semana4-kit-original` → `semana4-ihdp-v1` → `semana4-entrega-v1` → `semana4-final` |

---

## 11. Problemas frecuentes

| Síntoma | Causa | Solución |
|---|---|---|
| `ModuleNotFoundError: fastapi` en `make humo` | El kernel o el `python3` no es el del entorno | Activar el entorno o registrarlo como `sic-estudiante` |
| `/consulta` responde `abstencion` con un perfil válido | `SIC_ESCENARIO` no coincide con los artefactos del registro | `make limpiar` y regenerar con el escenario correcto |
| `make ventanas` dice que falta `tarjeta.json` | No se ejecutó `make registrar` | El registro precede a la puerta y al servicio |
| `ValueError: truth_train.csv` | Alguien reintrodujo la verdad en el paquete | Es la pared funcionando: retirar el archivo |
| `docker build` falla con `docker.sock` | El daemon (colima/Docker Desktop) está apagado | `colima start` o dejar Docker fuera de alcance |
| El notebook abre con otro kernel | `sic-estudiante` no registrado | Paso 1.3 |

---

## 12. Qué queda fuera (por diseño)

- Learners no lineales y *repeated cross-fitting*: eso es el proyecto final.
- CATE continuo o políticas: el corte es de dos hojas y se informa como tal.
- Autenticación, persistencia, monitorización en vivo.
- `interventions.json` contiene `ate`/`att`: es el hueco de la pared; no se usa para
  estimar, decidir ni calibrar.
