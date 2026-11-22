from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from datetime import datetime, timedelta, timezone
from pathlib import Path
from unittest import mock

from causalops import flujo, puerta, registro_local, tarjeta


NOW = datetime(2026, 1, 15, 12, 0, tzinfo=timezone.utc)
HEALTHY = {
    "frac_ps_extremo": 0.0,
    "ess_rel_min": 0.9,
    "smd_pond_max": 0.02,
    "nc_abs_z": 0.2,
}
ESTIMATION = {
    "n": 100,
    "metodo": "IRM de prueba",
    "ate": 1.0,
    "se": 0.1,
    "ic95": [0.8, 1.2],
    "k_folds": 2,
    "semilla": 0,
}


def iso(value: datetime) -> str:
    return value.astimezone(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def make_card(result=None, *, timestamp: datetime = NOW) -> dict:
    result = puerta.evaluar(HEALTHY) if result is None else result
    with mock.patch("causalops.tarjeta._ahora", return_value=iso(timestamp)):
        return tarjeta.construir(
            nombre="modelo-de-prueba",
            version="pendiente",
            fuente_datos="fixture sintética para pruebas de promoción",
            sha256_datos="0" * 64,
            resumen_estimacion=ESTIMATION,
            resultado_puerta=result,
            sensibilidad={"e_value": {"punto": 2.0}},
            contraste_experimental=None,
            commit=None,
        )


def register(root: Path, card: dict) -> str:
    return registro_local.registrar_version(root, ESTIMATION, card, "0" * 64)


def update_manifest(root: Path, version: str, **changes) -> None:
    path = root / version / "manifest.json"
    manifest = json.loads(path.read_text(encoding="utf-8"))
    manifest.update(changes)
    path.write_text(json.dumps(manifest), encoding="utf-8")


class GateEvaluationTests(unittest.TestCase):
    def test_complete_finite_diagnostics_pass(self):
        result = puerta.evaluar(HEALTHY)
        self.assertEqual(result["estado"], "pasa")
        self.assertEqual(puerta.motivos_rechazo(result), [])

    def test_missing_malformed_and_nonfinite_diagnostics_fail(self):
        invalid_values = (None, "0.1", True, float("nan"), float("inf"), -float("inf"), [], {})
        for name in HEALTHY:
            for bad_value in invalid_values:
                with self.subTest(metric=name, value=bad_value):
                    diagnostics = dict(HEALTHY)
                    diagnostics[name] = bad_value
                    result = puerta.evaluar(diagnostics)
                    self.assertEqual(result["estado"], "falla")
                    check = next(c for c in result["chequeos"] if c["clave"] == name)
                    self.assertEqual(check["estado"], "falla")
                    self.assertIn("motivo", check)
                    self.assertNotEqual(puerta.motivos_rechazo_evidencia(make_card(result)), [])

        with self.subTest(metric="all-missing"):
            result = puerta.evaluar({})
            self.assertEqual(result["estado"], "falla")
            self.assertEqual(len(result["chequeos"]), len(puerta.UMBRALES_POR_DEFECTO))
            for check in result["chequeos"]:
                self.assertIn("ausente", check["motivo"])

        with self.subTest(metric="not-an-object"):
            self.assertEqual(puerta.evaluar(None)["estado"], "falla")

    def test_claimed_pass_without_coherent_checks_is_rejected(self):
        candidates = [
            {"estado": "pasa"},
            {"estado": "pasa", "chequeos": []},
            {"estado": "desconocido", "chequeos": []},
            {"estado": [], "chequeos": []},
            None,
        ]
        for result in candidates:
            with self.subTest(result=result):
                self.assertNotEqual(puerta.motivos_rechazo(result), [])

        tampered = puerta.evaluar(HEALTHY)
        tampered["chequeos"][0]["valor"] = 1.0
        self.assertTrue(any("incoherente" in reason for reason in puerta.motivos_rechazo(tampered)))


class PersistedEvidenceTests(unittest.TestCase):
    def test_current_complete_card_is_accepted(self):
        self.assertEqual(puerta.motivos_rechazo_evidencia(make_card(), ahora=NOW), [])

    def test_missing_unknown_malformed_and_stale_evidence_is_rejected(self):
        cases = []

        missing = make_card()
        del missing["supuestos"]["observables"][0]["verificado_en"]
        cases.append(("missing-timestamp", missing, "ausente o mal formada"))

        unknown = make_card()
        unknown["puerta"]["estado"] = "desconocido"
        cases.append(("unknown-state", unknown, "desconocido"))

        malformed = make_card()
        malformed["supuestos"]["observables"][0]["verificado_en"] = "ayer"
        cases.append(("malformed-timestamp", malformed, "ISO 8601"))

        naive = make_card()
        naive["supuestos"]["observables"][0]["verificado_en"] = "2026-01-15T12:00:00"
        cases.append(("naive-timestamp", naive, "zona horaria"))

        stale = make_card()
        stale["supuestos"]["observables"][0]["verificado_en"] = iso(NOW - timedelta(hours=25))
        cases.append(("stale", stale, "obsoleta"))

        future = make_card()
        future["supuestos"]["observables"][0]["verificado_en"] = iso(NOW + timedelta(seconds=1))
        cases.append(("future", future, "futuro"))

        missing_diagnostic = make_card()
        missing_diagnostic["supuestos"]["observables"].pop()
        cases.append(("missing-diagnostic", missing_diagnostic, "ausente"))

        for name, card, expected in cases:
            with self.subTest(case=name):
                reasons = puerta.motivos_rechazo_evidencia(card, ahora=NOW)
                self.assertTrue(reasons)
                self.assertIn(expected, "; ".join(reasons))

    def test_alert_still_requires_the_explicit_existing_override(self):
        diagnostics = dict(HEALTHY, nc_abs_z=3.5)
        card = make_card(puerta.evaluar(diagnostics))
        self.assertTrue(puerta.motivos_rechazo_evidencia(card, ahora=NOW))
        self.assertEqual(
            puerta.motivos_rechazo_evidencia(card, ahora=NOW, aceptar_alerta=True),
            [],
        )


class RegistryPromotionTests(unittest.TestCase):
    def test_current_positive_evidence_promotes_atomically(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            version = register(root, make_card())
            registro_local.promover(root, version, ahora=NOW)
            alias = registro_local.cargar_alias(root)
            self.assertEqual(alias["version"], version)
            self.assertEqual(alias["tarjeta"]["puerta"]["estado"], "pasa")

    def test_bad_current_evidence_never_creates_an_alias(self):
        cases = ("stale", "future", "malformed", "naive", "missing-diagnostic", "incoherent")
        for case in cases:
            with self.subTest(case=case), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                card = make_card()
                observable = card["supuestos"]["observables"][0]
                if case == "stale":
                    observable["verificado_en"] = iso(NOW - timedelta(hours=25))
                    expected = "obsoleta"
                elif case == "future":
                    observable["verificado_en"] = iso(NOW + timedelta(seconds=1))
                    expected = "futuro"
                elif case == "malformed":
                    observable["verificado_en"] = "no-es-una-fecha"
                    expected = "ISO 8601"
                elif case == "naive":
                    observable["verificado_en"] = "2026-01-15T12:00:00"
                    expected = "zona horaria"
                elif case == "missing-diagnostic":
                    card["supuestos"]["observables"].pop()
                    expected = "ausente"
                else:
                    observable["valor"] = 1.0
                    expected = "incoherente"

                version = register(root, card)
                with self.assertRaises(registro_local.PromocionRechazada) as caught:
                    registro_local.promover(root, version, ahora=NOW)
                self.assertIn(expected, str(caught.exception))
                self.assertFalse((root / "alias_champion.json").exists())

    def test_missing_unknown_and_mismatched_manifest_states_fail_closed(self):
        mutations = [
            ("missing", False, None, "falta el estado"),
            ("unknown", True, "desconocido", "desconocido"),
            ("null", True, None, "desconocido"),
            ("malformed", True, ["pasa"], "desconocido"),
            ("mismatch", True, "alerta", "manifiesto declara"),
        ]
        for name, present, state, expected in mutations:
            with self.subTest(case=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                version = register(root, make_card())
                path = root / version / "manifest.json"
                manifest = json.loads(path.read_text(encoding="utf-8"))
                if present:
                    manifest["puerta"] = state
                else:
                    del manifest["puerta"]
                path.write_text(json.dumps(manifest), encoding="utf-8")
                with self.assertRaises(registro_local.PromocionRechazada) as caught:
                    registro_local.promover(root, version, ahora=NOW)
                self.assertIn(expected, str(caught.exception))
                self.assertFalse((root / "alias_champion.json").exists())

    def test_invalid_card_is_rejected_even_if_its_hash_was_recomputed(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            card = make_card()
            version = register(root, card)
            del card["supuestos"]["observables"][0]["verificado_en"]
            card_path = root / version / "tarjeta.json"
            card_path.write_text(json.dumps(card), encoding="utf-8")
            manifest_path = root / version / "manifest.json"
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            manifest["archivos"]["tarjeta.json"] = hashlib.sha256(card_path.read_bytes()).hexdigest()
            manifest_path.write_text(json.dumps(manifest), encoding="utf-8")

            with self.assertRaisesRegex(registro_local.PromocionRechazada, "model card inválida"):
                registro_local.promover(root, version, ahora=NOW)
            self.assertFalse((root / "alias_champion.json").exists())


class FlowPromotionGuardTests(unittest.TestCase):
    def test_flow_does_not_call_registry_for_stale_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            card = make_card(timestamp=datetime(2000, 1, 1, tzinfo=timezone.utc))
            with mock.patch.object(flujo.registro_local, "promover") as promote:
                promoted, reason = flujo._intentar_promover(root, "v0001", card)
            self.assertFalse(promoted)
            self.assertIn("obsoleta", reason)
            promote.assert_not_called()

    def test_flow_promotes_fresh_complete_evidence(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            card = make_card(timestamp=datetime.now(timezone.utc))
            version = register(root, card)
            promoted, reason = flujo._intentar_promover(root, version, card)
            self.assertTrue(promoted, reason)
            self.assertEqual(registro_local.cargar_alias(root)["version"], version)


if __name__ == "__main__":
    unittest.main()
