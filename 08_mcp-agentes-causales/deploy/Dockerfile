# Dockerfile — Servicio MCP causal sin privilegios
FROM python:3.12-slim

# Sin privilegios
RUN useradd -m -u 1000 mcp
USER mcp

WORKDIR /app

# Instalar dependencias del paquete
COPY pyproject.toml .
COPY src/ src/
RUN pip install --no-cache-dir --user .

# El bundle viaja, no los datos
# (en producción: COPY artifacts/ artifacts/)

EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
    CMD python -c "from mcp_causal import __version__; print(__version__)" || exit 1

# El servidor MCP corre por stdio (no expuesto en red)
# Para servicio HTTP, usar el CLI con uvicorn (ver docs/deploy/)
CMD ["python", "-m", "mcp_causal.cli", "--version"]
