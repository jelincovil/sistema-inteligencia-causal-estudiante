from __future__ import annotations

import math
import unittest

import numpy as np

from causalops import diagnosticos
from causalops.monitor import REQUIRED_MONITOR_METRICS, decidir


def healthy_metrics():
    return {
        "frac_ps_extremo": 0.0,
        "ess_rel_min": 0.9,
        "smd_pond_max": 0.02,
        "nc_z": -0.2,
        "psi_max": 0.01,
        "z_efecto": -0.1,
    }


class CoreMonitorEvidenceTests(unittest.TestCase):
    def test_complete_valid_evidence_can_continue_with_signed_z_statistics(self):
        result = decidir(healthy_metrics())
        self.assertEqual(result["accion"], "continuar")
        self.assertEqual(result["motivo"], "sin señales")

    def test_each_missing_required_metric_abstains_with_actionable_reason(self):
        for name in REQUIRED_MONITOR_METRICS:
            with self.subTest(metric=name):
                metrics = healthy_metrics()
                del metrics[name]
                result = decidir(metrics)
                self.assertEqual(result["accion"], "abstenerse")
                self.assertIn(name, result["motivo"])
                self.assertIn("ausente", result["motivo"])

    def test_malformed_and_nonfinite_metrics_never_raise_or_continue(self):
        invalid_values = (None, True, "0", [], {}, float("nan"), float("inf"), -float("inf"))
        for name in REQUIRED_MONITOR_METRICS:
            for bad_value in invalid_values:
                with self.subTest(metric=name, value=bad_value):
                    metrics = healthy_metrics()
                    metrics[name] = bad_value
                    result = decidir(metrics)
                    self.assertEqual(result["accion"], "abstenerse")
                    self.assertIn(name, result["motivo"])
                    self.assertNotEqual(result["accion"], "continuar")

    def test_nonmapping_evidence_abstains_instead_of_raising(self):
        for metrics in (None, [], "healthy", 0):
            with self.subTest(metrics=metrics):
                result = decidir(metrics)
                self.assertEqual(result["accion"], "abstenerse")
                self.assertIn("no forman un objeto", result["motivo"])

    def test_finite_domain_violations_abstain_with_metric_specific_reason(self):
        cases = {
            "frac_ps_extremo": (-0.01, 1.01),
            "ess_rel_min": (-0.01, 1.01),
            "smd_pond_max": (-0.01,),
            "psi_max": (-0.01,),
        }
        for name, bad_values in cases.items():
            for bad_value in bad_values:
                with self.subTest(metric=name, value=bad_value):
                    metrics = healthy_metrics()
                    metrics[name] = bad_value
                    result = decidir(metrics)
                    self.assertEqual(result["accion"], "abstenerse")
                    self.assertIn(name, result["motivo"])
                    self.assertIn("dominio físico", result["motivo"])


class CoreDegeneratePsiTests(unittest.TestCase):
    def test_constant_reference_with_identical_window_is_exactly_zero(self):
        self.assertEqual(diagnosticos.psi_drift([3.0, 3.0], [3.0, 3.0, 3.0]), 0.0)

    def test_constant_reference_detects_complete_shift_in_either_direction(self):
        for shifted in (-2.0, 2.0):
            with self.subTest(shifted=shifted):
                value = diagnosticos.psi_drift([0.0, 0.0], [shifted, shifted])
                self.assertGreater(value, 0.0)
                self.assertTrue(math.isfinite(value))

        tiny_eps = np.nextafter(0.0, 1.0)
        tiny_value = diagnosticos.psi_drift([0.0, 0.0], [1.0, 1.0], eps=tiny_eps)
        self.assertGreater(tiny_value, 0.0)
        self.assertTrue(math.isfinite(tiny_value))

    def test_mixed_ties_are_deterministic_and_invalid_samples_are_rejected(self):
        ref = [0.0, 0.0, 0.0, 0.0]
        new = [-1.0, 0.0, 1.0, 0.0]
        first = diagnosticos.psi_drift(ref, new)
        self.assertEqual(first, diagnosticos.psi_drift(ref, new))
        self.assertGreater(first, 0.0)
        self.assertTrue(math.isfinite(first))

        for bad_ref, bad_new in (([], [1.0]), ([1.0], []), ([float("nan")], [1.0]), ([1.0], [float("inf")])):
            with self.subTest(ref=bad_ref, new=bad_new), self.assertRaises(ValueError):
                diagnosticos.psi_drift(bad_ref, bad_new)


if __name__ == "__main__":
    unittest.main()
