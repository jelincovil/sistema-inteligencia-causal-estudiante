from __future__ import annotations

import hashlib
import json
import tempfile
import unittest
from pathlib import Path

from app.runtime import REQUIRED_ARTIFACTS, RuntimeBundle, load_runtime


MISSING = object()


def write_json(path: Path, value) -> None:
    path.write_text(json.dumps(value), encoding="utf-8")


def make_runtime(root: Path, gate_status, card_status="pasa") -> None:
    version = {"version": "v0001", "alias": "champion"}
    if gate_status is not MISSING:
        version["gate_status"] = gate_status
    card_gate = {}
    if card_status is not MISSING:
        card_gate["estado"] = card_status
    documents = {
        "support.json": {"features": {"x": [0.0, 1.0]}},
        "version.json": version,
        "model_card.json": {"puerta": card_gate},
        "feature_list.json": ["x"],
        "training_meta.json": {"method": "test-double"},
    }
    for name, value in documents.items():
        write_json(root / name, value)
    (root / "dml_estimator.joblib").write_bytes(b"test fixture; never deserialized")

    files = {
        name: hashlib.sha256((root / name).read_bytes()).hexdigest()
        for name in REQUIRED_ARTIFACTS
    }
    write_json(root / "manifest.json", {"files": files})


def read_manifest(root: Path) -> dict:
    return json.loads((root / "manifest.json").read_text(encoding="utf-8"))


class DMLRuntimeGateTests(unittest.TestCase):
    def test_only_explicit_pasa_can_be_served(self):
        rejected = [MISSING, None, "falla", "alerta", "desconocido", "PASA", "", 1, ["pasa"]]
        for state in rejected:
            with self.subTest(state=state), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                make_runtime(root, state)
                with self.assertRaisesRegex(ValueError, "explícitamente.*pasa"):
                    load_runtime(root)

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            make_runtime(root, "pasa")
            bundle = load_runtime(root)
            self.assertEqual(bundle.gate_status, "pasa")
            self.assertEqual(bundle.version, "v0001")


class DMLSupportTests(unittest.TestCase):
    def setUp(self):
        self.bundle = RuntimeBundle(
            version="v0001",
            alias="champion",
            gate_status="pasa",
            support={"x": (0.0, 1.0)},
            manifest={},
            card={},
        )

    def test_nonfinite_values_cannot_be_treated_as_inside_support(self):
        for value in (float("nan"), float("inf"), -float("inf")):
            with self.subTest(value=value):
                reasons = self.bundle.outside_support([[value]], ["x"])
                self.assertEqual(len(reasons), 1)
                self.assertIn("no es finito; soporte indeterminado", reasons[0])
                self.assertTrue(reasons[0].startswith("fila 0: x="))

    def test_undeclared_support_is_rejected_instead_of_using_infinite_bounds(self):
        reasons = self.bundle.outside_support([[0.5, -10.0]], ["x", "z"])
        self.assertEqual(reasons, ["fila 0: z: sin soporte registrado"])
        self.assertEqual(self.bundle.outside_support([[0.5]], ["x"]), [])


class DMLManifestTests(unittest.TestCase):
    def test_files_must_be_a_mapping(self):
        for files in (MISSING, None, [], "hashes", 0):
            with self.subTest(files=files), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                make_runtime(root, "pasa")
                manifest = read_manifest(root)
                if files is MISSING:
                    del manifest["files"]
                else:
                    manifest["files"] = files
                write_json(root / "manifest.json", manifest)
                with self.assertRaisesRegex(ValueError, "objeto 'files'"):
                    load_runtime(root)

    def test_every_required_artifact_needs_hash_coverage(self):
        for name in REQUIRED_ARTIFACTS:
            with self.subTest(artifact=name), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                make_runtime(root, "pasa")
                manifest = read_manifest(root)
                del manifest["files"][name]
                write_json(root / "manifest.json", manifest)
                with self.assertRaises(ValueError) as caught:
                    load_runtime(root)
                self.assertIn("cobertura hash", str(caught.exception))
                self.assertIn(name, str(caught.exception))

    def test_missing_or_changed_required_artifacts_are_rejected(self):
        for mutation in ("missing", "changed"):
            for name in REQUIRED_ARTIFACTS:
                with self.subTest(mutation=mutation, artifact=name), tempfile.TemporaryDirectory() as directory:
                    root = Path(directory)
                    make_runtime(root, "pasa")
                    if mutation == "missing":
                        (root / name).unlink()
                    else:
                        with (root / name).open("ab") as artifact:
                            artifact.write(b"changed without rehashing")
                    with self.assertRaises(ValueError) as caught:
                        load_runtime(root)
                    self.assertIn("Hash inválido o archivo ausente", str(caught.exception))
                    self.assertIn(name, str(caught.exception))

    def test_correctly_rehashed_contradictory_gate_states_are_rejected(self):
        for version_status, card_status in (("pasa", "falla"), ("falla", "pasa")):
            with self.subTest(version=version_status, card=card_status), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                make_runtime(root, version_status, card_status)
                with self.assertRaises(ValueError):
                    load_runtime(root)

        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            make_runtime(root, "pasa", "falla")
            with self.assertRaisesRegex(ValueError, "incoherentes"):
                load_runtime(root)

    def test_card_gate_must_be_present_and_explicitly_pass(self):
        rejected = [MISSING, None, "falla", "alerta", "desconocido", "PASA", "", 1, ["pasa"]]
        for state in rejected:
            with self.subTest(state=state), tempfile.TemporaryDirectory() as directory:
                root = Path(directory)
                make_runtime(root, "pasa", state)
                with self.assertRaisesRegex(ValueError, "incoherentes.*ambos deben ser 'pasa'"):
                    load_runtime(root)


if __name__ == "__main__":
    unittest.main()
