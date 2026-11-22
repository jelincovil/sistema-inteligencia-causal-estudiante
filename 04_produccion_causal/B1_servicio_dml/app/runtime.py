"""Runtime contract for versioned causal artifacts.

The service refuses to treat an artifact bundle as production-ready unless its
manifest hashes, support limits and promotion metadata are available.
"""
from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REQUIRED_ARTIFACTS = (
    "dml_estimator.joblib",
    "feature_list.json",
    "training_meta.json",
    "version.json",
    "support.json",
    "model_card.json",
)


@dataclass(frozen=True)
class RuntimeBundle:
    version: str
    alias: str
    gate_status: str
    support: dict[str, tuple[float, float]]
    manifest: dict[str, Any]
    card: dict[str, Any]

    def outside_support(self, rows: list[list[float]], feature_names: list[str]) -> list[str]:
        reasons: list[str] = []
        for row_number, row in enumerate(rows):
            for name, value in zip(feature_names, row):
                bounds = self.support.get(name)
                if bounds is None:
                    reasons.append(f"fila {row_number}: {name}: sin soporte registrado")
                    continue
                lo, hi = bounds
                if not math.isfinite(value):
                    reasons.append(f"fila {row_number}: {name}={value:g} no es finito; soporte indeterminado")
                elif value < lo or value > hi:
                    reasons.append(f"fila {row_number}: {name}={value:g} fuera de [{lo:g}, {hi:g}]")
        return reasons


def _sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def _read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"Falta el artefacto de producción: {path.name}")
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"Se esperaba un objeto JSON en {path}")
    return value


def load_runtime(artifacts_dir: Path) -> RuntimeBundle:
    root = Path(artifacts_dir)
    manifest = _read_json(root / "manifest.json")
    files = manifest.get("files")
    if not isinstance(files, dict):
        raise ValueError("El manifiesto debe declarar un objeto 'files' con cobertura hash")
    missing_coverage = [name for name in REQUIRED_ARTIFACTS if name not in files]
    if missing_coverage:
        raise ValueError(
            "El manifiesto no declara cobertura hash para artefactos requeridos: "
            + ", ".join(missing_coverage)
        )
    for filename, expected in files.items():
        path = root / filename
        if not path.is_file() or _sha256(path) != expected:
            raise ValueError(f"Hash inválido o archivo ausente en el manifiesto: {filename}")
    support_raw = _read_json(root / "support.json")
    support = {
        str(name): (float(bounds[0]), float(bounds[1]))
        for name, bounds in support_raw.get("features", {}).items()
    }
    version = _read_json(root / "version.json")
    card = _read_json(root / "model_card.json")
    gate_status = version.get("gate_status")
    if gate_status != "pasa":
        received = "ausente" if "gate_status" not in version else repr(gate_status)
        raise ValueError(
            "La versión no puede ser servida: la puerta causal debe estar "
            f"explícitamente en 'pasa'; estado recibido: {received}"
        )
    card_gate = card.get("puerta")
    card_status = card_gate.get("estado") if isinstance(card_gate, dict) else None
    if card_status != gate_status:
        raise ValueError(
            "Estados de puerta incoherentes entre version.json "
            f"({gate_status!r}) y model_card.json ({card_status!r}); ambos deben ser 'pasa'"
        )
    return RuntimeBundle(
        version=str(version.get("version", "desconocida")),
        alias=str(version.get("alias", "champion")),
        gate_status=gate_status,
        support=support,
        manifest=manifest,
        card=card,
    )
