"""Versioned policy bundle and support checks for the local service."""
from __future__ import annotations

import hashlib
import json
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Any


REQUIRED_ARTIFACTS = (
    "policy.joblib",
    "version.json",
    "support.json",
    "policy_card.json",
)


@dataclass(frozen=True)
class PolicyBundle:
    version: str
    alias: str
    gate_status: str
    support: dict[str, tuple[float, float]]
    card: dict[str, Any]
    manifest: dict[str, Any]

    def outside_support(self, row: dict[str, float]) -> list[str]:
        reasons = []
        for name, value in row.items():
            bounds = self.support.get(name)
            if bounds is None:
                reasons.append(f"{name}: sin soporte registrado")
                continue
            lo, hi = bounds
            if not math.isfinite(value):
                reasons.append(f"{name}={value:g} no es finito; soporte indeterminado")
            elif value < lo or value > hi:
                reasons.append(f"{name}={value:g} fuera de [{lo:g}, {hi:g}]")
        return reasons


def _read(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(f"Falta {path.name}; ejecute build_runtime_bundles.py")
    return json.loads(path.read_text(encoding="utf-8"))


def load_bundle(root: Path) -> PolicyBundle:
    root = Path(root)
    manifest = _read(root / "manifest.json")
    files = manifest.get("files")
    if not isinstance(files, dict):
        raise ValueError("El manifiesto debe declarar un objeto 'files' con cobertura hash")
    missing_coverage = [name for name in REQUIRED_ARTIFACTS if name not in files]
    if missing_coverage:
        raise ValueError(
            "El manifiesto no declara cobertura hash para artefactos requeridos: "
            + ", ".join(missing_coverage)
        )
    for name, expected in files.items():
        path = root / name
        actual = hashlib.sha256(path.read_bytes()).hexdigest() if path.is_file() else ""
        if actual != expected:
            raise ValueError(f"Hash inválido o archivo ausente: {name}")
    support_data = _read(root / "support.json")
    support = {name: (float(v[0]), float(v[1])) for name, v in support_data["features"].items()}
    version = _read(root / "version.json")
    card = _read(root / "policy_card.json")
    gate_status = version.get("gate_status")
    if gate_status != "pasa":
        received = "ausente" if "gate_status" not in version else repr(gate_status)
        raise ValueError(
            "La policy no puede servirse: la puerta causal debe estar explícitamente "
            f"en 'pasa'; estado recibido: {received}"
        )
    card_gate = card.get("puerta")
    card_status = card_gate.get("estado") if isinstance(card_gate, dict) else None
    if card_status != gate_status:
        raise ValueError(
            "Estados de puerta incoherentes entre version.json "
            f"({gate_status!r}) y policy_card.json ({card_status!r}); ambos deben ser 'pasa'"
        )
    return PolicyBundle(
        version=str(version["version"]),
        alias=str(version.get("alias", "champion")),
        gate_status=gate_status,
        support=support,
        card=card,
        manifest=manifest,
    )
