"""modelos.py — Tipos fundamentales del sistema causal.

Cada modelo es un contrato de datos: define qué es válido y qué no.
Usa dataclasses con validación explícita para evitar dependencias pesadas
y mantener compatibilidad con Python 3.10+.
"""
from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from pathlib import Path
from typing import Any


class Status(Enum):
    """Estado de una verificación o resultado."""
    PASS = "pass"
    WARN = "warn"
    FAIL = "fail"
    UNKNOWN = "unknown"
    NOT_APPLICABLE = "not_applicable"


class ClaimLevel(Enum):
    """Nivel de afirmación: qué evidencia respalda el resultado."""
    DECLARED = "declared"      # Afirmado por el usuario, no verificado
    COMPUTED = "computed"      # Calculado por el sistema
    VERIFIED = "verified"      # Verificado contra criterios externos


class Accion(Enum):
    """Las cinco acciones del sistema (Cap. 2 del libro)."""
    CONTINUAR = "continuar"
    ALERTAR = "alertar"
    REVISAR_IDENTIFICACION = "revisar_identificacion"
    ABSTENERSE = "abstenerse"
    REENTRENAR = "reentrenar"


class TipoEstimando(Enum):
    """Tipos de estimando soportados."""
    ATE = "ate"
    ATT = "att"
    CATE = "cate"
    POLICY_VALUE = "policy_value"
    LATE = "late"


class ClaseSupuesto(Enum):
    """Clasificación de supuestos (adenda de contratos)."""
    OBSERVABLE = "observable"
    NO_OBSERVABLE = "no_observable"


@dataclass(frozen=True)
class Supuesto:
    """Un supuesto causal con su clasificación y tratamiento."""
    nombre: str
    clase: ClaseSupuesto
    justificacion: str = ""
    sensibilidad: dict[str, Any] = field(default_factory=dict)
    criterio_revision: str = ""

    def __post_init__(self):
        if not self.nombre or not self.nombre.strip():
            raise ValueError("Supuesto sin nombre")
        if self.clase == ClaseSupuesto.NO_OBSERVABLE and not self.criterio_revision:
            raise ValueError(
                f"Supuesto no observable '{self.nombre}' sin criterio de revisión"
            )

    def to_dict(self) -> dict:
        return {
            "nombre": self.nombre,
            "clase": self.clase.value,
            "justificacion": self.justificacion,
            "sensibilidad": self.sensibilidad,
            "criterio_revision": self.criterio_revision,
        }


@dataclass(frozen=True)
class DeclaracionCausal:
    """Declaración de estimando: qué compara, sobre quién, bajo qué supuestos.

    Es la primera pieza del sistema: sin ella, nada más funciona (Q-01).
    """
    estimando: TipoEstimando
    tratamiento: str
    resultado: str
    poblacion: str
    supuestos: tuple[Supuesto, ...] = ()
    horizonte: str = ""
    escala: str = ""
    uso_previsto: str = ""
    dag_referencia: str = ""

    def __post_init__(self):
        if not self.tratamiento or not self.tratamiento.strip():
            raise ValueError("Declaración sin tratamiento")
        if not self.resultado or not self.resultado.strip():
            raise ValueError("Declaración sin resultado")
        if not self.poblacion or not self.poblacion.strip():
            raise ValueError("Declaración sin población")
        # Al menos un supuesto no observable
        tiene_no_obs = any(
            s.clase == ClaseSupuesto.NO_OBSERVABLE for s in self.supuestos
        )
        if not tiene_no_obs:
            raise ValueError(
                "Declaración sin supuestos no observables: "
                "toda afirmación causal descansa en al menos uno"
            )

    @property
    def id_estable(self) -> str:
        """ID determinista basado en contenido."""
        contenido = json.dumps(self.to_dict(), sort_keys=True)
        return hashlib.sha256(contenido.encode()).hexdigest()[:12]

    def to_dict(self) -> dict:
        return {
            "estimando": self.estimando.value,
            "tratamiento": self.tratamiento,
            "resultado": self.resultado,
            "poblacion": self.poblacion,
            "supuestos": [s.to_dict() for s in self.supuestos],
            "horizonte": self.horizonte,
            "escala": self.escala,
            "uso_previsto": self.uso_previsto,
            "dag_referencia": self.dag_referencia,
        }


@dataclass
class RegistroEvidencia:
    """Un artefacto registrado con su hash y metadatos de procedencia."""
    artifact_id: str
    ruta: Path
    sha256: str
    version_datos: str = ""
    version_codigo: str = ""
    version_config: str = ""
    registrado_en: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )

    @classmethod
    def desde_archivo(cls, ruta: Path) -> "RegistroEvidencia":
        """Crea un registro recomputando el hash del archivo."""
        if not ruta.exists():
            raise FileNotFoundError(f"Artefacto no existe: {ruta}")
        contenido = ruta.read_bytes()
        sha = hashlib.sha256(contenido).hexdigest()
        return cls(
            artifact_id=f"art_{sha[:12]}",
            ruta=ruta,
            sha256=sha,
        )

    def verificar(self) -> bool:
        """Recomputa el hash y compara."""
        if not self.ruta.exists():
            return False
        return hashlib.sha256(self.ruta.read_bytes()).hexdigest() == self.sha256


@dataclass
class ResultadoVerificacion:
    """Resultado de ejecutar un verificador de contrato.

    Schema_version, project_id, check_id, status, claim_level,
    reason_codes, evidence_ids, artifact_hashes, configuration_hash,
    checked_at, checker_version, limitations, recommended_action.
    """
    schema_version: str = "2.0"
    project_id: str = ""
    check_id: str = ""
    status: Status = Status.UNKNOWN
    claim_level: ClaimLevel = ClaimLevel.DECLARED
    reason_codes: list[str] = field(default_factory=list)
    evidence_ids: list[str] = field(default_factory=list)
    artifact_hashes: list[str] = field(default_factory=list)
    configuration_hash: str = ""
    checked_at: str = field(
        default_factory=lambda: datetime.now(timezone.utc).isoformat()
    )
    checker_version: str = "2.0.0"
    limitations: list[str] = field(default_factory=list)
    recommended_action: Accion = Accion.CONTINUAR
    mensaje_humano: str = ""

    def to_dict(self) -> dict:
        return {
            "schema_version": self.schema_version,
            "project_id": self.project_id,
            "check_id": self.check_id,
            "status": self.status.value,
            "claim_level": self.claim_level.value,
            "reason_codes": self.reason_codes,
            "evidence_ids": self.evidence_ids,
            "artifact_hashes": self.artifact_hashes,
            "configuration_hash": self.configuration_hash,
            "checked_at": self.checked_at,
            "checker_version": self.checker_version,
            "limitations": self.limitations,
            "recommended_action": self.recommended_action.value,
            "mensaje_humano": self.mensaje_humano,
        }


@dataclass
class FichaConocimiento:
    """Una ficha de conocimiento curada con fuentes verificadas."""
    id: str
    titulo: str
    version: str = "1.0"
    pregunta_operativa: str = ""
    alcance: str = ""
    condiciones: list[str] = field(default_factory=list)
    principios: list[str] = field(default_factory=list)
    pasos: list[str] = field(default_factory=list)
    evidencia_requerida: list[str] = field(default_factory=list)
    fallos: list[str] = field(default_factory=list)
    alternativas: list[str] = field(default_factory=list)
    ejemplo: str = ""
    limitaciones: list[str] = field(default_factory=list)
    fuentes: list[dict[str, str]] = field(default_factory=list)
    fecha_revision: str = ""
    contratos_relacionados: list[str] = field(default_factory=list)
    criterios_relacionados: list[str] = field(default_factory=list)
    etiquetas: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "titulo": self.titulo,
            "version": self.version,
            "pregunta_operativa": self.pregunta_operativa,
            "alcance": self.alcance,
            "condiciones": self.condiciones,
            "principios": self.principios,
            "pasos": self.pasos,
            "evidencia_requerida": self.evidencia_requerida,
            "fallos": self.fallos,
            "alternativas": self.alternativas,
            "ejemplo": self.ejemplo,
            "limitaciones": self.limitaciones,
            "fuentes": self.fuentes,
            "fecha_revision": self.fecha_revision,
            "contratos_relacionados": self.contratos_relacionados,
            "criterios_relacionados": self.criterios_relacionados,
            "etiquetas": self.etiquetas,
        }


@dataclass
class Procedimiento:
    """Un workflow: pasos ordenados con precondiciones y salidas."""
    id: str
    titulo: str
    version: str = "1.0"
    descripcion: str = ""
    precondiciones: list[str] = field(default_factory=list)
    pasos: list[dict[str, str]] = field(default_factory=list)
    tools_necesarias: list[str] = field(default_factory=list)
    artefactos_salida: list[str] = field(default_factory=list)
    decisiones: list[str] = field(default_factory=list)
    ruta_fallo: str = ""
    contratos_relacionados: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "titulo": self.titulo,
            "version": self.version,
            "descripcion": self.descripcion,
            "precondiciones": self.precondiciones,
            "pasos": self.pasos,
            "tools_necesarias": self.tools_necesarias,
            "artefactos_salida": self.artefactos_salida,
            "decisiones": self.decisiones,
            "ruta_fallo": self.ruta_fallo,
            "contratos_relacionados": self.contratos_relacionados,
        }
