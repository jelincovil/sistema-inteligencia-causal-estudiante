"""monitor.py — [BLOQUE 5, min 90–115] C-02 + puerta causal: pasa / alerta / falla.

Se completa en vivo: el PSI y las tres ventanas; evaluar_ventana viene con
el andamio de la puerta (la lógica de umbrales es la última pieza).
"""
from __future__ import annotations

import json

import numpy as np

from datos import EsquemaCausal, leer
from estimacion import ess_kish, propensity, smd
from registro import champion
from rutas import ESCENARIO, REGISTRO

SEMILLA_VENTANA = 4242

# Ventanas por escenario: qué covariable mueve la deriva y cuál ordena la positividad.
CONFIG = {
    "real/jobs": {"sana_n": 700, "deriva": ("age", 10.0), "positividad": "re74"},
    "real/ihdp": {"sana_n": 300, "deriva": ("bw", 1.0), "positividad": "bw"},
}


def psi(ref: np.ndarray, nueva: np.ndarray, bins: int = 10, eps: float = 1e-4) -> float:
    """Population Stability Index entre una referencia y una ventana."""
    # Deriva: los deciles de la referencia fijan los cortes; se comparan frecuencias.
    cortes = np.unique(np.quantile(ref, np.linspace(0, 1, bins + 1)))
    a = np.histogram(ref, bins=cortes)[0] / len(ref)
    b = np.histogram(nueva, bins=cortes)[0] / len(nueva)
    a, b = np.clip(a, eps, None), np.clip(b, eps, None)
    return float(np.sum((a - b) * np.log(a / b)))


def ventana_sana(train: dict, esquema: EsquemaCausal) -> dict:
    """Otra extracción de la misma población (submuestra sin reemplazo)."""
    # Otra extracción de la misma población: sin reemplazo, semilla fija.
    g = np.random.default_rng(SEMILLA_VENTANA)
    n = len(train[esquema.tratamiento])
    idx = g.choice(n, min(CONFIG[ESCENARIO]["sana_n"], n), replace=False)
    return {columna: valores[idx] for columna, valores in train.items()}


def ventana_deriva(train: dict, esquema: EsquemaCausal) -> dict:
    """La población envejeció: la edad llega corrida diez años."""
    # Copia, no mutación: el train original queda intacto.
    variable, corrimiento = CONFIG[ESCENARIO]["deriva"]
    ventana = {columna: valores.copy() for columna, valores in train.items()}
    ventana[variable] = ventana[variable] + corrimiento
    return ventana


def ventana_positividad(train: dict, esquema: EsquemaCausal) -> dict:
    """La asignación se volvió casi determinista por ingreso previo (re74)."""
    # Asignación casi determinista: tratados altos (p75), controles bajos (p25).
    D = train[esquema.tratamiento]
    eje = train[CONFIG[ESCENARIO]["positividad"]]
    p25, p75 = np.percentile(eje, [25, 75])
    seleccion = ((D == 1) & (eje > p75)) | ((D == 0) & (eje < p25))
    return {columna: valores[seleccion] for columna, valores in train.items()}


VENTANAS = {"sana": ventana_sana, "deriva": ventana_deriva,
            "positividad": ventana_positividad}


def evaluar_ventana(train: dict, ventana: dict, esquema: EsquemaCausal,
                    umbrales: dict) -> dict:
    """Evalúa una ventana: señales, estado de puerta y acción de las cinco."""
    Dw = ventana[esquema.tratamiento]
    if len(set(Dw.tolist())) < 2:
        return {"estado": "falla", "accion": "abstenerse",
                "motivo": ["el tratamiento no varía en la ventana"]}
    Xw = np.column_stack([ventana[c] for c in esquema.covariables])
    e = propensity(Xw, Dw)
    solape = float(((e >= 0.05) & (e <= 0.95)).mean())
    ess_n = ess_kish(Dw, e) / len(Dw)
    psis = {c: psi(train[c], ventana[c]) for c in esquema.covariables}
    psi_max = max(psis.values())
    smd_max = max(abs(smd(ventana[c], Dw)) for c in esquema.covariables)

    motivo = []
    estado = "pasa"
    # La puerta: primero el soporte (falla), después deriva y balance (alerta).
    if solape < umbrales["solape_min"]:
        estado = "falla"
        motivo.append(f"solapamiento roto: {solape:.0%} de unidades con e en "
                      f"[0.05, 0.95] (mínimo {umbrales['solape_min']:.0%})")
    elif psi_max > umbrales["psi_alerta"]:
        estado = "alerta"
        culpable = max(psis, key=psis.get)
        motivo.append(f"deriva: PSI de {culpable} = {psi_max:.2f} "
                      f"(umbral {umbrales['psi_alerta']})")
    if estado == "pasa" and smd_max > umbrales["smd_max"]:
        estado = "alerta"
        motivo.append(f"balance: SMD máx = {smd_max:.2f} "
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
