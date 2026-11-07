# MCP Causal Server — Especificación mínima

**Stack:** FastMCP (Python) stdio. Sin Docker obligatorio para iteración 1.

## Estructura

```
server/
├── mcp_causal/
│   ├── __init__.py
│   ├── server.py          # FastMCP(), 10 tools
│   ├── gates.py           # Q-01..Q-08 lógica
│   └── contracts.py       # carga C-01..C-12 JSON + validación
├── tests/
│   └── test_gates.py      # 1 test por tool (usa DGPs)
├── pyproject.toml
└── README.md              # este archivo
```

## Tools (firma)

```python
@mcp.tool()
def declarar_estimando(estimando: str, poblacion: str, supuestos: list) -> dict: ...
@mcp.tool()
def validar_esquema_roles(esquema: dict, tabla: str) -> dict: ...
@mcp.tool()
def auditar_validez_temporal(features: list, rol: dict, timestamps: dict) -> dict: ...
@mcp.tool()
def verificar_version_linaje(manifest: dict, semilla: int) -> dict: ...
@mcp.tool()
def verificar_particion_pared(splits: dict) -> dict: ...
@mcp.tool()
def medir_observabilidad(ref: str, ventana: str, umbrales: dict) -> dict: ...
@mcp.tool()
def verificar_benchmark_producto(paquete: str) -> dict: ...
@mcp.tool()
def entregar_exigencias_estimador(bundle: dict) -> dict: ...
@mcp.tool()
def evaluar_puerta_causal(senales: dict, umbrales: dict) -> dict: ...
@mcp.tool()
def abstenerse_soporte(perfil: dict, soporte: dict) -> dict: ...
```

Cada tool devuelve `{estado, motivo, accion, evidencia}` mapeado a 5 acciones.

## Config cliente (Claude/Cursor/VS Code)


```json
{
  "mcpServers": {
    "causal": {
      "command": "python",
      "args": ["-m", "mcp_causal.server"],
      "cwd": "08_mcp-agentes-causales/server"
    }
  }
}
```

## Instalación dev

```bash
cd 08_mcp-agentes-causales/server
pip install -e .
python -m mcp_causal.server  # stdio, espera handshake
pytest tests/test_gates.py -v
```

## Roadmap por iteración

- Iter 1 (caps 1-9): scaffold + 6 tools (declarar, esquema, version, particion, temporal, observabilidad)
- Iter 2 (caps 10-11): +2 (hetero, sensibilidad)
- Iter 3 (caps 12-15): +4 (puerta, abstención, monitor, tarjeta) → 12 tools completas

Ver `../plan-capitulos/PLAN_MCP_CAPITULOS.md` para DoD por día.
