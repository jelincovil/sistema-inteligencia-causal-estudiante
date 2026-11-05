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
from rutas import REGISTRO

SEMILLA_VENTANA = 4242


def psi(ref: np.ndarray, nueva: np.ndarray, bins: int = 10, eps: float = 1e-4) -> float:
    """Population Stability Index entre una referencia y una ventana."""
    # TODO-14 (deriva, Cap. 7): deciles de ref como cortes; frecuencias
    # relativas a y b de ref y nueva en esos cortes (clip eps);
    # devolver sum((a-b) * log(a/b)).
    raise NotImplementedError("TODO-14 pendiente de completar")


def ventana_sana(train: dict, esquema: EsquemaCausal) -> dict:
    """Otra extracción de la misma población (submuestra sin reemplazo)."""
    # TODO-15: rng.choice(n, 700, replace=False) con semilla SEMILLA_VENTANA;
    # devolver el dict con las columnas en esos índices.
    raise NotImplementedError("TODO-15 pendiente de completar")


def ventana_deriva(train: dict, esquema: EsquemaCausal) -> dict:
    """La población envejeció: la edad llega corrida diez años."""
    # TODO-16: copia del train con age + 10 (cuidado de no mutar el original).
    raise NotImplementedError("TODO-16 pendiente de completar")


def ventana_positividad(train: dict, esquema: EsquemaCausal) -> dict:
    """La asignación se volvió casi determinista por ingreso previo (re74)."""
    # TODO-17: quedarse con (tratados con re74 > p75) y (controles con re74 < p25).
    raise NotImplementedError("TODO-17 pendiente de completar")


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
    # TODO-18 (la puerta): falla si solape < umbrales["solape_min"];
    # alerta si psi_max > umbrales["psi_alerta"] (nombrando la covariable)
    # o si smd_max > umbrales["smd_max"] (solo si aún estaba en pasa).
    raise NotImplementedError("TODO-18 pendiente de completar")

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
