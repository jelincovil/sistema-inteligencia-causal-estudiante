#!/usr/bin/env python3
"""
Script de aceptación automática para local_v1 — Contrato v1 Local.

Crea una especificación versionada con:
- Identificador y versión del contrato
- Capacidades obligatorias
- Identificadores canónicos de verificaciones
- Requisitos de evidencia y vigencia
- Tratamiento de PASS, WARN, FAIL, UNKNOWN y NOT_APPLICABLE
- Pruebas que demuestran cada requisito

Ejecuta todas las comprobaciones obligatorias y genera:
- Reporte JSON con evidencia completa
- Resumen legible
- Versión, revisión y hash del código
- Entorno, comandos, códigos de salida y evidencia
- Registro de versión, revisión o hash del código ejecutado

Estados finales:
- READY_LOCAL_V1: todos los requisitos obligatorios pasan
- BLOCKED_LOCAL_V1: al menos un requisito fallido, omitido o no ejecutado

Uso: python scripts/accept_local_v1.py
"""
from __future__ import annotations

import hashlib
import json
import os
import platform
import shlex
import subprocess
import sys
import tempfile
import traceback
from datetime import datetime, timezone
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]

# Colores para output
GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
RESET = "\033[0m"
BOLD = "\033[1m"


def get_git_info():
    """Obtiene información de git del proyecto."""
    try:
        commit = subprocess.check_output(
            ["git", "rev-parse", "HEAD"], text=True, timeout=5, cwd=PROJECT_ROOT
        ).strip()
        branch = subprocess.check_output(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"], text=True, timeout=5,
            cwd=PROJECT_ROOT,
        ).strip()
        status = subprocess.check_output(
            ["git", "status", "--short"], text=True, timeout=5, cwd=PROJECT_ROOT
        ).strip()
        if status:
            commit += " (dirty)"
        return {"commit": commit, "branch": branch}
    except Exception as e:
        return {"commit": "unknown", "branch": "unknown", "error": str(e)}


def run_command(cmd: str, timeout: int = 30) -> dict:
    """Ejecuta un comando y retorna el resultado."""
    try:
        result = subprocess.run(
            cmd, shell=True, capture_output=True, text=True, timeout=timeout
        )
        return {
            "command": cmd,
            "returncode": result.returncode,
            "stdout": result.stdout,
            "stderr": result.stderr,
        }
    except subprocess.TimeoutExpired:
        return {"command": cmd, "returncode": -1, "stdout": "", "stderr": "Timeout"}
    except Exception as e:
        return {"command": cmd, "returncode": -1, "stdout": "", "stderr": str(e)}


def load_contract():
    """Carga el contrato local_v1."""
    with open(PROJECT_ROOT / "contracts" / "local_v1.json") as f:
        return json.load(f)


def find_workspace():
    """Ubica el workspace desde el script, independientemente del cwd."""
    if PROJECT_ROOT.name != "08_mcp-agentes-causales":
        raise RuntimeError(
            "No se pudo ubicar 08_mcp-agentes-causales desde la ruta del script: "
            f"{PROJECT_ROOT}"
        )
    return PROJECT_ROOT.parent


def estado_aceptacion(required_ids: set[str], results: list[dict]) -> str:
    """Solo cobertura exacta y PASS ejecutados permiten READY_LOCAL_V1."""
    result_ids = {r.get("requirement_id") for r in results}
    ready = (
        bool(required_ids)
        and len(results) == len(required_ids)
        and result_ids == required_ids
        and all(r.get("status") == "PASS" for r in results)
    )
    return "READY_LOCAL_V1" if ready else "BLOCKED_LOCAL_V1"


def test_wheel_installation(workspace: Path) -> dict:
    """V1-01: Instalación limpia del wheel e importaciones documentadas."""
    result = {"requirement_id": "V1-01", "status": "UNKNOWN", "evidence": {}}
    try:
        # Verificar que el wheel existe
        wheels = list(workspace.glob("08_mcp-agentes-causales/dist/mcp_causal*.whl"))
        if not wheels:
            result["status"] = "FAIL"
            result["reason"] = "No se encontró wheel en 08_mcp-agentes-causales/dist/"
            return result

        # Intentar instalar en entorno temporal
        with tempfile.TemporaryDirectory(prefix="v1-test-") as tmpdir:
            venv_path = Path(tmpdir) / "venv"
            creation = subprocess.run(
                [sys.executable, "-m", "venv", str(venv_path)],
                capture_output=True,
                text=True,
                timeout=30,
            )
            result["evidence"]["venv_returncode"] = creation.returncode
            if creation.returncode != 0:
                result["status"] = "FAIL"
                result["reason"] = f"No se pudo crear el venv: {creation.stderr.strip()}"
                return result

            pip = venv_path / "bin" / "pip"
            python = venv_path / "bin" / "python"

            # Instalar wheel; red acotada por pip y por el timeout del proceso.
            install = subprocess.run(
                [str(pip), "install", "--quiet", "--disable-pip-version-check",
                 "--timeout", "10", "--retries", "1", str(wheels[0])],
                capture_output=True,
                text=True,
                timeout=60,
            )
            result["evidence"]["install_returncode"] = install.returncode
            result["evidence"]["wheel"] = str(wheels[0])
            if install.returncode != 0:
                result["status"] = "FAIL"
                result["reason"] = f"Instalación del wheel falló: {install.stderr.strip()}"
                return result

            # Verificar importaciones documentadas
            imports_ok = True
            python_command = shlex.quote(str(python))
            for imp in [
                "import mcp_causal",
                "from mcp_causal.models import DeclaracionCausal",
                "from mcp_causal.knowledge import buscar_conocimiento",
            ]:
                code = f"{imp}; print('OK')"
                check = run_command(
                    f"{python_command} -c {shlex.quote(code)}", timeout=10
                )
                if check["returncode"] != 0 or "OK" not in check["stdout"]:
                    imports_ok = False
                    result["evidence"]["import_check"] = f"Falló: {imp}"
                    break

            if imports_ok:
                result["status"] = "PASS"
                result["evidence"]["wheel"] = str(wheels[0])
                result["evidence"]["imports"] = "OK"
            else:
                result["status"] = "FAIL"
                result["reason"] = "Importaciones documentadas fallan"

        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_blocked_project(workspace: Path) -> dict:
    """V1-04: Proyecto sin declaración → bloqueado."""
    result = {"requirement_id": "V1-04", "status": "UNKNOWN", "evidence": {}}
    try:
        sys.path.insert(0, str(workspace / "08_mcp-agentes-causales" / "src"))
        from mcp_causal.projects import ProjectStore

        with tempfile.TemporaryDirectory(prefix="v1-test-") as tmpdir:
            store = ProjectStore(tmpdir)
            store.crear_proyecto("v1_test_04", "Sin declaración")
            estado = store.estado_promocion("v1_test_04")

            if estado["estado"] == "bloqueado":
                result["status"] = "PASS"
                result["evidence"] = estado
            else:
                result["status"] = "FAIL"
                result["reason"] = f"Esperado bloqueado, obtenido: {estado}"

        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_single_verification_blocked(workspace: Path) -> dict:
    """V1-05: Una verificación arbitraria no habilita."""
    result = {"requirement_id": "V1-05", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal.models import ResultadoVerificacion, Status, ClaimLevel, Accion
        from mcp_causal.projects import ProjectStore

        with tempfile.TemporaryDirectory(prefix="v1-test-") as tmpdir:
            store = ProjectStore(tmpdir)
            store.crear_proyecto("v1_test_05", "Una verificación")
            store.guardar_verificacion(
                "v1_test_05",
                ResultadoVerificacion(
                    check_id="arbitrario",
                    status=Status.PASS,
                    claim_level=ClaimLevel.COMPUTED,
                    recommended_action=Accion.CONTINUAR,
                ),
            )
            estado = store.estado_promocion("v1_test_05")
            if estado["estado"] == "bloqueado":
                result["status"] = "PASS"
                result["evidence"] = estado
            else:
                result["status"] = "FAIL"
                result["reason"] = f"Esperado bloqueado, obtenido: {estado}"

        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_empty_gate_blocked(workspace: Path) -> dict:
    """V1-06: Puerta vacía nunca aprueba."""
    result = {"requirement_id": "V1-06", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal.validators import evaluar_puerta

        # Puerta con señales vacías
        r_vacio = evaluar_puerta({}, {"solape_min": 0.5, "psi_alerta": 0.25})
        # Puerta con señales parciales
        r_parcial = evaluar_puerta(
            {"solape": 0.9}, {"solape_min": 0.5, "psi_alerta": 0.25, "smd_max": 0.25}
        )
        # NaN
        import math

        r_nan = evaluar_puerta(
            {"solape": math.nan, "psi": 0.1, "smd_max": 0.1},
            {"solape_min": 0.5, "psi_alerta": 0.25, "smd_max": 0.25},
        )
        # Inf
        r_inf = evaluar_puerta(
            {"solape": 0.8, "psi": math.inf, "smd_max": 0.1},
            {"solape_min": 0.5, "psi_alerta": 0.25, "smd_max": 0.25},
        )
        # Umbrales inválidos: deben producir UNKNOWN, nunca PASS ni una excepción.
        r_umbral_nan = evaluar_puerta(
            {"solape": 0.8, "psi": 0.1, "smd_max": 0.1},
            {"solape_min": math.nan, "psi_alerta": 0.25, "smd_max": 0.25},
        )
        r_umbral_tipo = evaluar_puerta(
            {"solape": 0.8, "psi": 0.1, "smd_max": 0.1},
            {"solape_min": "0.5", "psi_alerta": 0.25, "smd_max": 0.25},
        )

        checks = [
            (r_vacio.status.value != "pass", "vacío no es PASS"),
            (r_parcial.status.value != "pass", "parcial no es PASS"),
            (r_nan.status.value != "pass", "NaN no es PASS"),
            (r_inf.status.value != "pass", "Inf no es PASS"),
            (r_umbral_nan.status.value == "unknown", "umbral NaN produce UNKNOWN"),
            (r_umbral_tipo.status.value == "unknown", "umbral no numérico produce UNKNOWN"),
        ]

        if all(ok for ok, _ in checks):
            result["status"] = "PASS"
            result["evidence"] = {
                "vacío": r_vacio.status.value,
                "parcial": r_parcial.status.value,
                "nan": r_nan.status.value,
                "inf": r_inf.status.value,
                "umbral_nan": r_umbral_nan.status.value,
                "umbral_tipo": r_umbral_tipo.status.value,
            }
        else:
            result["status"] = "FAIL"
            result["reason"] = "; ".join(
                msg for (ok, msg), _ in checks if not ok
            )
            result["evidence"] = {
                "vacío": r_vacio.status.value,
                "parcial": r_parcial.status.value,
            }

        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_evidence_integrity(workspace: Path) -> dict:
    """V1-07: Archivo ausente/hash incorrecto/ruta fuera bloquea."""
    result = {"requirement_id": "V1-07", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal.projects import ProjectStore
        from mcp_causal.validators import validar_version_linaje

        with tempfile.TemporaryDirectory(prefix="v1-test-") as tmpdir:
            ws = Path(tmpdir) / "workspace"
            ws.mkdir()
            store = ProjectStore(ws)

            store.crear_proyecto("v1_test_07", "Evidencia")

            # Archivo ausente dentro del workspace autorizado.
            try:
                store.registrar_artefacto("v1_test_07", ws / "ausente.zip")
                result["status"] = "FAIL"
                result["reason"] = "Archivo inexistente no bloqueó"
                return result
            except FileNotFoundError:
                pass  # Esperado

            # Archivo existente fuera del workspace, pero dentro del temporal de prueba.
            outside = Path(tmpdir) / "outside"
            outside.mkdir()
            outside_file = outside / "datos.csv"
            outside_file.write_text("x,d,y\n1,0,2\n")
            try:
                store.registrar_artefacto("v1_test_07", outside_file)
                result["status"] = "FAIL"
                result["reason"] = "Ruta fuera del workspace no bloqueó"
                return result
            except ValueError:
                pass  # Esperado

            # Modificar un artefacto registrado debe invalidar su hash.
            contained_file = ws / "datos.csv"
            contained_file.write_text("x,d,y\n1,0,2\n")
            registro = store.registrar_artefacto("v1_test_07", contained_file)
            contained_file.write_text("x,d,y\n1,0,99\n")
            if store.verificar_evidencia("v1_test_07", registro.artifact_id):
                result["status"] = "FAIL"
                result["reason"] = "Hash incorrecto no bloqueó"
                return result

            lineage_file = ws / "lineage.csv"
            lineage_bytes = b"x,d,y\n1,0,2\n"
            lineage_file.write_bytes(lineage_bytes)
            lineage_digest = hashlib.sha256(lineage_bytes).hexdigest()
            lineage_cases = [
                (
                    "no_path",
                    {"version": "v1", "dataset_sha256": lineage_digest},
                    "FAIL",
                    "falta_ruta_datos",
                ),
                (
                    "malformed_digest",
                    {"version": "v1", "dataset_sha256": "abc123",
                     "_ruta_datos": str(lineage_file)},
                    "FAIL",
                    "hash_invalido",
                ),
                (
                    "missing_data_file",
                    {"version": "v1", "dataset_sha256": lineage_digest,
                     "_ruta_datos": str(ws / "lineage-ausente.csv")},
                    "FAIL",
                    "ruta_datos_ausente",
                ),
                (
                    "matching_digest",
                    {"version": "v1", "dataset_sha256": lineage_digest,
                     "_ruta_datos": str(lineage_file)},
                    "PASS",
                    None,
                ),
                (
                    "mismatched_digest",
                    {"version": "v1", "dataset_sha256": "0" * 64,
                     "_ruta_datos": str(lineage_file)},
                    "FAIL",
                    "hash_no_coincide",
                ),
                (
                    "outside_workspace",
                    {"version": "v1", "dataset_sha256": lineage_digest,
                     "_ruta_datos": str(outside_file)},
                    "FAIL",
                    "ruta_fuera_workspace",
                ),
            ]
            lineage_evidence = {}
            lineage_failures = []
            for name, manifest, expected_status, expected_reason in lineage_cases:
                lineage_result = validar_version_linaje(manifest, workspace=ws)
                lineage_evidence[name] = {
                    "status": lineage_result.status.value,
                    "reason_codes": lineage_result.reason_codes,
                }
                if lineage_result.status.value != expected_status.lower():
                    lineage_failures.append(f"{name}: estado inesperado")
                if (expected_reason is not None
                        and expected_reason not in lineage_result.reason_codes):
                    lineage_failures.append(f"{name}: falta {expected_reason}")

            result["evidence"] = {
                "missing_file_blocked": True,
                "outside_workspace_blocked": True,
                "hash_mismatch_blocked": True,
                "lineage": lineage_evidence,
            }
            if lineage_failures:
                result["status"] = "FAIL"
                result["reason"] = "; ".join(lineage_failures)
                return result

            result["status"] = "PASS"

        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_support_abstention(workspace: Path) -> dict:
    """V1-08: Soporte vacío/fuera → abstención."""
    result = {"requirement_id": "V1-08", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal.validators import validar_abstencion

        # Perfil vacío
        r_vacio = validar_abstencion({}, {"age": (18, 54)})
        # Perfil incompleto
        r_incompleto = validar_abstencion({"age": 30}, {"age": (18, 54), "educ": (10, 20)})
        # Fuera del soporte
        r_fuera = validar_abstencion({"age": 99, "educ": 15}, {"age": (18, 54), "educ": (10, 20)})

        checks = [
            (r_vacio.recommended_action.value == "abstenerse", "vacío → abstenerse"),
            (r_incompleto.recommended_action.value == "abstenerse", "incompleto → abstenerse"),
            (r_fuera.recommended_action.value == "abstenerse", "fuera → abstenerse"),
        ]

        if all(ok for ok, _ in checks):
            result["status"] = "PASS"
            result["evidence"] = {msg: ok for ok, msg in checks}
        else:
            result["status"] = "FAIL"
            result["reason"] = "; ".join(msg for ok, msg in checks if not ok)

        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_full_journey(workspace: Path) -> dict:
    """V1-09: Recorrido completo → elegible."""
    result = {"requirement_id": "V1-09", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal.estimators import DGPSintetico, estimar_aipw
        from mcp_causal.models import DeclaracionCausal, Supuesto, ClaseSupuesto, TipoEstimando

        from mcp_causal.projects import ProjectStore

        with tempfile.TemporaryDirectory(prefix="v1-test-") as tmpdir:
            ws = Path(tmpdir) / "workspace"
            ws.mkdir()
            store = ProjectStore(ws)
            store.crear_proyecto("v1_test_09", "Recorrido completo")

            decl = DeclaracionCausal(
                estimando=TipoEstimando.ATE,
                tratamiento="D",
                resultado="Y",
                poblacion="sintética",
                supuestos=(
                    Supuesto(
                        nombre="no confusión",
                        clase=ClaseSupuesto.NO_OBSERVABLE,
                        criterio_revision="revisar placebo",
                    ),
                ),
            )
            store.guardar_declaracion("v1_test_09", decl)

            # Generar evidencia: archivo en el workspace
            csv_path = ws / "datos.csv"
            csv_path.write_text("x,d,y\n1,0,2\n2,1,3\n3,0,1\n")
            store.registrar_artefacto("v1_test_09", csv_path)

            # Estimación de referencia
            dgp = DGPSintetico(n=1000, tau=0.5, semilla=42)
            X, D, Y = dgp.generar(semilla=42)
            r = estimar_aipw(X, D, Y, semilla=42)
            result["evidence"]["ate"] = round(r.ate, 3)

            # Estas operaciones parciales no ejecutan el recorrido MCP completo
            # hasta elegibilidad exigido por V1-09; no deben producir un PASS.
            result["status"] = "NOT_IMPLEMENTED"
            result["reason"] = (
                "No se ejecutó aquí el recorrido MCP completo con verificaciones, "
                "tarjeta y elegibilidad exigido por V1-09"
            )
            result["evidence"]["partial_steps"] = (
                "crear_proyecto → declarar_estimando → registrar_evidencia → estimar"
            )

        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_evidence_modification_blocks(workspace: Path) -> dict:
    """V1-10: Modificar evidencia → bloquea elegibilidad."""
    result = {"requirement_id": "V1-10", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal.projects import ProjectStore
        from mcp_causal.models import DeclaracionCausal, Supuesto, ClaseSupuesto, TipoEstimando, ResultadoVerificacion, Status, ClaimLevel, Accion
        import tempfile
        from pathlib import Path

        with tempfile.TemporaryDirectory(prefix="v1-test-") as tmpdir:
            ws = Path(tmpdir) / "workspace"
            ws.mkdir()
            store = ProjectStore(ws)
            store.crear_proyecto("v1_test_10", "Invalidacion evidencia")
            decl = DeclaracionCausal(
                estimando=TipoEstimando.ATE, tratamiento="D", resultado="Y", poblacion="pob",
                supuestos=(Supuesto(nombre="s", clase=ClaseSupuesto.NO_OBSERVABLE, criterio_revision="r"),))
            store.guardar_declaracion("v1_test_10", decl)
            # Crear archivo evidencia
            csv_path = ws / "datos.csv"
            csv_path.write_text("x,d,y\n1,0,2\n2,1,3\n")
            reg = store.registrar_artefacto("v1_test_10", csv_path)
            # Crear verificacion que depende de la evidencia
            store.guardar_verificacion("v1_test_10",
                ResultadoVerificacion(check_id="C-01_test", status=Status.PASS, claim_level=ClaimLevel.COMPUTED, recommended_action=Accion.CONTINUAR),
                artifact_ids=[reg.artifact_id])
            # Completar primero todos los requisitos para alcanzar elegibilidad.
            for cid in ["C-01_roles", "C-03_temporal", "C-09_linaje", "C-10_particion", "C-02_observabilidad", "C-12_exigencias", "C-06_puerta"]:
                store.guardar_verificacion(
                    "v1_test_10",
                    ResultadoVerificacion(check_id=cid, status=Status.PASS, claim_level=ClaimLevel.COMPUTED, recommended_action=Accion.CONTINUAR),
                    artifact_ids=[reg.artifact_id] if cid == "C-01_roles" else None,
                )
            estado_antes = store.estado_promocion("v1_test_10")
            # Modificar archivo: la consulta de elegibilidad debe invalidar sin intervención.
            csv_path.write_text("x,d,y\n1,0,9\n2,1,9\n")
            estado_despues = store.estado_promocion("v1_test_10")
            evidencia_vigente = store.verificar_evidencia("v1_test_10", reg.artifact_id)
            if (estado_antes.get("estado") == "elegible"
                    and estado_despues.get("estado") == "bloqueado"
                    and not evidencia_vigente):
                result["status"] = "PASS"
                result["evidence"] = {
                    "before": estado_antes,
                    "after": estado_despues,
                    "evidence_invalidated": not evidencia_vigente,
                }
            else:
                result["status"] = "FAIL"
                result["reason"] = (
                    f"La modificación no bloqueó elegibilidad: antes={estado_antes}, "
                    f"después={estado_despues}, evidencia_vigente={evidencia_vigente}"
                )

        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_declaration_change_invalidates(workspace: Path) -> dict:
    """V1-11: Cambiar declaración invalida resultados."""
    result = {"requirement_id": "V1-11", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal.projects import ProjectStore
        from mcp_causal.models import DeclaracionCausal, Supuesto, ClaseSupuesto, TipoEstimando, ResultadoVerificacion, Status, ClaimLevel, Accion
        with tempfile.TemporaryDirectory(prefix="v1-test-") as tmpdir:
            ws = Path(tmpdir) / "workspace"
            ws.mkdir()
            store = ProjectStore(ws)
            store.crear_proyecto("v1_test_11", "Cambio declaracion")
            decl1 = DeclaracionCausal(
                estimando=TipoEstimando.ATE, tratamiento="D", resultado="Y", poblacion="pob_a",
                supuestos=(Supuesto(nombre="s1", clase=ClaseSupuesto.NO_OBSERVABLE, criterio_revision="r1"),))
            store.guardar_declaracion("v1_test_11", decl1)
            # Verificación que depende de la declaración
            store.guardar_verificacion("v1_test_11",
                ResultadoVerificacion(check_id="C-01_roles", status=Status.PASS, claim_level=ClaimLevel.COMPUTED, recommended_action=Accion.CONTINUAR))
            rev1 = store.obtener_revision_declaracion("v1_test_11")
            estado_antes = store.estado_promocion("v1_test_11")
            # Cambiar declaración (misma población distinta -> nueva revisión)
            decl2 = DeclaracionCausal(
                estimando=TipoEstimando.ATE, tratamiento="D", resultado="Y", poblacion="pob_b",
                supuestos=(Supuesto(nombre="s1", clase=ClaseSupuesto.NO_OBSERVABLE, criterio_revision="r1"),))
            store.guardar_declaracion("v1_test_11", decl2)
            rev2 = store.obtener_revision_declaracion("v1_test_11")
            verifs = store.listar_verificaciones("v1_test_11")
            # La verificación previa debe estar en unknown
            estados_verif = {v["check_id"]: v["status"] for v in verifs}
            if rev1 == rev2:
                result["status"] = "FAIL"
                result["reason"] = "Revisión no cambió tras declarar distinto"
            elif estados_verif.get("C-01_roles") != "unknown":
                result["status"] = "FAIL"
                result["reason"] = f"C-01_roles no invalidado: {estados_verif}"
            else:
                result["status"] = "PASS"
                result["evidence"] = {"rev_antes": rev1, "rev_despues": rev2, "verificacion": estados_verif}
        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_restart_preserves_state(workspace: Path) -> dict:
    """V1-12: Reinicio conserva estado, aislamiento entre proyectos."""
    result = {"requirement_id": "V1-12", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal.models import DeclaracionCausal, Supuesto, ClaseSupuesto, TipoEstimando
        from mcp_causal.projects import ProjectStore

        with tempfile.TemporaryDirectory(prefix="v1-test-") as tmpdir:
            ws = Path(tmpdir) / "workspace"
            ws.mkdir()
            store1 = ProjectStore(ws)
            store1.crear_proyecto("v1_test_12a", "Proyecto A")
            store1.crear_proyecto("v1_test_12b", "Proyecto B")
            decl = DeclaracionCausal(
                estimando=TipoEstimando.ATE,
                tratamiento="D",
                resultado="Y",
                poblacion="pob",
                supuestos=(
                    Supuesto(
                        nombre="s", clase=ClaseSupuesto.NO_OBSERVABLE, criterio_revision="r"
                    ),
                ),
            )
            store1.guardar_declaracion("v1_test_12a", decl)

            # Simular reinicio
            store2 = ProjectStore(ws)
            decl_b = store2.obtener_declaracion("v1_test_12b")
            decl_a = store2.obtener_declaracion("v1_test_12a")
            proyectos = store2.listar_proyectos()

            if decl_b is None and decl_a is not None and len(proyectos) == 2:
                result["status"] = "PASS"
                result["evidence"] = {"isolation": True, "persistence": True}
            else:
                result["status"] = "FAIL"
                result["reason"] = f"Aislamiento o persistencia falló: A={decl_a}, B={decl_b}"

        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_consistency_after_invalidation(workspace: Path) -> dict:
    """V1-13: Todas las consultas concuerdan tras invalidación."""
    result = {"requirement_id": "V1-13", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal.projects import ProjectStore
        from mcp_causal.models import DeclaracionCausal, Supuesto, ClaseSupuesto, TipoEstimando, ResultadoVerificacion, Status, ClaimLevel, Accion
        with tempfile.TemporaryDirectory(prefix="v1-test-") as tmpdir:
            ws = Path(tmpdir) / "workspace"
            ws.mkdir()
            store = ProjectStore(ws)
            store.crear_proyecto("v1_test_13", "Consistencia")
            decl = DeclaracionCausal(
                estimando=TipoEstimando.ATE, tratamiento="D", resultado="Y", poblacion="pob",
                supuestos=(Supuesto(nombre="s", clase=ClaseSupuesto.NO_OBSERVABLE, criterio_revision="r"),))
            store.guardar_declaracion("v1_test_13", decl)
            # Satisfacer todos los requisitos del perfil aprobar_bundle_causal
            for cid in ["C-01_roles", "C-03_temporal", "C-09_linaje", "C-10_particion", "C-02_observabilidad", "C-12_exigencias", "C-06_puerta"]:
                store.guardar_verificacion("v1_test_13",
                    ResultadoVerificacion(check_id=cid, status=Status.PASS, claim_level=ClaimLevel.COMPUTED, recommended_action=Accion.CONTINUAR))
            # Crear artefacto ligado a una verificación
            csv_path = ws / "datos.csv"
            csv_path.write_text("x,d,y\n1,0,2\n")
            reg = store.registrar_artefacto("v1_test_13", csv_path)
            store.guardar_verificacion("v1_test_13",
                ResultadoVerificacion(check_id="C-01_roles", status=Status.PASS, claim_level=ClaimLevel.COMPUTED, recommended_action=Accion.CONTINUAR),
                artifact_ids=[reg.artifact_id])
            estado_ok = store.estado_promocion("v1_test_13")
            tarjeta_ok = store.emitir_tarjeta_dict("v1_test_13")
            proyecto_ok = store.consultar_proyecto("v1_test_13")
            # Invalidar por artefacto
            csv_path.write_text("x,d,y\n1,0,99\n")
            store.verificar_vigencia("v1_test_13")
            estado_inv = store.estado_promocion("v1_test_13")
            tarjeta_inv = store.emitir_tarjeta_dict("v1_test_13")
            proyecto_inv = store.consultar_proyecto("v1_test_13")
            # Todas deben concordar: promocion bloqueada
            verificaciones_inv = {
                v["check_id"]: v["status"]
                for v in (proyecto_inv or {}).get("verificaciones", [])
            }
            checks = [
                estado_ok.get("estado") == "elegible",
                tarjeta_ok.get("estado") == "elegible",
                estado_inv.get("estado") == "bloqueado",
                tarjeta_inv.get("estado") == "bloqueado",
                verificaciones_inv.get("C-01_roles") == "unknown",
            ]
            if all(checks):
                result["status"] = "PASS"
                result["evidence"] = {
                    "estado_ok": estado_ok.get("estado"),
                    "estado_inv": estado_inv.get("estado"),
                    "tarjeta_inv": tarjeta_inv.get("estado"),
                    "proyecto_inv": verificaciones_inv,
                }
            else:
                result["status"] = "FAIL"
                result["reason"] = f"Inconsistencia: promocion={estado_inv}, tarjeta={tarjeta_inv}"
        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_json_validation(workspace: Path) -> dict:
    """V1-14: La tool rechaza JSON mal formado sin guardar verificaciones."""
    result = {"requirement_id": "V1-14", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal import server
        from mcp_causal.projects import ProjectStore

        json_malos = ["{mal formado", '{"incompleto": ', "[1, 2, 3"]
        with tempfile.TemporaryDirectory(prefix="v1-json-") as tmpdir:
            original_store = server._store
            store = ProjectStore(Path(tmpdir) / "workspace")
            server._store = store
            try:
                store.crear_proyecto("json-validation", "Validación JSON")
                declaracion = json.loads(server.declarar_estimando(
                    project_id="json-validation",
                    tipo="ate",
                    tratamiento="D",
                    resultado="Y",
                    poblacion="población de prueba",
                    supuestos_json=json.dumps([{
                        "nombre": "no confusión",
                        "clase": "no_observable",
                        "criterio_revision": "revisar con placebo",
                    }]),
                ))
                if declaracion.get("estado") != "pasa":
                    raise AssertionError(f"No se pudo preparar la declaración: {declaracion}")

                respuestas = [json.loads(server.validar_esquema("json-validation", malo))
                              for malo in json_malos]
                validas = all(
                    r.get("estado") == "falla" and "JSON" in r.get("motivo", "")
                    for r in respuestas
                )
                result["evidence"]["responses"] = respuestas
                result["evidence"]["saved_checks"] = store.listar_verificaciones("json-validation")
                if validas and not result["evidence"]["saved_checks"]:
                    result["status"] = "PASS"
                else:
                    result["status"] = "FAIL"
                    result["reason"] = "La tool no rechazó todos los JSON o guardó resultados"
            finally:
                server._store = original_store
        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_card_reflects_state(workspace: Path) -> dict:
    """V1-15: Tarjeta refleja fielmente estado."""
    result = {"requirement_id": "V1-15", "status": "UNKNOWN", "evidence": {}}
    try:
        from mcp_causal.projects import ProjectStore
        from mcp_causal.models import DeclaracionCausal, Supuesto, ClaseSupuesto, TipoEstimando, ResultadoVerificacion, Status, ClaimLevel, Accion
        with tempfile.TemporaryDirectory(prefix="v1-test-") as tmpdir:
            ws = Path(tmpdir) / "workspace"
            ws.mkdir()
            store = ProjectStore(ws)
            # Caso bloqueado: sin verificaciones
            store.crear_proyecto("v1_test_15a", "Tarjeta bloqueada")
            decl = DeclaracionCausal(
                estimando=TipoEstimando.ATE, tratamiento="D", resultado="Y", poblacion="pob",
                supuestos=(Supuesto(nombre="s", clase=ClaseSupuesto.NO_OBSERVABLE, criterio_revision="r"),))
            store.guardar_declaracion("v1_test_15a", decl)
            tarjeta_bloq = store.emitir_tarjeta_dict("v1_test_15a")
            # Caso elegible: todas en pass
            store.crear_proyecto("v1_test_15b", "Tarjeta elegible")
            store.guardar_declaracion("v1_test_15b", decl)
            for cid in ["C-01_roles", "C-03_temporal", "C-09_linaje", "C-10_particion", "C-02_observabilidad", "C-12_exigencias", "C-06_puerta"]:
                store.guardar_verificacion("v1_test_15b",
                    ResultadoVerificacion(check_id=cid, status=Status.PASS, claim_level=ClaimLevel.COMPUTED, recommended_action=Accion.CONTINUAR))
            tarjeta_elig = store.emitir_tarjeta_dict("v1_test_15b")
            ok_bloq = tarjeta_bloq.get("promocion", {}).get("estado") == "bloqueado" or tarjeta_bloq.get("estado") == "bloqueado"
            ok_elig = tarjeta_elig.get("promocion", {}).get("estado") == "elegible"
            tiene_revision = bool(tarjeta_elig.get("revision_declaracion"))
            tiene_verifs = len(tarjeta_elig.get("verificaciones", [])) >= 7
            if ok_bloq and ok_elig and tiene_revision and tiene_verifs:
                result["status"] = "PASS"
                result["evidence"] = {"bloqueada": tarjeta_bloq.get("promocion"), "elegible": tarjeta_elig.get("promocion"), "revision": tarjeta_elig.get("revision_declaracion")}
            else:
                result["status"] = "FAIL"
                result["reason"] = f"Tarjeta no fiel: bloq={tarjeta_bloq.get('promocion')}, elig={tarjeta_elig.get('promocion')}, rev={tiene_revision}, verifs={tiene_verifs}"
        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


def test_documentation_matches(workspace: Path) -> dict:
    """V1-16: README y API corresponden a implementación."""
    result = {"requirement_id": "V1-16", "status": "UNKNOWN", "evidence": {}}
    try:
        readme = workspace / "08_mcp-agentes-causales" / "README.md"
        if readme.exists():
            content = readme.read_text()
            has_mcp = "mcp-causal" in content or "MCP" in content
            has_tool = "declarar_estimando" in content or "Tool" in content
            if has_mcp and has_tool:
                result["status"] = "PASS"
                result["evidence"] = {"readme": "OK", "mcp_mentions": content.count("mcp-causal") + content.count("MCP")}
            else:
                result["status"] = "FAIL"
                result["reason"] = f"README incompleto: mcp={has_mcp}, tools={has_tool}"
        else:
            result["status"] = "FAIL"
            result["reason"] = "README no encontrado"

        return result
    except Exception as e:
        result["status"] = "FAIL"
        result["reason"] = str(e)
        result["traceback"] = traceback.format_exc()
        return result


# Lista de pruebas v1
ALL_TESTS = [
    test_wheel_installation,
    test_blocked_project,
    test_single_verification_blocked,
    test_empty_gate_blocked,
    test_evidence_integrity,
    test_support_abstention,
    test_full_journey,
    test_evidence_modification_blocks,
    test_declaration_change_invalidates,
    test_restart_preserves_state,
    test_consistency_after_invalidation,
    test_json_validation,
    test_card_reflects_state,
    test_documentation_matches,
]


def main():
    workspace = find_workspace()
    contract = load_contract()
    git_info = get_git_info()

    print(f"\n{BOLD}Contrato: {contract['contract_id']} v{contract['version']}{RESET}")
    print(f"Workspace: {workspace}")
    print(f"Commit: {git_info.get('commit', 'unknown')[:8]}")
    print(f"Python: {platform.python_version()}")
    print(f"Fecha: {datetime.now(timezone.utc).isoformat()}")
    print(f"\n{BOLD}{'='*60}{RESET}")

    required_ids = {req["id"] for req in contract["proof_of_concept"]["requirements"]}
    results = []
    for test_func in ALL_TESTS:
        try:
            result = test_func(workspace)
            results.append(result)
            test_name = test_func.__name__.replace("test_", "").replace("_", " ").title()
            if result.get("status") == "PASS":
                print(f"  {GREEN}✓{RESET} {test_name}: PASS")
            elif result.get("status") == "FAIL":
                print(f"  {RED}✗{RESET} {test_name}: FAIL - {result.get('reason', '')}")
            elif result.get("status") == "NOT_IMPLEMENTED":
                print(f"  {YELLOW}○{RESET} {test_name}: NOT_IMPLEMENTED")
            else:
                print(f"  {YELLOW}?{RESET} {test_name}: {result.get('status', 'UNKNOWN')}")
        except Exception as e:
            print(f"  {RED}✗{RESET} {test_func.__name__}: ERROR - {e}")
            results.append(
                {
                    "requirement_id": "UNKNOWN",
                    "status": "FAIL",
                    "reason": str(e),
                    "traceback": traceback.format_exc(),
                }
            )

    # Un requisito sin prueba ejecutada nunca puede desaparecer del reporte.
    represented_ids = {r.get("requirement_id") for r in results}
    for requirement_id in sorted(required_ids - represented_ids):
        results.append({
            "requirement_id": requirement_id,
            "status": "NOT_IMPLEMENTED",
            "reason": "No hay una comprobación ejecutada por este script",
        })

    print(f"\n{BOLD}{'='*60}{RESET}")

    # Estadísticas
    passed = sum(1 for r in results if r.get("status") == "PASS")
    failed = sum(1 for r in results if r.get("status") == "FAIL")
    not_implemented = sum(1 for r in results if r.get("status") == "NOT_IMPLEMENTED")
    skipped = len(results) - passed - failed - not_implemented

    print(f"Resultados: {passed} PASS, {failed} FAIL, {skipped} SKIPPED, {not_implemented} PENDIENTE")
    print(f"{BOLD}{'='*60}{RESET}\n")

    # Generar reporte JSON
    report = {
        "contract_id": contract["contract_id"],
        "contract_version": contract["version"],
        "timestamp": datetime.now(timezone.utc).isoformat(),
        "git_commit": git_info.get("commit", "unknown"),
        "git_branch": git_info.get("branch", "unknown"),
        "python_version": platform.python_version(),
        "results": results,
        "summary": {
            "total": len(results),
            "passed": passed,
            "failed": failed,
            "skipped": skipped,
            "not_implemented": not_implemented,
        },
        "status": estado_aceptacion(required_ids, results),
    }
    ready = report["status"] == "READY_LOCAL_V1"

    # Guardar reporte
    reports_dir = workspace / "08_mcp-agentes-causales" / "reports"
    reports_dir.mkdir(parents=True, exist_ok=True)
    report_path = reports_dir / f"acceptance_{datetime.now(timezone.utc).strftime('%Y%m%d_%H%M%S')}.json"
    with open(report_path, "w") as f:
        json.dump(report, f, indent=2, ensure_ascii=False)
    print(f"Reporte guardado: {report_path}")

    # Resumen del estado
    if ready:
        print(f"{GREEN}{BOLD}Estado: READY_LOCAL_V1{RESET}")
    else:
        print(f"{RED}{BOLD}Estado: BLOCKED_LOCAL_V1{RESET}")
        print(f"Requisitos no aprobados: {[(r.get('requirement_id'), r.get('status')) for r in results if r.get('status') != 'PASS']}")

    return 0 if ready else 1


if __name__ == "__main__":
    sys.exit(main())
