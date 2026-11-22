"""projects.py — Expediente persistente por proyecto (SQLite).

Cada proyecto tiene su propio espacio aislado. Una declaración del
proyecto A no habilita nada en el proyecto B. El estado persiste
tras reiniciar. Los artefactos cambiantes invalidan verificaciones
dependientes (invalidación transitiva).
"""

import hashlib
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
    declaracion_json TEXT,
    declaracion_revision TEXT DEFAULT ''
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
    revision_declaracion TEXT DEFAULT '',
    perfil_version TEXT DEFAULT '',
    aceptacion_revision TEXT DEFAULT '',
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
CREATE TABLE IF NOT EXISTS aceptaciones (
    project_id TEXT NOT NULL,
    check_id TEXT NOT NULL,
    revision_declaracion TEXT NOT NULL,
    revisor TEXT DEFAULT '',
    aceptado_en TEXT NOT NULL,
    FOREIGN KEY (project_id) REFERENCES proyectos(project_id),
    PRIMARY KEY (project_id, check_id, revision_declaracion)
);

CREATE INDEX IF NOT EXISTS idx_dep_artifact ON dependencias(project_id, artifact_id);
"""


def _revision_declaracion(project_id: str, declaracion_data: dict) -> str:
    """Hash corto de la declaración vigente, usado para ligar aceptaciones y verificaciones."""
    payload = json.dumps({"project_id": project_id, "declaracion": declaracion_data}, sort_keys=True)
    return hashlib.sha256(payload.encode()).hexdigest()[:12]


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
            # Migración suave: añadir columna si falta (bases antiguas)
            cols_p = {r[1] for r in conn.execute("PRAGMA table_info(proyectos)").fetchall()}
            if "declaracion_revision" not in cols_p:
                try:
                    conn.execute("ALTER TABLE proyectos ADD COLUMN declaracion_revision TEXT DEFAULT ''")
                except Exception:
                    pass
            cols_v = {r[1] for r in conn.execute("PRAGMA table_info(verificaciones)").fetchall()}
            for col in ("revision_declaracion", "perfil_version", "aceptacion_revision"):
                if col not in cols_v:
                    try:
                        conn.execute(f"ALTER TABLE verificaciones ADD COLUMN {col} TEXT DEFAULT ''")
                    except Exception:
                        pass

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
        """Guarda la declaración; si cambia la revisión, invalida verificaciones previas."""
        nuevo_json = json.dumps(decl.to_dict(), ensure_ascii=False)
        nuevo_data = decl.to_dict()
        with self._lock, self._conn() as conn:
            row = conn.execute(
                "SELECT declaracion_json, declaracion_revision FROM proyectos WHERE project_id = ?", (project_id,)
            ).fetchone()
            if row is None:
                raise ValueError(f"Proyecto '{project_id}' no existe")
            viejo_json = row[0]
            if viejo_json:
                viejo_data = json.loads(viejo_json)
                viejo_rev = row[1] or _revision_declaracion(project_id, viejo_data)
                nuevo_rev = _revision_declaracion(project_id, nuevo_data)
                if viejo_rev != nuevo_rev:
                    # Cambio de declaración -> invalida todas las verificaciones
                    conn.execute(
                        "UPDATE verificaciones SET status='unknown', claim_level='declared', reason_codes=?, mensaje_humano=? WHERE project_id=?",
                        (json.dumps([f"declaracion_cambio:{viejo_rev}->{nuevo_rev}"]), f"Invalidada por cambio de declaracion {viejo_rev}->{nuevo_rev}", project_id),
                    )
            else:
                nuevo_rev = _revision_declaracion(project_id, nuevo_data)
            conn.execute(
                "UPDATE proyectos SET declaracion_json=?, declaracion_revision=? WHERE project_id=?",
                (nuevo_json, _revision_declaracion(project_id, nuevo_data), project_id),
            )

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

    def obtener_revision_declaracion(self, project_id: str) -> str:
        """Devuelve el hash corto de la declaración vigente, o '' si no hay."""
        with self._lock, self._conn() as conn:
            row = conn.execute("SELECT declaracion_json, declaracion_revision FROM proyectos WHERE project_id=?", (project_id,)).fetchone()
        if row is None or row[0] is None:
            return ""
        if row[1]:
            return row[1]
        data = json.loads(row[0])
        return _revision_declaracion(project_id, data)

    # ------------------------------------------------------------- evidencia

    def registrar_artefacto(
        self, project_id: str, ruta: Path | str, **versiones: str
    ) -> RegistroEvidencia:
        """Registra un artefacto con su hash SHA-256 recomputado.

        Rechaza rutas fuera del workspace (A19: traversal y symlinks).
        """
        ruta = Path(ruta).resolve()
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
            # Detectar si el hash cambió respecto al previo con el mismo artifact_id
            prev = conn.execute("SELECT sha256 FROM evidencia WHERE project_id=? AND artifact_id=?", (project_id, reg.artifact_id)).fetchone()
            hash_cambio = prev is not None and prev[0] != reg.sha256
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
            if hash_cambio:
                # Auto-invalidar verificaciones ligadas a este artefacto
                rows = conn.execute("SELECT check_id FROM dependencias WHERE project_id=? AND artifact_id=?", (project_id, reg.artifact_id)).fetchall()
                for (cid,) in rows:
                    conn.execute("UPDATE verificaciones SET status='unknown', claim_level='declared', reason_codes=? WHERE project_id=? AND check_id=?",
                                 (json.dumps([f"evidencia_modificada:{reg.artifact_id}"]), project_id, cid))
        return reg

    def registrar_artefacto_contenido(
        self, project_id: str, nombre: str, contenido: bytes, **versiones: str
    ) -> RegistroEvidencia:
        """Registra un artefacto escribiendo contenido dentro del workspace (útil para tests)."""
        ruta = (self.workspace / nombre).resolve()
        ruta.parent.mkdir(parents=True, exist_ok=True)
        try:
            ruta.relative_to(self.workspace.resolve())
        except ValueError:
            raise ValueError(f"Ruta fuera del workspace: {ruta}")
        ruta.write_bytes(contenido)
        return self.registrar_artefacto(project_id, ruta, **versiones)

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
        return hashlib.sha256(ruta.read_bytes()).hexdigest() == sha

    def verificar_toda_evidencia(self, project_id: str) -> dict:
        """Verifica todos los artefactos del proyecto; devuelve los que fallan."""
        evidencias = self.obtener_evidencia(project_id)
        fallos = []
        for ev in evidencias:
            if not self.verificar_evidencia(project_id, ev["artifact_id"]):
                fallos.append(ev["artifact_id"])
        return {"total": len(evidencias), "fallos": fallos, "vigente": len(fallos) == 0}

    # -------------------------------------------------------- verificaciones

    def guardar_verificacion(
        self,
        project_id: str,
        resultado: ResultadoVerificacion,
        artifact_ids: list[str] | None = None,
    ) -> None:
        """Guarda una verificación y sus dependencias de artefactos."""
        resultado.project_id = project_id
        # Sellar con la revisión vigente de la declaración
        with self._lock, self._conn() as conn:
            decl_row = conn.execute("SELECT declaracion_json, declaracion_revision FROM proyectos WHERE project_id=?", (project_id,)).fetchone()
            rev_decl = ""
            if decl_row and decl_row[0]:
                if decl_row[1]:
                    rev_decl = decl_row[1]
                else:
                    rev_decl = _revision_declaracion(project_id, json.loads(decl_row[0]))
            # Persistir revision_declaracion en la fila
            conn.execute(
                """INSERT OR REPLACE INTO verificaciones
                (project_id, check_id, status, claim_level, reason_codes, evidence_ids,
                 artifact_hashes, configuration_hash, checked_at, checker_version,
                 limitations, recommended_action, mensaje_humano, revision_declaracion, result_json)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)""",
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
                    rev_decl,
                    json.dumps(resultado.to_dict(), ensure_ascii=False),
                ),
            )
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
                "SELECT check_id, status, claim_level, recommended_action, checked_at, mensaje_humano, revision_declaracion "
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
                "revision_declaracion": r[6],
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

    def aceptar_advertencia(self, project_id: str, check_id: str, revisor: str = "") -> dict:
        """Acepta explícitamente una advertencia para la revisión vigente."""
        with self._lock, self._conn() as conn:
            row = conn.execute("SELECT declaracion_json FROM proyectos WHERE project_id=?", (project_id,)).fetchone()
            if row is None or row[0] is None:
                raise ValueError("Proyecto sin declaración")
            rev_hash = _revision_declaracion(project_id, json.loads(row[0]))
            st = conn.execute("SELECT status FROM verificaciones WHERE project_id=? AND check_id=?", (project_id, check_id)).fetchone()
            if st is None or st[0] != "warn":
                raise ValueError(f"Check {check_id} no está en warn")
            conn.execute("INSERT OR REPLACE INTO aceptaciones (project_id, check_id, revision_declaracion, revisor, aceptado_en) VALUES (?,?,?, ?, datetime('now'))", (project_id, check_id, rev_hash, revisor))
        return {"project_id": project_id, "check_id": check_id, "revision": rev_hash, "estado": "aceptado"}

    def invalidar_por_artefacto(self, project_id: str, artifact_id: str) -> list[str]:
        """Invalida verificaciones que dependen de un artefacto cambiado."""
        with self._lock, self._conn() as conn:
            rows = conn.execute(
                "SELECT check_id FROM dependencias WHERE project_id = ? AND artifact_id = ?",
                (project_id, artifact_id),
            ).fetchall()
            invalidados = [r[0] for r in rows]
            for check_id in invalidados:
                conn.execute(
                    "UPDATE verificaciones SET status = 'unknown', claim_level = 'declared', reason_codes=? "
                    "WHERE project_id = ? AND check_id = ?",
                    (json.dumps([f"evidencia_invalida:{artifact_id}"]), project_id, check_id),
                )
        return invalidados

    def invalidar_por_revision(self, project_id: str) -> list[str]:
        """Invalida verificaciones cuya revisión ya no coincide con la vigente."""
        with self._lock, self._conn() as conn:
            vigente = self.obtener_revision_declaracion(project_id)
            if not vigente:
                return []
            rows = conn.execute("SELECT check_id, revision_declaracion FROM verificaciones WHERE project_id=?", (project_id,)).fetchall()
            invalidados = []
            for cid, rev in rows:
                if rev and rev != vigente:
                    invalidados.append(cid)
                    conn.execute("UPDATE verificaciones SET status='unknown', claim_level='declared', reason_codes=? WHERE project_id=? AND check_id=?",
                                 (json.dumps([f"revision_desactualizada:{rev}->{vigente}"]), project_id, cid))
        return invalidados

    def verificar_vigencia(self, project_id: str) -> dict:
        """Chequea que todas las dependencias de cada verificación sigan vigentes.

        Si un artefacto cambió en disco, marca la verificación como unknown.
        Devuelve el resumen de invalidados.
        """
        invalidados: list[str] = []
        with self._lock, self._conn() as conn:
            deps = conn.execute("SELECT check_id, artifact_id FROM dependencias WHERE project_id=?", (project_id,)).fetchall()
            # Agrupar por artifact
            art_to_checks: dict[str, list[str]] = {}
            for cid, aid in deps:
                art_to_checks.setdefault(aid, []).append(cid)
            for aid, cids in art_to_checks.items():
                erow = conn.execute("SELECT ruta, sha256 FROM evidencia WHERE project_id=? AND artifact_id=?", (project_id, aid)).fetchone()
                if erow is None:
                    continue
                ruta, sha = Path(erow[0]), erow[1]
                vigente = ruta.exists() and hashlib.sha256(ruta.read_bytes()).hexdigest() == sha
                if not vigente:
                    for cid in cids:
                        conn.execute("UPDATE verificaciones SET status='unknown', claim_level='declared', reason_codes=? WHERE project_id=? AND check_id=?",
                                     (json.dumps([f"evidencia_modificada:{aid}"]), project_id, cid))
                        if cid not in invalidados:
                            invalidados.append(cid)
        return {"invalidados": invalidados, "vigente": len(invalidados) == 0}

    def estado_promocion(self, project_id: str, perfil: str = "aprobar_bundle_causal") -> dict:
        """Evalúa elegibilidad según el perfil de requisitos versionado.

        Antes de decidir, verifica vigencia de evidencia (hash del artefacto) y
        que la revisión de declaración coincida.
        """
        from .perfiles import PERFILES
        if perfil == "consultar_conocimiento":
            return {"estado": "elegible", "perfil": perfil, "motivo": "sin requisitos"}
        with self._lock, self._conn() as conn:
            row = conn.execute("SELECT declaracion_json FROM proyectos WHERE project_id=?", (project_id,)).fetchone()
        if row is None or row[0] is None:
            return {"estado": "bloqueado", "perfil": perfil, "motivo": "sin declaración causal válida"}
        data = json.loads(row[0])
        from .models import ClaseSupuesto, Supuesto, TipoEstimando
        try:
            supuestos = tuple(Supuesto(nombre=s["nombre"], clase=ClaseSupuesto(s["clase"]), justificacion=s.get("justificacion",""), criterio_revision=s.get("criterio_revision","")) for s in data.get("supuestos", []))
            decl = __import__("mcp_causal.models", fromlist=["DeclaracionCausal"]).DeclaracionCausal(estimando=TipoEstimando(data["estimando"]), tratamiento=data["tratamiento"], resultado=data["resultado"], poblacion=data["poblacion"], supuestos=supuestos)
        except Exception as e:
            return {"estado": "bloqueado", "perfil": perfil, "motivo": f"declaración inválida: {e}"}
        perfil_def = PERFILES.get(perfil)
        if perfil_def is None:
            return {"estado": "bloqueado", "perfil": perfil, "motivo": f"perfil desconocido: {perfil}"}
        # Verificar vigencia antes de evaluar requisitos (no bloquea el dict, solo marca)
        self.verificar_vigencia(project_id)
        # Chequear revisión desactualizada
        vigente_rev = _revision_declaracion(project_id, data)
        with self._lock, self._conn() as conn:
            for req in perfil_def.get("requisitos", []):
                cid = req["check_id"]
                r = conn.execute("SELECT status, revision_declaracion FROM verificaciones WHERE project_id=? AND check_id=?", (project_id, cid)).fetchone()
                if r is None:
                    return {"estado": "bloqueado", "perfil": perfil, "motivo": f"requisito ausente: {cid}"}
                status, rev_check = r[0], r[1]
                # Revisión desactualizada -> bloquea
                if rev_check and rev_check != vigente_rev:
                    return {"estado": "bloqueado", "perfil": perfil, "motivo": f"{cid} revision desactualizada {rev_check}->{vigente_rev}: redeclaracion invalido verificaciones"}
                if status in ("fail", "unknown"):
                    return {"estado": "bloqueado", "perfil": perfil, "motivo": f"{cid} en {status}"}
                if status == "not_applicable":
                    if not perfil_def.get("autoriza_abstencion", False):
                        return {"estado": "bloqueado", "perfil": perfil, "motivo": f"{cid} not_applicable no autorizado"}
                if status == "warn":
                    acc = conn.execute("SELECT 1 FROM aceptaciones WHERE project_id=? AND check_id=? AND revision_declaracion=?", (project_id, cid, vigente_rev)).fetchone()
                    if acc is None:
                        return {"estado": "requiere_revision", "perfil": perfil, "motivo": f"{cid} en warn sin aceptacion para revision {vigente_rev}"}
        return {"estado": "elegible", "perfil": perfil, "motivo": "todos los requisitos en pass o aceptados"}

    # ------------------------------------------------------- tarjeta / reporte

    def emitir_tarjeta_dict(self, project_id: str) -> dict:
        """Construye el dict de tarjeta reflejando fielmente el estado de promocion."""
        proyecto = self.consultar_proyecto(project_id)
        if proyecto is None:
            return {"estado": "falla", "motivo": "proyecto no encontrado"}
        if proyecto.get("declaracion") is None:
            return {"estado": "bloqueado", "motivo": "sin declaracion", "verificaciones": proyecto.get("verificaciones", [])}
        verifs = proyecto.get("verificaciones", [])
        # Clasificar
        bloqueantes = [v for v in verifs if v.get("status") in ("fail", "unknown")]
        pendientes = [v for v in verifs if v.get("status") == "warn"]
        promocion = self.estado_promocion(project_id)
        tarjeta = {
            "project_id": project_id,
            "declaracion": proyecto["declaracion"],
            "revision_declaracion": self.obtener_revision_declaracion(project_id),
            "verificaciones": verifs,
            "promocion": promocion,
            "estado": promocion["estado"],
            "bloqueantes": [b["check_id"] for b in bloqueantes],
            "pendientes_revision": [p["check_id"] for p in pendientes],
            "evidencia": self.obtener_evidencia(project_id),
            "evidencia_vigente": self.verificar_toda_evidencia(project_id),
        }
        return tarjeta
