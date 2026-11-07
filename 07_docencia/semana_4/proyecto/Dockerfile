# Imagen del prototipo: el bundle viaja (registro + artefactos), los datos no.
FROM python:3.13-slim
WORKDIR /app
RUN pip install --no-cache-dir numpy scipy fastapi "uvicorn[standard]"
COPY servicio.py servicio_core.py rutas.py /app/
COPY artifacts /app/artifacts
EXPOSE 8000
CMD ["uvicorn", "servicio:app", "--host", "0.0.0.0", "--port", "8000"]
