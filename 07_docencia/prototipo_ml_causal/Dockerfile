# Imagen del prototipo: el bundle viaja (registro + artefactos), los datos no.
# Base fijada por digest (python:3.13-slim) para builds reproducibles.
FROM python:3.13-slim@sha256:e48f59cdba69a3cbd9ed2cf0f348d90d45a8d350d98134cf1070bc106ee9ed90
WORKDIR /app
# El servicio consume JSON: no necesita DoWhy, pandas ni deserializar pickle/joblib.
# Dependencias con hashes fijados (requirements-docker.txt): revisar el fichero
# antes de regenerar o desactivar la verificación.
COPY requirements-docker.txt /app/
RUN pip install --no-cache-dir --require-hashes -r /app/requirements-docker.txt
COPY servicio.py servicio_core.py registro.py rutas.py sensibilidad.py healthcheck.py /app/
COPY artifacts /app/artifacts
RUN chmod -R a+rX /app
RUN useradd --create-home --uid 10001 app
USER app
EXPOSE 8000
ENV SIC_ESCENARIO=synthetic/ihdp SIC_VERSION_ESPERADA=v0009
HEALTHCHECK --interval=10s --timeout=3s --start-period=5s --retries=6 \
  CMD ["python", "/app/healthcheck.py"]
CMD ["uvicorn", "servicio:app", "--host", "0.0.0.0", "--port", "8000"]
