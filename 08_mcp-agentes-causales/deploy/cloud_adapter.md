# Preparación de nube — Cloud Run (referencia)

## Estado: CLOUD_UNVERIFIED

Esta configuración está preparada pero **no verificada** contra una nube real.
No se han usado credenciales ni se ha desplegado infraestructura.

## Arquitectura

```
Dockerfile (sin privilegios)
    → Cloud Run (contenedor administrado)
    → Mismo bundle y contrato que local
```

## Configuración

```bash
# Construir imagen
docker build -t mcp-causal -f deploy/Dockerfile .

# Desplegar a Cloud Run (requiere credenciales — NO ejecutar sin autorización)
# gcloud run deploy mcp-causal --image mcp-causal --memory 512Mi --cpu 1
```

## Variables de entorno

| Variable | Descripción | Default |
|---|---|---|
| `MCP_CAUSAL_WORKSPACE` | Directorio del workspace SQLite | `.mcp_causal_workspace` |

## Secretos

- No hay secretos en el código ni en la imagen.
- En producción, usar el gestor de secretos de la plataforma (Secret Manager, Vault).
- Nunca hardcodear credenciales.

## Costos estimados (Cloud Run, 2026)

| Recurso | Configuración | Costo mensual estimado |
|---|---|---|
| Cloud Run | 512MB, 1 vCPU, escala a 0 | $0-5 (tráfico bajo) |
| Artifact Registry | 1 imagen | <$1 |
| Total | | <$10/mes en desarrollo |

## Equivalencia local/nube

El mismo bundle y contrato de API se sirven en local y en nube.
La equivalencia es **contractual** (misma respuesta, mismo hash), no bit a bit
(el cómputo puede diferir en precisión de punto flotante entre plataformas).

## Rollback

```bash
# Apuntar a la versión anterior
# gcloud run services update-traffic mcp-causal --to-revisions PREVIOUS=100
```

El registro local garantiza que ninguna versión en `falla` llega a `champion`.
El rollback en nube apunta a la revisión anterior del servicio.
