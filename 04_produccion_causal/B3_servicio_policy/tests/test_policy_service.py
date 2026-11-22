from __future__ import annotations

import unittest

import numpy as np

from policy_service import predict_rows
from runtime import PolicyBundle


class FakePolicy:
    feature_names = ["x", "z"]
    threshold = 0.5
    budget_fraction = 0.25

    def __init__(self):
        self.calls = 0

    def predict(self, *, X):
        self.calls += 1
        scores = np.asarray(X, dtype=float)[:, 0]
        return {
            "decision": (scores >= self.threshold).astype(int),
            "uplift_score": scores,
        }


def make_bundle(support=None):
    return PolicyBundle(
        version="v0001",
        alias="champion",
        gate_status="pasa",
        support=support if support is not None else {"x": (0.0, 1.0), "z": (-1.0, 1.0)},
        card={},
        manifest={},
    )


class PredictRowsSupportTests(unittest.TestCase):
    def setUp(self):
        self.policy = FakePolicy()
        self.bundle = make_bundle()

    def test_supported_batch_still_predicts_every_row(self):
        out = predict_rows(
            self.policy,
            [{"x": 0.25, "z": 0.0}, {"x": 0.75, "z": 0.5}],
            bundle=self.bundle,
        )
        self.assertFalse(out["abstiene"])
        self.assertEqual(out["decision"].tolist(), [0, 1])
        self.assertEqual(out["uplift_score"].tolist(), [0.25, 0.75])
        self.assertEqual(self.policy.calls, 1)

    def test_out_of_support_single_and_batch_both_abstain(self):
        single = predict_rows(self.policy, {"x": 2.0, "z": 0.0}, bundle=self.bundle)
        batch = predict_rows(self.policy, np.asarray([[0.25, 0.0], [2.0, 0.0]]), bundle=self.bundle)

        for out in (single, batch):
            self.assertTrue(out["abstiene"])
            self.assertIn("x=2 fuera de [0, 1]", out["motivo"])
            self.assertEqual(out["decision"].size, 0)
            self.assertEqual(out["uplift_score"].size, 0)
        self.assertIn("fila 1:", batch["motivo"])
        self.assertEqual(self.policy.calls, 0, "abstention must happen before policy prediction")

    def test_mixed_batch_abstains_instead_of_serving_only_valid_rows(self):
        out = predict_rows(
            self.policy,
            [
                {"x": 0.25, "z": 0.0},
                {"x": 0.50, "z": 3.0},
                {"x": 0.75, "z": 0.0},
            ],
            bundle=self.bundle,
        )
        self.assertTrue(out["abstiene"])
        self.assertIn("fila 1: z=3 fuera de [-1, 1]", out["motivo"])
        self.assertEqual(out["decision"].size, 0)
        self.assertEqual(self.policy.calls, 0)

    def test_each_batch_position_is_checked(self):
        rows = [[0.25, 0.0], [0.50, 0.0], [0.75, 0.0]]
        for bad_index in range(3):
            with self.subTest(bad_index=bad_index):
                policy = FakePolicy()
                candidate = np.asarray(rows, dtype=float)
                candidate[bad_index][0] = -5.0
                out = predict_rows(policy, candidate, bundle=self.bundle)
                self.assertTrue(out["abstiene"])
                self.assertIn(f"fila {bad_index}: x=-5", out["motivo"])
                self.assertEqual(policy.calls, 0)

    def test_missing_support_and_nonfinite_rows_fail_closed(self):
        incomplete = make_bundle(support={"x": (0.0, 1.0)})
        cases = [
            (incomplete, [{"x": 0.25, "z": 0.0}], "sin soporte registrado"),
            (self.bundle, [{"x": float("nan"), "z": 0.0}], "no es finito"),
            (self.bundle, np.asarray([[0.25, 0.0], [0.5, float("inf")]]), "fila 1: z=inf no es finito"),
        ]
        for bundle, rows, expected in cases:
            with self.subTest(expected=expected):
                policy = FakePolicy()
                out = predict_rows(policy, rows, bundle=bundle)
                self.assertTrue(out["abstiene"])
                self.assertIn(expected, out["motivo"])
                self.assertEqual(policy.calls, 0)


if __name__ == "__main__":
    unittest.main()
