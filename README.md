# Sistema de Inteligencia Causal — repositorio del estudiante

[![Semana 4 CI](https://github.com/jelincovil/sistemas-de-inteligencia-causal/actions/workflows/semana4-proyecto.yml/badge.svg)](https://github.com/jelincovil/sistemas-de-inteligencia-causal/actions/workflows/semana4-proyecto.yml)

Edición pública local del curso: 32 sesiones de 90 minutos, cuatro casos Serie A y un proyecto final único. El recorrido no requiere nube, Docker ni credenciales externas.

## Instalación

Entorno validado: Linux x86_64 y Python 3.13.13.

```bash
python3 -m venv .venv-causal
. .venv-causal/bin/activate
python -m pip install -r requirements.txt
python -m ipykernel install --user --name sic-estudiante --display-name "Python (SIC estudiante)"
python scripts/doctor_minimo.py
python scripts/validate_student_repo.py
```

La guía completa de dependencias está en [`docs/REQUISITOS_NOTEBOOKS.md`](docs/REQUISITOS_NOTEBOOKS.md).

## Recorrido de notebooks

### Serie A

- `03_notebooks_caso_estudio/notebooks/A1_identificacion_jobs.ipynb`
- `03_notebooks_caso_estudio/notebooks/A2_dml_ihdp_medium.ipynb`
- `03_notebooks_caso_estudio/notebooks/A3_cate_meta_learners_ihdp.ipynb`
- `03_notebooks_caso_estudio/notebooks/A4_policy_uplift_ihdp.ipynb`

### Contenido técnico

`05_contenido_tecnico/` contiene los documentos del snapshot de noviembre 2026 del libro (fuentes Typst, PDF, bibliografía auditada y reportes de `verificacion/`), sin la herramienta Rust ni sus artefactos; las fuentes Rust `verificacion/herramientas/` que sí se trackean están en `02_causal AI en produccion/Causal_AI/verificacion/herramientas/`. La edición vigente y auditada vive en `02_causal AI en produccion/Causal_AI/`.

## Orden recomendado

1. Lee el capítulo indicado en `01_silabo/lectura_por_sesion.md`.
2. Trabaja A1–A4 como integración formativa.
3. Usa `04_produccion_causal/` para construir servicio, tarjeta, puerta, registro y monitor local.
4. Entrega solo el proyecto descrito en `06_proyecto_final/`; los casos Serie A son formativos.

El prototipo de referencia de la semana 4 vive en [`07_docencia/semana_4_proyecto/`](07_docencia/semana_4_proyecto/) (material docente; ver [`07_docencia/README.md`](07_docencia/README.md)).

Los notebooks A1–A4 que señalan una sección de evaluación reservada terminan antes de las comparaciones con verdad sintética u oráculos. Esas secciones no forman parte de la evidencia pública del estudiante; las decisiones deben apoyarse en observables, incertidumbre, soporte y supuestos declarados.

## Alcance y validación de la distribución pública

La distribución pública del estudiante es la definida por [`MANIFEST_ESTUDIANTE.json`](MANIFEST_ESTUDIANTE.json) y excluye por contrato soluciones, autograders, datos `truth`, claves de evaluación y credenciales. Este repositorio además trackea las fuentes Typst del libro (`02_causal AI en produccion/`), el material de docencia (`07_docencia/`) y el servidor MCP (`08_mcp-agentes-causales/`).

`scripts/validate_student_repo.py` comprueba nombres y rutas prohibidos, el número de notebooks Serie A, y la existencia, el tamaño y el SHA-256 de cada archivo declarado en el manifiesto. No escanea el contenido en busca de secretos ni certifica la integridad de archivos no declarados o del resto del árbol de trabajo.
