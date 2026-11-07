#!/usr/bin/env python3
"""Cap. 2 — Traza de una consulta a través del sistema, escenario real/jobs.

Lee los archivos reales del benchmark (metadata, identification, splits)
y la tabla observada, y reconstruye el camino dato -> esquema -> split ->
comparación -> estimando. Todas las cifras son de los archivos.
"""
import csv
import json
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
ESC = RAIZ / "data_benchmark_causal" / "causal_benchmark_synthetic" / "datasets" / "real" / "jobs"

def main():
    meta = json.loads((ESC / "metadata.json").read_text())
    ident = json.loads((ESC / "identification.json").read_text())
    splits = json.loads((ESC / "splits.json").read_text())

    with open(ESC / "observed.csv") as f:
        filas = list(csv.DictReader(f))
    d = np_sum = None
    import numpy as np
    D = np.array([float(r["treatment"]) for r in filas])
    Y = np.array([float(r["re78"]) for r in filas])

    print("== Traza del escenario real/jobs ==")
    print(f"1. dato bruto        : {meta['num_units']} unidades, {len(filas[0])} columnas ({meta['name']}, {meta['reference']})")
    print(f"2. esquema (C-01)    : tratamiento = treatment, resultado = re78")
    print(f"   covariables       : {', '.join(meta['covariates'])}")
    print(f"   ajuste declarado   : {len(ident['valid_adjustment_sets'][0])} covariables pre-tratamiento")
    print(f"3. procedencia        : asignación {meta['num_experimental']} experimental + {meta['num_observational']} observacional (LaLonde-style, sintético)")
    print(f"4. splits (semilla {splits['split_seed']}): "
          f"train {splits['splits']['train']['n_rows']} / "
          f"val {splits['splits']['validation']['n_rows']} / "
          f"test {splits['splits']['test']['n_rows']} ({splits['split_method']})")
    print(f"   hash del train     : {splits['splits']['train']['file_sha256'][:16]}…")
    print(f"5. comparación cruda  : E[Y|D=1] - E[Y|D=0] = {Y[D==1].mean() - Y[D==0].mean():.1f} USD")
    print(f"   (E[Y|D=1] = {Y[D==1].mean():.1f}, E[Y|D=0] = {Y[D==0].mean():.1f}, P(D=1) = {D.mean():.3f})")
    print(f"6. referencia del DGP : {meta['what_is_real'].split(';')[0]}")
    print()
    print("La diferencia de medias de 5 no es el ATE: mezcla el efecto con la")
    print("selección del programa. Separarlos es trabajo del plano de método,")
    print("y solo es posible si el plano de datos preservó roles, tiempos y splits.")

if __name__ == "__main__":
    main()
