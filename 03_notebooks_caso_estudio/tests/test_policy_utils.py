"""Deterministic tests for A4 policy values and frozen-split protocols.

These tests deliberately avoid model fitting and empirical holdout evaluation.
The notebook checks are static JSON/AST checks, not notebook execution.
"""

from __future__ import annotations

import ast
import inspect
import json
import sys
from pathlib import Path

import numpy as np
import pytest

CASE_DIR = Path(__file__).resolve().parents[1]
if str(CASE_DIR) not in sys.path:
    sys.path.insert(0, str(CASE_DIR))

from lib import policy_utils as pu  # noqa: E402


Y = np.array([10.0, 20.0, 30.0, 40.0])
T = np.array([1, 0, 1, 0])
DECISION = np.array([1, 1, 0, 0])
E_CONSTANT = np.full(4, 0.5)
E_NONCONSTANT = np.array([0.5, 0.25, 0.75, 0.2])


@pytest.mark.parametrize(
    ("decision", "expected"),
    [
        (DECISION, 25.0),
        (np.ones(4, dtype=int), 20.0),
        (np.zeros(4, dtype=int), 30.0),
    ],
)
def test_target_policy_ipw_exact_horvitz_thompson_values(decision, expected):
    value = pu.target_policy_value_ipw(
        Y, T, decision, E_CONSTANT, clip=0.0
    )
    assert value == pytest.approx(expected)


def test_target_ipw_differs_from_alignment_average_and_factual_value():
    # Aligned contributions are 10 / 0.5 = 20 and 40 / (1 - 0.2) = 50.
    # HT divides their sum by n=4; the legacy diagnostic divides by 2 + 1.25.
    target = pu.target_policy_value_ipw(
        Y, T, DECISION, E_NONCONSTANT, clip=0.0
    )
    legacy = pu.alignment_weighted_outcome_mean(
        Y, T, DECISION, E_NONCONSTANT, clip=0.0
    )
    factual = pu.observed_policy_value(Y)

    assert target == pytest.approx(17.5)
    assert legacy == pytest.approx(70.0 / 3.25)
    assert factual == pytest.approx(25.0)
    assert target != pytest.approx(legacy)
    assert target != pytest.approx(factual)


def test_legacy_policy_value_wrapper_warns_and_preserves_numeric_result():
    expected = 70.0 / 3.25
    with pytest.warns(DeprecationWarning, match=r"not E\[Y\(pi\)\]"):
        actual = pu.policy_value_ipw(
            Y, T, DECISION, E_NONCONSTANT, clip=0.0
        )
    assert actual == pytest.approx(expected)


@pytest.mark.parametrize(
    "propensity",
    [
        np.array([0.0, 0.25, 0.75, 0.2]),
        np.array([0.5, 0.25, 1.0, 0.2]),
    ],
)
def test_target_ipw_rejects_no_overlap_even_with_clipping(propensity):
    with pytest.raises(ValueError, match="strictly between 0 and 1"):
        pu.target_policy_value_ipw(
            Y, T, DECISION, propensity, clip=0.49
        )


def test_target_ipw_rejects_zero_selected_mass():
    with pytest.raises(ValueError, match="zero selected mass"):
        pu.target_policy_value_ipw(
            Y,
            np.array([1, 1, 0, 0]),
            np.array([0, 0, 1, 1]),
            E_CONSTANT,
            clip=0.0,
        )


@pytest.mark.parametrize(
    ("field", "bad_value"),
    [
        ("y", np.array([10.0, np.nan, 30.0, 40.0])),
        ("t", np.array([1.0, 0.0, np.inf, 0.0])),
        ("decision", np.array([1.0, -np.inf, 0.0, 0.0])),
        ("propensity", np.array([0.5, np.nan, 0.75, 0.2])),
    ],
)
def test_target_ipw_rejects_nonfinite_inputs(field, bad_value):
    values = {"y": Y, "t": T, "decision": DECISION, "propensity": E_CONSTANT}
    values[field] = bad_value
    with pytest.raises(ValueError, match="finite"):
        pu.target_policy_value_ipw(**values, clip=0.0)


@pytest.mark.parametrize(
    ("field", "bad_value", "match"),
    [
        ("decision", np.ones((2, 2)), "one-dimensional"),
        ("propensity", np.full((4, 1), 0.5), "one-dimensional"),
        ("decision", np.array([1, 0]), "identical shapes"),
        ("propensity", np.array([0.5, 0.5]), "identical shapes"),
    ],
)
def test_target_ipw_rejects_invalid_shapes(field, bad_value, match):
    values = {"y": Y, "t": T, "decision": DECISION, "propensity": E_CONSTANT}
    values[field] = bad_value
    with pytest.raises(ValueError, match=match):
        pu.target_policy_value_ipw(**values, clip=0.0)


@pytest.mark.parametrize(
    ("field", "bad_value"),
    [
        ("t", np.array([1, 0, 2, 0])),
        ("decision", np.array([1, -1, 0, 0])),
    ],
)
def test_target_ipw_rejects_nonbinary_actions(field, bad_value):
    values = {"y": Y, "t": T, "decision": DECISION, "propensity": E_CONSTANT}
    values[field] = bad_value
    with pytest.raises(ValueError, match="binary 0/1"):
        pu.target_policy_value_ipw(**values, clip=0.0)


@pytest.mark.parametrize("clip", [-0.01, 0.5, 1.0, np.nan, np.inf])
def test_target_ipw_rejects_invalid_clip(clip):
    with pytest.raises(ValueError, match="clip"):
        pu.target_policy_value_ipw(Y, T, DECISION, E_CONSTANT, clip=clip)


def test_target_ipw_rejects_empty_vectors():
    with pytest.raises(ValueError, match="must not be empty"):
        pu.target_policy_value_ipw([], [], [], [], clip=0.0)


def test_frozen_policy_uses_validation_quantile_and_application_cannot_change_it():
    calibration_scores = np.array([0.0, 1.0, 2.0, 3.0, 4.0])
    policy = pu.build_frozen_policy(
        calibration_scores,
        calibration_role="validation",
        evaluation_role="test",
        budget_fraction=0.25,
        mode="topk",
    )

    expected = float(np.quantile(calibration_scores, 0.75))
    assert policy.threshold == pytest.approx(expected)
    assert policy.meta["fit_role"] == "train"
    assert policy.meta["calibration_role"] == "validation"
    assert policy.meta["evaluation_role"] == "test"
    assert policy.meta["policy_frozen"] is True

    policy.predict(scores=np.array([-1000.0, 1000.0]))
    policy.predict(scores=np.array([2.9, 3.0, 3.1]))
    assert policy.threshold == pytest.approx(expected)


@pytest.mark.parametrize(
    ("calibration_role", "evaluation_role"),
    [
        ("test", "test"),
        ("train", "test"),
        ("validation", "validation"),
        ("validation", "exploratory"),
        (None, "test"),
        ("validation", None),
    ],
)
def test_frozen_policy_rejects_ambiguous_roles(calibration_role, evaluation_role):
    with pytest.raises(ValueError, match="role"):
        pu.build_frozen_policy(
            [0.0, 1.0],
            calibration_role=calibration_role,
            evaluation_role=evaluation_role,
        )


def test_frozen_policy_requires_roles_and_valid_calibration_scores():
    with pytest.raises(TypeError):
        pu.build_frozen_policy([0.0, 1.0])

    for bad_scores in ([0.0, np.nan], [0.0, np.inf], [], [[0.0], [1.0]]):
        with pytest.raises(ValueError):
            pu.build_frozen_policy(
                bad_scores,
                calibration_role="validation",
                evaluation_role="test",
            )


def test_compare_policies_uses_exact_target_ipw_not_legacy_alignment_value():
    result = pu.compare_policies(
        {"toy": DECISION},
        y=Y,
        t=T,
        propensity=E_NONCONSTANT,
        evaluation_role="test",
    )

    assert result.loc[0, "target_value_ipw"] == pytest.approx(17.5)
    assert result.loc[0, "treat_rate"] == pytest.approx(0.5)
    assert result.loc[0, "evaluation_role"] == "test"
    assert "value_ipw" not in result.columns


@pytest.mark.parametrize(
    "ipw_inputs",
    [
        {"y": Y},
        {"t": T},
        {"propensity": E_CONSTANT},
        {"y": Y, "t": T},
        {"y": Y, "propensity": E_CONSTANT},
        {"t": T, "propensity": E_CONSTANT},
    ],
)
def test_compare_policies_rejects_partial_ipw_inputs(ipw_inputs):
    with pytest.raises(ValueError, match="supplied together"):
        pu.compare_policies(
            {"toy": DECISION}, evaluation_role="test", **ipw_inputs
        )


def test_compare_policies_requires_test_role_and_strict_decisions():
    with pytest.raises(TypeError):
        pu.compare_policies({"toy": DECISION})

    with pytest.raises(ValueError, match="evaluation_role"):
        pu.compare_policies({"toy": DECISION}, evaluation_role="validation")

    with pytest.raises(ValueError, match="one-dimensional"):
        pu.compare_policies(
            {"toy": np.ones((2, 2))}, evaluation_role="test"
        )

    with pytest.raises(ValueError, match="binary 0/1"):
        pu.compare_policies({"toy": [0, 1, 2]}, evaluation_role="test")


def test_model_fitting_helpers_reject_invalid_roles_before_data_or_fitting():
    missing_scenario = "scenario/that/does/not/exist"

    with pytest.raises(ValueError, match="calibration_role"):
        pu.fit_frozen_policy_calibration(
            missing_scenario,
            calibration_role="test",
            evaluation_role="test",
        )

    with pytest.raises(ValueError, match="method_selected"):
        pu.fit_frozen_policy_calibration(
            missing_scenario,
            method_selected="unknown",
            calibration_role="validation",
            evaluation_role="test",
        )

    with pytest.raises(ValueError, match="evaluation_role"):
        pu.load_or_compute_cate_scores(
            missing_scenario, evaluation_role="validation"
        )

    with pytest.raises(TypeError):
        pu.load_or_compute_cate_scores(missing_scenario)

    with pytest.raises(ValueError, match="calibration_role"):
        pu.export_a4_artifacts(
            missing_scenario,
            calibration_role="test",
            evaluation_role="test",
        )


def _rich_card_kwargs():
    return {
        "scenario_id": "toy",
        "scenario": "toy/scenario",
        "budget_fraction": 0.2,
        "method_name": "t_learner",
        "threshold": 1.25,
        "mode": "topk",
        "feature_names": ["x1", "x2"],
        "treat_rate_test": 0.2,
        "n_test": 5,
        "calibration_role": "validation",
        "evaluation_role": "test",
    }


def test_policy_cards_make_roles_and_holdout_limits_explicit():
    card = pu.build_rich_policy_card(**_rich_card_kwargs())
    assert "| **fit role** | `train`" in card
    assert "| **calibration role** | `validation`" in card
    assert "| **evaluation role** | `test`" in card
    assert "already inspected holdout remain exploratory/contaminated" in card
    assert "not inputs for choosing another method" in card

    minimal = pu.default_policy_card(
        scenario_id="toy",
        budget_fraction=0.2,
        method_name="t_learner",
        calibration_role="validation",
        evaluation_role="test",
    )
    assert "**fit_role**: `train`" in minimal
    assert "**calibration_role**: `validation`" in minimal
    assert "**evaluation_role**: `test`" in minimal


def test_policy_cards_refuse_missing_or_ambiguous_roles():
    kwargs = _rich_card_kwargs()
    kwargs["calibration_role"] = "test"
    with pytest.raises(ValueError, match="calibration_role"):
        pu.build_rich_policy_card(**kwargs)

    kwargs = _rich_card_kwargs()
    del kwargs["evaluation_role"]
    with pytest.raises(TypeError):
        pu.build_rich_policy_card(**kwargs)

    with pytest.raises(ValueError, match="evaluation_role"):
        pu.default_policy_card(
            scenario_id="toy",
            budget_fraction=0.2,
            method_name="t_learner",
            evaluation_role="validation",
        )


def _notebook_code_cells():
    path = CASE_DIR / "notebooks" / "A4_policy_uplift_ihdp.ipynb"
    with path.open(encoding="utf-8") as handle:
        notebook = json.load(handle)

    cells = []
    for index, cell in enumerate(notebook["cells"]):
        if cell["cell_type"] != "code":
            continue
        source = "".join(cell["source"])
        tree = ast.parse(source, filename=f"{path.name}:cell_{index}")
        cells.append((index, source, tree))
    return cells


def _calls(tree):
    return [node for node in ast.walk(tree) if isinstance(node, ast.Call)]


def _is_named_call(call, name):
    return isinstance(call.func, ast.Name) and call.func.id == name


def _is_method_call(call, receiver, method):
    return (
        isinstance(call.func, ast.Attribute)
        and call.func.attr == method
        and isinstance(call.func.value, ast.Name)
        and call.func.value.id == receiver
    )


def test_notebook_is_valid_json_python_without_legacy_calibration_calls():
    cells = _notebook_code_cells()
    assert cells
    combined = "\n".join(source for _, source, _ in cells)
    for stale in (
        "make_threshold_policy(",
        "outcome_only_policy(",
        "export_a4_artifacts(",
        "a3_scores_path",
        "tau_hat",
        "scores_df",
        "policy_value_ipw(",
    ):
        assert stale not in combined
    assert 'EVIDENCE_STATUS = "exploratory_contaminated_holdout"' in combined


def test_notebook_freezes_every_policy_before_single_test_evaluation():
    cells = _notebook_code_cells()
    frozen_calls = []
    test_scoring = []
    test_opening = []
    fit_calls = []
    risk_fits = []
    propensity_fits = []
    comparisons = []

    for cell_index, _, tree in cells:
        for call in _calls(tree):
            if _is_named_call(call, "build_frozen_policy"):
                frozen_calls.append((cell_index, call))
            if _is_method_call(call, "scorer", "predict") and any(
                isinstance(arg, ast.Name) and arg.id == "X_te"
                for arg in call.args
            ):
                test_scoring.append(cell_index)
            if _is_method_call(call, "bundle", "ytx") and any(
                isinstance(arg, ast.Name) and arg.id == "EVALUATION_ROLE"
                for arg in call.args
            ):
                test_opening.append(cell_index)
            if _is_named_call(call, "fit_frozen_policy_calibration"):
                fit_calls.append(cell_index)
            if _is_method_call(call, "risk_model", "fit"):
                risk_fits.append(cell_index)
            if _is_method_call(call, "prop_clf", "fit"):
                propensity_fits.append(cell_index)
            if _is_named_call(call, "compare_policies"):
                comparisons.append(cell_index)

    assert len(test_scoring) == 1
    assert test_opening == test_scoring
    assert len(fit_calls) == 1
    assert len(risk_fits) == 1
    assert len(propensity_fits) == 1
    assert len(comparisons) == 1

    evaluation_cell = test_scoring[0]
    assert frozen_calls
    assert max(index for index, _ in frozen_calls) < evaluation_cell
    assert max(fit_calls + risk_fits + propensity_fits) < evaluation_cell
    assert comparisons == [evaluation_cell]

    forbidden_test_names = {"tau_te", "y_risk_te", "Y_te", "T_te", "X_te"}
    for _, call in frozen_calls:
        assert call.args, "calibration scores must be explicit"
        score_names = {
            node.id for node in ast.walk(call.args[0]) if isinstance(node, ast.Name)
        }
        assert score_names.isdisjoint(forbidden_test_names)


def test_export_freezes_all_models_and_policies_before_opening_test():
    source = inspect.getsource(pu.export_a4_artifacts)
    test_open = source.index("y_te, t_te, X_te = bundle.ytx(evaluation_role)")

    before_test_markers = (
        "tau_cal, method, scorer = fit_frozen_policy_calibration(",
        "policy = build_frozen_policy(",
        "risk_policy = build_frozen_policy(",
        "risk_model.fit(",
        "prop.fit(",
    )
    for marker in before_test_markers:
        assert source.index(marker) < test_open

    assert source.index("tau_hat = scorer.predict(X_te)") > test_open
    assert source.index("e_te = prop.predict_proba(") > test_open
    assert source.index("cmp = compare_policies(") > test_open
    assert '"evidence_status": "unverified_holdout_history"' in source
