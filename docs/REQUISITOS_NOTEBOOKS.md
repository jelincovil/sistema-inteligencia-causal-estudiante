# Requisitos de ejecución — notebooks del estudiante

Entorno validado: Linux x86_64 y Python 3.10 o superior (el entorno de referencia del curso usó Python 3.13.13). Todo es local: no requiere nube, Docker ni credenciales externas.

## Instalación

```bash
python3 -m venv .venv-causal
. .venv-causal/bin/activate
python -m pip install -r requirements.txt
python -m ipykernel install --user --name sic-estudiante --display-name "Python (SIC estudiante)"
```

El archivo `requirements.txt` (raíz del repositorio) fija las versiones exactas usadas por el curso: `numpy`, `pandas`, `scipy`, `scikit-learn`, `matplotlib`, `seaborn`, `statsmodels`, `networkx`, `joblib`, `pyyaml`, `jsonschema`, `pydantic`, `fastapi`, `uvicorn`, `httpx`, `econml`, `jupyter`/`ipykernel` y `pytest`.

## Verificación

```bash
python scripts/doctor_minimo.py
python scripts/validate_student_repo.py
```

`doctor_minimo.py` comprueba Python ≥ 3.10, la importación de `numpy`, `pandas` y `sklearn`, y reporta la semilla de referencia del curso (`42`). No instala paquetes. `validate_student_repo.py` comprueba que el árbol público no contiene material docente, soluciones ni datos `truth`.

## Notas

- Las secciones de evaluación reservada de los notebooks Serie A terminan antes de cualquier comparación con verdad sintética u oráculos; no forman parte de la evidencia pública del estudiante.
- Los escenarios de datos disponibles están en `data_benchmark_causal/` (ver `MANIFEST_ESTUDIANTE.json` para el listado exacto distribuido al estudiante).
