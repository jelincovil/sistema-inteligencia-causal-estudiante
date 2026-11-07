"""projects.py — Expediente persistente por proyecto (SQLite).

Cada proyecto tiene su propio espacio aislado. Una declaración del
proyecto A no habilita nada en el proyecto B. El estado persiste
tras reiniciar. Los artefactos cambiantes invalidan verificaciones
dependientes (invalidación transitiva).
"""
from __future__ import annotations

import json
import sqlite3
import threading
from pathlib import Path
from typing import Any

from .models import (
    Accion,
    ClaimLevel,
    DeclaracionCausal,
    RegistroEvidencia,
    ResultadoVerificacion,
    Status,
)

_SCHEMA = """
CREATE TABLE IF NOT EXISTS proyectos (
    project_id TEXT PRIMARY KEY,
    nombre TEXT NOT NULL,
    creado_en TEXT NOT NULL,
    declaracion_json TEXT
);

CREATE TABLE IF NOT EXISTS evidencia (
    project_id TEXT NOT NULL,
    artifact_id TEXT NOT NULL,
    ruta TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    version_datos TEXT DEFAULT '',
    version_codigo TEXT DEFAULT '',
    version_config TEXT DEFAULT '',
    registrado_en TEXT NOT NULL,
    FOREIGN KEY (project_id) REFERENCES proyectos(project_id),
    PRIMARY KEY (project_id, artifact_id)
);

CREATE TABLE IF NOT EXISTS verificaciones (
    project_id TEXT NOT NULL,
    check_id TEXT NOT NULL,
    status TEXT NOT NULL,
    claim_level TEXT NOT NULL,
    reason_codes TEXT,
    evidence_ids TEXT,
    artifact_hashes TEXT,
    configuration_hash TEXT DEFAULT '',
    checked_at TEXT NOT NULL,
    checker_version TEXT DEFAULT '',
    limitations TEXT,
    recommended_action TEXT NOT NULL,
    mensaje_humano TEXT DEFAULT '',
    result_json TEXT NOT NULL,
    FOREIGN KEY (project_id) REFERENCES proyectos(project_id),
    PRIMARY KEY (project_id, check_id)
);

CREATE TABLE IF NOT EXISTS dependencias (
    project_id TEXT NOT NULL,
    check_id TEXT NOT NULL,
    artifact_id TEXT NOT NULL,
    FOREIGN KEY (project_id, check_id) REFERENCES verificaciones(project_id, check_id),
    FOREIGN KEY (project_id, artifact_id) REFERENCES evidencia(project_id, artifact_id),
    PRIMARY KEY (project_id, check_id, artifact_id)
);

CREATE INDEX IF NOT EXISTS idx_evidencia_proyecto ON evidencia(project_id);
CREATE INDEX IF NOT EXISTS idx_verif_proyecto ON verificaciones(project_id);
CREATE INDEX IF NOT EXISTS idx_dep_artifact ON dependencias(project_id, artifact_id);
"""


class ProjectStore:
    """Almacén de proyectos con aislamiento y persistencia SQLite."""

    def __init__(self, workspace: Path | str = ".mcp_causal_workspace"):
        self.workspace = Path(workspace)
        self.workspace.mkdir(parents=True, exist_ok=True)
        self._db_path = self.workspace / "projects.db"
        self._lock = threading.Lock()
        self._init_db()

    def _conn(self) -> sqlite3.Connection:
        conn = sqlite3.connect(str(self._db_path))
        conn.execute("PRAGMA foreign_keys = ON")
        return conn

    def _init_db(self) -> None:
        with self._lock, self._conn() as conn:
            conn.executescript(_SCHEMA)

    # ------------------------------------------------------------ proyectos

    def crear_proyecto(self, project_id: str, nombre: str) -> dict:
        """Crea un proyecto nuevo. Falla si ya existe."""
        if not project_id or not project_id.strip():
            raise ValueError("project_id vacío")
        with self._lock, self._conn() as conn:
            try:
                conn.execute(
                    "INSERT INTO proyectos (project_id, nombre, creado_en) VALUES (?, ?, datetime('now'))",
                    (project_id, nombre),
                )
            except sqlite3.IntegrityError:
                raise ValueError(f"Proyecto '{project_id}' ya existe")
        return {"project_id": project_id, "nombre": nombre, "estado": "creado"}

    def consultar_proyecto(self, project_id: str) -> dict | None:
        """Consulta un proyecto con su declaración y verificaciones."""
        with self._lock, self._conn() as conn:
            row = conn.execute(
                "SELECT project_id, nombre, creado_en, declaracion_json FROM proyectos WHERE project_id = ?",
                (project_id,),
            ).fetchone()
        if row is None:
            return None
        result = {
            "project_id": row[0],
            "nombre": row[1],
            "creado_en": row[2],
            "declaracion": json.loads(row[3]) if row[3] else None,
            "verificaciones": self.listar_verificaciones(project_id),
        }
        return result

    def listar_proyectos(self) -> list[dict]:
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT project_id, nombre, creado_en FROM proyectos ORDER BY creado_en"
            ).fetchall()
        return [
            {"project_id": r[0], "nombre": r[1], "creado_en": r[2]} for r in rows
        ]

    # ---------------------------------------------------------- declaración

    def guardar_declaracion(self, project_id: str, decl: DeclaracionCausal) -> None:
        """Guarda la declaración causal del proyecto."""
        with self._lock, self._conn() as conn:
            cur = conn.execute(
                "UPDATE proyectos SET declaracion_json = ? WHERE project_id = ?",
                (json.dumps(decl.to_dict(), ensure_ascii=False), project_id),
            )
            if cur.rowcount == 0:
                raise ValueError(f"Proyecto '{project_id}' no existe")

    def obtener_declaracion(self, project_id: str) -> DeclaracionCausal | None:
        """Recupera la declaración causal del proyecto."""
        with self._lock, self._conn() as conn:
            row = conn.execute(
                "SELECT declaracion_json FROM proyectos WHERE project_id = ?",
                (project_id,),
            ).fetchone()
        if row is None or row[0] is None:
            return None
        data = json.loads(row[0])
        from .models import ClaseSupuesto, Supuesto, TipoEstimando
        supuestos = tuple(
            Supuesto(
                nombre=s["nombre"],
                clase=ClaseSupuesto(s["clase"]),
                justificacion=s.get("justificacion", ""),
                sensibilidad=s.get("sensibilidad", {}),
                criterio_revision=s.get("criterio_revision", ""),
            )
            for s in data.get("supuestos", [])
        )
        return DeclaracionCausal(
            estimando=TipoEstimando(data["estimando"]),
            tratamiento=data["tratamiento"],
            resultado=data["resultado"],
            poblacion=data["poblacion"],
            supuestos=supuestos,
            horizonte=data.get("horizonte", ""),
            escala=data.get("escala", ""),
            uso_previsto=data.get("uso_previsto", ""),
            dag_referencia=data.get("dag_referencia", ""),
        )

    # ------------------------------------------------------------- evidencia

    def registrar_artefacto(
        self, project_id: str, ruta: Path | str, **versiones: str
    ) -> RegistroEvidencia:
        """Registra un artefacto con su hash SHA-256 recomputado.

        Rechaza rutas fuera del workspace (A19: traversal y symlinks).
        """
        ruta = Path(ruta).resolve()  # Resolver symlinks y `..`
        # A19: la ruta resuelta debe estar dentro del workspace
        try:
            ruta.relative_to(self.workspace.resolve())
        except ValueError:
            raise ValueError(
                f"Ruta fuera del workspace: {ruta}. "
                f"El workspace autorizado es {self.workspace.resolve()}"
            )
        if not ruta.exists():
            raise FileNotFoundError(f"Artefacto no existe: {ruta}")
        reg = RegistroEvidencia.desde_archivo(ruta)
        reg.version_datos = versiones.get("version_datos", "")
        reg.version_codigo = versiones.get("version_codigo", "")
        reg.version_config = versiones.get("version_config", "")
        with self._lock, self._conn() as conn:
            conn.execute(
                """INSERT OR REPLACE INTO evidencia
                (project_id, artifact_id, ruta, sha256, version_datos, version_codigo, version_config, registrado_en)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    project_id,
                    reg.artifact_id,
                    str(ruta),
                    reg.sha256,
                    reg.version_datos,
                    reg.version_codigo,
                    reg.version_config,
                    reg.registrado_en,
                ),
            )
        return reg

    def obtener_evidencia(self, project_id: str) -> list[dict]:
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT artifact_id, ruta, sha256, version_datos, version_codigo, version_config, registrado_en "
                "FROM evidencia WHERE project_id = ?",
                (project_id,),
            ).fetchall()
        return [
            {
                "artifact_id": r[0],
                "ruta": r[1],
                "sha256": r[2],
                "version_datos": r[3],
                "version_codigo": r[4],
                "version_config": r[5],
                "registrado_en": r[6],
            }
            for r in rows
        ]

    def verificar_evidencia(self, project_id: str, artifact_id: str) -> bool:
        """Recomputa el hash de un artefacto y compara."""
        with self._lock, self._conn() as conn:
            row = conn.execute(
                "SELECT ruta, sha256 FROM evidencia WHERE project_id = ? AND artifact_id = ?",
                (project_id, artifact_id),
            ).fetchone()
        if row is None:
            return False
        ruta, sha = Path(row[0]), row[1]
        if not ruta.exists():
            return False
        import hashlib
        return hashlib.sha256(ruta.read_bytes()).hexdigest() == sha

    # -------------------------------------------------------- verificaciones

    def guardar_verificacion(
        self,
        project_id: str,
        resultado: ResultadoVerificacion,
        artifact_ids: list[str] | None = None,
    ) -> None:
        """Guarda una verificación y sus dependencias de artefactos."""
        resultado.project_id = project_id
        with self._lock, self._conn() as conn:
            conn.execute(
                """INSERT OR REPLACE INTO verificaciones
                (project_id, check_id, status, claim_level, reason_codes, evidence_ids,
                 artifact_hashes, configuration_hash, checked_at, checker_version,
                 limitations, recommended_action, mensaje_humano, result_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
                (
                    project_id,
                    resultado.check_id,
                    resultado.status.value,
                    resultado.claim_level.value,
                    json.dumps(resultado.reason_codes),
                    json.dumps(resultado.evidence_ids),
                    json.dumps(resultado.artifact_hashes),
                    resultado.configuration_hash,
                    resultado.checked_at,
                    resultado.checker_version,
                    json.dumps(resultado.limitations),
                    resultado.recommended_action.value,
                    resultado.mensaje_humano,
                    json.dumps(resultado.to_dict(), ensure_ascii=False),
                ),
            )
            # Registrar dependencias
            if artifact_ids:
                conn.execute(
                    "DELETE FROM dependencias WHERE project_id = ? AND check_id = ?",
                    (project_id, resultado.check_id),
                )
                for aid in artifact_ids:
                    conn.execute(
                        "INSERT OR IGNORE INTO dependencias (project_id, check_id, artifact_id) VALUES (?, ?, ?)",
                        (project_id, resultado.check_id, aid),
                    )

    def listar_verificaciones(self, project_id: str) -> list[dict]:
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT check_id, status, claim_level, recommended_action, checked_at, mensaje_humano "
                "FROM verificaciones WHERE project_id = ? ORDER BY checked_at",
                (project_id,),
            ).fetchall()
        return [
            {
                "check_id": r[0],
                "status": r[1],
                "claim_level": r[2],
                "recommended_action": r[3],
                "checked_at": r[4],
                "mensaje": r[5],
            }
            for r in rows
        ]

    def obtener_verificacion(self, project_id: str, check_id: str) -> dict | None:
        with self._lock, self._conn() as conn:
            row = conn.execute(
                "SELECT result_json FROM verificaciones WHERE project_id = ? AND check_id = ?",
                (project_id, check_id),
            ).fetchone()
        return json.loads(row[0]) if row else None

    # ------------------------------------------------------------- invalidación

    def invalidar_por_artefacto(self, project_id: str, artifact_id: str) -> list[str]:
        """Invalida verificaciones que dependen de un artefacto cambiado.

        Devuelve la lista de check_ids invalidados.
        """
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT check_id FROM dependencias WHERE project_id = ? AND artifact_id = ?",
                (project_id, artifact_id),
            ).fetchall()
            invalidados = [r[0] for r in rows]
            for check_id in invalidados:
                conn.execute(
                    "UPDATE verificaciones SET status = 'unknown', claim_level = 'declared' "
                    "WHERE project_id = ? AND check_id = ?",
                    (project_id, check_id),
                )
        return invalidados

    def estado_promocion(self, project_id: str) -> dict:
        """Evalúa si el proyecto es elegible para promoción.

        Reglas (02_ARQUITECTURA.md):
        - fallo requerido → bloqueado
        - evidencia requerida ausente/obsoleta → unknown y bloqueado
        - advertencia → revisión explícita registrada
        - todo requerido válido → elegible
        """
        verificaciones = self.listar_verificaciones(project_id)
        if not verificaciones:
            return {"estado": "bloqueado", "motivo": "sin verificaciones"}
        tiene_fallo = any(v["status"] == "fail" for v in verificaciones)
        tiene_unknown = any(v["status"] == "unknown" for v in verificaciones)
        tiene_warn = any(v["status"] == "warn" for v in verificaciones)
        if tiene_fallo:
            return {"estado": "bloqueado", "motivo": "verificación en fallo"}
        if tiene_unknown:
            return {"estado": "bloqueado", "motivo": "verificación con estado unknown"}
        if tiene_warn:
            return {
                "estado": "requiere_revision",
                "motivo": "advertencia pendiente de aceptación explícita",
            }
        return {"estado": "elegible", "motivo": "todas las verificaciones en pass"}
