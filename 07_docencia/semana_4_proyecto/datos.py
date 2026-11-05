"""datos.py — [BLOQUE 2, min 10–35] Contrato C-01 (roles) + C-10 (splits y la pared).

Se completa en vivo: tres funciones con TODO. Todo lo demás ya está.
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
        # TODO-1 (C-01): rechazar (a) columnas del esquema ausentes en los datos,
        # (b) columnas con dos roles y (c) un tratamiento que no varía.
        # Pista: tres `if` con raise ValueError que NOMREN la columna culpable.
        raise NotImplementedError("TODO-1 pendiente de completar")


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
        # TODO-2 (C-10): hash SHA-256 del archivo de la partición y comparación
        # con declarados["splits"][parte]["file_sha256"].
        # Pista: hashlib.sha256((DATOS / f"observed_{parte}.csv").read_bytes())
        raise NotImplementedError("TODO-2 pendiente de completar")
        ok &= coincide
        print(f"  {parte:12s} hash {'OK' if coincide else 'NO COINCIDE'}"
              f"  ({declarados['splits'][parte]['n_rows']} filas,"
              f" semilla {declarados['split_seed']})")
    return ok


# --------------------------------------------------------------- la pared (C-10)

def comprobar_pared() -> None:
    """La verdad del escenario no está en el paquete: intentar cargarla falla."""
    # TODO-3 (la pared): abrir truth_train.csv y convertir el FileNotFoundError
    # en la confirmación de que la pared se cumple (print + return);
    # si el archivo EXISTIERA, la pared está rota -> RuntimeError.
    raise NotImplementedError("TODO-3 pendiente de completar")


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
