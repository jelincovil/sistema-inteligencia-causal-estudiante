"""validators.py — Validadores reales de contratos.

Cada validador ejecuta comprobaciones concretas sobre datos y produce
un ResultadoVerificacion con evidencia. No son if/else simplificados:
validan tipos, rangos, consistencia y producen reason_codes específicos.
"""

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
    """C-01_roles: cada columna un solo rol; tabla valida; tratamiento varia."""
    reasons = []
    tratamiento = esquema.get("tratamiento", "")
    resultado_col = esquema.get("resultado", "")
    covariables = esquema.get("covariables", [])
    instrumentos = esquema.get("instrumentos", [])

    if not tratamiento or not tratamiento.strip():
        return _resultado("C-01_roles", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          ["tratamiento_vacio"], "Esquema sin tratamiento")
    if not resultado_col or not resultado_col.strip():
        return _resultado("C-01_roles", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          ["resultado_vacio"], "Esquema sin resultado")
    if not covariables:
        return _resultado("C-01_roles", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          ["sin_covariables"], "Esquema sin covariables")

    todas = [tratamiento, resultado_col] + list(covariables) + list(instrumentos)
    dobles = sorted({c for c in todas if todas.count(c) > 1})
    if dobles:
        return _resultado("C-01_roles", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          [f"doble_rol:{c}" for c in dobles],
                          f"Columnas con dos roles: {dobles}")

    datos = esquema.get("_datos_columnas")
    if datos is not None:
        ausentes = sorted(set(todas) - set(datos))
        if ausentes:
            return _resultado("C-01_roles", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                              [f"columna_ausente:{c}" for c in ausentes],
                              f"Columnas ausentes en datos: {ausentes}")

    return _resultado("C-01_roles", Status.PASS, Accion.CONTINUAR,
                      [], "Esquema valido: un rol por columna")


# ============================================================ C-03 temporal

def validar_validez_temporal(features: list[dict]) -> ResultadoVerificacion:
    """C-03_temporal: ninguna feature post-tratamiento o sin timestamp verificable."""
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
        elif f.get("timestamp_es_ingesta", False):
            bloqueadas.append(nombre)
            reasons.append(f"timestamp_ingesta_no_medicion:{nombre}")

    if bloqueadas:
        return _resultado("C-03_temporal", Status.FAIL, Accion.ABSTENERSE, reasons,
                          f"Features bloqueadas: {bloqueadas}")
    return _resultado("C-03_temporal", Status.PASS, Accion.CONTINUAR, [],
                      "Todas las features verificables como pre-tratamiento")


# ============================================================== C-09 linaje

def validar_version_linaje(manifest: dict) -> ResultadoVerificacion:
    """C-09_linaje: hash presente, version inmutable, champion resuelto."""
    reasons = []
    if not manifest:
        return _resultado("C-09_linaje", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          ["manifest_vacio"], "Manifest vacio o inexistente")
    for campo in ("version", "dataset_sha256"):
        if campo not in manifest or not manifest[campo]:
            reasons.append(f"falta_{campo}")
    if reasons:
        return _resultado("C-09_linaje", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          reasons, f"Manifest incompleto: {reasons}")

    ruta_datos = manifest.get("_ruta_datos")
    if ruta_datos and Path(ruta_datos).exists():
        sha_recomputado = hashlib.sha256(Path(ruta_datos).read_bytes()).hexdigest()
        if sha_recomputado != manifest["dataset_sha256"]:
            return _resultado("C-09_linaje", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                              ["hash_no_coincide"],
                              "Hash recomputado difiere del declarado")

    return _resultado("C-09_linaje", Status.PASS, Accion.CONTINUAR, [],
                      f"Version {manifest['version']} integra")


# =========================================================== C-10 particion

def validar_particion_pared(splits: dict) -> ResultadoVerificacion:
    """C-10_particion: semilla, disjuncion, cobertura, pared."""
    reasons = []
    semilla = splits.get("semilla")
    if semilla is None:
        reasons.append("sin_semilla")
    elif not isinstance(semilla, int):
        reasons.append("semilla_no_entero")
    bloques = splits.get("bloques", {})
    if not bloques:
        reasons.append("sin_bloques")
    else:
        indices = [set(b.get("indices", [])) for b in bloques.values()]
        todos = set()
        for idx in indices:
            solape = todos & idx
            if solape:
                reasons.append(f"solape_{len(solape)}_indices")
            todos |= idx
        n_total = splits.get("n_total")
        if n_total and len(todos) != n_total:
            reasons.append(f"cobertura_{len(todos)}_de_{n_total}")
    if splits.get("_truth_en_observed", False):
        reasons.append("truth_en_observed")

    if reasons:
        return _resultado("C-10_particion", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          reasons, f"Particion invalida: {reasons}")
    return _resultado("C-10_particion", Status.PASS, Accion.CONTINUAR, [],
                      "Particion valida con semilla, disjuncion y pared")


# ========================================================== C-02 observabilidad

def validar_observabilidad(
    psi: float, smd_max: float, ess_n: float, umbrales: dict
) -> ResultadoVerificacion:
    """C-02_observabilidad: SMD, PSI, ESS contra umbrales. NaN/inf no producen pass."""
    reasons = []
    for nombre, valor in [("psi", psi), ("smd_max", smd_max), ("ess_n", ess_n)]:
        if valor is None or (isinstance(valor, float) and (math.isnan(valor) or math.isinf(valor))):
            return _resultado("C-02_observabilidad", Status.UNKNOWN, Accion.ABSTENERSE,
                              [f"{nombre}_nan_o_inf"],
                              f"Senal {nombre} es NaN o infinito: no puede evaluarse")

    if ess_n < umbrales.get("ess_min", 0.1):
        reasons.append(f"ess_bajo:{ess_n:.3f}")
    if psi > umbrales.get("psi_alerta", 0.25):
        reasons.append(f"psi_alto:{psi:.3f}")
    if smd_max > umbrales.get("smd_max", 0.25):
        reasons.append(f"smd_alto:{smd_max:.3f}")

    if not reasons:
        return _resultado("C-02_observabilidad", Status.PASS, Accion.CONTINUAR, [],
                          "Senales dentro de umbral")
    if any(r.startswith("ess_bajo") for r in reasons):
        return _resultado("C-02_observabilidad", Status.FAIL, Accion.ABSTENERSE, reasons,
                          f"Observabilidad comprometida: {reasons}")
    return _resultado("C-02_observabilidad", Status.WARN, Accion.ALERTAR, reasons,
                      f"Advertencia de observabilidad: {reasons}")


# ============================================================= C-08 sensibilidad

def validar_sensibilidad(
    p_placebo: float, p_control_negativo: float, gamma: float,
    metodo_gamma: str = "rosenbaum", umbrales: dict | None = None,
) -> ResultadoVerificacion:
    """C-08: placebo, control negativo y Gamma (Rosenbaum dominio >= 1)."""
    umbrales = umbrales or {}
    reasons = []
    if metodo_gamma == "rosenbaum" and gamma < 1.0:
        return _resultado("C-08_sensibilidad", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
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
        return _resultado("C-08_sensibilidad", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          reasons, "Falsacion fallo: la identificacion esta comprometida")
    if reasons:
        return _resultado("C-08_sensibilidad", Status.WARN, Accion.ALERTAR, reasons,
                          f"Sensibilidad debil: {reasons}")
    return _resultado("C-08_sensibilidad", Status.PASS, Accion.CONTINUAR, [],
                      "Placebo, control negativo y Gamma dentro de criterios")


# ================================================================ C-06 puerta

def _rechazar_tipo(valor, nombre, esperado) -> str | None:
    if isinstance(valor, bool):
        return f"{nombre} es bool, esperado {esperado}"
    if nombre in ("solape", "solape_min", "psi", "psi_alerta", "smd_max", "smd"):
        if not isinstance(valor, (int, float)):
            return f"{nombre} tipo {type(valor).__name__}, esperado numero"
        if isinstance(valor, float) and (valor != valor or valor == float('inf') or valor == float('-inf')):
            return f"{nombre} es NaN o infinito"
        if nombre.startswith("solape") and not (0 <= float(valor) <= 1):
            return f"{nombre} fuera de [0,1]"
    return None

def evaluar_puerta(senales: dict, umbrales: dict) -> ResultadoVerificacion:
    """C-06_puerta: produce pasa/alerta/falla con motivo que nombra la senal."""
    requeridos = ["solape", "psi", "smd_max"]
    ausentes = [k for k in requeridos if k not in senales]
    if ausentes:
        return _resultado("C-06_puerta", Status.UNKNOWN, Accion.ABSTENERSE, [f"senales_ausentes:{','.join(ausentes)}"], f"Senales ausentes: {ausentes} -> UNKNOWN")
    reasons = []
    solape = senales["solape"]
    psi = senales["psi"]
    smd = senales["smd_max"]
    for n, v, esp in [("solape", solape, "numero"), ("psi", psi, "numero"), ("smd_max", smd, "numero")]:
        if (e := _rechazar_tipo(v, n, esp)):
            return _resultado("C-06_puerta", Status.UNKNOWN, Accion.ABSTENERSE, [f"tipo_{n}"], e)

    if solape < umbrales.get("solape_min", 0.5):
        return _resultado("C-06_puerta", Status.FAIL, Accion.ABSTENERSE,
                          [f"solape_roto:{solape:.2f}"],
                          f"Solapamiento {solape:.0%} < minimo {umbrales.get('solape_min', 0.5):.0%}")
    if psi > umbrales.get("psi_alerta", 0.25):
        reasons.append(f"deriva:{psi:.2f}")
    if smd > umbrales.get("smd_max", 0.25):
        reasons.append(f"desbalance:{smd:.2f}")

    if reasons:
        return _resultado("C-06_puerta", Status.WARN, Accion.ALERTAR, reasons,
                          f"Puerta en alerta: {reasons}")
    return _resultado("C-06_puerta", Status.PASS, Accion.CONTINUAR, [],
                      "Puerta en pasa: todas las senales dentro de umbral")


# ================================================================ C-04 servicio

def _es_rango_valido(rango, nombre) -> str | None:
    if not isinstance(rango, (list, tuple)) or len(rango) != 2:
        return f"{nombre} rango no es [lo, hi]"
    lo, hi = rango
    for x, lab in [(lo, 'lo'), (hi, 'hi')]:
        if not isinstance(x, (int, float)):
            return f"{nombre} {lab} no es numero"
        if x != x or x in (float('inf'), float('-inf')):
            return f"{nombre} {lab} NaN o infinito"
    if lo > hi:
        return f"{nombre} lo>hi"
    return None

def validar_abstencion(perfil: dict, soporte: dict, justificacion: str = "", autorizado: bool = False) -> ResultadoVerificacion:
    """C-04_servicio: dentro del soporte responde, fuera se abstiene sin numero."""
    for cov, rango in soporte.items() if isinstance(soporte, dict) else []:
        if (e := _es_rango_valido(rango, cov)):
            return _resultado("C-04_servicio", Status.UNKNOWN, Accion.ABSTENERSE, [f"rango_{cov}"], e)
    if not perfil:
        return _resultado("C-04_servicio", Status.UNKNOWN, Accion.ABSTENERSE,
                          ["perfil_vacio"], "Perfil incompleto: no se puede evaluar")
    for cov, val in (perfil.items() if isinstance(perfil, dict) else []):
        if not isinstance(val, (int, float)):
            return _resultado("C-04_servicio", Status.UNKNOWN, Accion.ABSTENERSE, [f"perfil_{cov}_tipo"], f"{cov} no es numero")
        if isinstance(val, float) and (val != val or val in (float('inf'), float('-inf'))):
            return _resultado("C-04_servicio", Status.UNKNOWN, Accion.ABSTENERSE, [f"perfil_{cov}_nan"], f"{cov} NaN o infinito")
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
        if not autorizado:
            return _resultado("C-04_servicio", Status.UNKNOWN, Accion.ABSTENERSE, ["sin_autorizacion"], "Abstencion sin autorizacion del perfil")
        if not justificacion:
            return _resultado("C-04_servicio", Status.UNKNOWN, Accion.ABSTENERSE, ["sin_justificacion"], "Abstencion sin justificacion")
        return _resultado("C-04_servicio", Status.NOT_APPLICABLE, Accion.ABSTENERSE, fuera, f"Abstencion justificada: {justificacion}")
    return _resultado("C-04_servicio", Status.PASS, Accion.CONTINUAR, [],
                      "Perfil dentro del soporte declarado")


# ============================================================ C-12 exigencias

def validar_exigencias_estimador(
    bundle: dict | None = None, trimming: dict | None = None,
    ess_sobre_n: float | None = None, semilla_crossfit: int | None = None,
    folds_info: dict | None = None, **kwargs,
) -> ResultadoVerificacion:
    """C-12_exigencias: exigencias del estimador (DML/AIPW)."""
    CHECK = "C-12_exigencias"
    reasons: list[str] = []
    if folds_info is None and bundle is not None and isinstance(bundle, dict):
        folds_info = bundle.get("folds_info") or bundle.get("_folds_info")
        if semilla_crossfit is None:
            semilla_crossfit = bundle.get("semilla_crossfit") or bundle.get("semilla")
        if ess_sobre_n is None:
            ess_sobre_n = bundle.get("ess_sobre_n") or bundle.get("ess_n")
        if trimming is None:
            trimming = bundle.get("trimming")
    if ess_sobre_n is None and "ess_n" in kwargs:
        ess_sobre_n = kwargs["ess_n"]
    if semilla_crossfit is None and "semilla" in kwargs:
        semilla_crossfit = kwargs["semilla"]

    if ess_sobre_n is not None:
        if isinstance(ess_sobre_n, bool):
            return _resultado(CHECK, Status.UNKNOWN, Accion.ABSTENERSE, ["ess_tipo_bool"], "ESS es bool, esperado numero")
        if not isinstance(ess_sobre_n, (int, float)):
            return _resultado(CHECK, Status.UNKNOWN, Accion.ABSTENERSE, ["ess_tipo"], f"ESS tipo {type(ess_sobre_n).__name__}")
        if isinstance(ess_sobre_n, float) and (math.isnan(ess_sobre_n) or math.isinf(ess_sobre_n)):
            return _resultado(CHECK, Status.UNKNOWN, Accion.ABSTENERSE, ["ess_nan_o_inf"], "ESS no evaluable")
        if ess_sobre_n < 0.1:
            reasons.append(f"ess_bajo:{ess_sobre_n:.3f}")
    if trimming is not None and isinstance(trimming, dict):
        if trimming.get("recortado") and not trimming.get("nuevo_estimando"):
            reasons.append("trimming_sin_nuevo_estimando")
        frac = trimming.get("fraccion_excluida", 0)
        if frac and frac > 0.5:
            reasons.append(f"trimming_excesivo:{frac:.0%}")
    if folds_info and isinstance(folds_info, dict):
        bloques = folds_info.get("bloques")
        if bloques:
            idxs = [set(b.get("indices", [])) for b in bloques.values()]
            vistos: set = set()
            for s in idxs:
                if vistos & s:
                    reasons.append("folds_solapados")
                    break
                vistos |= s
            if folds_info.get("_prepro_fuera_del_fold"):
                reasons.append("prepro_fuera_del_fold")
    if not reasons and ess_sobre_n is None and not folds_info and not trimming:
        return _resultado(CHECK, Status.UNKNOWN, Accion.ABSTENERSE, ["sin_datos_estimador"],
                          "Sin datos de estimador (ESS, folds o bundle) para verificar C-12")
    if reasons:
        if any(r.startswith("ess_bajo") for r in reasons):
            return _resultado(CHECK, Status.FAIL, Accion.ABSTENERSE, reasons, f"Exigencias no cumplidas: {reasons}")
        return _resultado(CHECK, Status.WARN, Accion.ALERTAR, reasons, f"Exigencias con advertencias: {reasons}")
    return _resultado(CHECK, Status.PASS, Accion.CONTINUAR, [], "Exigencias del estimador verificadas")


# ================================================================ C-13 equidad

def validar_equidad(
    efectos_por_grupo: dict, atributo: str, umbrales: dict | None = None
) -> ResultadoVerificacion:
    """C-13: compara efectos por grupo. Exige contexto, escala e incertidumbre."""
    umbrales = umbrales or {}
    if not efectos_por_grupo or len(efectos_por_grupo) < 2:
        return _resultado("C-13", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                          ["insuficientes_grupos"],
                          "Se necesitan al menos dos grupos para comparar")
    for grupo, datos in efectos_por_grupo.items():
        for campo in ("efecto", "se", "n"):
            if campo not in datos:
                return _resultado("C-13", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                                  [f"grupo_{grupo}_sin_{campo}"],
                                  f"Grupo '{grupo}' sin {campo}: no se puede evaluar equidad sin incertidumbre")
        if datos["se"] is None or datos["se"] <= 0:
            return _resultado("C-13", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                              [f"grupo_{grupo}_se_invalido"],
                              f"Grupo '{grupo}' con SE invalido")
    efectos = [d["efecto"] for d in efectos_por_grupo.values()]
    ses = [d["se"] for d in efectos_por_grupo.values()]
    brecha = max(efectos) - min(efectos)
    se_pooled = math.sqrt(sum(s ** 2 for s in ses) / len(ses))
    if "escala" not in (umbrales or {}) or "contexto" not in (umbrales or {}):
        return _resultado("C-13", Status.UNKNOWN, Accion.ABSTENERSE, ["sin_escala_o_contexto"], "Equidad sin escala o contexto declarados")
    brecha_en_se = brecha / se_pooled if se_pooled > 0 else float("inf")
    umbral_se = umbrales.get("brecha_max_se", 2.0)
    if brecha_en_se > umbral_se:
        return _resultado("C-13", Status.WARN, Accion.ALERTAR,
                          [f"brecha_{brecha_en_se:.1f}_se"],
                          f"Brecha de {brecha:.2f} ({brecha_en_se:.1f} SE) entre {atributo}")
    return _resultado("C-13", Status.PASS, Accion.CONTINUAR, [],
                      f"Brecha de {brecha:.2f} ({brecha_en_se:.1f} SE) dentro de umbral")


# ================================================================ C-15 dano

def validar_impacto_dano(
    efecto: dict, funcion_perdida: str = "umbral", margen: float | None = None, contexto: str = ""
) -> ResultadoVerificacion:
    """C-15: dano no es abs+SE sin funcion de perdida."""
    for campo in ("efecto", "se"):
        if campo not in efecto:
            return _resultado("C-15", Status.FAIL, Accion.REVISAR_IDENTIFICACION,
                              [f"sin_{campo}"], f"Efecto sin {campo}")
    if margen is None:
        return _resultado("C-15", Status.UNKNOWN, Accion.ABSTENERSE, ["sin_margen"], "Dano sin margen ni contexto")
    if not contexto:
        return _resultado("C-15", Status.UNKNOWN, Accion.ABSTENERSE, ["sin_contexto"], "Dano sin contexto de decision")
    if funcion_perdida == "heuristica_abs_se":
        return _resultado("C-15", Status.UNKNOWN, Accion.ABSTENERSE, ["heuristica_no_dano"], "Heuristica abs+1.96SE no es dano; use perdida explicita")
    if funcion_perdida == "umbral":
        exceso = abs(efecto["efecto"]) - margen
        incertidumbre = 1.96 * efecto["se"]
        dano = max(0, exceso) + incertidumbre * (1 if exceso > 0 else 0)
        if dano > margen:
            return _resultado("C-15", Status.WARN, Accion.ABSTENERSE,
                              [f"dano_{dano:.1f}_cruza_margen_{margen}"],
                              f"Dano esperado {dano:.1f} cruza margen {margen}")
        return _resultado("C-15", Status.PASS, Accion.CONTINUAR, [],
                          f"Dano {dano:.1f} dentro de margen {margen}")
    return _resultado("C-15", Status.UNKNOWN, Accion.ABSTENERSE,
                      [f"funcion_perdida_no_implementada:{funcion_perdida}"],
                      f"Funcion de perdida '{funcion_perdida}' no implementada")
