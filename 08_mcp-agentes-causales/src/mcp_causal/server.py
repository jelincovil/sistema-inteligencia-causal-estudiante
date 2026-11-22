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
    validar_esquema_roles, validar_exigencias_estimador, validar_observabilidad,
    validar_particion_pared, validar_sensibilidad,
    validar_validez_temporal, validar_version_linaje,
    validar_impacto_dano,
)

mcp = FastMCP("causal")
_workspace = os.environ.get("MCP_CAUSAL_WORKSPACE", ".mcp_causal_workspace")
_store = ProjectStore(_workspace)


def _falla(motivo: str, codigo: str | None = None) -> str:
    respuesta = {"estado": "falla", "motivo": motivo}
    if codigo:
        respuesta["error"] = codigo
    return json.dumps(respuesta, ensure_ascii=False)


def _pj(texto, default=None, campo: str = "parámetros"):
    if not texto:
        return default if default is not None else {}
    try:
        return json.loads(texto)
    except (json.JSONDecodeError, TypeError) as e:
        raise ValueError(f"JSON inválido en {campo}: {e}") from e


def _pj_objeto(texto, campo: str) -> dict:
    valor = _pj(texto, campo=campo)
    if not isinstance(valor, dict):
        raise ValueError(f"{campo} debe contener un objeto JSON")
    return valor


def _verificar_declaracion_previa(project_id: str) -> str | None:
    try:
        declaracion = _store.obtener_declaracion(project_id)
    except (ValueError, TypeError, KeyError, AttributeError) as e:
        return _falla(
            f"La declaración causal guardada es inválida ({e}); declare nuevamente con declarar_estimando",
            "PRECONDITION_FAILED",
        )
    if declaracion is None:
        return _falla(
            "Declaración causal ausente; ejecute crear_proyecto y declarar_estimando antes de esta operación",
            "PRECONDITION_FAILED",
        )
    return None


@mcp.tool()
def declarar_estimando(project_id: str, tipo: str, tratamiento: str,
                       resultado: str, poblacion: str, supuestos_json: str) -> str:
    """Q-01: Declara el estimando. supuestos_json: [{"nombre":"...","clase":"no_observable","criterio_revision":"..."}]"""
    try:
        tipo_enum = TipoEstimando(tipo)
    except ValueError:
        return _falla(f"tipo inválido: {tipo}")
    try:
        supuestos_data = _pj(supuestos_json, [], campo="supuestos_json")
        if not isinstance(supuestos_data, list):
            raise ValueError("supuestos_json debe contener una lista JSON")
        supuestos_t = tuple(
            Supuesto(nombre=s.get("nombre",""), clase=ClaseSupuesto(s.get("clase","no_observable")),
                     criterio_revision=s.get("criterio_revision",""))
            for s in supuestos_data
        )
        decl = DeclaracionCausal(estimando=tipo_enum, tratamiento=tratamiento,
                                 resultado=resultado, poblacion=poblacion, supuestos=supuestos_t)
    except (ValueError, TypeError, KeyError, AttributeError) as e:
        return _falla(str(e))
    _store.guardar_declaracion(project_id, decl)
    return json.dumps({"estado": "pasa", "id": decl.id_estable}, ensure_ascii=False)


@mcp.tool()
def validar_esquema(project_id: str, esquema_json: str) -> str:
    """C-01: Valida roles. esquema_json: {"tratamiento":"D","resultado":"Y","covariables":["X1"]}"""
    error = _verificar_declaracion_previa(project_id)
    if error:
        return error
    try:
        esquema = _pj_objeto(esquema_json, "esquema_json")
    except (ValueError, TypeError) as e:
        return _falla(str(e))
    r = validar_esquema_roles(esquema)
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
    error = _verificar_declaracion_previa(project_id)
    if error:
        return error
    try:
        senales = _pj_objeto(senales_json, "senales_json")
        umbrales = _pj_objeto(umbrales_json, "umbrales_json")
    except (ValueError, TypeError) as e:
        return _falla(str(e))
    r = evaluar_puerta(senales, umbrales)
    r.project_id = project_id
    _store.guardar_verificacion(project_id, r)
    return json.dumps(r.to_dict(), ensure_ascii=False)


@mcp.tool()
def abstenerse_soporte(perfil_json: str, soporte_json: str) -> str:
    """C-04: Dentro responde, fuera se abstiene. perfil_json: {"age":30} soporte_json: {"age":[18,54]}"""
    try:
        perfil = _pj_objeto(perfil_json, "perfil_json")
        soporte = _pj_objeto(soporte_json, "soporte_json")
    except (ValueError, TypeError) as e:
        return _falla(str(e))
    r = validar_abstencion(perfil, soporte)
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
    error = _verificar_declaracion_previa(project_id)
    if error:
        return error
    try:
        parametros = _pj_objeto(parametros_json, "parametros_json")
    except (ValueError, TypeError) as e:
        return _falla(str(e))
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
        "exigencias_estimador": validar_exigencias_estimador,
    }
    fn = validadores.get(tipo)
    if fn is None:
        return _falla(f"desconocido: {tipo}")
    if tipo == "version_linaje":
        parametros["workspace"] = _store.workspace
    try:
        r = fn(**parametros)
    except (TypeError, ValueError, KeyError, AttributeError, OSError) as e:
        return _falla(str(e))
    r.project_id = project_id
    _store.guardar_verificacion(project_id, r)
    return json.dumps(r.to_dict(), ensure_ascii=False)


@mcp.tool()
def consultar_evidencia(project_id: str) -> str:
    """Consulta la evidencia registrada."""
    return json.dumps({"evidencia": _store.obtener_evidencia(project_id)}, ensure_ascii=False)


@mcp.tool()
def verificar_evidencia_tool(project_id: str, artifact_id: str) -> str:
    """Recomputa el hash de un artefacto y reporta si sigue vigente."""
    vigente = _store.verificar_evidencia(project_id, artifact_id)
    return json.dumps({"artifact_id": artifact_id, "vigente": vigente}, ensure_ascii=False)


@mcp.tool()
def verificar_vigencia(project_id: str) -> str:
    """Verifica vigencia de todas las dependencias; invalida verificaciones con evidencia modificada."""
    r = _store.verificar_vigencia(project_id)
    return json.dumps(r, ensure_ascii=False)


@mcp.tool()
def invalidar_por_artefacto(project_id: str, artifact_id: str) -> str:
    """Invalida verificaciones que dependen de un artefacto."""
    inv = _store.invalidar_por_artefacto(project_id, artifact_id)
    return json.dumps({"invalidados": inv}, ensure_ascii=False)


@mcp.tool()
def aceptar_advertencia_tool(project_id: str, check_id: str, revisor: str = "") -> str:
    """Acepta una advertencia (warn) para la revisión vigente."""
    try:
        return json.dumps(_store.aceptar_advertencia(project_id, check_id, revisor), ensure_ascii=False)
    except ValueError as e:
        return json.dumps({"estado": "falla", "motivo": str(e)}, ensure_ascii=False)


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
    tarjeta = _store.emitir_tarjeta_dict(project_id)
    # Registrar la tarjeta como verificación C-05
    prom = tarjeta.get("promocion", {})
    estado_t = Status.PASS if prom.get("estado") == "elegible" else Status.FAIL if prom.get("estado") == "bloqueado" else Status.UNKNOWN
    resultado = ResultadoVerificacion(check_id="C-05_tarjeta", status=estado_t,
                                       claim_level=ClaimLevel.COMPUTED,
                                       recommended_action=Accion.CONTINUAR if estado_t == Status.PASS else Accion.ABSTENERSE,
                                       mensaje_humano=f"Tarjeta: {tarjeta.get('estado')}",
                                       reason_codes=[f"promocion:{prom.get('estado')}"] if prom else [])
    _store.guardar_verificacion(project_id, resultado)
    return json.dumps({"estado": "pasa" if estado_t == Status.PASS else "bloqueado", "tarjeta": tarjeta}, ensure_ascii=False, default=str)


@mcp.tool()
def consultar_elegibilidad(project_id: str, perfil: str = "aprobar_bundle_causal") -> str:
    return json.dumps(_store.estado_promocion(project_id, perfil), ensure_ascii=False)


@mcp.tool()
def registrar_artefacto_tool(project_id: str, artifact_path: str) -> str:
    return json.dumps(_store.registrar_artefacto(project_id, __import__('pathlib').Path(artifact_path)).__dict__, ensure_ascii=False, default=str)


@mcp.tool()
def generar_y_estimar(project_id: str, n: int = 2000, tau: float = 0.5,
                      k_folds: int = 5, semilla: int = 4242) -> str:
    """Genera DGP sintético y estima ATE por AIPW con cross-fitting."""
    error = _verificar_declaracion_previa(project_id)
    if error:
        return error
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
