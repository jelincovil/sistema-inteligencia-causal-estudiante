"""Policy learning utilities for Notebook A4 (threshold / top-k, welfare, equity).

Serializes policies for Serie B notebook B3 via joblib.
"""

from __future__ import annotations

import json
import warnings
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple, Union

import numpy as np
import pandas as pd
from joblib import dump, load

from .paths import RANDOM_STATE, ensure_dir

ArrayLike = Union[Sequence[float], np.ndarray, pd.Series]
MatrixLike = Union[pd.DataFrame, np.ndarray]


def _as_1d(a: ArrayLike) -> np.ndarray:
    return np.asarray(a, dtype=float).reshape(-1)


def _as_strict_1d(a: ArrayLike, name: str) -> np.ndarray:
    """Return a non-empty vector without silently flattening matrices."""
    arr = np.asarray(a, dtype=float)
    if arr.ndim != 1:
        raise ValueError(f"{name} must be one-dimensional; got shape {arr.shape}")
    if arr.size == 0:
        raise ValueError(f"{name} must not be empty")
    return arr


def _validate_protocol_roles(calibration_role: str, evaluation_role: str) -> None:
    """Enforce the course's train → validation → frozen test protocol."""
    if calibration_role != "validation":
        raise ValueError(
            "calibration_role must be 'validation'; thresholds and budgets "
            "must not be calibrated on train or test"
        )
    if evaluation_role != "test":
        raise ValueError(
            "evaluation_role must be 'test' and disjoint from validation "
            "calibration"
        )


@dataclass
class Policy:
    """Serializable treatment policy: decision from uplift scores.

    Parameters
    ----------
    mode:
        ``'threshold'`` — treat if score > threshold.
        ``'topk'`` — treat top ``budget_fraction`` by score (threshold set on calibration data).
    """

    mode: str = "threshold"
    threshold: float = 0.0
    budget_fraction: float = 0.2
    feature_names: Optional[List[str]] = None
    method_name: str = "cate"
    meta: Dict[str, Any] = field(default_factory=dict)
    # Optional embedded score function for full X → decision (set after fit)
    _score_model: Any = field(default=None, repr=False)

    def score(self, X: Optional[MatrixLike] = None, scores: Optional[ArrayLike] = None) -> np.ndarray:
        """Return uplift scores. Prefer precomputed ``scores``; else use ``_score_model``."""
        if scores is not None:
            return _as_1d(scores)
        if self._score_model is None:
            raise ValueError(
                "No scores provided and policy has no embedded score model"
            )
        X_arr = np.asarray(X, dtype=float)
        if X_arr.ndim == 1:
            X_arr = X_arr.reshape(-1, 1)
        if hasattr(self._score_model, "predict"):
            return _as_1d(self._score_model.predict(X_arr))
        return _as_1d(self._score_model(X_arr))

    def predict(
        self,
        X: Optional[MatrixLike] = None,
        scores: Optional[ArrayLike] = None,
    ) -> Dict[str, np.ndarray]:
        """Return ``{'decision': 0/1 array, 'uplift_score': float array}``."""
        s = self.score(X=X, scores=scores)
        if self.mode == "threshold":
            decision = (s > self.threshold).astype(int)
        elif self.mode == "topk":
            # Calibrated threshold from budget: treat if score >= quantile
            # When predicting on new data, use stored threshold set at fit time.
            decision = (s >= self.threshold).astype(int)
        else:
            raise ValueError(f"Unknown policy mode {self.mode!r}")
        return {"decision": decision, "uplift_score": s}

    def predict_decision(
        self,
        X: Optional[MatrixLike] = None,
        scores: Optional[ArrayLike] = None,
    ) -> np.ndarray:
        return self.predict(X=X, scores=scores)["decision"]


def threshold_from_budget(
    scores: ArrayLike,
    budget_fraction: float,
) -> float:
    """Threshold so that approximately ``budget_fraction`` units are treated.

    Treat units with score >= threshold. Uses the empirical quantile
    ``1 - budget_fraction``.
    """
    s = _as_1d(scores)
    b = float(budget_fraction)
    if not 0.0 < b <= 1.0:
        raise ValueError("budget_fraction must be in (0, 1]")
    if s.size == 0:
        raise ValueError("Empty scores")
    q = 1.0 - b
    return float(np.quantile(s, q))


def make_threshold_policy(
    scores: ArrayLike,
    *,
    budget_fraction: float = 0.2,
    mode: str = "topk",
    method_name: str = "cate",
    feature_names: Optional[Sequence[str]] = None,
    score_model: Any = None,
    meta: Optional[Dict[str, Any]] = None,
) -> Policy:
    """Build a policy calibrated to treat ~``budget_fraction`` of units."""
    thr = threshold_from_budget(scores, budget_fraction)
    pol = Policy(
        mode=mode if mode in ("threshold", "topk") else "topk",
        threshold=thr,
        budget_fraction=float(budget_fraction),
        feature_names=list(feature_names) if feature_names else None,
        method_name=method_name,
        meta=dict(meta or {}),
        _score_model=score_model,
    )
    return pol


def build_frozen_policy(
    calibration_scores: ArrayLike,
    *,
    calibration_role: str,
    evaluation_role: str,
    budget_fraction: float = 0.2,
    mode: str = "topk",
    method_name: str = "cate",
    feature_names: Optional[Sequence[str]] = None,
    score_model: Any = None,
    meta: Optional[Dict[str, Any]] = None,
) -> Policy:
    """Calibrate on validation and freeze a policy before test evaluation.

    The fitted score function belongs to the earlier ``train`` role. Only
    ``calibration_scores`` from ``validation`` may determine the threshold;
    test scores and outcomes are never used to choose it. Applying the returned
    object to test data changes no parameters and selects no winner.
    """
    _validate_protocol_roles(calibration_role, evaluation_role)
    cal_scores = _as_strict_1d(calibration_scores, "calibration_scores")
    if not np.isfinite(cal_scores).all():
        raise ValueError("calibration_scores must contain only finite values")
    policy_meta = dict(meta or {})
    policy_meta.update(
        {
            "fit_role": "train",
            "calibration_role": calibration_role,
            "evaluation_role": evaluation_role,
            "policy_frozen": True,
        }
    )
    return make_threshold_policy(
        cal_scores,
        budget_fraction=budget_fraction,
        mode=mode,
        method_name=method_name,
        feature_names=feature_names,
        score_model=score_model,
        meta=policy_meta,
    )


def apply_policy(
    scores: ArrayLike,
    policy: Policy,
) -> np.ndarray:
    """Binary decisions from scores under ``policy``."""
    return policy.predict(scores=scores)["decision"]


def policy_value_from_tau(
    decision: ArrayLike,
    tau: ArrayLike,
) -> float:
    """Oracle welfare under known ITEs: mean( decision * tau ).

    Assumes untreated baseline is absorbed so incremental value is τ for treated.
    """
    d = _as_1d(decision)
    t = _as_1d(tau)
    if d.shape != t.shape:
        raise ValueError("decision and tau length mismatch")
    return float(np.mean(d * t))


def observed_policy_value(y: ArrayLike) -> float:
    """Mean factual outcome under the observed behavior policy, ``mean(Y)``.

    This is not the value of a proposed target policy and does not use a
    candidate decision vector.
    """
    y_a = _as_strict_1d(y, "y")
    if not np.isfinite(y_a).all():
        raise ValueError("y must contain only finite values")
    return float(np.mean(y_a))


def _validated_policy_arrays(
    y: ArrayLike,
    t: ArrayLike,
    decision: ArrayLike,
    propensity: ArrayLike,
) -> Tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    y_a = _as_strict_1d(y, "y")
    t_a = _as_strict_1d(t, "t")
    d = _as_strict_1d(decision, "decision")
    e = _as_strict_1d(propensity, "propensity")
    if not (y_a.shape == t_a.shape == d.shape == e.shape):
        raise ValueError(
            "y, t, decision, and propensity must have identical shapes; "
            f"got {y_a.shape}, {t_a.shape}, {d.shape}, {e.shape}"
        )
    for name, arr in (("y", y_a), ("t", t_a), ("decision", d), ("propensity", e)):
        if not np.isfinite(arr).all():
            raise ValueError(f"{name} must contain only finite values")
    if not np.isin(t_a, (0.0, 1.0)).all():
        raise ValueError("t must contain only binary 0/1 actions")
    if not np.isin(d, (0.0, 1.0)).all():
        raise ValueError("decision must contain only binary 0/1 actions")
    if not ((e > 0.0) & (e < 1.0)).all():
        raise ValueError(
            "propensity must lie strictly between 0 and 1; exact 0/1 "
            "propensities violate overlap and are not repaired by clipping"
        )
    return y_a, t_a, d, e


def _validated_clip(clip: float) -> float:
    c = float(clip)
    if not np.isfinite(c) or not 0.0 <= c < 0.5:
        raise ValueError("clip must be finite and in [0, 0.5)")
    return c


def target_policy_value_ipw(
    y: ArrayLike,
    t: ArrayLike,
    decision: ArrayLike,
    propensity: ArrayLike,
    *,
    clip: float = 0.01,
) -> float:
    r"""Horvitz–Thompson IPW estimate of the deterministic target policy value.

    For :math:`d_i = \pi(X_i) \in \{0,1\}` and behavior propensity
    :math:`e_i = P(T_i=1\mid X_i)`, the estimand is
    :math:`V(\pi) = E[Y(\pi(X))]`. The implemented estimator is

    .. math::

        \hat V_{IPW}(\pi) = \frac{1}{n} \sum_{i=1}^{n}
        \frac{1\{T_i=d_i\}Y_i}
        {e_i\text{ if }d_i=1\text{, otherwise }1-e_i}.

    The denominator is the full sample size ``n``, not the sum of alignment
    weights. Positivity, consistency, SUTVA, and unconfoundedness are required
    for the causal interpretation. ``clip`` regularizes non-extreme propensity
    estimates; with a positive value, the estimator is no longer exact HT and
    can be biased even when the stated causal assumptions hold. Exact 0/1
    propensities are rejected before clipping. Zero selected
    mass (no unit with ``T == decision``) is an estimation failure, not NaN.
    """
    y_a, t_a, d, e = _validated_policy_arrays(y, t, decision, propensity)
    c = _validated_clip(clip)
    e_used = np.clip(e, c, 1.0 - c)
    selected = t_a == d
    if not selected.any():
        raise ValueError(
            "zero selected mass: no observed treatment equals the target "
            "policy decision, so the IPW policy value is not estimable"
        )
    action_prob = np.where(d == 1.0, e_used, 1.0 - e_used)
    weights = selected.astype(float) / action_prob
    if not np.isfinite(weights).all():
        raise ValueError("non-finite IPW weight; check overlap and clipping")
    return float(np.sum(weights * y_a) / y_a.size)


def alignment_weighted_outcome_mean(
    y: ArrayLike,
    t: ArrayLike,
    decision: ArrayLike,
    propensity: ArrayLike,
    *,
    clip: float = 0.01,
) -> float:
    r"""Legacy alignment diagnostic; not a target or observed policy value.

    This inverse-propensity weighted average is normalized only over units
    with ``T == decision``. It answers a different, conditioning-on-alignment
    question and must not be represented as :math:`E[Y(\pi)]`.
    """
    y_a, t_a, d, e = _validated_policy_arrays(y, t, decision, propensity)
    c = _validated_clip(clip)
    e_used = np.clip(e, c, 1.0 - c)
    w = np.where(t_a == 1.0, 1.0 / e_used, 1.0 / (1.0 - e_used))
    align = (d == t_a).astype(float)
    if align.sum() == 0:
        return float("nan")
    return float(np.sum(align * w * y_a) / np.sum(align * w))


def policy_value_ipw(
    y: ArrayLike,
    t: ArrayLike,
    decision: ArrayLike,
    propensity: ArrayLike,
    *,
    clip: float = 0.01,
) -> float:
    r"""Deprecated compatibility wrapper for the legacy alignment average.

    The historical name misleadingly suggested a target-policy value. For
    valid inputs its numeric result is intentionally unchanged; stricter
    overlap/shape guards now reject invalid inputs. New code must use
    :func:`target_policy_value_ipw` for :math:`E[Y(\pi)]` or
    :func:`alignment_weighted_outcome_mean` for the legacy diagnostic.
    """
    warnings.warn(
        "policy_value_ipw is deprecated and returns an alignment-weighted "
        "outcome mean, not E[Y(pi)]. Use target_policy_value_ipw for target "
        "policy value or alignment_weighted_outcome_mean for this diagnostic.",
        DeprecationWarning,
        stacklevel=2,
    )
    return alignment_weighted_outcome_mean(
        y, t, decision, propensity, clip=clip
    )


def random_policy(
    n: int,
    budget_fraction: float,
    *,
    random_state: int = RANDOM_STATE,
) -> np.ndarray:
    """Baseline: treat a random ``budget_fraction`` of units."""
    rng = np.random.RandomState(random_state)
    k = int(round(budget_fraction * n))
    decision = np.zeros(n, dtype=int)
    if k <= 0:
        return decision
    idx = rng.choice(n, size=min(k, n), replace=False)
    decision[idx] = 1
    return decision


def outcome_only_policy(
    y_pred_risk: ArrayLike,
    budget_fraction: float,
    *,
    treat_highest_risk: bool = True,
) -> np.ndarray:
    """Baseline: treat top/bottom by predicted outcome (non-causal risk).

    If ``treat_highest_risk`` is True, treat highest predicted Y (or risk);
    otherwise treat lowest predicted outcome.
    """
    s = _as_1d(y_pred_risk)
    n = s.size
    k = int(round(budget_fraction * n))
    decision = np.zeros(n, dtype=int)
    if k <= 0:
        return decision
    order = np.argsort(-s if treat_highest_risk else s, kind="mergesort")
    decision[order[:k]] = 1
    return decision


def compare_policies(
    policies: Dict[str, ArrayLike],
    tau: Optional[ArrayLike] = None,
    *,
    y: Optional[ArrayLike] = None,
    t: Optional[ArrayLike] = None,
    propensity: Optional[ArrayLike] = None,
    evaluation_role: str,
) -> pd.DataFrame:
    """Compare already-frozen policies on the declared test split.

    ``target_value_ipw`` estimates :math:`E[Y(\\pi)]` by Horvitz–Thompson IPW.
    ``value_tau`` remains an oracle quantity. ``evaluation_role='test'`` is
    mandatory for every comparison, including descriptive treatment rates, so
    validation/calibration results cannot be mislabeled as untouched holdout
    evaluation. Partial IPW inputs are rejected rather than silently omitting
    policy evaluation. This function never calibrates or selects a policy.
    """
    _validate_protocol_roles("validation", evaluation_role)
    ipw_inputs = (y, t, propensity)
    any_ipw = any(value is not None for value in ipw_inputs)
    all_ipw = all(value is not None for value in ipw_inputs)
    if any_ipw and not all_ipw:
        raise ValueError("y, t, and propensity must be supplied together")
    rows = []
    for name, dec in policies.items():
        d = _as_strict_1d(dec, f"decision for policy {name!r}")
        if not np.isfinite(d).all() or not np.isin(d, (0.0, 1.0)).all():
            raise ValueError(
                f"decision for policy {name!r} must contain only finite binary 0/1 actions"
            )
        row: Dict[str, Any] = {
            "policy": name,
            "treat_rate": float(np.mean(d)),
            "n_treated": int(d.sum()),
            "n": int(d.size),
            "evaluation_role": evaluation_role,
        }
        if tau is not None:
            row["value_tau"] = policy_value_from_tau(d, tau)
        if all_ipw:
            row["target_value_ipw"] = target_policy_value_ipw(
                y, t, d, propensity
            )
        rows.append(row)
    return pd.DataFrame(rows)


def equity_table(
    decision: ArrayLike,
    group: ArrayLike,
    *,
    group_name: str = "group",
) -> pd.DataFrame:
    """Simple equity audit: treatment rate by group."""
    d = _as_1d(decision).astype(int)
    g = np.asarray(group)
    if d.shape[0] != g.shape[0]:
        raise ValueError("decision and group length mismatch")
    df = pd.DataFrame({"decision": d, group_name: g})
    out = (
        df.groupby(group_name, dropna=False)
        .agg(
            n=(group_name, "size"),
            n_treated=("decision", "sum"),
            treat_rate=("decision", "mean"),
        )
        .reset_index()
    )
    return out


def equity_table_multi(
    decision: ArrayLike,
    frame: pd.DataFrame,
    group_cols: Sequence[str],
) -> Dict[str, pd.DataFrame]:
    """Equity tables for several group columns."""
    return {
        col: equity_table(decision, frame[col].to_numpy(), group_name=col)
        for col in group_cols
        if col in frame.columns
    }


def save_policy(
    policy: Policy,
    path: Union[str, Path],
    *,
    policy_card: Optional[str] = None,
) -> Path:
    """Serialize policy for B3. Optionally write ``policy_card.md`` beside it."""
    path = Path(path)
    ensure_dir(path.parent)
    dump(policy, path)
    if policy_card is not None:
        card_path = path.parent / "policy_card.md"
        card_path.write_text(policy_card, encoding="utf-8")
    return path


def load_policy(path: Union[str, Path]) -> Policy:
    """Load a policy joblib artifact.

    Accepts absolute paths, cwd-relative paths, or monorepo-relative paths
    as produced by :func:`export_a4_artifacts` / ``export_meta.json``.
    """
    from .paths import resolve_repo_path

    resolved = resolve_repo_path(path)
    obj = load(resolved)
    if not isinstance(obj, Policy):
        # Allow raw dict-like wrappers in future
        return obj
    return obj


@dataclass
class EmbeddedTLearnerScorer:
    """Picklable uplift scorer: τ̂(x) = μ̂₁(x) − μ̂₀(x).

    Nested closures inside :class:`lib.cate_utils.CATEModel` do not pickle
    with standard joblib; this dataclass holds the two fitted regressors.
    """

    model_1: Any
    model_0: Any
    name: str = "t_learner"
    feature_names: Optional[List[str]] = None

    def predict(self, X: MatrixLike) -> np.ndarray:
        X_arr = np.asarray(X, dtype=float)
        if X_arr.ndim == 1:
            X_arr = X_arr.reshape(-1, 1)
        return _as_1d(self.model_1.predict(X_arr) - self.model_0.predict(X_arr))


def scorer_from_t_learner(cate_model: Any) -> EmbeddedTLearnerScorer:
    """Build a picklable scorer from a fitted T-learner :class:`CATEModel`."""
    extra = getattr(cate_model, "extra", None) or {}
    m1 = extra.get("model_1")
    m0 = extra.get("model_0")
    if m1 is None or m0 is None:
        raise ValueError(
            "CATEModel must expose extra['model_1'] and extra['model_0'] "
            "(T-learner). Got keys: "
            f"{list(extra.keys())}"
        )
    return EmbeddedTLearnerScorer(
        model_1=m1,
        model_0=m0,
        name=str(getattr(cate_model, "name", "t_learner")),
    )


def resolve_cate_scores_column(
    scores_df: pd.DataFrame,
    method_selected: Optional[str] = None,
) -> Tuple[str, np.ndarray, str]:
    """Pick the CATE column from an A3 scores table.

    Returns
    -------
    (column_name, scores_array, method_name)
    """
    if scores_df is None or scores_df.empty:
        raise ValueError("Empty CATE scores frame")
    method = method_selected
    if method is None and "method_selected" in scores_df.columns:
        method = str(scores_df["method_selected"].iloc[0])
    method = method or "t_learner"
    col = f"tau_hat_{method}"
    if col not in scores_df.columns:
        # fuzzy: method substring match
        tau_cols = [c for c in scores_df.columns if str(c).startswith("tau_hat_")]
        preferred = [c for c in tau_cols if "t_learner" in c]
        if preferred:
            col = preferred[0]
            method = col.replace("tau_hat_", "", 1)
        elif tau_cols:
            col = tau_cols[0]
            method = col.replace("tau_hat_", "", 1)
        else:
            raise KeyError(
                f"No tau_hat_* column in scores; columns={list(scores_df.columns)}"
            )
    return col, _as_1d(scores_df[col]), method


def load_or_compute_cate_scores(
    scenario: str = "real/ihdp",
    *,
    evaluation_role: str,
    a3_scores_path: Optional[Union[str, Path]] = None,
    method_selected: str = "t_learner",
    random_state: int = RANDOM_STATE,
) -> Tuple[pd.DataFrame, np.ndarray, str, Any]:
    """Load or compute test-only scores for exploratory evaluation.

    ``evaluation_role='test'`` must be explicit. The returned scores are marked
    ``score_role='test'`` and cannot calibrate a frozen policy: this function
    provides no matching validation scores from the same scorer. Use
    :func:`fit_frozen_policy_calibration` followed by
    :func:`build_frozen_policy` for the rigorous train/validation/test protocol.

    Returns
    -------
    scores_df, tau_hat_test, method_name, score_model (picklable or None)
    """
    _validate_protocol_roles("validation", evaluation_role)

    from .cate_utils import fit_t_learner
    from .data_io import load_scenario
    from .paths import artifacts_dir

    bundle = load_scenario(scenario)
    y_tr, t_tr, X_tr = bundle.ytx("train")
    _, _, X_te = bundle.ytx("test")

    # Always fit a picklable T-learner scorer for B3 (X → decision).
    t_model = fit_t_learner(y_tr, t_tr, X_tr, random_state=random_state)
    scorer = scorer_from_t_learner(t_model)

    path = Path(a3_scores_path) if a3_scores_path is not None else (
        artifacts_dir("A3") / "cate_scores_test.csv"
    )
    if path.is_file():
        scores_df = pd.read_csv(path)
        # Align to test by row_id when possible
        if "row_id" in scores_df.columns and "row_id" in bundle.test.columns:
            merged = bundle.test[["row_id"]].merge(
                scores_df, on="row_id", how="left", validate="one_to_one"
            )
            if merged.filter(like="tau_hat_").isna().any().any():
                # fallback: assume same order / length
                if len(scores_df) == len(bundle.test):
                    scores_df = scores_df.reset_index(drop=True)
                else:
                    raise ValueError(
                        f"A3 scores row_id misaligned with test "
                        f"(scores n={len(scores_df)}, test n={len(bundle.test)})"
                    )
            else:
                scores_df = merged
        col, tau_hat, method = resolve_cate_scores_column(
            scores_df, method_selected=method_selected
        )
        # If selected method is t_learner, prefer embedded scorer predictions
        # only for interface; ranking uses A3 scores for continuity with A3.
        _ = col  # documented for audit
        scores_df = scores_df.copy()
        scores_df["score_role"] = evaluation_role
        return scores_df, tau_hat, method, scorer

    # No A3 artifact: score test with freshly fit T-learner
    tau_hat = scorer.predict(X_te)
    row_ids = (
        bundle.test["row_id"].to_numpy()
        if "row_id" in bundle.test.columns
        else np.arange(len(bundle.test))
    )
    scores_df = pd.DataFrame(
        {
            "row_id": row_ids,
            f"tau_hat_{method_selected}": tau_hat,
            "method_selected": method_selected,
            "score_role": evaluation_role,
        }
    )
    return scores_df, tau_hat, method_selected, scorer


def fit_frozen_policy_calibration(
    scenario: str = "real/ihdp",
    *,
    method_selected: str = "t_learner",
    calibration_role: str = "validation",
    evaluation_role: str = "test",
    random_state: int = RANDOM_STATE,
) -> Tuple[np.ndarray, str, Any]:
    """Fit on train and return only validation scores plus the scorer.

    Returns ``(calibration_scores, method, scorer)``. Test features are
    deliberately not scored here: callers first pass the calibration scores to
    :func:`build_frozen_policy`, then apply the frozen scorer and threshold to
    test. Test results cannot calibrate thresholds, budgets, methods, or winners.

    A3's test-only score CSV cannot provide matching validation scores from an
    identical fitted scorer. This strict path therefore fits the course's fixed
    T-learner on train and does not reuse that artifact. Other methods are
    rejected rather than silently pairing one method's test scores with another
    method's calibration scores.
    """
    _validate_protocol_roles(calibration_role, evaluation_role)
    if method_selected != "t_learner":
        raise ValueError(
            "fit_frozen_policy_calibration requires "
            "method_selected='t_learner' so calibration and test use the "
            "same frozen scorer"
        )

    from .cate_utils import fit_t_learner
    from .data_io import load_scenario

    bundle = load_scenario(scenario)
    y_tr, t_tr, X_tr = bundle.ytx("train")
    _, _, X_cal = bundle.ytx(calibration_role)
    t_model = fit_t_learner(y_tr, t_tr, X_tr, random_state=random_state)
    scorer = scorer_from_t_learner(t_model)
    calibration_scores = scorer.predict(X_cal)
    return calibration_scores, method_selected, scorer


def build_rich_policy_card(
    *,
    scenario_id: str,
    scenario: str,
    budget_fraction: float,
    method_name: str,
    threshold: float,
    mode: str,
    feature_names: Sequence[str],
    treat_rate_test: float,
    n_test: int,
    calibration_role: str,
    evaluation_role: str,
    equity_group: str = "bw_tercile",
    random_state: int = RANDOM_STATE,
) -> str:
    """Human-auditable policy card for A4 → B3 (scope, risks, non-claims)."""
    _validate_protocol_roles(calibration_role, evaluation_role)
    feats = ", ".join(f"`{f}`" for f in feature_names)
    # Raw f-string: markdown may contain LaTeX-like \( ... \) sequences.
    return rf"""# Policy card — Serie A4 (policy / uplift targeting)

## Scope

| Campo | Valor |
|-------|--------|
| **scenario** | `{scenario}` |
| **scenario_id** | `{scenario_id}` |
| **fit role** | `train` (score and nuisance models) |
| **calibration role** | `{calibration_role}` (threshold/budget only) |
| **evaluation role** | `{evaluation_role}` (frozen policy; no reselection) |
| **population** | Official **{evaluation_role}** split of the IHDP-style scenario (n={n_test}) |
| **outcome (Y)** | `outcome` (cognitive / development score scale of the benchmark) |
| **treatment (T)** | `treatment` (binary program assignment in the SEM) |
| **features (X)** | {feats} |
| **scoring method** | `{method_name}` (fixed course T-learner fitted on train; validation and test use the same scorer) |
| **policy mode** | `{mode}` (treat if score ≥ threshold calibrated to budget) |
| **budget_fraction (B)** | {budget_fraction:.2f} ({100 * budget_fraction:.0f}% of units) |
| **threshold (λ)** | {threshold:.6f} |
| **observed treat rate under π (test)** | {treat_rate_test:.4f} |
| **random_state** | {random_state} |

## Decision rule

1. Compute uplift score \(s(x) = \\hat\\tau(x)\) with the scoring method above.
2. Using only `{calibration_role}` scores, calibrate threshold \(λ\) at empirical quantile \(1-B\); freeze it before opening `{evaluation_role}` outcomes.
3. Apply the frozen decision \(π(x) = 1\\{{ s(x) ≥ λ \\}}\) to `{evaluation_role}` once; do not select another policy from its results.

## Interface (Serie B / B3)

```python
from joblib import load
policy = load("artifacts/A4/policy.joblib")
out = policy.predict(X=X_new)           # needs embedded score model
# or: out = policy.predict(scores=s)    # precomputed uplift scores
# out["decision"]      -> {{0,1}} array
# out["uplift_score"]  -> float array
```

## Assumptions (identification / policy)

- **Unconfoundedness / ignorability** given the listed covariates (true *by design* of the synthetic SEM; **not** proven for real clinical IHDP).
- **SUTVA** (no interference; stable treatment version).
- **Overlap** sufficient for the CATE model used to score units.
- Budget constraint is a **hard capacity** stylized as top-B% targeting (myopic; not full offline policy optimization with costs).
- Welfare comparisons that use `tau` are **oracle evaluations** for teaching only.

## Risks and limitations

- Data are **synthetic with Hill-style variable names** — not clinical or administrative records.
- CATE scores inherit model bias; ranking quality ≠ identification of τ(x).
- Equity tables (e.g. treat rate by `{equity_group}`) are **descriptive**, not a fairness proof or legal compliance check.
- Threshold calibrated on the validation split is noisy; a new deployment threshold requires a new calibration protocol, never tuning on the reported test set.
- Embedded scorer is the **T-learner RF** fitted on train. A3 test-only score files are not used for calibration because they cannot provide matching validation scores from this frozen scorer.
- Test metrics are one-time evaluations within the frozen run, not inputs for choosing another method, threshold, budget, or winner.
- Code can enforce split roles but cannot verify that test was never inspected historically. Results on an already inspected holdout remain exploratory/contaminated, not confirmatory evidence; prospective confirmation requires a new uninspected holdout.

## Non-claims (explicit)

- This artifact does **not** claim clinical validity, regulatory approval, or external validity to real infants/programs.
- Beating a random baseline on oracle welfare does **not** justify deployment.
- Equity analysis does **not** certify absence of disparate impact.
- The policy is a **teaching handoff** for B3 (servicio local), not a clinical or regulatory decision system.

## Artifacts in this folder

- `policy.joblib` — serialized :class:`Policy`
- `policy_card.md` — this document
- `uplift_curve.png` — Qini / uplift ranking figure
- `equity_table.csv` — treat rates by group
"""


def default_policy_card(
    *,
    scenario_id: str,
    budget_fraction: float,
    method_name: str,
    population: str = "test split of IHDP-style scenario",
    assumptions: str = "unconfoundedness given covariates; SUTVA; score is CATE",
    limits: str = "Synthetic data; equity tables are descriptive only",
    calibration_role: str = "validation",
    evaluation_role: str = "test",
) -> str:
    """Minimal model/policy card markdown for A4 → B3 handoff."""
    _validate_protocol_roles(calibration_role, evaluation_role)
    return f"""# Policy card — Serie A4

- **scenario_id**: `{scenario_id}`
- **fit_role**: `train`
- **calibration_role**: `{calibration_role}` (threshold/budget only)
- **evaluation_role**: `{evaluation_role}` (frozen; no reselection)
- **population**: {population}
- **budget_fraction**: {budget_fraction}
- **scoring method**: {method_name}
- **assumptions**: {assumptions}
- **limits**: {limits}
- **interface**: `policy.predict(X=..., scores=...) -> {{decision, uplift_score}}`
- **non-claims**: not clinical; not a fairness certification; teaching artifact for B3
"""


def export_a4_artifacts(
    scenario: str = "real/ihdp",
    out_dir: Optional[Union[str, Path]] = None,
    *,
    budget_fraction: float = 0.20,
    method_selected: str = "t_learner",
    a3_scores_path: Optional[Union[str, Path]] = None,
    random_state: int = RANDOM_STATE,
    equity_col: str = "bw",
    n_terciles: int = 3,
    save_plot: bool = True,
    calibration_role: str = "validation",
    evaluation_role: str = "test",
) -> Dict[str, Any]:
    """Freeze on validation, evaluate once on test, and write A4 artifacts.

    Models use ``train``; all CATE and outcome-only thresholds use only
    ``validation`` scores. The returned/exported test metrics describe already
    frozen policies and must not feed another selection round. Test-only A3
    score files are not role-sufficient for this protocol.

    Writes under ``artifacts/A4/`` (by default)::

        policy.joblib
        policy_card.md
        uplift_curve.png
        equity_table.csv

    ``a3_scores_path`` remains for call-site compatibility but is not used by
    the strict protocol; passing it emits a warning rather than silently
    combining mismatched calibration and evaluation scores.
    """
    _validate_protocol_roles(calibration_role, evaluation_role)
    if a3_scores_path is not None:
        warnings.warn(
            "a3_scores_path is ignored by export_a4_artifacts: test-only "
            "scores cannot calibrate a frozen validation/test protocol. "
            "The fixed T-learner is fitted on train instead.",
            UserWarning,
            stacklevel=2,
        )

    from sklearn.ensemble import RandomForestRegressor
    from sklearn.linear_model import LogisticRegression

    from .data_io import load_scenario
    from .metrics import qini_auc, qini_curve, uplift_curve
    from .paths import SCENARIO_IDS, artifacts_dir, ensure_dir, relative_to_repo

    bundle = load_scenario(scenario)
    y_tr, t_tr, X_tr = bundle.ytx("train")
    _, _, X_cal = bundle.ytx(calibration_role)
    feature_names = list(X_cal.columns)
    scenario_id = str(
        bundle.scenario_id
        or SCENARIO_IDS.get(scenario)
        or scenario.replace("/", "_")
    )

    tau_cal, method, scorer = fit_frozen_policy_calibration(
        scenario,
        method_selected=method_selected,
        calibration_role=calibration_role,
        evaluation_role=evaluation_role,
        random_state=random_state,
    )

    policy = build_frozen_policy(
        tau_cal,
        calibration_role=calibration_role,
        evaluation_role=evaluation_role,
        budget_fraction=budget_fraction,
        mode="topk",
        method_name=method,
        feature_names=feature_names,
        score_model=scorer,
        meta={
            "scenario": scenario,
            "scenario_id": scenario_id,
            "budget_fraction": float(budget_fraction),
            "method_selected": method,
            "random_state": int(random_state),
            "n_features": len(feature_names),
            "interface": "predict(X|scores) -> {decision, uplift_score}",
        },
    )
    # Outcome-only baseline: train fit, validation threshold, frozen test use.
    risk_model = RandomForestRegressor(
        n_estimators=100,
        min_samples_leaf=5,
        random_state=random_state,
        n_jobs=-1,
    )
    risk_model.fit(np.asarray(X_tr, dtype=float), np.asarray(y_tr, dtype=float))
    y_risk_cal = risk_model.predict(np.asarray(X_cal, dtype=float))
    risk_policy = build_frozen_policy(
        -y_risk_cal,
        calibration_role=calibration_role,
        evaluation_role=evaluation_role,
        budget_fraction=budget_fraction,
        mode="topk",
        method_name="outcome_only_low_y",
        feature_names=feature_names,
        meta={"baseline": "lowest predicted factual outcome"},
    )
    # The IPW nuisance model is also fitted and frozen on train before test.
    prop = LogisticRegression(max_iter=1000, random_state=random_state)
    prop.fit(np.asarray(X_tr, dtype=float), np.asarray(t_tr, dtype=int))

    # Evaluate test only after every model and policy choice is frozen.
    y_te, t_te, X_te = bundle.ytx(evaluation_role)
    tau_hat = scorer.predict(X_te)
    out_pred = policy.predict(scores=tau_hat)
    decision = out_pred["decision"]
    treat_rate = float(np.mean(decision))
    y_risk = risk_model.predict(np.asarray(X_te, dtype=float))
    dec_random = random_policy(
        len(tau_hat), budget_fraction, random_state=random_state
    )
    dec_risk = apply_policy(-y_risk, risk_policy)
    # For IHDP cognitive scores, "treat lowest predicted outcome" = highest need
    # (worse baseline). Also report highest for completeness in notebook.

    # Equity strata are descriptive test summaries only. They never feed
    # policy calibration, model selection, or selection of a winner.
    eq_frame = X_te.copy()
    if equity_col not in eq_frame.columns:
        # fallback first continuous-looking column
        equity_col = feature_names[0]
    try:
        eq_frame[f"{equity_col}_tercile"] = pd.qcut(
            eq_frame[equity_col],
            q=n_terciles,
            labels=[f"T{i+1}" for i in range(n_terciles)],
            duplicates="drop",
        )
        group_col = f"{equity_col}_tercile"
    except ValueError:
        # constant or too few unique values
        group_col = equity_col
    eq_tbl = equity_table(decision, eq_frame[group_col], group_name=group_col)

    # Optional second group: sex median split if present
    equity_tables = {group_col: eq_tbl}
    if "sex" in X_te.columns:
        sex_med = float(np.median(X_te["sex"].to_numpy(dtype=float)))
        sex_bin = np.where(
            X_te["sex"].to_numpy(dtype=float) >= sex_med, "sex_high", "sex_low"
        )
        equity_tables["sex_median_split"] = equity_table(
            decision, sex_bin, group_name="sex_median_split"
        )
    if "b.marr" in X_te.columns:
        bm_med = float(np.median(X_te["b.marr"].to_numpy(dtype=float)))
        bm_bin = np.where(
            X_te["b.marr"].to_numpy(dtype=float) >= bm_med,
            "b.marr_high",
            "b.marr_low",
        )
        equity_tables["b.marr_median_split"] = equity_table(
            decision, bm_bin, group_name="b.marr_median_split"
        )

    # Stack equity tables with a group_var column for a single CSV
    eq_parts = []
    for gname, tbl in equity_tables.items():
        part = tbl.copy()
        # equity_table names the group column as group_name=gname
        if gname in part.columns:
            part = part.rename(columns={gname: "group"})
        elif len(part.columns) and "group" not in part.columns:
            # first column is the grouping key
            first = part.columns[0]
            part = part.rename(columns={first: "group"})
        part.insert(0, "group_var", gname)
        eq_parts.append(part[["group_var", "group", "n", "n_treated", "treat_rate"]])
    equity_out = pd.concat(eq_parts, ignore_index=True)

    # Qini / uplift curves (observed only)
    curve = qini_curve(y_te, t_te, tau_hat)
    q_auc = qini_auc(curve)
    uplift_df = uplift_curve(y_te, t_te, tau_hat, n_bins=10)

    out = Path(out_dir) if out_dir is not None else artifacts_dir("A4")
    ensure_dir(out)

    policy_path = out / "policy.joblib"
    card = build_rich_policy_card(
        scenario_id=scenario_id,
        scenario=scenario,
        budget_fraction=budget_fraction,
        method_name=method,
        threshold=float(policy.threshold),
        mode=str(policy.mode),
        feature_names=feature_names,
        treat_rate_test=treat_rate,
        n_test=int(len(tau_hat)),
        calibration_role=calibration_role,
        evaluation_role=evaluation_role,
        equity_group=group_col,
        random_state=random_state,
    )
    save_policy(policy, policy_path, policy_card=card)

    equity_path = out / "equity_table.csv"
    equity_out.to_csv(equity_path, index=False)

    uplift_path = out / "uplift_curve.png"
    if save_plot:
        try:
            import matplotlib

            matplotlib.use("Agg")
            import matplotlib.pyplot as plt

            from .plotting import plot_qini, plot_uplift_bins

            fig, axes = plt.subplots(1, 2, figsize=(11.0, 4.2))
            plot_qini(
                curve,
                ax=axes[0],
                title=f"Qini (test) — {method}",
            )
            plot_uplift_bins(
                uplift_df,
                ax=axes[1],
                title="Uplift by score bin (test)",
            )
            fig.suptitle(
                f"A4 uplift curves | B={budget_fraction:.0%} | treat_rate={treat_rate:.2%}",
                fontsize=11,
            )
            fig.tight_layout()
            fig.savefig(uplift_path, dpi=120)
            plt.close(fig)
        except Exception as exc:  # pragma: no cover
            uplift_path = None  # type: ignore
            plot_error = str(exc)
        else:
            plot_error = None
    else:
        plot_error = None
        uplift_path = None  # type: ignore

    # Target-policy evaluation uses the train-fitted propensity model.
    e_te = prop.predict_proba(np.asarray(X_te, dtype=float))[:, 1]
    policies = {
        "cate_topk": decision,
        "random": dec_random,
        "outcome_only_low_y": dec_risk,
    }
    cmp = compare_policies(
        policies,
        y=y_te,
        t=t_te,
        propensity=e_te,
        evaluation_role=evaluation_role,
    )

    def _rel(p: Optional[Path]) -> Optional[str]:
        if p is None:
            return None
        return relative_to_repo(p)

    info: Dict[str, Any] = {
        # Repo-relative paths only (no machine-specific absolute paths).
        "policy_path": _rel(policy_path),
        "policy_card_path": _rel(out / "policy_card.md"),
        "uplift_curve_path": _rel(uplift_path) if uplift_path else None,
        "equity_table_path": _rel(equity_path),
        "scenario": scenario,
        "scenario_id": scenario_id,
        "method_selected": method,
        "fit_role": "train",
        "calibration_role": calibration_role,
        "evaluation_role": evaluation_role,
        "policy_frozen_before_test": True,
        "evidence_status": "unverified_holdout_history",
        "budget_fraction": float(budget_fraction),
        "threshold": float(policy.threshold),
        "treat_rate_test": treat_rate,
        "qini_auc_test": float(q_auc),
        "n_test": int(len(tau_hat)),
        "comparison_ipw": cmp.to_dict(orient="records"),
        "observed_policy_value_test": observed_policy_value(y_te),
        "a3_scores_used": False,
        "a3_scores_ignored_for_frozen_protocol": a3_scores_path is not None,
        "equity_group": group_col,
        "plot_error": plot_error,
    }
    # side JSON for debugging / grader
    meta_path = out / "export_meta.json"
    with meta_path.open("w", encoding="utf-8") as f:
        json.dump(info, f, indent=2, default=str)
    info["export_meta_path"] = _rel(meta_path)
    return info
