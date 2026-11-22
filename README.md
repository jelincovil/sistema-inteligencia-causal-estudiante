# Sistema de Inteligencia Causal — repositorio del estudiante

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

`05_contenido_tecnico/` está reservado para el contenido técnico del curso y por ahora está vacío.

## Orden recomendado

1. Lee el capítulo indicado en `01_silabo/lectura_por_sesion.md`.
2. Trabaja A1–A4 como integración formativa.
3. Usa `04_produccion_causal/` para construir servicio, tarjeta, puerta, registro y monitor local.
4. Entrega solo el proyecto descrito en `06_proyecto_final/`; los casos Serie A son formativos.

Los notebooks A1–A4 que señalan una sección de evaluación reservada terminan antes de las comparaciones con verdad sintética u oráculos. Esas secciones no forman parte de la evidencia pública del estudiante; las decisiones deben apoyarse en observables, incertidumbre, soporte y supuestos declarados.

## Qué no contiene este repositorio

No contiene soluciones, autograders, datos `truth`, claves de evaluación, guía del profesor, fuentes Typst, artefactos docentes ni credenciales.
