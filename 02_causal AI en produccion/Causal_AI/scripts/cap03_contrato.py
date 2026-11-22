#!/usr/bin/env python3
"""Cap. 3 — La prueba de aceptación del contrato C-01 sobre datos reales.

Valida el esquema de roles del escenario real/jobs contra su tabla de
entrenamiento (debe pasar) y contra dos copias corrompidas (deben fallar,
nombrando la columna responsable).
"""
import csv
from dataclasses import dataclass
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
TRAIN = RAIZ / "data_benchmark_causal" / "causal_benchmark_synthetic" / "datasets" / "real" / "jobs" / "observed_train.csv"

@dataclass(frozen=True)
class CausalSchema:
    treatment: str
    outcome: str
    covariates: tuple
    instruments: tuple = ()

    def __post_init__(self):
        if not self.covariates:
            raise ValueError("Se necesita al menos una covariable")
        cols = [self.treatment, self.outcome, *self.covariates, *self.instruments]
        dobles = sorted({c for c in cols if cols.count(c) > 1})
        if dobles:
            raise ValueError(f"Columnas con dos roles: {dobles}")

    def validate(self, columnas, tratamiento) -> None:
        ausentes = sorted(set(self.columns()) - set(columnas))
        if ausentes:
            raise ValueError(f"Columnas ausentes en los datos: {ausentes}")
        if len(set(tratamiento)) < 2:
            raise ValueError(f"El tratamiento '{self.treatment}' no varía en estos datos")

    def columns(self):
        return [self.treatment, self.outcome, *self.covariates, *self.instruments]

def leer(ruta):
    with open(ruta) as f:
        r = csv.reader(f)
        return next(r)

def main():
    esquema = CausalSchema(treatment="treatment", outcome="re78",
                           covariates=("age", "educ", "black", "hispan",
                                       "married", "nodegree", "re74", "re75"))
    print("Esquema C-01 (real/jobs):", esquema)

    # (a) la tabla real: debe pasar
    with open(TRAIN) as f:
        r = csv.DictReader(f)
        columnas = r.fieldnames
        valores_d = [fila["treatment"] for fila in r]
    try:
        esquema.validate(columnas, valores_d)
        print("(a) tabla real            : PASA (todas las columnas presentes, el tratamiento varía)")
    except ValueError as e:
        print(f"(a) tabla real            : FALLA ({e})")

    # (b) el origen renombró una columna
    try:
        esquema.validate([c if c != "educ" else "educacion" for c in columnas], valores_d)
        print("(b) columna renombrada    : PASA")
    except ValueError as e:
        print(f"(b) columna renombrada    : FALLA -> {e}")

    # (c) un filtro dejó el tratamiento constante
    try:
        esquema.validate(columnas, ["1"] * len(valores_d))
        print("(c) tratamiento constante : PASA")
    except ValueError as e:
        print(f"(c) tratamiento constante : FALLA -> {e}")

    # (d) el tratamiento se coló entre las covariables
    try:
        CausalSchema(treatment="treatment", outcome="re78",
                    covariates=("age", "treatment")).validate(columnas, valores_d)
        print("(d) doble rol             : PASA")
    except ValueError as e:
        print(f"(d) doble rol             : FALLA -> {e}")

if __name__ == "__main__":
    main()
