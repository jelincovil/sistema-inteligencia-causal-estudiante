"""datos.py — Contrato C-01 (roles) + C-10 (particiones y la pared) sobre real/jobs.

Bloque 2 de la clase: el esquema de roles, la verificación de los splits
publicados por hash, y la pared (la verdad no está en el paquete).
"""
from __future__ import annotations

import csv
import hashlib
import json
from dataclasses import dataclass

import numpy as np

from rutas import DATOS

# ---------------------------------------------------------------- esquema C-01


@dataclass(frozen=True)
class EsquemaCausal:
    """Cada columna, un solo rol. El esquema viaja con los datos (C-01)."""

    tratamiento: str = "treatment"
    resultado: str = "re78"
    covariables: tuple = ("age", "educ", "black", "hispan",
                         "married", "nodegree", "re74", "re75")

    def columnas(self) -> list[str]:
        return [self.tratamiento, self.resultado, *self.covariables]

    def validar(self, columnas_datos: list[str], valores_tratamiento) -> None:
        ausentes = sorted(set(self.columnas()) - set(columnas_datos))
        if ausentes:
            raise ValueError(f"Columnas ausentes en los datos: {ausentes}")
        dobles = sorted({c for c in self.columnas()
                         if self.columnas().count(c) > 1})
        if dobles:
            raise ValueError(f"Columnas con dos roles: {dobles}")
        if len(set(valores_tratamiento)) < 2:
            raise ValueError(
                f"El tratamiento '{self.tratamiento}' no varía en estos datos")


# ------------------------------------------------------------------ carga CSV


def leer(particion: str = "train") -> dict[str, np.ndarray]:
    """Lee una partición observada. Solo observed_*: la pared es literal."""
    with open(DATOS / f"observed_{particion}.csv") as f:
        filas = list(csv.DictReader(f))
    return {k: np.array([float(r[k]) for r in filas])
            for k in filas[0] if k != "row_id"}


# ------------------------------------------------------- splits por hash (C-10)


def verificar_splits() -> bool:
    """Recomputa el SHA-256 de cada partición y lo compara con splits.json."""
    declarados = json.loads((DATOS / "splits.json").read_text())
    ok = True
    for parte in ("train", "validation", "test"):
        h = hashlib.sha256(
            (DATOS / f"observed_{parte}.csv").read_bytes()).hexdigest()
        coincide = h == declarados["splits"][parte]["file_sha256"]
        ok &= coincide
        print(f"  {parte:12s} hash {'OK' if coincide else 'NO COINCIDE'}"
              f"  ({declarados['splits'][parte]['n_rows']} filas,"
              f" semilla {declarados['split_seed']})")
    return ok


# --------------------------------------------------------------- la pared (C-10)


def comprobar_pared() -> None:
    """La verdad del escenario no está en el paquete: intentar cargarla falla."""
    try:
        with open(DATOS / "truth_train.csv") as f:
            f.read()
    except FileNotFoundError:
        print("  pared OK: truth_train.csv no existe en el paquete (reservado)")
    else:
        raise RuntimeError("¡La verdad está en el paquete! La pared está rota.")


if __name__ == "__main__":
    esquema = EsquemaCausal()
    print("Esquema C-01:", esquema)
    train = leer("train")
    esquema.validar(list(train), train[esquema.tratamiento])
    print(f"esquema valida contra observed_train: OK "
          f"(n = {len(train[esquema.tratamiento])},"
          f" tratados = {int(train[esquema.tratamiento].sum())})")
    print("Verificación de splits (C-10):")
    assert verificar_splits()
    print("La pared (C-10):")
    comprobar_pared()
