"""server.py — Servidor MCP causal con tools, resources y prompts.

Protocolo stdio. Logs a stderr, stdout limpio para el protocolo.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from mcp.server.fastmcp import FastMCP

from . import __version__
from .estimators import DGPSintetico, estimar_aipw
from .knowledge import buscar_conocimiento, contar_fichas, obtener_ficha, listar_fichas
from .models import (
    Accion,
    ClaimLevel,
    ClaseSupuesto,
    DeclaracionCausal,
    ResultadoVerificacion,
    Status,
    Supuesto,
    TipoEstimando,
)
from .projects import ProjectStore
from .validators import (
    evaluar_puerta,
    validar_abstencion,
    validar_equidad,
    validar_esquema_roles,
    validar_observabilidad,
    validar_particion_pared,
    validar_sensibilidad,
    validar_validez_temporal,
    validar_version_linaje,
    validar_impacto_dano,
)

mcp = FastMCP("causal")

# Workspace por defecto (se puede configurar por variable de entorno)
import os
_workspace = os.environ.get("MCP_CAUSAL_WORKSPACE", ".mcp_causal_workspace")
_store = ProjectStore(_workspace)


# ================================================================== TOOLS

@mcp.tool()
def declarar_estimando(
    project_id: str,
    tipo: str,
    tratamiento: str,
    resultado: str,
    poblacion: str,
    supuestos: list[dict],
) -> dict:
    """Q-01: Declara el estimando. Sin esto, nada más funciona."""
    try:
        tipo_enum = TipoEstimando(tipo)
    except ValueError:
        return {"estado": "falla", "motivo": f"tipo de estimando inválido: {tipo}"}
    supuestos_t = tuple(
        Supuesto(
            nombre=s["nombre"],
            clase=ClaseSupuesto(s["clase"]),
            justificacion=s.get("justificacion", ""),
            criterio_revision=s.get("criterio_revision", ""),
        )
        for s in supuestos
    )
    try:
        decl = DeclaracionCausal(
            estimando=tipo_enum,
            tratamiento=tratamiento,
            resultado=resultado,
            poblacion=poblacion,
            supuestos=supuestos_t,
        )
    except ValueError as e:
        return {"estado": "falla", "motivo": str(e)}
    _store.guardar_declaracion(project_id, decl)
    return {"estado": "pasa", "estimando": decl.to_dict(), "id": decl.id_estable}


@mcp.tool()
def validar_esquema(project_id: str, esquema: dict) -> dict:
    """C-01: Valida roles de columnas."""
    r = validar_esquema_roles(esquema)
    r.project_id = project_id
    _store.guardar_verificacion(project_id, r)
    return r.to_dict()


@mcp.tool()
def buscar(base: str, limite: int = 10) -> dict:
    """Busca en la base de conocimiento."""
    resultados = buscar_conocimiento(base, limite=limite)
    return {"consulta": base, "resultados": resultados, "total": len(resultados)}


@mcp.tool()
def estimar_ate(
    project_id: str, X: list[list[float]], D: list[int], Y: list[float],
    k_folds: int = 5, semilla: int = 4242,
) -> dict:
    """Estima ATE por AIPW con cross-fitting."""
    X_np = np.array(X)
    D_np = np.array(D)
    Y_np = np.array(Y)
    r = estimar_aipw(X_np, D_np, Y_np, k_folds=k_folds, semilla=semilla)
    resultado = ResultadoVerificacion(
        check_id="ate_aipw",
        status=Status.PASS if r.ess_sobre_n > 0.1 else Status.WARN,
        claim_level=ClaimLevel.COMPUTED,
        recommended_action=Accion.CONTINUAR,
        mensaje_humano=f"ATE={r.ate:.3f} SE={r.se:.3f} IC=[{r.ic[0]:.3f},{r.ic[1]:.3f}] ESS/n={r.ess_sobre_n:.2f}",
    )
    _store.guardar_verificacion(project_id, resultado)
    return {
        "ate": r.ate, "se": r.se, "ic": list(r.ic),
        "ess_sobre_n": r.ess_sobre_n,
        "rango_e": list(r.rango_propensidad),
        "n": r.n, "tratados": r.n_tratados,
    }


@mcp.tool()
def evaluar_puerta_causal(project_id: str, senales: dict, umbrales: dict) -> dict:
    """C-06: Produce pasa/alerta/falla con motivo."""
    r = evaluar_puerta(senales, umbrales)
    r.project_id = project_id
    _store.guardar_verificacion(project_id, r)
    return r.to_dict()


@mcp.tool()
def abstenerse_soporte(perfil: dict, soporte: dict) -> dict:
    """C-04: Dentro responde, fuera se abstiene sin número."""
    r = validar_abstencion(perfil, soporte)
    return r.to_dict()


@mcp.tool()
def crear_proyecto(project_id: str, nombre: str) -> dict:
    """Crea un proyecto nuevo."""
    try:
        return _store.crear_proyecto(project_id, nombre)
    except ValueError as e:
        return {"estado": "falla", "motivo": str(e)}


@mcp.tool()
def consultar_proyecto(project_id: str) -> dict:
    """Consulta un proyecto con su declaración y verificaciones."""
    r = _store.consultar_proyecto(project_id)
    if r is None:
        return {"estado": "no_encontrado", "project_id": project_id}
    return r


@mcp.tool()
def ejecutar_verificacion(
    project_id: str, tipo: str, parametros: dict
) -> dict:
    """Ejecuta un verificador de contrato por tipo."""
    validadores = {
        "esquema_roles": validar_esquema_roles,
        "validez_temporal": validar_validez_temporal,
        "version_linaje": validar_version_linaje,
        "particion_pared": validar_particion_pared,
        "observabilidad": validar_observabilidad,
        "sensibilidad": validar_sensibilidad,
        "puerta": evaluar_puerta,
        "abstencion": validar_abstencion,
        "equidad": validar_equidad,
        "impacto_dano": validar_impacto_dano,
    }
    fn = validadores.get(tipo)
    if fn is None:
        return {"estado": "falla", "motivo": f"verificador desconocido: {tipo}"}
    try:
        r = fn(**parametros) if not isinstance(parametros.get("umbrales", None), dict) else fn(**parametros)
    except TypeError as e:
        return {"estado": "falla", "motivo": f"parámetros inválidos: {e}"}
    r.project_id = project_id
    _store.guardar_verificacion(project_id, r)
    return r.to_dict()


@mcp.tool()
def consultar_evidencia(project_id: str) -> dict:
    """Consulta la evidencia registrada de un proyecto."""
    return {"project_id": project_id, "evidencia": _store.obtener_evidencia(project_id)}


@mcp.tool()
def emitir_tarjeta(project_id: str) -> dict:
    """C-05: Emite la tarjeta del modelo desde el proyecto."""
    proyecto = _store.consultar_proyecto(project_id)
    if proyecto is None:
        return {"estado": "falla", "motivo": "proyecto no encontrado"}
    decl = proyecto.get("declaracion")
    if decl is None:
        return {"estado": "falla", "motivo": "proyecto sin declaración"}
    verificaciones = proyecto.get("verificaciones", [])
    tiene_no_obs = any(
        s.get("clase") == "no_observable" for s in decl.get("supuestos", [])
    )
    if not tiene_no_obs:
        return {"estado": "falla", "motivo": "sin supuestos no observables"}
    tarjeta = {
        "project_id": project_id,
        "estimando": decl,
        "verificaciones": verificaciones,
        "estado_promocion": _store.estado_promocion(project_id),
    }
    resultado = ResultadoVerificacion(
        check_id="tarjeta_c05",
        status=Status.PASS,
        claim_level=ClaimLevel.COMPUTED,
        recommended_action=Accion.CONTINUAR,
        mensaje_humano="Tarjeta válida con supuestos clasificados",
    )
    _store.guardar_verificacion(project_id, resultado)
    return {"estado": "pasa", "tarjeta": tarjeta}


# =============================================================== RESOURCES

@mcp.resource("causal://knowledge/{ficha_id}")
def obtener_ficha_resource(ficha_id: str) -> str:
    """Recupera una ficha de conocimiento por URI."""
    ficha = obtener_ficha(ficha_id)
    if ficha is None:
        return json.dumps({"error": f"ficha '{ficha_id}' no encontrada"})
    return json.dumps(ficha, ensure_ascii=False, indent=2)


@mcp.resource("causal://knowledge")
def listar_fichas_resource() -> str:
    """Lista todas las fichas disponibles."""
    fichas = [{"id": fid, "titulo": obtener_ficha(fid)["titulo"]} for fid in listar_fichas()]
    return json.dumps({"total": contar_fichas(), "fichas": fichas}, ensure_ascii=False, indent=2)


# ================================================================ PROMPTS

@mcp.prompt()
def diseñar_sistema(pregunta: str) -> str:
    """Prompt para diseñar un sistema causal desde una pregunta."""
    fichas = buscar_conocimiento(pregunta, limite=5)
    contexto = "\n".join(f"- {f['id']}: {f['titulo']}" for f in fichas)
    return f"""Estoy diseñando un sistema causal para: {pregunta}

Fichas relevantes:
{contexto}

Pasos a seguir:
1. Declarar el estimando (tipo, tratamiento, resultado, población, supuestos)
2. Diseñar el esquema de roles (C-01)
3. Planificar las particiones y la pared (C-10)
4. Auditar la validez temporal de las features (C-03)
5. Elegir estimador y verificar sus exigencias (C-12)

Usa las tools del MCP para cada paso. Registra toda evidencia."""


@mcp.prompt()
def investigar_alerta(motivo: str) -> str:
    """Prompt para investigar una alerta del monitor."""
    return f"""El monitor produjo una alerta: {motivo}

Pasos de investigación:
1. Consultar el proyecto y sus verificaciones
2. Leer las fichas de monitoreo y sensibilidad
3. Determinar si la identificación está comprometida
4. Decidir la acción: continuar, alertar, revisar, abstenerse o reentrenar
5. Registrar la decisión con evidencia

No reentrenes sin revisar la identificación primero."""


# ================================================================== MAIN

def main() -> int:
    mcp.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
