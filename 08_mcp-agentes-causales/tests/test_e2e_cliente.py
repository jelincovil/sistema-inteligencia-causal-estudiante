"""test_e2e_cliente.py — Conexión de punta a punta con cliente MCP real.

Simula exactamente lo que hace Claude/Cursor al conectarse:
arranca el servidor por stdio, hace handshake, y usa las tools
como las usaría un agente: crear proyecto, declarar estimando,
buscar conocimiento, generar datos, estimar, evaluar puerta,
consultar proyecto, leer resource.
"""
import asyncio
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parents[1] / "src"))

from mcp import ClientSession, StdioServerParameters
from mcp.client.stdio import stdio_client


async def e2e() -> dict:
    """Ejecuta el flujo completo que haría un agente conectado."""
    pasos = {}

    server_params = StdioServerParameters(
        command=sys.executable,
        args=["-m", "mcp_causal.server"],
    )

    async with stdio_client(server_params) as (read, write):
        async with ClientSession(read, write) as session:
            # === HANDSHAKE ===
            init = await session.initialize()
            pasos["handshake"] = {
                "protocolo": getattr(init, "protocolVersion", "?"),
                "ok": True,
            }

            # === 1. Crear proyecto ===
            r = await session.call_tool("crear_proyecto", arguments={
                "project_id": "demo_e2e",
                "nombre": "Demostración punta a punta",
            })
            pasos["crear_proyecto"] = json.loads(r.content[0].text)
            print(f"[1] crear_proyecto: {pasos['crear_proyecto'].get('estado', '?')}")

            # === 2. Declarar estimando ===
            supuestos = json.dumps([
                {"nombre": "no confusión", "clase": "no_observable",
                 "criterio_revision": "revisar si placebo falla"},
                {"nombre": "soporte", "clase": "observable"},
            ])
            r = await session.call_tool("declarar_estimando", arguments={
                "project_id": "demo_e2e",
                "tipo": "ate",
                "tratamiento": "D",
                "resultado": "Y",
                "poblacion": "unidades del DGP sintético",
                "supuestos_json": supuestos,
            })
            pasos["declarar_estimando"] = json.loads(r.content[0].text)
            print(f"[2] declarar_estimando: {pasos['declarar_estimando'].get('estado', '?')}")

            # === 3. Buscar conocimiento ===
            r = await session.call_tool("buscar", arguments={
                "base": "AIPW cross-fitting estimación",
                "limite": 3,
            })
            busqueda = json.loads(r.content[0].text)
            pasos["buscar"] = {
                "total": len(busqueda.get("resultados", [])),
                "primera": busqueda["resultados"][0]["titulo"] if busqueda.get("resultados") else "sin resultados",
            }
            print(f"[3] buscar: {pasos['buscar']['total']} resultados, primera: {pasos['buscar']['primera'][:50]}")

            # === 4. Leer un resource (ficha de conocimiento) ===
            r = await session.read_resource("causal://knowledge/aipw_dml")
            ficha = json.loads(r.contents[0].text)
            pasos["read_resource"] = {
                "id": ficha.get("id"),
                "titulo": ficha.get("titulo", "?")[:60],
                "fuentes": len(ficha.get("fuentes", [])),
            }
            print(f"[4] read_resource: ficha '{pasos['read_resource']['id']}' con {pasos['read_resource']['fuentes']} fuentes")

            # === 5. Generar datos y estimar ATE ===
            r = await session.call_tool("generar_y_estimar", arguments={
                "project_id": "demo_e2e",
                "n": 2000,
                "tau": 0.5,
                "k_folds": 5,
                "semilla": 4242,
            })
            estimacion = json.loads(r.content[0].text)
            pasos["estimar"] = {
                "ate": round(estimacion["ate"], 3),
                "se": round(estimacion["se"], 3),
                "ic": [round(estimacion["ic"][0], 2), round(estimacion["ic"][1], 2)],
                "ess": round(estimacion["ess_sobre_n"], 2),
            }
            print(f"[5] estimar_ate: ATE={pasos['estimar']['ate']} SE={pasos['estimar']['se']} IC={pasos['estimar']['ic']}")

            # === 6. Evaluar puerta causal ===
            r = await session.call_tool("evaluar_puerta_causal", arguments={
                "project_id": "demo_e2e",
                "senales_json": json.dumps({"solape": 0.85, "psi": 0.05, "smd_max": 0.12}),
                "umbrales_json": json.dumps({"solape_min": 0.5, "psi_alerta": 0.25, "smd_max": 0.25}),
            })
            puerta = json.loads(r.content[0].text)
            pasos["puerta"] = {
                "estado": puerta.get("status"),
                "accion": puerta.get("recommended_action"),
            }
            print(f"[6] evaluar_puerta: estado={pasos['puerta']['estado']} accion={pasos['puerta']['accion']}")

            # === 7. Abstenerse fuera del soporte ===
            r = await session.call_tool("abstenerse_soporte", arguments={
                "perfil_json": json.dumps({"age": 99}),
                "soporte_json": json.dumps({"age": [18, 54]}),
            })
            abstencion = json.loads(r.content[0].text)
            pasos["abstencion"] = {
                "estado": abstencion.get("status"),
                "accion": abstencion.get("recommended_action"),
            }
            print(f"[7] abstenerse_soporte (age=99): {pasos['abstencion']['estado']} -> {pasos['abstencion']['accion']}")

            # === 8. Usar un prompt ===
            prompts = await session.list_prompts()
            pasos["prompts"] = {
                "total": len(prompts.prompts),
                "nombres": [p.name for p in prompts.prompts],
            }
            print(f"[8] prompts disponibles: {pasos['prompts']['nombres']}")

            # === 9. Consultar el proyecto completo ===
            r = await session.call_tool("consultar_proyecto", arguments={
                "project_id": "demo_e2e",
            })
            proyecto = json.loads(r.content[0].text)
            pasos["consultar_proyecto"] = {
                "declaracion": proyecto.get("declaracion") is not None,
                "verificaciones": len(proyecto.get("verificaciones", [])),
                "promocion": proyecto.get("estado_promocion", {}).get("estado", "?"),
            }
            print(f"[9] consultar_proyecto: declaracion={pasos['consultar_proyecto']['declaracion']}, "
                  f"verificaciones={pasos['consultar_proyecto']['verificaciones']}, "
                  f"promocion={pasos['consultar_proyecto']['promocion']}")

            # === 10. Emitir tarjeta ===
            r = await session.call_tool("emitir_tarjeta", arguments={
                "project_id": "demo_e2e",
            })
            tarjeta = json.loads(r.content[0].text)
            pasos["tarjeta"] = {
                "estado": tarjeta.get("estado"),
            }
            print(f"[10] emitir_tarjeta: {pasos['tarjeta']['estado']}")

    return pasos


def main():
    print("=" * 60)
    print("E2E CLIENTE MCP — FLUJO COMPLETO")
    print("=" * 60)
    print()

    pasos = asyncio.run(e2e())

    print()
    print("=" * 60)
    print("RESUMEN")
    print("=" * 60)

    # Contar exitosos
    exitosos = 0
    total = 0
    for nombre, r in pasos.items():
        total += 1
        ok = True
        if isinstance(r, dict):
            if "estado" in r and r["estado"] in ("falla", "no_encontrado"):
                ok = False
            elif "ok" in r and not r["ok"]:
                ok = False
        if ok:
            exitosos += 1
            print(f"  ✓ {nombre}")
        else:
            print(f"  ✗ {nombre}: {r}")

    print(f"\n{exitosos}/{total} pasos exitosos")

    # Verificaciones específicas
    assert pasos["handshake"]["ok"], "Handshake falló"
    assert pasos["crear_proyecto"].get("estado") == "creado", "Proyecto no creado"
    assert pasos["declarar_estimando"].get("estado") == "pasa", "Declaración falló"
    assert pasos["buscar"]["total"] > 0, "Búsqueda sin resultados"
    assert pasos["read_resource"]["id"] == "aipw_dml", "Resource no leído"
    assert pasos["estimar"]["ate"] is not None, "Estimación falló"
    assert 0.2 < pasos["estimar"]["ate"] < 0.8, f"ATE fuera de rango: {pasos['estimar']['ate']}"
    assert pasos["puerta"]["estado"] == "pass", "Puerta no pasó"
    assert pasos["abstencion"]["accion"] == "abstenerse", "No se abstuvo"
    assert pasos["consultar_proyecto"]["declaracion"], "Sin declaración"
    assert pasos["consultar_proyecto"]["verificaciones"] >= 2, "Sin verificaciones"
    assert pasos["tarjeta"]["estado"] == "pasa", "Tarjeta falló"

    print("\nE2E: TODAS LAS VERIFICACIONES PASARON")
    print("=" * 60)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
