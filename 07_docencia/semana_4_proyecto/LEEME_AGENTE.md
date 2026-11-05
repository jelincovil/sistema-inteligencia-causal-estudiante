# LEEME para un agente externo

Este paquete contiene un **prototipo causal local** completo: estima un efecto promedio
(ATE) con intervalo, lo publica como artefacto versionado con hash, lo sirve por API y se
abstiene cuando el caso cae fuera del soporte de los datos.

**Estado congelado:** escenario `real/ihdp`, artefacto `v0001`, tag `v1.0.0`.

---

## 1. Lee en este orden

| Orden | Archivo | Para qué |
|---|---|---|
| 1 | `pregunta_jobs.md` · `pregunta_ihdp.md` | qué se estima y bajo qué supuestos (declarado **antes** de mirar datos) |
| 2 | `GUIA_CONSTRUCCION.md` | cómo está construido, bloque a bloque, con salidas esperadas |
| 3 | `BITACORA.md` | qué se decidió, por qué y con qué evidencia (incluye hallazgos y límites) |
| 4 | `data_benchmark_causal/.../datasets/dataset_y_metodo.typ` (o el `.pdf`) | ficha del dataset, del efecto y del método |
| 5 | `datos.py` → `estimacion.py` → `registro.py` → `monitor.py` → `servicio_core.py` | el código, en el orden en que fluyen los datos |

`ENTREGA.md` describe el checklist del trabajo académico; `README.md` y `LEEME_PRIMERO.txt`
son el material original del curso.

---

## 2. Qué hay dentro

```text
datos.py              esquema de roles, hashes de splits, "la pared"
estimacion.py         OLS, propensity, ESS, SMD, AIPW cross-fitting, estratos, trampa
registro.py           tarjeta, versión inmutable, manifiesto, promoción de champion
monitor.py            PSI, tres ventanas, puerta pasa/alerta/falla
servicio_core.py      bundle cacheado, /consulta y /efecto_individual
servicio.py           FastAPI + formulario HTML
humo.py               prueba de humo del servicio
rutas.py              raíz del repo y escenario (SIC_ESCENARIO)
Makefile              verificar · estimar · registrar · ventanas · humo · demo
proyecto.ipynb        notebook conductor, ejecutado
artifacts/            estimación + registro v0001 + champion (evidencia publicada)
data_benchmark_causal/  dos escenarios sintéticos (ihdp y jobs) con sus metadatos
BASELINE.sha256       huella del kit original, antes de resolver los 22 TODOs
```

`make demo` (≈ 2 s) ejecuta los cinco checkpoints.

---

## 3. Cómo comprobarlo en 2 minutos

```sh
python3.13 -m venv .venv && . .venv/bin/activate
python -m pip install -r requirements.txt

make verificar                       # esquema + hashes + pared
SIC_ESCENARIO=real/ihdp make demo    # los cinco pasos, verde
make humo                            # servicio por TestClient
```

Números de referencia que debe reproducir (si no salen, algo cambió):

| Pieza | Valor |
|---|---|
| ATE AIPW (K=5) | 5,2 · IC95 [3,9; 6,4] |
| ATE OLS (referencia) | 4,8 |
| Estratos por `bw` | 7,2 [5,5; 8,8] y 3,2 [1,4; 4,9] |
| Ventanas | sana `pasa` · deriva `alerta` · positividad `falla` |
| Consulta fuera de soporte | `abstencion`, HTTP 200, sin número |

---

## 4. Invariantes que no se pueden romper

1. **Nada de `truth_*.csv`, `y0`, `y1` ni `tau`** en entrenamiento, bundle o servicio.
2. `interventions.json` **contiene la verdad** (`ate`, `att`): no se usa para estimar,
   decidir ni calibrar umbrales.
3. El servicio **no lee CSV**: solo el bundle del `champion`.
4. Abstención = **HTTP 200 sin número**, nunca un 4xx.
5. **Un artefacto, un escenario**: cambiar `SIC_ESCENARIO` exige regenerar y reiniciar.
6. Los umbrales y el corte de heterogeneidad se declaran **antes** de ver resultados.

---

## 5. Límites declarados (no son defectos ocultos)

- Las dos piernas del AIPW son **lineales** (OLS por brazo, logística en los logits).
- El efecto por perfil (`/efecto_individual`) es una **proyección lineal del score**, con
  `R²` bajo publicado en la propia respuesta; **no** es un CATE validado.
- Sin autenticación ni TLS; sin verificación de hash al cargar el bundle.
- Sin learners no lineales ni *repeated cross-fitting*: eso queda fuera del alcance.

---

## 6. Si algo no cuadra

`BITACORA.md` §11–§15 documenta los fallos encontrados y su corrección (arranque sin
directorio de datos, módulo no copiado en la imagen, permisos, validación del formulario,
nota de heterogeneidad). `GUIA_CONSTRUCCION.md` §12 lista los errores frecuentes con su causa.
