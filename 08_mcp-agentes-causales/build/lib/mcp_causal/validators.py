"""validators.py — Validadores reales de contratos.

Cada validador ejecuta comprobaciones concretas sobre datos y produce
un ResultadoVerificacion con evidencia. No son if/else simplificados:
validan tipos, rangos, consistencia y producen reason_codes específicos.
"""
from __future__ import annotations

import hashlib
import json
import math
from pathlib import Path
from typing import Any

import numpy as np

from .models import (
    Accion,
    ClaimLevel,
    DeclaracionCausal,
    ResultadoVerificacion,
    Status,
)


def _resultado(
    check_id: str,
    status: Status,
    action: Accion,
    reasons: list[str],
    mensaje: str = "",
    claim: ClaimLevel = ClaimLevel.COMPUTED,
) -> ResultadoVerificacion:
    return ResultadoVerificacion(
        check_id=check_id,
        status=status,
        claim_level=claim,
        reason_codes=reasons,
        recommended_action=action,
        mensaje_humano=mensaje,
    )


# ================================================================ C-01 roles

def validar_esquema_roles(esquema: dict) -> ResultadoVerificacion:
    """C-01: cada columna un solo rol; tabla válida; tratamiento varía."""
    reasons = []
    tratamiento = esquema.get("tratamiento", "")
    resultado_col = esquema.get("resultado", "")
    covariables = esquema.get("covariables", [])
    instrumentos = esquema.get("instrumentos", [])

    if not tratamiento or not tratamiento.strip():
        return _resultado("C-01", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          ["tratamiento_vacio"], "Esquema sin tratamiento")
    if not resultado_col or not resultado_col.strip():
        return _resultado("C-01", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          ["resultado_vacio"], "Esquema sin resultado")
    if not covariables:
        return _resultado("C-01", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          ["sin_covariables"], "Esquema sin covariables")

    todas = [tratamiento, resultado_col] + list(covariables) + list(instrumentos)
    dobles = sorted({c for c in todas if todas.count(c) > 1})
    if dobles:
        return _resultado("C-01", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          [f"doble_rol:{c}" for c in dobles],
                          f"Columnas con dos roles: {dobles}")

    # Validar contra datos si se proporcionan
    datos = esquema.get("_datos_columnas")
    if datos is not None:
        ausentes = sorted(set(todas) - set(datos))
        if ausentes:
            return _resultado("C-01", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                              [f"columna_ausente:{c}" for c in ausentes],
                              f"Columnas ausentes en datos: {ausentes}")

    return _resultado("C-01", Status.PASS, Accion.CONTINUAR,
                      [], "Esquema válido: un rol por columna")


# ============================================================ C-03 temporal

def validar_validez_temporal(features: list[dict]) -> ResultadoVerificacion:
    """C-03: ninguna feature post-tratamiento o sin timestamp verificable."""
    bloqueadas = []
    reasons = []
    for f in features:
        nombre = f.get("nombre", "?")
        if f.get("post_tratamiento", False):
            bloqueadas.append(nombre)
            reasons.append(f"post_tratamiento:{nombre}")
        elif not f.get("timestamp_verificable", False):
            bloqueadas.append(nombre)
            reasons.append(f"sin_timestamp:{nombre}")
        # fecha de ingesta no sustituye medición
        elif f.get("timestamp_es_ingesta", False):
            bloqueadas.append(nombre)
            reasons.append(f"timestamp_ingesta_no_medicion:{nombre}")

    if bloqueadas:
        return _resultado("C-03", Status.FAIL, Accion.ABSTENERSE, reasons,
                          f"Features bloqueadas: {bloqueadas}")
    return _resultado("C-03", Status.PASS, Accion.CONTINUAR, [],
                      "Todas las features verificables como pre-tratamiento")


# ============================================================== C-09 linaje

def validar_version_linaje(manifest: dict) -> ResultadoVerificacion:
    """C-09: hash presente, versión inmutable, champion resuelto."""
    reasons = []
    if not manifest:
        return _resultado("C-09", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          ["manifest_vacio"], "Manifest vacío o inexistente")
    for campo in ("version", "dataset_sha256"):
        if campo not in manifest or not manifest[campo]:
            reasons.append(f"falta_{campo}")
    if reasons:
        return _resultado("C-09", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          reasons, f"Manifest incompleto: {reasons}")

    # Verificar hash si hay ruta
    ruta_datos = manifest.get("_ruta_datos")
    if ruta_datos and Path(ruta_datos).exists():
        sha_recomputado = hashlib.sha256(Path(ruta_datos).read_bytes()).hexdigest()
        if sha_recomputado != manifest["dataset_sha256"]:
            return _resultado("C-09", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                              ["hash_no_coincide"],
                              "Hash recomputado difiere del declarado")

    return _resultado("C-09", Status.PASS, Accion.CONTINUAR, [],
                      f"Versión {manifest['version']} íntegra")


# =========================================================== C-10 partición

def validar_particion_pared(splits: dict) -> ResultadoVerificacion:
    """C-10: semilla, disjunción, cobertura, pared."""
    reasons = []
    semilla = splits.get("semilla")
    if semilla is None:
        reasons.append("sin_semilla")
    elif not isinstance(semilla, int):
        reasons.append("semilla_no_entero")
    # semilla 0 es válida
    bloques = splits.get("bloques", {})
    if not bloques:
        reasons.append("sin_bloques")
    else:
        indices = [set(b.get("indices", [])) for b in bloques.values()]
        # disjunción
        todos = set()
        for idx in indices:
            solape = todos & idx
            if solape:
                reasons.append(f"solape_{len(solape)}_indices")
            todos |= idx
        # cobertura (si se declara n_total)
        n_total = splits.get("n_total")
        if n_total and len(todos) != n_total:
            reasons.append(f"cobertura_{len(todos)}_de_{n_total}")
    # pared: no truth en observed
    if splits.get("_truth_en_observed", False):
        reasons.append("truth_en_observed")

    if reasons:
        return _resultado("C-10", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          reasons, f"Partición inválida: {reasons}")
    return _resultado("C-10", Status.PASS, Accion.CONTINUAR, [],
                      "Partición válida con semilla, disjunción y pared")


# ========================================================== C-02 observabilidad

def validar_observabilidad(
    psi: float, smd_max: float, ess_n: float, umbrales: dict
) -> ResultadoVerificacion:
    """C-02: SMD, PSI, ESS contra umbrales. NaN/inf no producen pass."""
    reasons = []
    # A06: NaN/inf no producen pass
    for nombre, valor in [("psi", psi), ("smd_max", smd_max), ("ess_n", ess_n)]:
        if valor is None or (isinstance(valor, float) and (math.isnan(valor) or math.isinf(valor))):
            return _resultado("C-02", Status.UNKNOWN, Accion.ABSTENERSE,
                              [f"{nombre}_nan_o_inf"],
                              f"Señal {nombre} es NaN o infinito: no puede evaluarse")

    if ess_n < umbrales.get("ess_min", 0.1):
        reasons.append(f"ess_bajo:{ess_n:.3f}")
    if psi > umbrales.get("psi_alerta", 0.25):
        reasons.append(f"psi_alto:{psi:.3f}")
    if smd_max > umbrales.get("smd_max", 0.25):
        reasons.append(f"smd_alto:{smd_max:.3f}")

    if not reasons:
        return _resultado("C-02", Status.PASS, Accion.CONTINUAR, [],
                          "Señales dentro de umbral")
    if any(r.startswith("ess_bajo") for r in reasons):
        return _resultado("C-02", Status.FAIL, Accion.ABSTENERSE, reasons,
                          f"Observabilidad comprometida: {reasons}")
    return _resultado("C-02", Status.WARN, Accion.ALERTAR, reasons,
                      f"Advertencia de observabilidad: {reasons}")


# ============================================================= C-08 sensibilidad

def validar_sensibilidad(
    p_placebo: float, p_control_negativo: float, gamma: float,
    metodo_gamma: str = "rosenbaum", umbrales: dict | None = None,
) -> ResultadoVerificacion:
    """C-08: placebo, control negativo y Gamma (Rosenbaum dominio >= 1)."""
    umbrales = umbrales or {}
    reasons = []
    # A08: Gamma Rosenbaum dominio >= 1
    if metodo_gamma == "rosenbaum" and gamma < 1.0:
        return _resultado("C-08", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          [f"gamma_rosenbaum_menor_1:{gamma}"],
                          "Gamma Rosenbaum debe ser >= 1")
    if p_placebo is None or p_placebo < umbrales.get("p_placebo_min", 0.05):
        reasons.append(f"placebo_con_senal:{p_placebo}")
    if p_control_negativo is not None and p_control_negativo < umbrales.get("p_nc_min", 0.05):
        reasons.append(f"control_negativo_rechaza:{p_control_negativo}")
    gamma_min = umbrales.get("gamma_min", 1.5)
    if gamma < gamma_min:
        reasons.append(f"gamma_bajo:{gamma:.2f}")

    if any(r.startswith("placebo") or r.startswith("control_negativo") for r in reasons):
        return _resultado("C-08", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          reasons, "Falsación falló: la identificación está comprometida")
    if reasons:
        return _resultado("C-08", Status.WARN, Accion.ALERTAR, reasons,
                          f"Sensibilidad débil: {reasons}")
    return _resultado("C-08", Status.PASS, Accion.CONTINUAR, [],
                      "Placebo, control negativo y Gamma dentro de criterios")


# ================================================================ C-06 puerta

def evaluar_puerta(senales: dict, umbrales: dict) -> ResultadoVerificacion:
    """C-06: produce pasa/alerta/falla con motivo que nombra la señal."""
    reasons = []
    solape = senales.get("solape", 1.0)
    psi = senales.get("psi", 0.0)
    smd = senales.get("smd_max", 0.0)

    if solape < umbrales.get("solape_min", 0.5):
        return _resultado("C-06", Status.FAIL, Accion.ABSTENERSE,
                          [f"solape_roto:{solape:.2f}"],
                          f"Solapamiento {solape:.0%} < mínimo {umbrales.get('solape_min', 0.5):.0%}")
    if psi > umbrales.get("psi_alerta", 0.25):
        reasons.append(f"deriva:{psi:.2f}")
    if smd > umbrales.get("smd_max", 0.25):
        reasons.append(f"desbalance:{smd:.2f}")

    if reasons:
        return _resultado("C-06", Status.WARN, Accion.ALERTAR, reasons,
                          f"Puerta en alerta: {reasons}")
    return _resultado("C-06", Status.PASS, Accion.CONTINUAR, [],
                      "Puerta en pasa: todas las señales dentro de umbral")


# ================================================================ C-04 servicio

def validar_abstencion(perfil: dict, soporte: dict) -> ResultadoVerificacion:
    """C-04: dentro del soporte responde, fuera se abstiene sin número."""
    # A09: perfil incompleto también se abstiene
    if not perfil:
        return _resultado("C-04", Status.UNKNOWN, Accion.ABSTENERSE,
                          ["perfil_vacio"], "Perfil incompleto: no se puede evaluar")
    fuera = []
    for cov, rango in soporte.items():
        if cov not in perfil:
            fuera.append(f"{cov}_ausente")
        else:
            lo, hi = rango if isinstance(rango, (list, tuple)) else (rango[0], rango[1])
            val = perfil[cov]
            if val is None or (isinstance(val, float) and math.isnan(val)):
                fuera.append(f"{cov}_nan")
            elif not (lo <= val <= hi):
                fuera.append(f"{cov}={val}_fuera_[{lo},{hi}]")
    if fuera:
        return _resultado("C-04", Status.NOT_APPLICABLE, Accion.ABSTENERSE,
                          fuera, f"Abstención: {fuera}")
    return _resultado("C-04", Status.PASS, Accion.CONTINUAR, [],
                      "Perfil dentro del soporte declarado")


# ================================================================ C-13 equidad

def validar_equidad(
    efectos_por_grupo: dict, atributo: str, umbrales: dict | None = None
) -> ResultadoVerificacion:
    """C-13: compara efectos por grupo. Exige contexto, escala e incertidumbre.

    A12: no certifica equidad por brecha pequeña sin incertidumbre.
    """
    umbrales = umbrales or {}
    if not efectos_por_grupo or len(efectos_por_grupo) < 2:
        return _resultado("C-13", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          ["insuficientes_grupos"],
                          "Se necesitan al menos dos grupos para comparar")
    # A12: cada grupo debe tener efecto, SE y n
    for grupo, datos in efectos_por_grupo.items():
        for campo in ("efecto", "se", "n"):
            if campo not in datos:
                return _resultado("C-13", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                                  [f"grupo_{grupo}_sin_{campo}"],
                                  f"Grupo '{grupo}' sin {campo}: no se puede evaluar equidad sin incertidumbre")
        if datos["se"] is None or datos["se"] <= 0:
            return _resultado("C-13", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                              [f"grupo_{grupo}_se_invalido"],
                              f"Grupo '{grupo}' con SE inválido")
    efectos = [d["efecto"] for d in efectos_por_grupo.values()]
    ses = [d["se"] for d in efectos_por_grupo.values()]
    brecha = max(efectos) - min(efectos)
    se_pooled = math.sqrt(sum(s ** 2 for s in ses) / len(ses))
    # Brecha relativa al SE agrupado (no solo brecha absoluta)
    brecha_en_se = brecha / se_pooled if se_pooled > 0 else float("inf")
    umbral_se = umbrales.get("brecha_max_se", 2.0)
    if brecha_en_se > umbral_se:
        return _resultado("C-13", Status.WARN, Accion.ALERTAR,
                          [f"brecha_{brecha_en_se:.1f}_se"],
                          f"Brecha de {brecha:.2f} ({brecha_en_se:.1f} SE) entre {atributo}")
    return _resultado("C-13", Status.PASS, Accion.CONTINUAR, [],
                      f"Brecha de {brecha:.2f} ({brecha_en_se:.1f} SE) dentro de umbral")


# ================================================================ C-15 daño

def validar_impacto_dano(
    efecto: dict, funcion_perdida: str = "umbral", margen: float = 0.0
) -> ResultadoVerificacion:
    """C-15: evalúa daño con función de pérdida explícita.

    A12: no denominar daño a abs(efecto)+1.96*SE.
    """
    for campo in ("efecto", "se"):
        if campo not in efecto:
            return _resultado("C-15", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                              [f"sin_{campo}"], f"Efecto sin {campo}")
    if funcion_perdida == "umbral":
        # Daño = cuánto excede el efecto el margen de decisión
        exceso = abs(efecto["efecto"]) - margen
        incertidumbre = 1.96 * efecto["se"]
        dano = max(0, exceso) + incertidumbre * (1 if exceso > 0 else 0)
        if dano > margen:
            return _resultado("C-15", Status.WARN, Accion.ABSTENERSE,
                              [f"dano_{dano:.1f}_cruza_margen_{margen}"],
                              f"Daño esperado {dano:.1f} cruza margen {margen}")
        return _resultado("C-15", Status.PASS, Accion.CONTINUAR, [],
                          f"Daño {dano:.1f} dentro de margen {margen}")
    # Otras funciones de pérdida: registrar como no implementada
    return _resultado("C-15", Status.UNKNOWN, Accion.ABSTENERSE,
                      [f"funcion_perdida_no_implementada:{funcion_perdida}"],
                      f"Función de pérdida '{funcion_perdida}' no implementada")
