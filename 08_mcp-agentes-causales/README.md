# MCP Causal — Criterios de calidad y contratos de construcción

**Para agentes que construyen sistemas causales y ML productivo.**

Este paquete expone contratos verificables del libro *Ingeniería de Datos Causales* mediante MCP. La regla central es: primero se declara el estimando; después se ejecutan validaciones o estimaciones asociadas al proyecto.

## Distribución soportada

La distribución canónica es **`mcp-causal` 2.0.0**, definida en el `pyproject.toml` de esta raíz y con código en `src/mcp_causal/`. El entrypoint soportado es:

```bash
mcp-causal serve --workspace .mcp_causal_workspace
```

`server/` conserva una implementación histórica 0.1.0 y sus pruebas. No es el servidor actual ni debe instalarse como `mcp-causal`; su distribución y comando se llaman `mcp-causal-legacy`.

## Instalación

Desde `08_mcp-agentes-causales/`:

```bash
# Biblioteca y CLI de conocimiento/proyectos, sin dependencias del servidor MCP
python -m pip install -e .

# Servidor MCP por stdio
python -m pip install -e '.[mcp]'

# Desarrollo y pruebas: incluye mcp y jsonschema
python -m pip install -e '.[test]'
python -m pytest -q
```

El extra `full` reúne las dependencias de ejecución MCP y pruebas. Python 3.10 o posterior es obligatorio.

## Flujo mínimo

1. Crear el proyecto con `crear_proyecto`.
2. Declarar el estimando con `declarar_estimando`.
3. Ejecutar las verificaciones y registrar la evidencia necesaria.
4. Consultar `consultar_elegibilidad` antes de emitir o promover un resultado.

`validar_esquema`, `evaluar_puerta_causal`, `ejecutar_verificacion` y `generar_y_estimar` comprueban la declaración **antes** de invocar validadores o estimadores y antes de guardar resultados. Si falta o está dañada, devuelven `PRECONDITION_FAILED`. Una revisión de declaración vacía o desactualizada tampoco permite promover.

## Tools actuales

| Área | Tools |
|---|---|
| Declaración y validación | `declarar_estimando`, `validar_esquema`, `evaluar_puerta_causal`, `ejecutar_verificacion` |
| Proyectos | `crear_proyecto`, `consultar_proyecto`, `consultar_elegibilidad`, `emitir_tarjeta` |
| Evidencia | `registrar_artefacto_tool`, `consultar_evidencia`, `verificar_evidencia_tool`, `verificar_vigencia`, `invalidar_por_artefacto` |
| Revisión | `aceptar_advertencia_tool` |
| Estimación sintética | `generar_y_estimar` |
| Conocimiento y soporte | `buscar`, `abstenerse_soporte` |

`ejecutar_verificacion` acepta los tipos `esquema_roles`, `validez_temporal`, `version_linaje`, `particion_pared`, `observabilidad`, `sensibilidad`, `puerta`, `abstencion`, `equidad`, `impacto_dano` y `exigencias_estimador`. Las rutas de datos y artefactos se resuelven y deben permanecer dentro del workspace, incluso cuando hay enlaces simbólicos.

## Configuración MCP

`mcp.json` usa el comando canónico. El workspace puede configurarse con `MCP_CAUSAL_WORKSPACE` o con `--workspace` en `serve`:

```json
{
  "mcpServers": {
    "causal": {
      "command": "mcp-causal",
      "args": ["serve", "--workspace", ".mcp_causal_workspace"]
    }
  }
}
```

El servidor también expone dos resources (`causal://knowledge` y `causal://knowledge/{ficha_id}`) y dos prompts.

## Docker local

La imagen instala el extra `mcp` y arranca el servidor; ya no termina tras imprimir la versión:

```bash
docker build -t mcp-causal:local -f deploy/Dockerfile .
docker run --rm -i -v mcp-causal-workspace:/workspace mcp-causal:local
```

MCP usa **stdio**, sin puerto HTTP ni health check HTTP. La ejecución de la imagen requiere un daemon Docker disponible; una revisión estática del Dockerfile no demuestra que la imagen construya o arranque. Cloud Run no es un destino soportado mientras no exista y se verifique un adaptador HTTP.

## Alcance estadístico

El DGP y AIPW incluidos son referencias reproducibles para ATE. ATT, CATE, IV, DiD y RD disponen de material de conocimiento, pero no de estimadores productivos equivalentes en esta distribución.
