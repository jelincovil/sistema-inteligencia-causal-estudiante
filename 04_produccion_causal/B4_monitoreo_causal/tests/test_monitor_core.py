from __future__ import annotations

import math
import unittest
from unittest.mock import patch

import numpy as np
import pandas as pd

from monitor_core import (
    REQUIRED_METRICS,
    MonitorThresholds,
    _psi_drift,
    decide_action,
    ks_drift_report,
    psi_drift_report,
    simulate_monitor_table,
)


def healthy_metrics():
    return {
        "frac_ps_extremo": 0.0,
        "ess_rel_min": 0.9,
        "smd_pond_max": 0.02,
        "nc_abs_z": 0.1,
        "z_efecto": 0.0,
        "psi_max": 0.01,
        "ks_max": 0.01,
    }


class MissingEvidenceTests(unittest.TestCase):
    def test_complete_valid_evidence_can_continue(self):
        self.assertEqual(decide_action(healthy_metrics())["accion"], "continuar")

    def test_each_missing_metric_abstains_with_actionable_reason(self):
        for name in REQUIRED_METRICS:
            with self.subTest(metric=name):
                metrics = healthy_metrics()
                del metrics[name]
                result = decide_action(metrics)
                self.assertEqual(result["accion"], "abstenerse")
                self.assertIn(name, result["motivo"])
                self.assertIn("ausente", result["motivo"])

    def test_nonfinite_boolean_text_and_null_metrics_fail_closed(self):
        for name in REQUIRED_METRICS:
            for bad_value in (float("nan"), float("inf"), -float("inf"), True, "0", None):
                with self.subTest(metric=name, value=bad_value):
                    metrics = healthy_metrics()
                    metrics[name] = bad_value
                    result = decide_action(metrics)
                    self.assertEqual(result["accion"], "abstenerse")
                    self.assertIn(name, result["motivo"])
                    self.assertNotEqual(result["accion"], "continuar")

    def test_non_mapping_metrics_cannot_be_neutral(self):
        for metrics in (None, [], "healthy", 0):
            with self.subTest(metrics=metrics):
                result = decide_action(metrics)
                self.assertEqual(result["accion"], "abstenerse")
                self.assertIn("no forman un objeto", result["motivo"])


class MetricDomainTests(unittest.TestCase):
    def test_finite_but_physically_impossible_metrics_abstain(self):
        cases = {
            "frac_ps_extremo": (-0.01, 1.01),
            "ess_rel_min": (-0.01, 1.01),
            "ks_max": (-0.01, 1.01),
            "smd_pond_max": (-0.01,),
            "nc_abs_z": (-0.01,),
            "psi_max": (-0.01,),
        }
        for name, bad_values in cases.items():
            for bad_value in bad_values:
                with self.subTest(metric=name, value=bad_value):
                    metrics = healthy_metrics()
                    metrics[name] = bad_value
                    result = decide_action(metrics)
                    self.assertEqual(result["accion"], "abstenerse")
                    self.assertIn(name, result["motivo"])
                    self.assertIn("dominio físico", result["motivo"])

    def test_signed_effect_z_is_allowed_and_boundary_values_are_not_nan(self):
        metrics = healthy_metrics()
        metrics["z_efecto"] = -0.1
        result = decide_action(metrics)
        self.assertEqual(result["accion"], "continuar")
        self.assertTrue(all(math.isfinite(float(value)) for value in metrics.values()))


class DegeneratePsiTests(unittest.TestCase):
    def test_constant_reference_with_identical_window_is_exactly_zero(self):
        self.assertEqual(_psi_drift([2.0, 2.0, 2.0], [2.0, 2.0]), 0.0)

    def test_constant_reference_with_complete_shift_is_positive_in_both_directions(self):
        eps = 1e-6
        expected = 2.0 * (1.0 - eps) * math.log(1.0 / eps)
        for shifted in (-1.0, 1.0):
            with self.subTest(shifted=shifted):
                value = _psi_drift([0.0, 0.0, 0.0], [shifted, shifted])
                self.assertAlmostEqual(value, expected)
                self.assertGreater(value, 0.0)
                self.assertTrue(math.isfinite(value))

        tiny_eps = np.nextafter(0.0, 1.0)
        tiny_value = _psi_drift([0.0, 0.0], [1.0, 1.0], eps=tiny_eps)
        self.assertGreater(tiny_value, 0.0)
        self.assertTrue(math.isfinite(tiny_value))

    def test_mixed_ties_are_deterministic_finite_and_nonnegative(self):
        constant_ref = [0.0, 0.0, 0.0, 0.0]
        shifted_window = [-1.0, 0.0, 1.0, 0.0]
        first = _psi_drift(constant_ref, shifted_window)
        self.assertEqual(first, _psi_drift(constant_ref, shifted_window))
        self.assertGreater(first, 0.0)
        self.assertTrue(math.isfinite(first))

        tied = _psi_drift([0.0, 0.0, 1.0, 1.0], [-1.0, 0.0, 1.0, 2.0])
        self.assertGreaterEqual(tied, 0.0)
        self.assertTrue(math.isfinite(tied))

    def test_empty_nonfinite_samples_and_invalid_parameters_are_rejected(self):
        invalid_samples = (
            ([], [1.0]),
            ([1.0], []),
            ([float("nan")], [1.0]),
            ([1.0], [float("inf")]),
        )
        for ref, new in invalid_samples:
            with self.subTest(ref=ref, new=new), self.assertRaises(ValueError):
                _psi_drift(ref, new)
        for kwargs in ({"bins": 0}, {"bins": 2.5}, {"eps": 0.0}, {"eps": 1.0}, {"eps": float("nan")}):
            with self.subTest(parameters=kwargs), self.assertRaises(ValueError):
                _psi_drift([0.0, 1.0], [0.0, 1.0], **kwargs)


class DriftMetricSemanticsTests(unittest.TestCase):
    def test_ks_is_the_two_sample_ks_statistic(self):
        baseline = np.array([[0.0], [0.0], [1.0], [1.0]])
        window = np.array([[0.0], [1.0], [1.0], [1.0]])
        report = ks_drift_report(baseline, window, feature_idx=(0,))
        self.assertAlmostEqual(report["ks_max"], 0.25)

        identical = ks_drift_report(baseline, baseline, feature_idx=(0,))
        self.assertEqual(identical["ks_max"], 0.0)

        disjoint = ks_drift_report(baseline, baseline + 10.0, feature_idx=(0,))
        self.assertEqual(disjoint["ks_max"], 1.0)

    def test_psi_uses_proportions_not_the_ks_statistic(self):
        baseline = np.array([[0.0], [0.0], [1.0], [1.0]])
        window = np.array([[0.0], [1.0], [1.0], [1.0]])
        report = psi_drift_report(baseline, window, feature_idx=(0,), bins=2)
        expected = (0.25 - 0.50) * math.log(0.25 / 0.50) + (0.75 - 0.50) * math.log(0.75 / 0.50)
        self.assertAlmostEqual(report["psi_f0"], expected)
        self.assertAlmostEqual(report["psi_max"], expected)
        self.assertNotAlmostEqual(report["psi_max"], ks_drift_report(baseline, window, (0,))["ks_max"])

        identical = psi_drift_report(baseline, baseline, feature_idx=(0,), bins=2)
        self.assertAlmostEqual(identical["psi_max"], 0.0)

    def test_ks_and_psi_thresholds_are_independent(self):
        psi_only = healthy_metrics()
        psi_only.update(psi_max=0.20, ks_max=0.0)
        thresholds = MonitorThresholds(ks_alert=100.0)
        self.assertEqual(decide_action(psi_only, thresholds)["accion"], "alertar")

        ks_only = healthy_metrics()
        ks_only.update(psi_max=0.0, ks_max=0.20)
        thresholds = MonitorThresholds(psi_alert=100.0, psi_large=101.0, ks_alert=0.15)
        self.assertEqual(decide_action(ks_only, thresholds)["accion"], "alertar")
        self.assertEqual(thresholds.psi_alert, 100.0)
        self.assertEqual(thresholds.psi_large, 101.0)

    def test_ks_alert_does_not_create_a_large_psi_decision(self):
        metrics = healthy_metrics()
        metrics.update(z_efecto=4.0, psi_max=0.0, ks_max=1.0)
        result = decide_action(metrics, MonitorThresholds(ks_alert=0.15, psi_large=0.25))
        self.assertEqual(result["accion"], "revisar_identificacion")
        self.assertNotEqual(result["accion"], "reentrenar")

    @patch("monitor_core._simple_support_metrics", return_value=(0.0, 0.9, 0.02))
    @patch("monitor_core.load_baseline_train")
    def test_simulation_abstains_without_measured_negative_control(self, load_baseline, _support):
        baseline = pd.DataFrame({
            "x0": np.arange(8, dtype=float),
            "treatment": [0, 1] * 4,
            "outcome": np.arange(8, dtype=float),
        })
        load_baseline.return_value = (
            baseline[["x0"]], baseline["treatment"], baseline["outcome"],
        )

        table = simulate_monitor_table(
            n_windows=1,
            window_size=16,
            drift_start=0,
            drift_strength=100.0,
            effect_shift=0.0,
            seed=7,
        )

        self.assertEqual(len(table), 1)
        row = table.iloc[0]
        self.assertTrue(np.isfinite(row["ks_max"]))
        self.assertTrue(np.isfinite(row["psi_max"]))
        self.assertAlmostEqual(row["ks_max"], 1.0)
        self.assertGreater(row["psi_max"], row["ks_max"])
        self.assertTrue(pd.isna(row["nc_abs_z"]))
        self.assertEqual(row["accion"], "abstenerse")
        self.assertIn("nc_abs_z", row["motivo"])


if __name__ == "__main__":
    unittest.main()
