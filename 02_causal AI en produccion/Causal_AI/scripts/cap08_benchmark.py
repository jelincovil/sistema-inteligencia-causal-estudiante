#!/usr/bin/env python3
"""Cap. 8 — El benchmark como producto de datos: qué declara cada escenario.

Recorre los cinco escenarios del paquete y lo que sus archivos declaran:
unidades, particiones con hash, estado de identificación y la pared (los
archivos de verdad se referencian pero no se entregan en el paquete público).
Suma el DGP demo (sano/positividad/confusor), que sí trae verdad en el mismo
paquete — otro régimen, también documentado.
"""
import csv
import hashlib
import json
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
BASE = RAIZ / "data_benchmark_causal" / "causal_benchmark_synthetic" / "datasets"
ESCENARIOS = [
    "real/jobs",
    "real/ihdp",
    "synthetic/inference/ihdp_medium",
    "synthetic/edge_cases/latent_confounder",
    "synthetic/linear_gaussian/10_vars_10_edges",
]

def filas(ruta):
    with open(ruta) as f:
        return sum(1 for _ in f) - 1

def sha(ruta):
    return hashlib.sha256(ruta.read_bytes()).hexdigest()[:12]

def main():
    print("== Los cinco escenarios del benchmark, leídos de sus archivos ==")
    for esc in ESCENARIOS:
        d = BASE / esc
        meta = json.loads((d / "metadata.json").read_text())
        ident = json.loads((d / "identification.json").read_text())
        splits = json.loads((d / "splits.json").read_text())
        sz = {k: v["n_rows"] for k, v in splits["splits"].items()}
        nombre = meta.get("name", meta.get("scenario_id", "?"))
        print(f"\n- {esc}")
        print(f"    nombre: {nombre} | semilla: {meta.get('seed', '?')}")
        print(f"    particiones (train/val/test): {sz['train']}/{sz['validation']}/{sz['test']} "
              f"| semilla del split: {splits.get('split_seed', '?')}")
        print(f"    identificación: {ident.get('identification_status', '?')[:80]}")
        print(f"    fuente: {str(meta.get('data_origin', meta.get('reference', '?')))[:70]}")
        print(f"    hash observed_train: {sha(d / 'observed_train.csv')}…")

    print("\n== El paquete público y la pared ==")
    for esp in ("truth_train.csv", "truth.csv", "truth_validation.csv", "truth_test.csv"):
        rutas = list(BASE.rglob(esp))
        print(f"  {esp}: {len(rutas)} archivos en el paquete (la pared se cumple: {len(rutas) == 0})")

    print("\n== El otro régimen, declarado también: el DGP demo (04_produccion_causal) ==")
    for nombre in ("sano", "positividad", "confusor"):
        ruta = RAIZ / "04_produccion_causal" / "datos" / "demo" / f"entrenamiento_{nombre}.csv"
        with open(ruta) as f:
            col = next(csv.reader(f))
        print(f"  entrenamiento_{nombre}.csv: {filas(ruta)} filas, columnas {col}")

if __name__ == "__main__":
    main()
