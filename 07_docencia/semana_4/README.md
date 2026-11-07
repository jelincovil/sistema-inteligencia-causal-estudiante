# Semana 4 — Prototipo de ML causal en producción local

Clase en vivo online de **2 h 30** que construye, paso a paso y sobre el benchmark real del repositorio, un servicio causal local: estimación con incertidumbre, tarjeta de modelo, registro con hashes y alias `champion`, servicio FastAPI que se abstiene fuera del soporte, y una puerta causal `pasa/alerta/falla` sobre ventanas de producción.

## Contenido de la carpeta

| Ruta | Qué es |
|---|---|
| [proyecto/](proyecto/) | **La distribución al estudiante**: `proyecto.ipynb` (conductor) + los módulos con 22 TODOs + `ENTREGA.md` (la tarea sobre `real/ihdp`) |
| [plan_clase.md](plan_clase.md) | Plan cronometrado de los 150 min, con checkpoints, números esperados y recortes de emergencia |
| [guia_profesor.md](guia_profesor.md) | Material del profesor: checklist de preparación, números verificados, fallos comunes, mapa al proyecto final |
| [kit/](kit/) | Máster en vivo del profesor (el proyecto/ se genera de aquí: mismos TODOs) |
| [solucion/](solucion/) | Solución de referencia, probada de punta a punta (material del profesor) |

## El prototipo en una frase

> «Puente»: un servicio local que responde «el efecto del programa es 1 638,6 USD, IC95 [1 001, 2 276] — AIPW con cross-fitting sobre la versión v0001 de real/jobs», que al consultar un perfil responde el efecto **de su estrato** con la nota que prohíbe el targeting apresurado (los intervalos se solapan), que se abstiene sin dar número fuera del soporte, y cuya promoción bloquea una puerta cuando la ventana de producción rompe el solapamiento.

## Qué ejerce de los capítulos 1–8 del libro

| Concepto | Cap. | Pieza |
|---|---|---|
| El estimando se declara antes de mirar | 1 | `pregunta.md` |
| Cinco acciones; abstención de primera clase | 2 | `monitor.py`, `servicio_core.py` |
| Contrato C-01 (roles) | 3 | `datos.py` |
| Contrato C-09 (hashes, versión, champion) | 4 | `registro.py` |
| Contrato C-10 (splits sembrados, la pared) | 5 | `datos.py` |
| Validez temporal (C-03): la trampa | 6 | `score_post` en `estimacion.py` |
| Contrato C-02: SMD/PSI/ESS con umbrales calibrados | 7 | `estimacion.py`, `monitor.py` |
| Benchmark como producto (C-11) | 8 | todo corre sobre `real/jobs` declarado |

## Decisiones de alcance (deliberadas)

1. **Estimador AIPW con cross-fitting (K=5)**: el DML del Cap. 9 en miniatura — doblemente robusto, nuisances fuera de muestra. Sin learners no lineales ni repeated cross-fitting (eso es el proyecto); el OLS queda como referencia ingenua. El servicio responde dos estimandos: el poblacional (`/efecto`) y el del estrato declarado (`/consulta`, un solo corte por `nodegree`, regla pre-declarada en la tarjeta — no un CATE continuo).
2. **Sin pandas**: `csv` + `numpy` + `scipy`; cada paso se ve. FastAPI solo en el envoltorio del servicio.
3. **Docker es demo opcional de 5 min** (HTTP y CLI son equivalentes, según el sílabo). La imagen copia el bundle del registro, no los datos: «el bundle viaja, los datos no».
4. **La verdad del escenario no existe en el paquete** y no se usa para nada: la pared se mantiene.
5. Umbrales del monitor **calibrados y escritos en la tarjeta** antes de mirar ventanas (Cap. 7).

## Cómo correrlo

```bash
cd proyecto                              # estudiante (clase en vivo + tarea)
pip install -r requirements.txt
jupyter lab proyecto.ipynb               # el conductor; make verificar falla con TODO-1: así se empieza

cd ../solucion && make demo              # profesor: flujo completo de referencia
```

## Nota sobre el repositorio

Esta carpeta es material de docencia (guía del profesor y solución incluidas). El `README.md` de la raíz declara que el paquete estudiantil no contiene guía del profesor: si este repositorio se distribuye a estudiantes, `guia_profesor.md` y `solucion/` se excluyen de esa distribución (o se actualiza la declaración del README).
