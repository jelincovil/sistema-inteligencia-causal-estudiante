"""Monitoreo por ventanas de los supuestos observables y falsificables, con regla de decisión.

Qué se mide en cada ventana (p. ej. una semana de datos con tratamiento y resultado ya observados):
  - drift de covariables (PSI, KS) frente a la referencia de entrenamiento
  - solapamiento y balance (propensity extremo, ESS relativo, SMD ponderado, calibración)
  - estabilidad del efecto: re-estimación en la ventana frente al ATE de referencia
  - control negativo (falsificación)

Lo NO observable no se "monitorea" aquí: se contrasta con el holdout aleatorizado (holdout.py).

Acciones, en orden de precedencia:
  abstenerse            la puerta de solapamiento/balance falla: el efecto no es fiable en la ventana
  revisar_identificacion el control negativo rechaza, o el efecto cambia sin drift de covariables
  reentrenar            hay drift grande y el efecto re-estimado se aleja de la referencia
  alertar               drift grande sin evidencia de cambio del efecto, o la puerta está en alerta
  continuar             nada que reportar
"""

from __future__ import annotations

import math
from collections.abc import Mapping
from dataclasses import dataclass

import pandas as pd

from . import diagnosticos as dg
from .dgp import Escenario, columnas_x, generar
from .estimador import ajustar_irm
from .falsificacion import control_negativo
from .puerta import evaluar


@dataclass(frozen=True)
class UmbralesMonitor:
    psi_grande: float = 0.25     # convención: PSI > 0.25 = cambio grande
    z_efecto: float = 3.0        # |z| de estabilidad del efecto; 3 y no 1.96 por comparaciones repetidas
    z_control_negativo: float = 3.0


def metricas_ventana(ref: pd.DataFrame, ventana: pd.DataFrame, ate_ref: float, se_ref: float, k: int = 3, semilla: int = 0) -> dict:
    cols = columnas_x(ref)
    Xr, Xw = ref[cols].to_numpy(), ventana[cols].to_numpy()
    t, y = ventana["t"].to_numpy(), ventana["y"].to_numpy()

    deriva = dg.drift_covariables(Xr, Xw, cols)
    r = ajustar_irm(Xw, t, y, columnas=cols, k=k, semilla=semilla)
    nc = control_negativo(Xw, t, ventana["nc"].to_numpy(), k=k, semilla=semilla)
    z_efecto = (r.ate - ate_ref) / math.sqrt(r.se**2 + se_ref**2)
    return {
        "n": int(len(ventana)),
        "psi_max": deriva["psi_max"],
        "ate": r.ate,
        "se": r.se,
        "z_efecto": float(z_efecto),
        "nc_z": nc["z"],
        "frac_ps_extremo": dg.frac_ps_extremo(r.e_hat),
        "ess_rel_min": dg.ess_relativo(r.e_hat, t),
        "smd_pond_max": dg.smd_max(Xw, t, r.e_hat),
        "calib_ps_z": dg.calibracion_ps_z(r.e_hat, t),
    }


REQUIRED_MONITOR_METRICS = (
    "frac_ps_extremo",
    "ess_rel_min",
    "smd_pond_max",
    "nc_z",
    "psi_max",
    "z_efecto",
)
UNIT_INTERVAL_METRICS = frozenset({"frac_ps_extremo", "ess_rel_min"})
NONNEGATIVE_METRICS = frozenset({"smd_pond_max", "psi_max"})


def _validar_metricas(m: dict) -> tuple[dict[str, float], list[str]]:
    if not isinstance(m, Mapping):
        return {}, ["las métricas no forman un objeto"]
    valores = {}
    invalidas = []
    for name in REQUIRED_MONITOR_METRICS:
        if name not in m:
            invalidas.append(f"{name} (ausente)")
            continue
        raw = m[name]
        if isinstance(raw, (str, bytes, bool)) or raw is None:
            invalidas.append(f"{name} (tipo no numérico)")
            continue
        try:
            value = float(raw)
        except (TypeError, ValueError, OverflowError):
            invalidas.append(f"{name} (mal formada)")
            continue
        if not math.isfinite(value):
            invalidas.append(f"{name} (no finita)")
            continue
        if name in UNIT_INTERVAL_METRICS and not 0.0 <= value <= 1.0:
            invalidas.append(f"{name} (fuera del dominio físico [0, 1])")
            continue
        if name in NONNEGATIVE_METRICS and value < 0.0:
            invalidas.append(f"{name} (fuera del dominio físico [0, inf))")
            continue
        valores[name] = value
    return valores, invalidas


def decidir(m: dict, u: UmbralesMonitor = UmbralesMonitor()) -> dict:
    """Aplica la regla solo con evidencia completa, finita y físicamente válida."""
    m, invalidas = _validar_metricas(m)
    if invalidas:
        return {
            "accion": "abstenerse",
            "motivo": "evidencia de monitoreo ausente o inválida: " + ", ".join(invalidas),
        }
    diagnosticos_puerta = {k: m[k] for k in ("frac_ps_extremo", "ess_rel_min", "smd_pond_max")}
    diagnosticos_puerta["nc_abs_z"] = abs(m["nc_z"])
    puerta = evaluar(diagnosticos_puerta)
    drift_grande = m["psi_max"] >= u.psi_grande
    efecto_roto = abs(m["z_efecto"]) >= u.z_efecto
    nc_rechaza = abs(m["nc_z"]) >= u.z_control_negativo

    if puerta["estado"] == "falla":
        malos = [c["clave"] for c in puerta["chequeos"] if c["estado"] == "falla"]
        return {"accion": "abstenerse", "motivo": f"solapamiento/balance fuera de límite: {', '.join(malos)}"}
    if nc_rechaza:
        return {"accion": "revisar_identificacion", "motivo": f"el control negativo rechaza (|z|={abs(m['nc_z']):.1f})"}
    if efecto_roto and not drift_grande:
        return {"accion": "revisar_identificacion", "motivo": f"el efecto cambió (|z|={abs(m['z_efecto']):.1f}) sin drift de covariables"}
    if drift_grande and efecto_roto:
        return {"accion": "reentrenar", "motivo": f"drift grande (PSI={m['psi_max']:.2f}) y efecto distinto (|z|={abs(m['z_efecto']):.1f})"}
    if drift_grande:
        return {"accion": "alertar", "motivo": f"drift grande (PSI={m['psi_max']:.2f}) sin evidencia de cambio del efecto; revisar soporte"}
    if puerta["estado"] == "alerta":
        return {"accion": "alertar", "motivo": "la puerta de solapamiento/balance está en alerta"}
    return {"accion": "continuar", "motivo": "sin señales"}


PLAN_POR_DEFECTO = (
    [("sano", Escenario())] * 6
    + [("drift de x1", Escenario(drift_x1=1.5))] * 2
    + [("confusor oculto", Escenario(gamma_u=1.0))] * 2
    + [("positividad violada", Escenario(positividad=0.8))] * 2
)


def simular_y_monitorear(plan=PLAN_POR_DEFECTO, n_ref: int = 6000, n_semana: int = 1500, semilla: int = 100) -> list[dict]:
    """Simula semanas de producción según `plan`, las monitorea y devuelve una fila por semana."""
    ref = generar(n_ref, Escenario(), semilla=semilla)
    cols = columnas_x(ref)
    r0 = ajustar_irm(ref[cols].to_numpy(), ref["t"].to_numpy(), ref["y"].to_numpy(), columnas=cols, semilla=semilla)
    filas = []
    for i, (nombre, esc) in enumerate(plan, start=1):
        ventana = generar(n_semana, esc, semilla=semilla + i)
        m = metricas_ventana(ref, ventana, r0.ate, r0.se, semilla=semilla + i)
        d = decidir(m)
        filas.append({"semana": i, "escenario_inyectado": nombre, **m, **d})
    return filas
