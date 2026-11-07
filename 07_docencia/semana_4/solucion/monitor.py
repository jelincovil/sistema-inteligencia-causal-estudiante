"""monitor.py — Contrato C-02 + puerta causal: pasa / alerta / falla.

Bloque 5 de la clase: tres ventanas de producción (sana, deriva, positividad)
evaluadas contra los umbrales declarados en la tarjeta. Cada ventana produce
un estado de puerta y una acción del vocabulario de las cinco acciones.
"""
from __future__ import annotations

import json

import numpy as np
from scipy import stats

from datos import EsquemaCausal, leer
from estimacion import ess_kish, propensity, smd
from registro import champion
from rutas import REGISTRO

SEMILLA_VENTANA = 4242


# ------------------------------------------------------------------- señales

def psi(ref: np.ndarray, nueva: np.ndarray, bins: int = 10, eps: float = 1e-4) -> float:
    """Population Stability Index entre una referencia y una ventana."""
    cortes = np.unique(np.quantile(ref, np.linspace(0, 1, bins + 1)))
    a = np.histogram(ref, cortes)[0] / len(ref)
    b = np.histogram(nueva, cortes)[0] / len(nueva)
    a, b = np.clip(a, eps, None), np.clip(b, eps, None)
    return float(np.sum((a - b) * np.log(a / b)))


# ------------------------------------------------------------- las 3 ventanas

def ventana_sana(train: dict, esquema: EsquemaCausal) -> dict:
    """Otra extracción de la misma población (submuestra sin reemplazo)."""
    g = np.random.default_rng(SEMILLA_VENTANA)
    idx = g.choice(len(train[esquema.tratamiento]), 700, replace=False)
    return {k: v[idx] for k, v in train.items()}


def ventana_deriva(train: dict, esquema: EsquemaCausal) -> dict:
    """La población envejeció: la edad llega corrida diez años."""
    w = {k: v.copy() for k, v in train.items()}
    w["age"] = w["age"] + 10
    return w


def ventana_positividad(train: dict, esquema: EsquemaCausal) -> dict:
    """La asignación se volvió casi determinista por ingreso previo (re74)."""
    D, re74 = train[esquema.tratamiento], train["re74"]
    q_alto, q_bajo = np.quantile(re74, 0.75), np.quantile(re74, 0.25)
    mask = ((D == 1) & (re74 > q_alto)) | ((D == 0) & (re74 < q_bajo))
    return {k: v[mask] for k, v in train.items()}


VENTANAS = {"sana": ventana_sana, "deriva": ventana_deriva,
            "positividad": ventana_positividad}


# ---------------------------------------------------------------------- puerta

def evaluar_ventana(train: dict, ventana: dict, esquema: EsquemaCausal,
                    umbrales: dict) -> dict:
    """Evalúa una ventana: señales, estado de puerta y acción de las cinco."""
    Dw = ventana[esquema.tratamiento]
    if len(set(Dw.tolist())) < 2:
        return {"estado": "falla", "accion": "abstenerse",
                "motivo": "el tratamiento no varía en la ventana"}
    Xw = np.column_stack([ventana[c] for c in esquema.covariables])
    e = propensity(Xw, Dw)
    solape = float(((e >= 0.05) & (e <= 0.95)).mean())
    ess_n = ess_kish(Dw, e) / len(Dw)
    psis = {c: psi(train[c], ventana[c]) for c in esquema.covariables}
    psi_max = max(psis.values())
    smd_max = max(abs(smd(ventana[c], Dw)) for c in esquema.covariables)

    motivo = []
    estado = "pasa"
    if solape < umbrales["solape_min"]:
        estado = "falla"
        motivo.append(f"solapamiento roto: {solape:.0%} de unidades con e en "
                      f"[0.05, 0.95] (mínimo {umbrales['solape_min']:.0%})")
    if psi_max > umbrales["psi_alerta"]:
        estado = "alerta" if estado == "pasa" else estado
        peor = max(psis, key=psis.get)
        motivo.append(f"deriva: PSI de {peor} = {psi_max:.2f} "
                      f"(umbral {umbrales['psi_alerta']})")
    if smd_max > umbrales["smd_max"] and estado == "pasa":
        estado = "alerta"
        motivo.append(f"desbalance de asignación: SMD máx = {smd_max:.2f} "
                      f"(umbral {umbrales['smd_max']})")
    accion = {"pasa": "continuar", "alerta": "alertar (revisar antes de reentrenar)",
              "falla": "abstenerse (bloquear la promoción)"}[estado]
    return {"estado": estado, "accion": accion, "motivo": motivo or ["todo dentro de umbral"],
            "n": int(len(Dw)), "psi_max": round(psi_max, 3),
            "smd_max": round(smd_max, 2), "ess_sobre_n": round(ess_n, 2),
            "solapamiento": round(solape, 2)}


if __name__ == "__main__":
    esquema = EsquemaCausal()
    train = leer("train")
    v = champion()
    tarjeta = json.loads((REGISTRO / v / "tarjeta.json").read_text())
    umbrales = tarjeta["umbrales"]
    print(f"ventanas de producción (contra champion = {v}, "
          f"umbrales de la tarjeta: {umbrales})\n")
    for nombre, fn in VENTANAS.items():
        r = evaluar_ventana(train, fn(train, esquema), esquema, umbrales)
        print(f"[{nombre:12s}] estado = {r['estado']:6s} | acción: {r['accion']}")
        print(f"              n={r['n']} | PSI máx = {r['psi_max']} | "
              f"SMD máx = {r['smd_max']} | ESS/n = {r['ess_sobre_n']} | "
              f"solapamiento = {r['solapamiento']:.0%}")
        for m in r["motivo"]:
            print(f"              - {m}")
        print()
