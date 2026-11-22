"""perfiles.py — Perfiles de requisitos versionados por operación."""
from __future__ import annotations

from dataclasses import dataclass

# Cada perfil define qué verificaciones son obligatorias para una operación.
# Consultar conocimiento no exige declaración; aprobar un bundle sí.
PERFILES: dict[str, dict] = {
    "consultar_conocimiento": {
        "version": "1.0",
        "requisitos": [],  # Sin requisitos
        "descripcion": "Solo leer fichas; no requiere declaración.",
    },
    "aprobar_bundle_causal": {
        "version": "1.0",
        "requisitos": [
            {"check_id": "C-01_roles", "status_requerido": "pass", "max_claim": "computed"},
            {"check_id": "C-03_temporal", "status_requerido": "pass"},
            {"check_id": "C-09_linaje", "status_requerido": "pass"},
            {"check_id": "C-10_particion", "status_requerido": "pass"},
            {"check_id": "C-02_observabilidad", "status_requerido": "pass"},
            {"check_id": "C-12_exigencias", "status_requerido": "pass"},
            {"check_id": "C-06_puerta", "status_requerido": "pass"},
        ],
        "descripcion": "Aprobar un bundle para promoción a champion.",
    },
    "abstencion": {
        "version": "1.0",
        "requisitos": [
            {"check_id": "C-04_servicio", "status_requerido": "not_applicable"},
        ],
        "autoriza_abstencion": True,
        "descripcion": "Responder abstención: no es aprobación.",
    },
    "promover_champion": {
        "version": "1.0",
        "requisitos": [
            {"check_id": "C-05_tarjeta", "status_requerido": "pass"},
            {"check_id": "C-06_puerta", "status_requerido": "pass"},
        ],
        "descripcion": "Promover una versión a champion.",
    },
}


def obtener_perfil(nombre: str) -> dict | None:
    return PERFILES.get(nombre)


def listar_perfiles() -> list[str]:
    return sorted(PERFILES.keys())
