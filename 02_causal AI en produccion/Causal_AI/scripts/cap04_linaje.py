#!/usr/bin/env python3
"""Cap. 4 — Registro, linaje y promoción de un alias, con archivos reales.

Construye un manifiesto con los hashes SHA-256 de los archivos del
escenario real/jobs, registra dos versiones, promueve `champion` y
detecta una mutación silenciosa de los datos.
"""
import hashlib
import json
from pathlib import Path

RAIZ = Path(__file__).resolve().parents[3]
ESC = RAIZ / "data_benchmark_causal" / "causal_benchmark_synthetic" / "datasets" / "real" / "jobs"

def sha256(ruta: Path) -> str:
    return hashlib.sha256(ruta.read_bytes()).hexdigest()

def main():
    archivos = ["observed_train.csv", "observed_validation.csv", "observed_test.csv", "splits.json"]
    manifiesto = {a: sha256(ESC / a) for a in archivos}

    print("== Registro de la versión v0001 (real/jobs, observado) ==")
    for a, h in manifiesto.items():
        print(f"  {a:26s} sha256 {h[:16]}…")

    # el benchmark ya declara sus propios hashes: el registro coincide con el productor
    splits = json.loads((ESC / "splits.json").read_text())
    declarado = splits["splits"]["train"]["file_sha256"]
    print(f"\nhash declarado por el productor (splits.json, train): {declarado[:16]}…")
    print(f"hash recalculado por el consumidor                : {manifiesto['observed_train.csv'][:16]}…")
    print(f"coinciden: {declarado == manifiesto['observed_train.csv']}")

    # se agrega una columna derivada mal calculada: nueva versión, otro hash
    print("\n== Versión v0002 (train + columna derivada) ==")
    contenido = (ESC / "observed_train.csv").read_bytes()
    mutado = contenido + b"0,0\n"   # dos filas espurias al final
    h_mutado = hashlib.sha256(mutado).hexdigest()
    print(f"  observed_train_v2.csv     sha256 {h_mutado[:16]}…  (distinto de v0001: {h_mutado != manifiesto['observed_train.csv']})")

    # un consumidor revalida contra el manifiesto de v0001
    print("\n== Puerta de integridad ==")
    print(f"  v0001 contra su manifiesto : {'PASA' if sha256(ESC / 'observed_train.csv') == manifiesto['observed_train.csv'] else 'FALLA'}")
    print(f"  datos mutados contra v0001 : {'PASA' if h_mutado == manifiesto['observed_train.csv'] else 'FALLA -> bloqueado: el hash no coincide, nadie promote una tabla que no es la registrada'}")

    # alias champion: un archivo de texto que se reescribe de forma atómica
    registro = Path(__import__("tempfile").mkdtemp()) / "registro"
    registro.mkdir(parents=True, exist_ok=True)
    (registro / "v0001").mkdir()
    (registro / "v0001" / "manifest.json").write_text(json.dumps({"dataset_sha256": manifiesto["observed_train.csv"]}, indent=2))
    alias = registro / "champion"
    tmp = registro / "champion.tmp"
    tmp.write_text("v0001")
    tmp.replace(alias)
    print(f"\n  alias champion -> {alias.read_text()} (escritura atómica: renombrar, nunca editar)")

if __name__ == "__main__":
    main()
