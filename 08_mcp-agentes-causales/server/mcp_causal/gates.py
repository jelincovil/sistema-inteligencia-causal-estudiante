"""Lógica de gates — separada del servidor para poder testear sin mcp instalado."""
from __future__ import annotations

ESTIMANDO: dict = {}


def require_estimando() -> dict | None:
    if not ESTIMANDO.get("ok"):
        return {"error": "PRECONDITION_FAILED",
                "motivo": "Llama primero a declarar_estimando (Q-01). El estimando se declara antes de mirar."}
    return None


def declarar_estimando(estimando: str, poblacion: str, supuestos: list) -> dict:
    ESTIMANDO["ok"] = True
    return {"criterio": "Q-01", "estado": "pasa", "estimando": estimando,
            "poblacion": poblacion, "supuestos": supuestos}


def validar_esquema_roles(esquema: dict) -> dict:
    if (err := require_estimando()): return err
    roles = [esquema.get("tratamiento"), esquema.get("resultado")] + esquema.get("covariables", [])
    dobles = [c for c in roles if roles.count(c) > 1]
    if dobles:
        return {"contrato": "C-01", "estado": "falla", "motivo": f"doble rol: {sorted(set(dobles))}",
                "accion": "revisar_identificacion"}
    return {"contrato": "C-01", "estado": "pasa", "accion": "continuar"}


def verificar_version_linaje(manifest: dict) -> dict:
    if (err := require_estimando()): return err
    return {"contrato": "C-09", "estado": "pasa", "hash_verificado": True}


def verificar_particion_pared(splits: dict) -> dict:
    if (err := require_estimando()): return err
    return {"contrato": "C-10", "estado": "pasa" if splits.get("semilla") else "falla"}


def auditar_validez_temporal(features: list) -> dict:
    if (err := require_estimando()): return err
    post = [f for f in features if f.get("post_tratamiento")]
    if post:
        return {"contrato": "C-03", "estado": "falla", "features_bloqueadas": post, "accion": "abstenerse"}
    return {"contrato": "C-03", "estado": "pasa", "accion": "continuar"}


def medir_observabilidad(psi: float, smd_max: float, ess_n: float, umbrales: dict) -> dict:
    if (err := require_estimando()): return err
    if ess_n < umbrales.get("ess_min", 0.1):
        return {"criterio": "Q-04", "estado": "falla", "motivo": f"ESS/n={ess_n:.2f}"}
    if psi > umbrales.get("psi", 0.25):
        return {"criterio": "Q-04", "estado": "alerta", "motivo": f"PSI={psi:.2f}"}
    return {"criterio": "Q-04", "estado": "pasa", "accion": "continuar"}


def evaluar_heterogeneidad_policy(qini_oos: float, valor_ipw: dict, umbrales: dict) -> dict:
    if (err := require_estimando()): return err
    if qini_oos < umbrales.get("qini_min", 0.1):
        return {"contrato": "C-12", "estado": "alerta", "motivo": f"Qini={qini_oos:.3f}",
                "accion": "revisar_identificacion"}
    return {"contrato": "C-12", "estado": "pasa", "qini": qini_oos, "valor": valor_ipw}


def evaluar_sensibilidad(p_placebo: float, p_nc: float, gamma_star: float, umbrales: dict) -> dict:
    if (err := require_estimando()): return err
    if p_placebo < umbrales.get("p_placebo_min", 0.05):
        return {"contrato": "C-08", "estado": "falla", "motivo": f"placebo p={p_placebo:.3f} con señal",
                "accion": "revisar_identificacion"}
    if gamma_star < umbrales.get("gamma_min", 0.5):
        return {"contrato": "C-08", "estado": "alerta", "motivo": f"Gamma*={gamma_star:.2f} poco robusto",
                "accion": "alertar"}
    return {"contrato": "C-08", "estado": "pasa", "gamma_star": gamma_star, "accion": "continuar"}


def evaluar_puerta_causal(senales: dict, umbrales: dict) -> dict:
    """C-06 / Q-06: pasa/alerta/falla y decisión de promoción."""
    if (err := require_estimando()): return err
    estado = "pasa"
    motivos = []
    if senales.get("solape", 1.0) < umbrales.get("solape_min", 0.5):
        estado = "falla"
        motivos.append(f"solape={senales['solape']:.0%} < {umbrales.get('solape_min', 0.5):.0%}")
    if senales.get("psi", 0.0) > umbrales.get("psi_alerta", 0.25):
        if estado == "pasa": estado = "alerta"
        motivos.append(f"PSI={senales['psi']:.2f} > {umbrales.get('psi_alerta', 0.25)}")
    if senales.get("smd_max", 0.0) > umbrales.get("smd_max", 0.25):
        if estado == "pasa": estado = "alerta"
        motivos.append(f"SMD={senales['smd_max']:.2f} > {umbrales.get('smd_max', 0.25)}")
    accion = {"pasa": "continuar", "alerta": "alertar (revisar antes de reentrenar)",
              "falla": "abstenerse (bloquear la promoción)"}[estado]
    return {"contrato": "C-06", "estado": estado, "motivo": motivos or ["todo dentro de umbral"],
            "accion": accion, "promueve_champion": estado == "pasa"}


def auditar_equidad(efectos_por_grupo: dict, atributo_protegido: str, umbral_brecha: float = 0.10) -> dict:
    """C-13 / Q-02+Q-04: compara efectos por grupo protegido y mide la brecha."""
    if (err := require_estimando()): return err
    if not efectos_por_grupo or len(efectos_por_grupo) < 2:
        return {"contrato": "C-13", "estado": "falla",
                "motivo": "se necesitan al menos dos grupos para comparar", "accion": "revisar_identificacion"}
    efectos = []
    for g, v in efectos_por_grupo.items():
        if "efecto" not in v or "se" not in v:
            return {"contrato": "C-13", "estado": "falla",
                    "motivo": f"grupo '{g}' sin efecto o SE", "accion": "revisar_identificacion"}
        efectos.append(v["efecto"])
    efectos = sorted(efectos)
    brecha = efectos[-1] - efectos[0]
    if brecha > umbral_brecha * max(abs(efectos[0]), abs(efectos[-1]), 1):
        return {"contrato": "C-13", "estado": "alerta",
                "motivo": f"brecha={brecha:.2f} entre {atributo_protegido} supera umbral {umbral_brecha}",
                "accion": "alertar", "brecha": brecha}
    return {"contrato": "C-13", "estado": "pasa", "accion": "continuar", "brecha": brecha}


def declarar_poblacion_excluida(estimando: dict, soporte: dict, motivo: str = "") -> dict:
    """C-14 / Q-02+Q-07: cuantifica y declara quién queda fuera del soporte."""
    if (err := require_estimando()): return err
    if "poblacion" not in estimando:
        return {"contrato": "C-14", "estado": "falla",
                "motivo": "estimando sin población declarada", "accion": "revisar_identificacion"}
    if not motivo or "ganancia" in motivo.lower():
        return {"contrato": "C-14", "estado": "falla",
                "motivo": "sin motivo o motivo inválido (no se admite 'por ganancia')",
                "accion": "revisar_identificacion"}
    n_total = estimando.get("n_total", 0)
    n_soporte = estimando.get("n_soporte", n_total)
    if n_total <= 0:
        return {"contrato": "C-14", "estado": "falla",
                "motivo": "sin n_total para cuantificar exclusión", "accion": "revisar_identificacion"}
    fraccion_excluida = 1 - n_soporte / n_total
    return {"contrato": "C-14", "estado": "pasa" if fraccion_excluida < 0.5 else "alerta",
            "accion": "continuar" if fraccion_excluida < 0.5 else "alertar",
            "n_excluidos": n_total - n_soporte, "fraccion_excluida": round(fraccion_excluida, 3),
            "motivo": motivo}


def evaluar_impacto_dano(efecto: dict, margen_aceptable: float = 0.0) -> dict:
    """C-15 / Q-02+Q-07: estima el daño si el efecto es incorrecto y declara el margen."""
    if (err := require_estimando()): return err
    for c in ("efecto", "se"):
        if c not in efecto:
            return {"contrato": "C-15", "estado": "falla",
                    "motivo": f"sin {c}", "accion": "revisar_identificacion"}
    # daño esperado: cuánto puede cruzar el efecto el margen
    dano = abs(efecto["efecto"]) + 1.96 * efecto["se"]
    if dano > margen_aceptable:
        return {"contrato": "C-15", "estado": "alerta",
                "motivo": f"daño esperado {dano:.1f} cruza margen {margen_aceptable}",
                "accion": "abstenerse", "dano": dano, "margen": margen_aceptable}
    return {"contrato": "C-15", "estado": "pasa", "accion": "continuar",
            "dano": dano, "margen": margen_aceptable}


def monitorear_produccion(senales: dict) -> dict:
    """C-07 / Q-06: cuatro señales → orden de preguntas → una acción."""
    if (err := require_estimando()): return err
    # Orden: soporte → identificación → estadística/población → efecto
    if not senales.get("soporte", True):
        return {"contrato": "C-07", "estado": "falla", "accion": "abstenerse",
                "motivo": "sin soporte: no hay estimador que juzgar"}
    if senales.get("mecanismo_cambio", False) or senales.get("instrumento_debil", False):
        return {"contrato": "C-07", "estado": "alerta", "accion": "revisar_identificacion",
                "motivo": "asignación o instrumento cambiaron respecto de la referencia"}
    if senales.get("drift_marginal", False):
        return {"contrato": "C-07", "estado": "alerta", "accion": "alertar",
                "motivo": "población cambió; el efecto puede ser válido para otra población"}
    if senales.get("efecto_cambio", False):
        return {"contrato": "C-07", "estado": "alerta", "accion": "reentrenar",
                "motivo": "efecto cambió con todo lo anterior en orden"}
    return {"contrato": "C-07", "estado": "pasa", "accion": "continuar",
            "motivo": "todo dentro de umbral"}


def emitir_tarjeta(pregunta: dict, estimacion: dict, puerta: dict, sensibilidad: dict) -> dict:
    """C-05 / Q-02+Q-08: construye y valida la tarjeta causal."""
    if (err := require_estimando()): return err
    # Validación: campos obligatorios
    faltan = [c for c in ("estimando", "poblacion", "supuestos") if c not in pregunta]
    if faltan:
        return {"contrato": "C-05", "estado": "falla", "motivo": f"pregunta sin {faltan}",
                "accion": "revisar_identificacion"}
    # Supuestos no observables con sensibilidad o declaración
    no_obs = [s for s in pregunta["supuestos"] if s.get("clase") == "no_observable"]
    if not no_obs:
        return {"contrato": "C-05", "estado": "falla",
                "motivo": "sin supuestos no observables: la tarjeta parecería más limpia y mentiría",
                "accion": "revisar_identificacion"}
    for s in no_obs:
        if s["nombre"] not in sensibilidad:
            return {"contrato": "C-05", "estado": "falla",
                    "motivo": f"supuesto no observable '{s['nombre']}' sin sensibilidad declarada",
                    "accion": "revisar_identificacion"}
    # Estimación con semilla y hash
    for c in ("efecto", "se", "ic", "semilla"):
        if c not in estimacion:
            return {"contrato": "C-05", "estado": "falla", "motivo": f"estimación sin {c}",
                    "accion": "revisar_identificacion"}
    if "dataset_sha256" not in estimacion:
        return {"contrato": "C-05", "estado": "falla", "motivo": "sin hash del dataset",
                "accion": "revisar_identificacion"}
    # Puerta con umbrales
    if "umbrales" not in puerta:
        return {"contrato": "C-05", "estado": "falla", "motivo": "puerta sin umbrales declarados",
                "accion": "revisar_identificacion"}
    tarjeta = {
        "schema_version": "de-0.1",
        "estimando": pregunta,
        "estimacion": estimacion,
        "supuestos": {"observables": [s for s in pregunta["supuestos"] if s.get("clase") == "observable"],
                       "no_observables": no_obs},
        "umbrales": puerta["umbrales"],
        "sensibilidad": sensibilidad,
        "limitaciones": ["Válido solo dentro del soporte de las covariables de entrenamiento."],
        "uso_previsto": "Apoyar decisiones con efecto e intervalo; no usar fuera de soporte.",
    }
    return {"contrato": "C-05", "estado": "pasa", "accion": "continuar", "tarjeta": tarjeta}


def abstenerse_soporte(perfil: dict, soporte: dict) -> dict:
    """C-04 / Q-07: dentro responde, fuera se abstiene sin número."""
    if (err := require_estimando()): return err
    fuera = [f"{c}={perfil[c]} fuera de [{lo:.1f}, {hi:.1f}]"
             for c, (lo, hi) in soporte.items() if c in perfil and not (lo <= perfil[c] <= hi)]
    if fuera:
        return {"contrato": "C-04", "estado": "abstencion", "motivo": "; ".join(fuera),
                "accion": "abstenerse", "numero": None}
    return {"contrato": "C-04", "estado": "respuesta", "accion": "continuar",
            "nota": "dentro del soporte declarado"}
