# Reporte Final — MCP Causal Local v1

Fecha: 2026-11-09
Commit: $(git rev-parse HEAD)
Rama: main

## Verificación ejecutada

### Tests unitarios y de aceptación
```
pytest 08_mcp-agentes-causales/tests/ -> 41 passed
```

### Script de aceptación v1
```
python 08_mcp-agentes-causales/scripts/accept_local_v1.py
Resultados: 14 PASS, 0 FAIL, 0 SKIPPED, 0 PENDIENTE
Estado: READY_LOCAL_V1
```

## Entregables

- **Wheel**: `08_mcp-agentes-causales/dist/mcp_causal-2.0.0-py3-none-any.whl` (build desde `src/`)
- **Código fuente**: `08_mcp-agentes-causales/src/mcp_causal/`
- **Contrato ejecutable**: `08_mcp-agentes-causales/contracts/local_v1.json`
- **Script de aceptación**: `08_mcp-agentes-causales/scripts/accept_local_v1.py`

## Instalación y uso

```bash
# Instalación base
pip install 08_mcp-agentes-causales/dist/mcp_causal-2.0.0-py3-none-any.whl

# Con soporte MCP
pip install 08_mcp-agentes-causales/dist/mcp_causal-2.0.0-py3-none-any.whl[mcp]

# Importación
from mcp_causal import __version__
from mcp_causal.models import DeclaracionCausal
from mcp_causal.knowledge import buscar_conocimiento

# Servidor MCP
mcp-causal serve --workspace .mcp_causal_workspace
```

## Qué cambió en esta iteración

- Alineación de `check_id`: validadores emiten `C-01_roles`, `C-03_temporal`, `C-09_linaje`,
  `C-10_particion`, `C-02_observabilidad`, `C-12_exigencias`, `C-06_puerta` — mismo
  namespace que `contracts/local_v1.json` y `perfiles.py`. Se añadió `C-12_exigencias`.
- Vigencia de evidencia: `guardar_declaracion` invalida verificaciones al cambiar la revisión;
  `estado_promocion` verifica `verificar_vigencia` (hash del artefacto en disco) y bloquea si
  la evidencia ya no coincide; `emitir_tarjeta_dict` refleja el estado real.
- Nuevos tools MCP: `verificar_evidencia_tool`, `verificar_vigencia`, `invalidar_por_artefacto`,
  `aceptar_advertencia_tool` (total 17 tools).
- Limpieza: `build/` y `dist/` fuera de tracking (artefactos regenerables), `contracts/`, `scripts/`
  y `reports/` añadidos a tracking.

## Limitaciones conocidas

- El conocimiento puede orientar proyectos destinados a nube, pero el MCP funciona solo localmente.
