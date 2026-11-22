"""Pruebas del criterio de cierre del generador de aceptación local."""
from __future__ import annotations

import importlib.util
from pathlib import Path


PROJECT_ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location(
    "accept_local_v1", PROJECT_ROOT / "scripts" / "accept_local_v1.py"
)
assert SPEC is not None and SPEC.loader is not None
accept_local_v1 = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(accept_local_v1)


def test_workspace_se_deriva_del_script_no_del_cwd(tmp_path, monkeypatch) -> None:
    monkeypatch.chdir(tmp_path)

    assert accept_local_v1.find_workspace() == PROJECT_ROOT.parent


def test_ready_exige_cada_requisito_en_pass_sin_duplicados() -> None:
    required = {"V1-01", "V1-02"}
    passing = [
        {"requirement_id": "V1-01", "status": "PASS"},
        {"requirement_id": "V1-02", "status": "PASS"},
    ]

    assert accept_local_v1.estado_aceptacion(required, passing) == "READY_LOCAL_V1"

    blocked_results = [
        passing[:1],
        [passing[0], {"requirement_id": "V1-02", "status": "NOT_IMPLEMENTED"}],
        [passing[0], {"requirement_id": "V1-02", "status": "UNKNOWN"}],
        [passing[0], {"requirement_id": "V1-02", "status": "FAIL"}],
        [passing[0], passing[0]],
        passing + [{"requirement_id": "V1-03", "status": "PASS"}],
    ]
    for results in blocked_results:
        assert accept_local_v1.estado_aceptacion(required, results) == "BLOCKED_LOCAL_V1"


def test_ready_no_esta_disponible_para_un_contrato_vacio() -> None:
    assert accept_local_v1.estado_aceptacion(set(), []) == "BLOCKED_LOCAL_V1"
