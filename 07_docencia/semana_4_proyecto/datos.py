"""datos.py — [BLOQUE 2, min 10–35] Contrato C-01 (roles) + C-10 (splits y la pared).

Se completa en vivo: tres funciones con TODO. Todo lo demás ya está.
"""
from __future__ import annotations

import csv
import hashlib
import json
from dataclasses import dataclass, field

import numpy as np

from rutas import DATOS, ESCENARIO

# Adaptación por escenario: el esquema se declara una vez y viaja con los datos.
COVARIABLES = {
    "synthetic/jobs": ("age", "educ", "black", "hispan",
                       "married", "nodegree", "re74", "re75"),
    "synthetic/ihdp": ("bw", "b.head", "preterm", "birth.o", "nnhealth", "momage",
                       "sex", "twin", "b.marr", "mom.lths", "mom.hs", "mom.scoll",
                       "cig", "first", "booze", "drugs", "work.dur", "prenatal",
                       "ark", "ein", "har", "mia", "pen", "tex", "was"),
}
RESULTADO = {"synthetic/jobs": "re78", "synthetic/ihdp": "outcome"}
PARTICIONES = ("train", "validation", "test")
COLUMNAS_VERDAD_PROHIBIDAS = frozenset({
    "truth", "y0", "y1", "tau", "taui", "mu0", "mu1", "ycf",
})


def _normalizar_columna(nombre: str) -> str:
    return "".join(c for c in nombre.casefold() if c.isalnum())


# ---------------------------------------------------------------- esquema C-01

@dataclass(frozen=True)
class EsquemaCausal:
    """Cada columna, un solo rol. El esquema viaja con los datos (C-01)."""

    tratamiento: str = "treatment"
    resultado: str = field(default_factory=lambda: RESULTADO[ESCENARIO])
    covariables: tuple = field(default_factory=lambda: COVARIABLES[ESCENARIO])

    def columnas(self) -> list[str]:
        return [self.tratamiento, self.resultado, *self.covariables]

    def validar(self, columnas_datos: list[str], valores_tratamiento) -> None:
        # C-01: cada columna, un solo rol; el rechazo nombra a la culpable.
        esquema = self.columnas()
        ausentes = [c for c in esquema if c not in columnas_datos]
        if ausentes:
            raise ValueError(
                f"columna(s) del esquema ausentes en los datos: {ausentes}")
        dobles = sorted({c for c in esquema if esquema.count(c) > 1})
        if dobles:
            raise ValueError(f"columna(s) con más de un rol: {dobles}")
        if np.unique(np.asarray(valores_tratamiento)).size < 2:
            raise ValueError(
                f"el tratamiento '{self.tratamiento}' no varía en los datos")


# ------------------------------------------------------------------ carga CSV

def leer(particion: str = "train") -> dict[str, np.ndarray]:
    """Lee una partición observada. Solo observed_*: la pared es literal."""
    with open(DATOS / f"observed_{particion}.csv") as f:
        filas = list(csv.DictReader(f))
    return {k: np.array([float(r[k]) for r in filas])
            for k in filas[0] if k != "row_id"}


# ------------------------------------------------------- splits por hash (C-10)

def verificar_splits() -> bool:
    """Verifica hashes, recuentos reales e IDs únicos y disjuntos por partición."""
    declarados = json.loads((DATOS / "splits.json").read_text())
    ok = True
    ids_por_parte: dict[str, set[str]] = {}
    for parte in PARTICIONES:
        declaracion = declarados["splits"][parte]
        ruta = DATOS / f"observed_{parte}.csv"
        # C-10: hashes, filas e IDs se recomputan; no se confía en lo declarado.
        coincide = (hashlib.sha256(ruta.read_bytes()).hexdigest()
                    == declaracion["file_sha256"])
        ok &= coincide
        with open(ruta, newline="") as f:
            lector = csv.DictReader(f)
            columnas = lector.fieldnames or []
            filas = list(lector)
        n_real = len(filas)
        n_declarado = declaracion["n_rows"]
        cuenta_ok = n_real == n_declarado
        ok &= cuenta_ok
        if "row_id" not in columnas:
            raise ValueError(f"{ruta.name}: falta la columna obligatoria 'row_id'")
        ids = [(fila.get("row_id") or "").strip() for fila in filas]
        if any(not row_id for row_id in ids):
            raise ValueError(f"{ruta.name}: hay uno o más row_id vacíos")
        duplicados = sorted({row_id for row_id in ids if ids.count(row_id) > 1})
        if duplicados:
            raise ValueError(
                f"{ruta.name}: row_id duplicados dentro de la partición: {duplicados}")
        ids_por_parte[parte] = set(ids)
        print(f"  {parte:12s} hash {'OK' if coincide else 'NO COINCIDE'}"
              f" | filas {n_real}/{n_declarado} "
              f"{'OK' if cuenta_ok else 'NO COINCIDE'}"
              f" | row_id únicos OK | semilla {declarados['split_seed']}")

    for i, izquierda in enumerate(PARTICIONES):
        for derecha in PARTICIONES[i + 1:]:
            interseccion = sorted(ids_por_parte[izquierda] & ids_por_parte[derecha])
            if interseccion:
                raise ValueError(
                    f"row_id compartidos entre {izquierda} y {derecha}: {interseccion}")
    print("  row_id no vacíos, únicos y disjuntos entre train/validation/test: OK")

    n_real_total = sum(len(ids) for ids in ids_por_parte.values())
    validacion = declarados.get("validation", {})
    totales = [("n_total", declarados.get("n_total")),
               ("validation.n_rows_sum", validacion.get("n_rows_sum")),
               ("validation.expected_n_rows", validacion.get("expected_n_rows"))]
    for nombre, declarado in totales:
        if not isinstance(declarado, int):
            raise ValueError(f"splits.json: falta el total entero '{nombre}'")
        total_ok = n_real_total == declarado
        ok &= total_ok
        print(f"  {nombre}: real {n_real_total} / declarado {declarado} "
              f"{'OK' if total_ok else 'NO COINCIDE'}")
    n_total = declarados["n_total"]
    cobertura_real = n_real_total == n_total
    if validacion.get("covers_all_rows") is not cobertura_real:
        ok = False
        print("  validation.covers_all_rows NO COINCIDE con la cobertura recomputada")
    if validacion.get("no_overlap") is not True:
        ok = False
        print("  validation.no_overlap NO COINCIDE con la disyunción recomputada")
    return ok


# --------------------------------------------------------------- la pared (C-10)

def comprobar_pared() -> None:
    """Rechaza truth*.csv y campos de verdad/latentes en las tres particiones."""
    verdades = sorted(
        ruta.name for ruta in DATOS.iterdir()
        if ruta.is_file() and ruta.name.casefold().startswith("truth")
        and ruta.suffix.casefold() == ".csv")
    if verdades:
        raise RuntimeError(f"pared rota: archivos de verdad en el paquete: {verdades}")
    for parte in PARTICIONES:
        ruta = DATOS / f"observed_{parte}.csv"
        with open(ruta, newline="") as f:
            columnas = next(csv.reader(f), [])
        prohibidas = sorted(
            columna for columna in columnas
            if _normalizar_columna(columna) in COLUMNAS_VERDAD_PROHIBIDAS)
        if prohibidas:
            raise RuntimeError(
                f"pared rota: columnas de verdad/latentes en {ruta.name}: {prohibidas}")
    print("  pared OK: sin truth*.csv ni columnas de verdad/latentes en "
          "train/validation/test")


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
