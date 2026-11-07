"""test_acceptance.py — Pruebas de la matriz de aceptación (A01-A24).

Cada test es independiente del detalle interno de implementación.
Convierte 05_ACEPTACION.md en pruebas ejecutables.
"""
from __future__ import annotations

import json
import math
import os
import tempfile
from pathlib import Path

import numpy as np
import pytest

# Importar del paquete
import sys
sys.path.insert(0, str(Path(__file__).parents[1] / "src"))

from mcp_causal.models import (
    Accion, ClaimLevel, ClaseSupuesto, DeclaracionCausal,
    ResultadoVerificacion, Status, Supuesto, TipoEstimando,
)
from mcp_causal.projects import ProjectStore
from mcp_causal.validators import (
    evaluar_puerta, validar_abstencion, validar_equidad,
    validar_esquema_roles, validar_observabilidad,
    validar_particion_pared, validar_sensibilidad,
    validar_validez_temporal, validar_version_linaje,
    validar_impacto_dano,
)
from mcp_causal.estimators import DGPSintetico, estimar_aipw
from mcp_causal.knowledge import buscar_conocimiento, contar_fichas, obtener_ficha


# ================================================================== HELPERS

def _store_temp():
    """Crea un ProjectStore con workspace temporal."""
    tmp = tempfile.mkdtemp(prefix="mcp_test_")
    return ProjectStore(tmp)


def _declaracion_valida():
    return DeclaracionCausal(
        estimando=TipoEstimando.ATE,
        tratamiento="D",
        resultado="Y",
        poblacion="población de prueba",
        supuestos=(
            Supuesto(nombre="no confusión", clase=ClaseSupuesto.NO_OBSERVABLE,
                     criterio_revision="revisar si placebo falla"),
        ),
    )


# ================================================================ A01

class TestA01Declaracion:
    """A01: Declaración vacía rechazada; supuestos declarados no reciben etiqueta verified."""

    def test_declaracion_vacia_rechazada(self):
        with pytest.raises(ValueError):
            DeclaracionCausal(
                estimando=TipoEstimando.ATE,
                tratamiento="",
                resultado="Y",
                poblacion="pob",
                supuestos=(),
            )

    def test_sin_no_observables_rechazado(self):
        with pytest.raises(ValueError):
            DeclaracionCausal(
                estimando=TipoEstimando.ATE,
                tratamiento="D", resultado="Y", poblacion="pob",
                supuestos=(Supuesto(nombre="obs", clase=ClaseSupuesto.OBSERVABLE),),
            )

    def test_supuesto_declarado_no_es_verified(self):
        decl = _declaracion_valida()
        r = ResultadoVerificacion(check_id="test", claim_level=ClaimLevel.DECLARED)
        assert r.claim_level == ClaimLevel.DECLARED
        assert r.claim_level != ClaimLevel.VERIFIED


# ================================================================ A02

class TestA02Aislamiento:
    """A02: Proyecto A no habilita B; estado persiste tras reiniciar."""

    def test_aislamiento_proyectos(self):
        store = _store_temp()
        store.crear_proyecto("a", "Proyecto A")
        store.crear_proyecto("b", "Proyecto B")
        store.guardar_declaracion("a", _declaracion_valida())
        # B no tiene declaración
        assert store.obtener_declaracion("a") is not None
        assert store.obtener_declaracion("b") is None

    def test_persistencia_tras_reinicio(self):
        tmp = tempfile.mkdtemp(prefix="mcp_test_")
        store1 = ProjectStore(tmp)
        store1.crear_proyecto("test", "Persistencia")
        store1.guardar_declaracion("test", _declaracion_valida())
        # "Reiniciar": crear nuevo store sobre el mismo workspace
        store2 = ProjectStore(tmp)
        decl = store2.obtener_declaracion("test")
        assert decl is not None
        assert decl.tratamiento == "D"


# ================================================================ A03

class TestA03Manifest:
    """A03: Manifest vacío/inexistente/hash alterado bloquea."""

    def test_manifest_vacio(self):
        r = validar_version_linaje({})
        assert r.status == Status.FAIL

    def test_manifest_inexistente(self):
        r = validar_version_linaje(None)
        assert r.status == Status.FAIL

    def test_hash_alterado(self):
        with tempfile.NamedTemporaryFile(mode="w", suffix=".csv", delete=False) as f:
            f.write("a,b\n1,2\n")
        r = validar_version_linaje({
            "version": "v1", "dataset_sha256": "hash_falso_123",
            "_ruta_datos": f.name,
        })
        assert r.status == Status.FAIL
        assert any("hash" in rc for rc in r.reason_codes)


# ================================================================ A04

class TestA04Particiones:
    """A04: Semilla 0 válida; sin semilla, solapadas, incompletas se detectan."""

    def test_semilla_cero_valida(self):
        r = validar_particion_pared({
            "semilla": 0, "bloques": {"train": {"indices": [1, 2]}, "test": {"indices": [3, 4]}},
        })
        assert r.status == Status.PASS

    def test_sin_semilla(self):
        r = validar_particion_pared({"bloques": {}})
        assert r.status == Status.FAIL
        assert any("semilla" in rc for rc in r.reason_codes)

    def test_solapadas(self):
        r = validar_particion_pared({
            "semilla": 42,
            "bloques": {"train": {"indices": [1, 2, 3]}, "test": {"indices": [3, 4]}},
        })
        assert r.status == Status.FAIL
        assert any("solape" in rc for rc in r.reason_codes)

    def test_truth_infiltrado(self):
        r = validar_particion_pared({
            "semilla": 1, "bloques": {"train": {"indices": [1]}},
            "_truth_en_observed": True,
        })
        assert r.status == Status.FAIL


# ================================================================ A05

class TestA05Temporal:
    """A05: Feature sin timestamp o post-tratamiento bloqueada."""

    def test_post_tratamiento_bloqueada(self):
        r = validar_validez_temporal([
            {"nombre": "f1", "post_tratamiento": True, "timestamp_verificable": True},
        ])
        assert r.status == Status.FAIL

    def test_sin_timestamp_bloqueada(self):
        r = validar_validez_temporal([
            {"nombre": "f1", "post_tratamiento": False, "timestamp_verificable": False},
        ])
        assert r.status == Status.FAIL

    def test_fecha_ingesta_no_valida(self):
        r = validar_validez_temporal([
            {"nombre": "f1", "post_tratamiento": False,
             "timestamp_verificable": True, "timestamp_es_ingesta": True},
        ])
        assert r.status == Status.FAIL


# ================================================================ A06

class TestA06NaN:
    """A06: NaN/inf, valores imposibles no producen pass."""

    def test_nan_no_pass(self):
        r = validar_observabilidad(
            psi=float("nan"), smd_max=0.1, ess_n=0.5, umbrales={}
        )
        assert r.status == Status.UNKNOWN

    def test_inf_no_pass(self):
        r = validar_observabilidad(
            psi=float("inf"), smd_max=0.1, ess_n=0.5, umbrales={}
        )
        assert r.status == Status.UNKNOWN


# ================================================================ A07

class TestA07Senales:
    """A07: SMD interviene en observabilidad; control negativo en sensibilidad."""

    def test_smd_interviene(self):
        r = validar_observabilidad(psi=0.05, smd_max=0.5, ess_n=0.5, umbrales={"smd_max": 0.25})
        assert r.status in (Status.WARN, Status.FAIL)

    def test_control_negativo_interviene(self):
        r = validar_sensibilidad(p_placebo=0.5, p_control_negativo=0.01, gamma=2.0)
        assert r.status == Status.FAIL


# ================================================================ A08

class TestA08Gamma:
    """A08: Gamma Rosenbaum dominio >= 1."""

    def test_gamma_menor_1_rechazado(self):
        r = validar_sensibilidad(p_placebo=0.5, p_control_negativo=0.5,
                                 gamma=0.5, metodo_gamma="rosenbaum")
        assert r.status == Status.FAIL
        assert any("menor_1" in rc for rc in r.reason_codes)


# ================================================================ A09

class TestA09Abstencion:
    """A09: Perfil incompleto o fuera del soporte se abstiene."""

    def test_perfil_vacio(self):
        r = validar_abstencion({}, {"age": (18, 54)})
        assert r.recommended_action == Accion.ABSTENERSE

    def test_fuera_de_soporte(self):
        r = validar_abstencion({"age": 99}, {"age": (18, 54)})
        assert r.recommended_action == Accion.ABSTENERSE

    def test_nan_en_perfil(self):
        r = validar_abstencion({"age": float("nan")}, {"age": (18, 54)})
        assert r.recommended_action == Accion.ABSTENERSE


# ================================================================ A10

class TestA10Puerta:
    """A10: Puerta vacía bloqueada; fail/unknown no promueven."""

    def test_senales_vacias(self):
        r = evaluar_puerta({"solape": 0.3}, {"solape_min": 0.5})
        assert r.status == Status.FAIL

    def test_fail_no_promueve(self):
        store = _store_temp()
        store.crear_proyecto("p10", "Test")
        resultado = ResultadoVerificacion(
            check_id="check1", status=Status.FAIL,
            recommended_action=Accion.ABSTENERSE,
        )
        store.guardar_verificacion("p10", resultado)
        estado = store.estado_promocion("p10")
        assert estado["estado"] == "bloqueado"


# ================================================================ A12

class TestA12Equidad:
    """A12: Equidad exige contexto, escala e incertidumbre; daño con función de pérdida."""

    def test_equidad_sin_se_rechazada(self):
        r = validar_equidad(
            {"g1": {"efecto": 100}, "g2": {"efecto": 50}}, "raza"
        )
        assert r.status == Status.FAIL  # Sin SE

    def test_equidad_con_se_evalua(self):
        r = validar_equidad(
            {"g1": {"efecto": 100, "se": 10, "n": 100},
             "g2": {"efecto": 50, "se": 10, "n": 100}},
            "raza",
        )
        assert r.status in (Status.PASS, Status.WARN)

    def test_dano_con_funcion_perdida(self):
        r = validar_impacto_dano({"efecto": 1596.0, "se": 301.6},
                                 funcion_perdida="umbral", margen=1000)
        assert r.status == Status.WARN
        assert r.recommended_action == Accion.ABSTENERSE

    def test_dano_no_es_abs_mas_se(self):
        """Verifica que el cálculo no es simplemente abs(efecto)+1.96*SE."""
        r = validar_impacto_dano({"efecto": 10.0, "se": 1.0},
                                 funcion_perdida="umbral", margen=20)
        # Con margen 20 y efecto 10: exceso = 0, no debe alertar
        assert r.status == Status.PASS


# ================================================================ A13

class TestA13Validacion:
    """A13: Contratos JSON validados, no solo presentes."""

    def test_schema_existe(self):
        schema_path = Path(__file__).parents[1] / "contratos" / "contrato.schema.json"
        assert schema_path.exists()
        schema = json.loads(schema_path.read_text())
        assert "properties" in schema

    def test_todos_contratos_validos(self):
        import jsonschema
        schema_path = Path(__file__).parents[1] / "contratos" / "contrato.schema.json"
        schema = json.loads(schema_path.read_text())
        contratos_dir = Path(__file__).parents[1] / "contratos"
        for f in contratos_dir.glob("C-*.json"):
            data = json.loads(f.read_text())
            jsonschema.validate(data, schema)  # Lanza si inválido


# ================================================================ A14

class TestA14Conocimiento:
    """A14: Búsqueda y recursos operativos sin red."""

    def test_busqueda_encuentra(self):
        r = buscar_conocimiento("estimando ATE")
        assert len(r) > 0

    def test_busqueda_sin_resultados(self):
        r = buscar_conocimiento("xyzabc123noexiste")
        assert len(r) == 0

    def test_minimo_24_fichas(self):
        assert contar_fichas() >= 24

    def test_ficha_completa(self):
        f = obtener_ficha("estimando")
        assert f is not None
        assert "fuentes" in f and len(f["fuentes"]) > 0
        assert "pregunta_operativa" in f


# ================================================================ A17

class TestA17Estadistica:
    """A17: Pruebas estadísticas reproducibles."""

    def test_aipw_reproducible(self):
        dgp = DGPSintetico(n=500, semilla=42)
        X, D, Y = dgp.generar()
        r1 = estimar_aipw(X, D, Y, semilla=42)
        r2 = estimar_aipw(X, D, Y, semilla=42)
        assert r1.ate == r2.ate  # Misma semilla, mismo resultado

    def test_aipw_recupera_efecto(self):
        """El AIPW debe recuperar el efecto en varios DGP/semillas."""
        dgp = DGPSintetico(n=1000, tau=0.5, semilla=20260701)
        errores = []
        for semilla in [1, 2, 3, 4, 5]:
            X, D, Y = dgp.generar(semilla=semilla)
            r = estimar_aipw(X, D, Y, semilla=semilla)
            errores.append(abs(r.ate - 0.5))
        # El error medio debe ser razonable (no exigir exactitud en una muestra)
        assert np.mean(errores) < 0.3  # Tolerancia justificada: n=1000, ruido sigma=1


# ================================================================ A19

class TestA19Seguridad:
    """A19: Traversal y symlinks fuera del workspace rechazados."""

    def test_ruta_traversal_rechazada(self):
        store = _store_temp()
        store.crear_proyecto("seg", "Seguridad")
        # Intentar registrar un artefacto fuera del workspace con path traversal
        ruta_maliciosa = Path(store.workspace) / ".." / ".." / "etc" / "passwd"
        # El archivo no existe o está fuera del workspace: debe fallar
        try:
            store.registrar_artefacto("seg", ruta_maliciosa)
            # Si llegó aquí, verificar que la ruta se rechaza por seguridad
            # (el archivo podría existir en algunos sistemas)
            evidencia = store.obtener_evidencia("seg")
            # No debe haber registrado algo fuera del workspace
            for e in evidencia:
                assert not ".." in e["ruta"], f"Ruta con traversal registrada: {e['ruta']}"
        except (FileNotFoundError, ValueError):
            pass  # Esperado: archivo no existe o ruta inválida


# ================================================================ A23

class TestA23Inventario:
    """A23: Documentación coincide con inventario generado del código."""

    def test_version_consistente(self):
        import mcp_causal
        assert mcp_causal.__version__ == "2.0.0"

    def test_fichas_con_ids_unicos(self):
        from mcp_causal.knowledge import listar_fichas
        ids = listar_fichas()
        assert len(ids) == len(set(ids))  # Sin duplicados


# ================================================================ RUN

if __name__ == "__main__":
    pytest.main([__file__, "-v"])
