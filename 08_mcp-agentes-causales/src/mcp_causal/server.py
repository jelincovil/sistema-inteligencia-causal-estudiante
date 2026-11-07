"""server.py — Servidor MCP causal con tools, resources y prompts."""
import json
import os

from mcp.server.fastmcp import FastMCP

from . import __version__
from .estimators import DGPSintetico, estimar_aipw
from .knowledge import buscar_conocimiento, contar_fichas, obtener_ficha, listar_fichas
from .models import (
    Accion, ClaimLevel, ClaseSupuesto, DeclaracionCausal,
    ResultadoVerificacion, Status, Supuesto, TipoEstimando,
)
from .projects import ProjectStore
from .validators import (
    evaluar_puerta, validar_abstencion, validar_equidad,
    validar_esquema_roles, validar_observabilidad,
    validar_particion_pared, validar_sensibilidad,
    validar_validez_temporal, validar_version_linaje,
    validar_impacto_dano,
)

mcp = FastMCP("causal")
_workspace = os.environ.get("MCP_CAUSAL_WORKSPACE", ".mcp_causal_workspace")
_store = ProjectStore(_workspace)


def _pj(texto, default=None):
    if not texto:
        return default if default is not None else {}
    try:
        return json.loads(texto)
    except (json.JSONDecodeError, TypeError):
        return default if default is not None else {}


@mcp.tool()
def declarar_estimando(project_id: str, tipo: str, tratamiento: str,
                       resultado: str, poblacion: str, supuestos_json: str) -> str:
    """Q-01: Declara el estimando. supuestos_json: [{"nombre":"...","clase":"no_observable","criterio_revision":"..."}]"""
    try:
        tipo_enum = TipoEstimando(tipo)
    except ValueError:
        return json.dumps({"estado": "falla", "motivo": f"tipo inválido: {tipo}"})
    supuestos_t = tuple(
        Supuesto(nombre=s.get("nombre",""), clase=ClaseSupuesto(s.get("clase","no_observable")),
                 criterio_revision=s.get("criterio_revision",""))
        for s in _pj(supuestos_json, [])
    )
    try:
        decl = DeclaracionCausal(estimando=tipo_enum, tratamiento=tratamiento,
                                 resultado=resultado, poblacion=poblacion, supuestos=supuestos_t)
    except ValueError as e:
        return json.dumps({"estado": "falla", "motivo": str(e)})
    _store.guardar_declaracion(project_id, decl)
    return json.dumps({"estado": "pasa", "id": decl.id_estable}, ensure_ascii=False)


@mcp.tool()
def validar_esquema(project_id: str, esquema_json: str) -> str:
    """C-01: Valida roles. esquema_json: {"tratamiento":"D","resultado":"Y","covariables":["X1"]}"""
    r = validar_esquema_roles(_pj(esquema_json))
    r.project_id = project_id
    _store.guardar_verificacion(project_id, r)
    return json.dumps(r.to_dict(), ensure_ascii=False)


@mcp.tool()
def buscar(base: str, limite: int = 10) -> str:
    """Busca en la base de conocimiento causal (25 fichas)."""
    return json.dumps({"resultados": buscar_conocimiento(base, limite=limite)}, ensure_ascii=False)


@mcp.tool()
def evaluar_puerta_causal(project_id: str, senales_json: str, umbrales_json: str) -> str:
    """C-06: pasa/alerta/falla. senales_json: {"solape":0.5,"psi":0.1,"smd_max":0.2}"""
    r = evaluar_puerta(_pj(senales_json), _pj(umbrales_json))
    r.project_id = project_id
    _store.guardar_verificacion(project_id, r)
    return json.dumps(r.to_dict(), ensure_ascii=False)


@mcp.tool()
def abstenerse_soporte(perfil_json: str, soporte_json: str) -> str:
    """C-04: Dentro responde, fuera se abstiene. perfil_json: {"age":30} soporte_json: {"age":[18,54]}"""
    r = validar_abstencion(_pj(perfil_json), _pj(soporte_json))
    return json.dumps(r.to_dict(), ensure_ascii=False)


@mcp.tool()
def crear_proyecto(project_id: str, nombre: str) -> str:
    """Crea un proyecto nuevo."""
    try:
        return json.dumps(_store.crear_proyecto(project_id, nombre), ensure_ascii=False)
    except ValueError as e:
        return json.dumps({"estado": "falla", "motivo": str(e)})


@mcp.tool()
def consultar_proyecto(project_id: str) -> str:
    """Consulta un proyecto con declaración y verificaciones."""
    r = _store.consultar_proyecto(project_id)
    return json.dumps(r if r else {"estado": "no_encontrado"}, ensure_ascii=False, default=str)


@mcp.tool()
def ejecutar_verificacion(project_id: str, tipo: str, parametros_json: str) -> str:
    """Ejecuta un verificador. tipo: esquema_roles, validez_temporal, observabilidad, sensibilidad, etc."""
    parametros = _pj(parametros_json)
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
        return json.dumps({"estado": "falla", "motivo": f"desconocido: {tipo}"})
    try:
        r = fn(**parametros)
    except TypeError as e:
        return json.dumps({"estado": "falla", "motivo": str(e)})
    r.project_id = project_id
    _store.guardar_verificacion(project_id, r)
    return json.dumps(r.to_dict(), ensure_ascii=False)


@mcp.tool()
def consultar_evidencia(project_id: str) -> str:
    """Consulta la evidencia registrada."""
    return json.dumps({"evidencia": _store.obtener_evidencia(project_id)}, ensure_ascii=False)


@mcp.tool()
def emitir_tarjeta(project_id: str) -> str:
    """C-05: Emite la tarjeta del modelo."""
    proyecto = _store.consultar_proyecto(project_id)
    if proyecto is None:
        return json.dumps({"estado": "falla", "motivo": "no encontrado"})
    decl = proyecto.get("declaracion")
    if decl is None:
        return json.dumps({"estado": "falla", "motivo": "sin declaración"})
    if not any(s.get("clase") == "no_observable" for s in decl.get("supuestos", [])):
        return json.dumps({"estado": "falla", "motivo": "sin no observables"})
    tarjeta = {"project_id": project_id, "estimando": decl,
               "verificaciones": proyecto.get("verificaciones", []),
               "promocion": _store.estado_promocion(project_id)}
    resultado = ResultadoVerificacion(check_id="tarjeta_c05", status=Status.PASS,
                                       claim_level=ClaimLevel.COMPUTED,
                                       recommended_action=Accion.CONTINUAR)
    _store.guardar_verificacion(project_id, resultado)
    return json.dumps({"estado": "pasa", "tarjeta": tarjeta}, ensure_ascii=False, default=str)


@mcp.tool()
def generar_y_estimar(project_id: str, n: int = 2000, tau: float = 0.5,
                      k_folds: int = 5, semilla: int = 4242) -> str:
    """Genera DGP sintético y estima ATE por AIPW con cross-fitting."""
    dgp = DGPSintetico(n=n, tau=tau, semilla=semilla)
    X, D, Y = dgp.generar()
    r = estimar_aipw(X, D, Y, k_folds=k_folds, semilla=semilla)
    resultado = ResultadoVerificacion(check_id="ate_aipw",
                                       status=Status.PASS if r.ess_sobre_n > 0.1 else Status.WARN,
                                       claim_level=ClaimLevel.COMPUTED,
                                       recommended_action=Accion.CONTINUAR,
                                       mensaje_humano=f"ATE={r.ate:.3f}")
    _store.guardar_verificacion(project_id, resultado)
    return json.dumps({"ate": r.ate, "se": r.se, "ic": list(r.ic),
                       "ess_sobre_n": r.ess_sobre_n, "n": r.n}, ensure_ascii=False)


# === RESOURCES ===

@mcp.resource("causal://knowledge/{ficha_id}")
def ficha_resource(ficha_id: str) -> str:
    ficha = obtener_ficha(ficha_id)
    return json.dumps(ficha if ficha else {"error": "no encontrada"}, ensure_ascii=False)


@mcp.resource("causal://knowledge")
def fichas_resource() -> str:
    fichas = [{"id": fid, "titulo": obtener_ficha(fid)["titulo"]} for fid in listar_fichas()]
    return json.dumps({"total": contar_fichas(), "fichas": fichas}, ensure_ascii=False)


# === PROMPTS ===

@mcp.prompt()
def disenar_sistema(pregunta: str) -> str:
    fichas = buscar_conocimiento(pregunta, limite=5)
    ctx = "\n".join(f"- {f['id']}: {f['titulo']}" for f in fichas)
    return f"Estoy diseñando un sistema causal para: {pregunta}\n\nFichas:\n{ctx}\n\nUsa las tools del MCP paso a paso."


@mcp.prompt()
def investigar_alerta(motivo: str) -> str:
    return f"El monitor alertó: {motivo}\n\nConsulta el proyecto, lee las fichas, decide la acción."


def main() -> int:
    mcp.run()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
