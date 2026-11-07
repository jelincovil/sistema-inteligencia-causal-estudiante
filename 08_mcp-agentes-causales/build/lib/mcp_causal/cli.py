"""cli.py — Interfaz de línea de comandos del MCP causal."""
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from . import __version__
from .knowledge import buscar_conocimiento, contar_fichas, listar_fichas, obtener_ficha
from .projects import ProjectStore


def main(args: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        prog="mcp-causal",
        description="MCP causal — criterios y contratos para sistemas causales",
    )
    parser.add_argument("--version", action="version", version=f"%(prog)s {__version__}")
    sub = parser.add_subparsers(dest="comando")

    # buscar
    p_buscar = sub.add_parser("buscar", help="Buscar en la base de conocimiento")
    p_buscar.add_argument("consulta", help="Texto a buscar")
    p_buscar.add_argument("--limite", type=int, default=10)
    p_buscar.add_argument("--etiqueta", default=None)

    # ficha
    p_ficha = sub.add_parser("ficha", help="Ver una ficha completa")
    p_ficha.add_argument("id", help="ID de la ficha")

    # listar
    p_listar = sub.add_parser("listar", help="Listar fichas disponibles")

    # project
    p_proy = sub.add_parser("proyecto", help="Gestionar proyectos")
    p_proy.add_argument("accion", choices=["crear", "consultar", "listar"])
    p_proy.add_argument("--id", default=None)
    p_proy.add_argument("--nombre", default=None)
    p_proy.add_argument("--workspace", default=".mcp_causal_workspace")

    # serve
    p_serve = sub.add_parser("serve", help="Iniciar servidor MCP (stdio)")
    p_serve.add_argument("--workspace", default=".mcp_causal_workspace")

    parsed = parser.parse_args(args)

    if parsed.comando == "buscar":
        filtros = {}
        if parsed.etiqueta:
            filtros["etiqueta"] = parsed.etiqueta
        resultados = buscar_conocimiento(parsed.consulta, limite=parsed.limite, **filtros)
        if not resultados:
            print("Sin resultados.")
            return 1
        for r in resultados:
            print(f"[{r['score']:.2f}] {r['id']}: {r['titulo']}")
            print(f"    {r['pregunta']}")
        return 0

    elif parsed.comando == "ficha":
        ficha = obtener_ficha(parsed.id)
        if ficha is None:
            print(f"Ficha '{parsed.id}' no encontrada.", file=sys.stderr)
            return 1
        print(json.dumps(ficha, indent=2, ensure_ascii=False))
        return 0

    elif parsed.comando == "listar":
        print(f"{contar_fichas()} fichas:")
        for fid in listar_fichas():
            f = obtener_ficha(fid)
            print(f"  {fid}: {f['titulo']}")
        return 0

    elif parsed.comando == "proyecto":
        store = ProjectStore(parsed.workspace)
        if parsed.accion == "crear":
            if not parsed.id or not parsed.nombre:
                print("Se necesitan --id y --nombre", file=sys.stderr)
                return 1
            try:
                r = store.crear_proyecto(parsed.id, parsed.nombre)
                print(json.dumps(r, ensure_ascii=False))
                return 0
            except ValueError as e:
                print(f"Error: {e}", file=sys.stderr)
                return 1
        elif parsed.accion == "consultar":
            if not parsed.id:
                print("Se necesita --id", file=sys.stderr)
                return 1
            r = store.consultar_proyecto(parsed.id)
            if r is None:
                print(f"Proyecto '{parsed.id}' no encontrado.", file=sys.stderr)
                return 1
            print(json.dumps(r, indent=2, ensure_ascii=False))
            return 0
        elif parsed.accion == "listar":
            for p in store.listar_proyectos():
                print(f"  {p['project_id']}: {p['nombre']} ({p['creado_en']})")
            return 0

    elif parsed.comando == "serve":
        try:
            from .server import main as serve_main
            return serve_main()
        except ImportError as e:
            print(f"Servidor MCP no disponible: {e}", file=sys.stderr)
            print("Instala con: pip install mcp-causal[mcp]", file=sys.stderr)
            return 1

    else:
        parser.print_help()
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
