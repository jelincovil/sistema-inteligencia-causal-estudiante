"""Rutas del prototipo: busca la raíz del repositorio subiendo hasta encontrar el benchmark."""
from __future__ import annotations

import os
from pathlib import Path

MARCA = "data_benchmark_causal"  # existe solo en la raíz del repositorio


def raiz_repo() -> Path:
    d = Path(__file__).resolve()
    for padre in [d, *d.parents]:
        if (padre / MARCA).is_dir():
            return padre
    raise FileNotFoundError(f"No encontré {MARCA}/ subiendo desde {d}")


ESCENARIO = os.environ.get("SIC_ESCENARIO", "real/jobs")  # p. ej.: SIC_ESCENARIO=real/ihdp
DATOS = raiz_repo() / MARCA / "causal_benchmark_synthetic" / "datasets" / ESCENARIO
ARTEFACTOS = Path(__file__).resolve().parent / "artifacts"
REGISTRO = ARTEFACTOS / "registro"


if __name__ == "__main__":
    print("raíz:      ", raiz_repo())
    print("escenario:", DATOS)
    print("artefactos:", ARTEFACTOS)
