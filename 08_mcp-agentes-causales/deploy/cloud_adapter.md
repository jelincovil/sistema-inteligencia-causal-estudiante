# Ejecución local con Docker y límite de despliegue en nube

## Estado: LOCAL_DOCKER_UNVERIFIED / CLOUD_UNSUPPORTED

El runtime soportado es el comando `mcp-causal serve` de la distribución de la raíz. El Dockerfile lo ejecuta por **stdio**, con `/workspace` para el estado SQLite y sin privilegios de root.

No se ha verificado aquí la construcción o ejecución de la imagen: requiere un daemon Docker disponible. Tampoco existe un adaptador HTTP implementado y probado para Cloud Run.

## Construcción y ejecución local

Desde `08_mcp-agentes-causales/`:

```bash
docker build -t mcp-causal:local -f deploy/Dockerfile .
docker run --rm -i -v mcp-causal-workspace:/workspace mcp-causal:local
```

El proceso queda esperando mensajes MCP por stdin; no imprime una versión y termina. Debe ejecutarse en modo interactivo (`-i`) o ser lanzado por un cliente MCP que mantenga stdin/stdout conectados. El volumen con nombre conserva el workspace y permite escribir como el usuario `mcp` (UID 1000).

## Variables y límites

| Variable | Descripción | Default en la imagen |
|---|---|---|
| `MCP_CAUSAL_WORKSPACE` | Directorio persistente del proyecto | `/workspace` |

- No se expone puerto 8000: stdio no es un servicio HTTP.
- No hay un health check HTTP. Un proceso de una sola ejecución que importa el paquete no prueba la salud de una sesión MCP persistente.
- No hay secretos en la imagen; cualquier credencial debe gestionarse fuera del código.

## Cloud Run

Cloud Run espera un servicio de red con un ciclo de vida y health checks apropiados. Este contenedor stdio no satisface ese contrato por sí solo. Por tanto:

- no se documenta un comando `gcloud run deploy` como si estuviera soportado;
- no se afirma equivalencia local/nube;
- un futuro despliegue requiere un adaptador HTTP autenticado, pruebas de transporte y una verificación de despliegue independiente.

Los resultados locales de validadores no implican que un servicio remoto esté disponible, sea seguro o produzca respuestas idénticas.
