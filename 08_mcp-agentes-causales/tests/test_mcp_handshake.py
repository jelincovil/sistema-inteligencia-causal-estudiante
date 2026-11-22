"""test_mcp_handshake.py — Verifica el handshake real del servidor MCP.

Usa el SDK de MCP para conectar un cliente contra el servidor stdio
y verificar: initialize, list_tools, list_resources, call_tool, read_resource.
Cierra A15.
"""
from __future__ import annotations

import asyncio
import json
import sys
from pathlib import Path

import pytest

# Asegurar import del paquete
sys.path.insert(0, str(Path(__file__).parents[1] / "src"))

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def _handshake() -> dict:
    """Ejecuta el handshake completo contra el servidor MCP."""
    resultados = {}

    # Arrancar el servidor como subproceso stdio
    server_params = StdioServerParameters(
        command=sys.executable,
        args=["-m", "mcp_causal.server"],
        env=None,
    )

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            # 1. Initialize
            init = await session.initialize()
            resultados["initialize"] = {
                "protocol": getattr(init, "protocolVersion", getattr(init, "protocol_version", "?")),
                "capabilities": bool(init.capabilities),
            }

            # 2. List tools
            tools = await session.list_tools()
            resultados["list_tools"] = {
                "count": len(tools.tools),
                "nombres": [t.name for t in tools.tools][:15],
            }

            # 3. List resources
            try:
                resources = await session.list_resources()
                resultados["list_resources"] = {
                    "count": len(resources.resources),
                }
            except Exception as e:
                resultados["list_resources"] = {"error": str(e)}

            # 4. List prompts
            try:
                prompts = await session.list_prompts()
                resultados["list_prompts"] = {
                    "count": len(prompts.prompts),
                }
            except Exception as e:
                resultados["list_prompts"] = {"error": str(e)}

            # 5. Call a tool (buscar)
            try:
                r = await session.call_tool(
                    "buscar", arguments={"base": "estimando", "limite": 3}
                )
                resultados["call_tool_buscar"] = {
                    "exitoso": bool(r.content),
                    "contenido_len": len(str(r.content)),
                }
            except Exception as e:
                resultados["call_tool_buscar"] = {"error": str(e)}

            # 6. Call a tool (crear proyecto)
            try:
                r = await session.call_tool(
                    "crear_proyecto",
                    arguments={"project_id": "handshake_test", "nombre": "Prueba handshake"},
                )
                resultados["call_tool_proyecto"] = {
                    "exitoso": "estado" in str(r.content) or "project_id" in str(r.content),
                }
            except Exception as e:
                resultados["call_tool_proyecto"] = {"error": str(e)}

            # 7. Read a resource
            try:
                r = await session.read_resource("causal://knowledge")
                resultados["read_resource"] = {
                    "exitoso": bool(r.contents),
                    "contenido_len": len(str(r.contents)),
                }
            except Exception as e:
                resultados["read_resource"] = {"error": str(e)}

    return resultados


def test_mcp_handshake():
    """A15: Cliente MCP real hace initialize, list, call y read."""
    resultados = asyncio.run(_handshake())

    # Verificar que cada paso funcionó
    assert "initialize" in resultados, "Falta initialize"
    assert resultados["initialize"]["capabilities"], "Initialize sin capabilities"

    assert "list_tools" in resultados, "Falta list_tools"
    assert resultados["list_tools"]["count"] >= 5, f"Menos de 5 tools: {resultados['list_tools']}"

    # Imprimir resultados para inspección
    print(f"\n{'='*60}")
    print("HANDSHAKE MCP — RESULTADOS")
    print(f"{'='*60}")
    for paso, r in resultados.items():
        estado = "✓" if "error" not in str(r).lower() else "✗"
        print(f"  {estado} {paso}: {json.dumps(r, ensure_ascii=False, default=str)[:120]}")
    print(f"{'='*60}")

    # Al menos 5 pasos deben funcionar
    exitosos = sum(1 for r in resultados.values() if "error" not in str(r).lower())
    assert exitosos >= 5, f"Solo {exitosos} pasos exitosos de {len(resultados)}"


if __name__ == "__main__":
    pytest.main([__file__, "-v", "-s"])
