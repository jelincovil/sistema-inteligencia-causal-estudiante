"""Regresiones para precondiciones, revisiones y confinamiento de rutas."""
from __future__ import annotations

import hashlib
import importlib
import json
import os
import sys
import types
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parents[1] / "src"))

from mcp_causal import cli
from mcp_causal.models import (
    Accion,
    ClaseSupuesto,
    ClaimLevel,
    DeclaracionCausal,
    ResultadoVerificacion,
    Status,
    Supuesto,
    TipoEstimando,
)
from mcp_causal.perfiles import PERFILES
from mcp_causal.projects import ProjectStore
from mcp_causal.validators import validar_version_linaje


def _declaracion() -> DeclaracionCausal:
    return DeclaracionCausal(
        estimando=TipoEstimando.ATE,
        tratamiento="D",
        resultado="Y",
        poblacion="población de prueba",
        supuestos=(
            Supuesto(
                nombre="no confusión",
                clase=ClaseSupuesto.NO_OBSERVABLE,
                criterio_revision="revisar con placebo",
            ),
        ),
    )


def _resultado(check_id: str = "C-TEST") -> ResultadoVerificacion:
    return ResultadoVerificacion(
        check_id=check_id,
        status=Status.PASS,
        claim_level=ClaimLevel.COMPUTED,
        recommended_action=Accion.CONTINUAR,
    )


@pytest.fixture
def store(tmp_path: Path) -> ProjectStore:
    almacen = ProjectStore(tmp_path / "workspace")
    almacen.crear_proyecto("p", "Proyecto")
    return almacen


@pytest.fixture
def store_declarado(store: ProjectStore) -> ProjectStore:
    store.guardar_declaracion("p", _declaracion())
    return store


@pytest.fixture
def perfil_simple(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setitem(
        PERFILES,
        "perfil_prueba",
        {"version": "1", "requisitos": [{"check_id": "C-TEST"}]},
    )


@pytest.fixture
def servidor(tmp_path: Path, monkeypatch: pytest.MonkeyPatch):
    monkeypatch.setenv("MCP_CAUSAL_WORKSPACE", str(tmp_path / "import-workspace"))
    modulo = importlib.import_module("mcp_causal.server")
    almacen = ProjectStore(tmp_path / "server-workspace")
    almacen.crear_proyecto("p", "Proyecto")
    monkeypatch.setattr(modulo, "_store", almacen)
    return modulo, almacen


def _declarar_en_servidor(modulo) -> None:
    respuesta = json.loads(modulo.declarar_estimando(
        project_id="p",
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
    assert respuesta["estado"] == "pasa"


@pytest.mark.parametrize("revision", ["", "revision-anterior"])
def test_revision_ausente_o_antigua_bloquea_promocion(
    store_declarado: ProjectStore,
    perfil_simple: None,
    revision: str,
) -> None:
    store_declarado.guardar_verificacion("p", _resultado())
    with store_declarado._conn() as conn:
        conn.execute(
            "UPDATE verificaciones SET revision_declaracion=? WHERE project_id='p' AND check_id='C-TEST'",
            (revision,),
        )

    estado = store_declarado.estado_promocion("p", "perfil_prueba")

    assert estado["estado"] == "bloqueado"
    assert "revision" in estado["motivo"]
    assert "C-TEST" in estado["motivo"]


@pytest.mark.parametrize("revision", ["", "revision-anterior"])
def test_invalidar_por_revision_incluye_revision_vacia(
    store_declarado: ProjectStore,
    revision: str,
) -> None:
    store_declarado.guardar_verificacion("p", _resultado())
    with store_declarado._conn() as conn:
        conn.execute(
            "UPDATE verificaciones SET revision_declaracion=? WHERE project_id='p' AND check_id='C-TEST'",
            (revision,),
        )

    assert store_declarado.invalidar_por_revision("p") == ["C-TEST"]
    verificacion = store_declarado.listar_verificaciones("p")[0]
    assert verificacion["status"] == "unknown"


def test_creacion_inicial_y_verificacion_con_revision_actual_son_validas(
    store_declarado: ProjectStore,
    perfil_simple: None,
) -> None:
    revision = store_declarado.obtener_revision_declaracion("p")
    assert revision
    assert store_declarado.invalidar_por_revision("p") == []

    store_declarado.guardar_verificacion("p", _resultado())

    assert store_declarado.listar_verificaciones("p")[0]["revision_declaracion"] == revision
    assert store_declarado.invalidar_por_revision("p") == []
    assert store_declarado.estado_promocion("p", "perfil_prueba")["estado"] == "elegible"


def test_proyecto_sin_declaracion_no_promueve(store: ProjectStore) -> None:
    store.guardar_verificacion("p", _resultado())
    assert store.estado_promocion("p")["estado"] == "bloqueado"


def test_estado_desconocido_falla_cerrado(
    store_declarado: ProjectStore,
    perfil_simple: None,
) -> None:
    store_declarado.guardar_verificacion("p", _resultado())
    with store_declarado._conn() as conn:
        conn.execute("UPDATE verificaciones SET status='unexpected' WHERE project_id='p'")

    estado = store_declarado.estado_promocion("p", "perfil_prueba")
    assert estado["estado"] == "bloqueado"
    assert "estado desconocido" in estado["motivo"]


def test_declaracion_json_corrupta_falla_cerrado(store_declarado: ProjectStore) -> None:
    with store_declarado._conn() as conn:
        conn.execute("UPDATE proyectos SET declaracion_json='{' WHERE project_id='p'")

    estado = store_declarado.estado_promocion("p")
    assert estado["estado"] == "bloqueado"
    assert "declaración inválida" in estado["motivo"]


@pytest.mark.parametrize(
    ("herramienta", "dependencia", "argumentos"),
    [
        ("validar_esquema", "validar_esquema_roles", {}),
        ("evaluar_puerta_causal", "evaluar_puerta", {}),
        ("ejecutar_verificacion", "validar_esquema_roles", {}),
        ("generar_y_estimar", "DGPSintetico", {}),
    ],
)
def test_precondicion_precede_a_operaciones_dependientes(
    servidor,
    monkeypatch: pytest.MonkeyPatch,
    herramienta: str,
    dependencia: str,
    argumentos: dict,
) -> None:
    modulo, almacen = servidor

    def no_debe_ejecutarse(*args, **kwargs):
        raise AssertionError(f"Se ejecutó {dependencia} sin declaración")

    monkeypatch.setattr(modulo, dependencia, no_debe_ejecutarse)
    if herramienta == "validar_esquema":
        argumentos = {"esquema_json": "{}"}
    elif herramienta == "evaluar_puerta_causal":
        argumentos = {"senales_json": "{}", "umbrales_json": "{}"}
    elif herramienta == "ejecutar_verificacion":
        argumentos = {"tipo": "esquema_roles", "parametros_json": "{}"}
    elif herramienta == "generar_y_estimar":
        argumentos = {"n": 10, "k_folds": 2}

    respuesta = json.loads(getattr(modulo, herramienta)(project_id="p", **argumentos))

    assert respuesta["estado"] == "falla"
    assert respuesta["error"] == "PRECONDITION_FAILED"
    assert "declarar_estimando" in respuesta["motivo"]
    assert almacen.listar_verificaciones("p") == []


def test_tool_valida_y_sella_solo_despues_de_declarar(servidor) -> None:
    modulo, almacen = servidor
    _declarar_en_servidor(modulo)

    respuesta = json.loads(modulo.validar_esquema("p", json.dumps({
        "tratamiento": "D",
        "resultado": "Y",
        "covariables": ["X"],
    })))

    assert respuesta["status"] == "pass"
    revision = almacen.obtener_revision_declaracion("p")
    assert almacen.listar_verificaciones("p")[0]["revision_declaracion"] == revision


def test_declaracion_malformada_no_se_guarda(servidor) -> None:
    modulo, almacen = servidor
    respuesta = json.loads(modulo.declarar_estimando(
        project_id="p",
        tipo="ate",
        tratamiento="D",
        resultado="Y",
        poblacion="población",
        supuestos_json="{",
    ))

    assert respuesta["estado"] == "falla"
    assert "supuestos_json" in respuesta["motivo"]
    assert almacen.obtener_declaracion("p") is None


@pytest.mark.parametrize(
    ("herramienta", "argumentos"),
    [
        ("validar_esquema", {"esquema_json": "{"}),
        ("validar_esquema", {"esquema_json": "[]"}),
        ("evaluar_puerta_causal", {"senales_json": "{", "umbrales_json": "{}"}),
        ("evaluar_puerta_causal", {"senales_json": "{}", "umbrales_json": "{"}),
        ("ejecutar_verificacion", {"tipo": "esquema_roles", "parametros_json": "{"}),
    ],
)
def test_json_malformado_no_ejecuta_ni_guarda(servidor, herramienta: str, argumentos: dict) -> None:
    modulo, almacen = servidor
    _declarar_en_servidor(modulo)

    respuesta = json.loads(getattr(modulo, herramienta)(project_id="p", **argumentos))

    assert respuesta["estado"] == "falla"
    assert "JSON" in respuesta["motivo"]
    assert almacen.listar_verificaciones("p") == []


def test_abstencion_json_malformado_falla_cerrado(servidor) -> None:
    modulo, _ = servidor
    respuesta = json.loads(modulo.abstenerse_soporte("{", "{}"))

    assert respuesta["estado"] == "falla"
    assert "perfil_json" in respuesta["motivo"]


def _manifest(ruta: Path) -> dict:
    return {
        "version": "v1",
        "dataset_sha256": hashlib.sha256(ruta.read_bytes()).hexdigest(),
        "_ruta_datos": str(ruta),
    }


def test_linaje_acepta_archivo_absoluto_dentro_del_workspace(tmp_path: Path) -> None:
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    datos = workspace / "datos.csv"
    datos.write_bytes(b"D,Y\n1,2\n")

    resultado = validar_version_linaje(_manifest(datos), workspace=workspace)

    assert resultado.status == Status.PASS


def test_linaje_sin_ruta_datos_falla(tmp_path: Path) -> None:
    resultado = validar_version_linaje({
        "version": "v1",
        "dataset_sha256": "0" * 64,
    }, workspace=tmp_path)

    assert resultado.status == Status.FAIL
    assert "falta_ruta_datos" in resultado.reason_codes


@pytest.mark.parametrize("digest", ["abc123", "g" * 64, "0" * 64 + "\n"])
def test_linaje_rechaza_hash_malformado(tmp_path: Path, digest: str) -> None:
    datos = tmp_path / "datos.csv"
    datos.write_bytes(b"D,Y\n1,2\n")
    manifest = _manifest(datos)
    manifest["dataset_sha256"] = digest

    resultado = validar_version_linaje(manifest, workspace=tmp_path)

    assert resultado.status == Status.FAIL
    assert "hash_invalido" in resultado.reason_codes


def test_linaje_normaliza_hash_hexadecimal_en_mayusculas(tmp_path: Path) -> None:
    datos = tmp_path / "datos.csv"
    datos.write_bytes(b"D,Y\n1,2\n")
    manifest = _manifest(datos)
    manifest["dataset_sha256"] = manifest["dataset_sha256"].upper()

    resultado = validar_version_linaje(manifest, workspace=tmp_path)

    assert resultado.status == Status.PASS


def test_servidor_inyecta_workspace_para_validar_linaje(servidor) -> None:
    modulo, almacen = servidor
    _declarar_en_servidor(modulo)
    datos = almacen.workspace / "datos.csv"
    datos.write_bytes(b"D,Y\n1,2\n")

    respuesta = json.loads(modulo.ejecutar_verificacion(
        project_id="p",
        tipo="version_linaje",
        parametros_json=json.dumps({"manifest": _manifest(datos)}),
    ))

    assert respuesta["status"] == Status.PASS.value


def test_linaje_recomprueba_hash_dentro_del_workspace(tmp_path: Path) -> None:
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    datos = workspace / "datos.csv"
    datos.write_bytes(b"D,Y\n1,2\n")
    manifest = _manifest(datos)
    manifest["dataset_sha256"] = "0" * 64

    resultado = validar_version_linaje(manifest, workspace=workspace)

    assert resultado.status == Status.FAIL
    assert "hash_no_coincide" in resultado.reason_codes


@pytest.mark.parametrize("nombre", ["../outside/datos.csv", "absoluto"])
def test_linaje_rechaza_ruta_fuera_del_workspace(tmp_path: Path, nombre: str) -> None:
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    outside = tmp_path / "outside"
    outside.mkdir()
    datos = outside / "datos.csv"
    datos.write_bytes(b"D,Y\n1,2\n")
    manifest = _manifest(datos)
    if nombre != "absoluto":
        manifest["_ruta_datos"] = str(workspace / nombre)

    resultado = validar_version_linaje(manifest, workspace=workspace)

    assert resultado.status == Status.FAIL
    assert "ruta_fuera_workspace" in resultado.reason_codes


def test_linaje_rechaza_symlink_que_escapa(tmp_path: Path) -> None:
    workspace = tmp_path / "workspace"
    workspace.mkdir()
    datos = tmp_path / "datos.csv"
    datos.write_bytes(b"D,Y\n1,2\n")
    enlace = workspace / "datos.csv"
    enlace.symlink_to(datos)

    resultado = validar_version_linaje(_manifest(enlace), workspace=workspace)

    assert resultado.status == Status.FAIL
    assert "ruta_fuera_workspace" in resultado.reason_codes


def test_linaje_ruta_ausente_no_es_exito(tmp_path: Path) -> None:
    resultado = validar_version_linaje({
        "version": "v1",
        "dataset_sha256": "0" * 64,
        "_ruta_datos": "ausente.csv",
    }, workspace=tmp_path)

    assert resultado.status == Status.FAIL
    assert "ruta_datos_ausente" in resultado.reason_codes


def test_linaje_con_ruta_exige_workspace(tmp_path: Path) -> None:
    datos = tmp_path / "datos.csv"
    datos.write_bytes(b"D,Y\n1,2\n")

    resultado = validar_version_linaje(_manifest(datos))

    assert resultado.status == Status.FAIL
    assert "workspace_requerido" in resultado.reason_codes


@pytest.mark.parametrize("nombre", ["../outside/nuevo/datos.csv", "absoluto"])
def test_escritura_contenida_precede_a_mkdir(
    store: ProjectStore,
    tmp_path: Path,
    nombre: str,
) -> None:
    outside = tmp_path / "outside"
    destino = str(outside / "nuevo" / "datos.csv") if nombre == "absoluto" else nombre

    with pytest.raises(ValueError, match="fuera del workspace"):
        store.registrar_artefacto_contenido("p", destino, b"no escribir")

    assert not outside.exists()


def test_symlink_no_permite_escritura_fuera(store: ProjectStore, tmp_path: Path) -> None:
    outside = tmp_path / "outside"
    outside.mkdir()
    (store.workspace / "enlace").symlink_to(outside, target_is_directory=True)

    with pytest.raises(ValueError, match="fuera del workspace"):
        store.registrar_artefacto_contenido("p", "enlace/nuevo/datos.csv", b"no escribir")

    assert list(outside.iterdir()) == []


def test_registro_contenido_anidado_valido(store: ProjectStore) -> None:
    registro = store.registrar_artefacto_contenido("p", "datos/validos.csv", b"D,Y\n1,2\n")

    assert registro.ruta.is_file()
    assert registro.ruta.resolve().is_relative_to(store.workspace.resolve())


@pytest.mark.parametrize("tipo_ruta", ["absoluta", "symlink"])
def test_registro_lectura_rechaza_fuera(store: ProjectStore, tmp_path: Path, tipo_ruta: str) -> None:
    datos = tmp_path / "outside.csv"
    datos.write_bytes(b"original")
    ruta = datos
    if tipo_ruta == "symlink":
        ruta = store.workspace / "enlace.csv"
        ruta.symlink_to(datos)

    with pytest.raises(ValueError, match="fuera del workspace"):
        store.registrar_artefacto("p", ruta)

    assert datos.read_bytes() == b"original"
    assert store.obtener_evidencia("p") == []


def test_cli_serve_aplica_workspace_antes_de_importar(
    tmp_path: Path,
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    llamado = []

    def servidor_falso() -> int:
        llamado.append(os.environ["MCP_CAUSAL_WORKSPACE"])
        return 0

    monkeypatch.delenv("MCP_CAUSAL_WORKSPACE", raising=False)
    monkeypatch.setitem(sys.modules, "mcp_causal.server", types.SimpleNamespace(main=servidor_falso))

    assert cli.main(["serve", "--workspace", str(tmp_path / "custom")]) == 0
    assert llamado == [str(tmp_path / "custom")]
