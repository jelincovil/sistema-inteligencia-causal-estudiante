"""Monitoring core for the local causal production path.

The module is deliberately independent of a UI. It returns auditable rows and
an operational action for each window: continue, alert, review identification,
abstain or retrain.
"""
from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, Tuple

import numpy as np
import pandas as pd
from scipy import stats

B4 = Path(__file__).resolve().parent
REPO = B4.parents[1]
DATA_ROOT = REPO / "data_benchmark_causal" / "causal_benchmark_synthetic" / "datasets"
SCENARIO = DATA_ROOT / "synthetic" / "inference" / "ihdp_medium"


@dataclass(frozen=True)
class MonitorThresholds:
    psi_alert: float = 0.12
    psi_large: float = 0.25
    z_effect: float = 3.0
    nc_z: float = 3.0
    frac_ps_fail: float = 0.10
    ess_alert: float = 0.30
    ess_fail: float = 0.15
    smd_alert: float = 0.10
    smd_fail: float = 0.25
    # Appended to preserve the existing positional-argument order.
    # Operational KS cutoff, not a significance test or a universal guarantee.
    ks_alert: float = 0.15


def load_baseline_train():
    frame = pd.read_csv(SCENARIO / "observed_train.csv")
    features = [c for c in frame.columns if c not in {"row_id", "treatment", "outcome"}]
    return frame[features].copy(), frame["treatment"].copy(), frame["outcome"].copy()


def ks_drift_report(
    X_base: np.ndarray,
    X_window: np.ndarray,
    feature_idx: Tuple[int, ...] = (0, 1, 2),
) -> Dict[str, float]:
    out = {}
    for j in feature_idx:
        out[f"ks_f{j}"] = float(stats.ks_2samp(X_base[:, j], X_window[:, j]).statistic)
    out["ks_max"] = float(max(out.values()))
    return out


def _psi_drift(ref: np.ndarray, new: np.ndarray, bins: int = 10, eps: float = 1e-6) -> float:
    """Population Stability Index using reference-derived bins.

    Nonconstant references use unique reference-quantile cuts. A constant
    reference ``c`` uses ``x < c``, ``x == c`` and ``x > c`` so a shift in either
    direction remains visible. If ``pr`` and ``pn`` are the clipped proportions,
    PSI is ``sum((pn - pr) * log(pn / pr))``; empty cells are clipped to ``eps``
    without renormalizing. PSI is a heuristic, not a hypothesis test.

    Empty or nonfinite samples, invalid bin counts and invalid clipping values
    are rejected instead of being interpreted as no drift.
    """
    ref = np.asarray(ref, dtype=float).reshape(-1)
    new = np.asarray(new, dtype=float).reshape(-1)
    if len(ref) == 0 or len(new) == 0:
        raise ValueError("PSI requiere muestras de referencia y ventana no vacías")
    if not np.isfinite(ref).all() or not np.isfinite(new).all():
        raise ValueError("PSI requiere observaciones finitas")
    if isinstance(bins, (bool, np.bool_)) or not isinstance(bins, (int, np.integer)) or bins < 1:
        raise ValueError("PSI requiere un número entero positivo de bins")
    try:
        eps = float(eps)
    except (TypeError, ValueError, OverflowError) as exc:
        raise ValueError("PSI requiere un epsilon numérico") from exc
    if not math.isfinite(eps) or not 0.0 < eps < 1.0:
        raise ValueError("PSI requiere 0 < epsilon < 1")

    if np.all(ref == ref[0]):
        constant = ref[0]
        ref_bins = (ref >= constant).astype(int) + (ref > constant).astype(int)
        new_bins = (new >= constant).astype(int) + (new > constant).astype(int)
        p_ref = np.bincount(ref_bins, minlength=3) / len(ref)
        p_new = np.bincount(new_bins, minlength=3) / len(new)
    else:
        cuts = np.unique(np.quantile(ref, np.linspace(0, 1, bins + 1)[1:-1]))
        p_ref = np.bincount(np.searchsorted(cuts, ref, side="right"), minlength=len(cuts) + 1) / len(ref)
        p_new = np.bincount(np.searchsorted(cuts, new, side="right"), minlength=len(cuts) + 1) / len(new)
    p_ref = np.clip(p_ref, eps, None)
    p_new = np.clip(p_new, eps, None)
    # The log difference is algebraically identical to log(p_new / p_ref),
    # but does not overflow when eps is a positive subnormal float.
    return float(np.sum((p_new - p_ref) * (np.log(p_new) - np.log(p_ref))))


def psi_drift_report(
    X_base: np.ndarray,
    X_window: np.ndarray,
    feature_idx: Tuple[int, ...] = (0, 1, 2),
    bins: int = 10,
) -> Dict[str, float]:
    out = {}
    for j in feature_idx:
        out[f"psi_f{j}"] = _psi_drift(X_base[:, j], X_window[:, j], bins=bins)
    if not out:
        raise ValueError("PSI requiere al menos una covariable")
    out["psi_max"] = float(max(out.values()))
    return out


def _difference_in_means(y: np.ndarray, t: np.ndarray) -> float:
    treated = y[t == 1]
    control = y[t == 0]
    if len(treated) == 0 or len(control) == 0:
        return float("nan")
    return float(treated.mean() - control.mean())


def _simple_support_metrics(X: np.ndarray, t: np.ndarray) -> tuple[float, float, float]:
    """Approximate overlap, ESS and weighted SMD without using truth."""
    from sklearn.linear_model import LogisticRegression

    # Binary logistic regression does not need the L-BFGS path here.  The
    # liblinear solver avoids the deprecated SciPy ``disp`` route while
    # preserving the support diagnostic used by the monitor.
    ps = LogisticRegression(max_iter=500, random_state=42, solver="liblinear").fit(X, t).predict_proba(X)[:, 1]
    ps = np.clip(ps, 1e-4, 1 - 1e-4)
    extreme = float(np.mean((ps < 0.05) | (ps > 0.95)))
    wt, wc = 1.0 / ps[t == 1], 1.0 / (1.0 - ps[t == 0])
    ess = min((wt.sum() ** 2 / (wt**2).sum()) / max(len(wt), 1), (wc.sum() ** 2 / (wc**2).sum()) / max(len(wc), 1))
    smd = []
    for j in range(X.shape[1]):
        pooled = float(np.std(X[:, j], ddof=1)) or 1.0
        smd.append(abs(float(np.average(X[t == 1, j], weights=wt) - np.average(X[t == 0, j], weights=wc))) / pooled)
    return extreme, float(ess), float(max(smd))


REQUIRED_METRICS = (
    "frac_ps_extremo",
    "ess_rel_min",
    "smd_pond_max",
    "nc_abs_z",
    "z_efecto",
    "psi_max",
    "ks_max",
)


UNIT_INTERVAL_METRICS = frozenset({"frac_ps_extremo", "ess_rel_min", "ks_max"})
NONNEGATIVE_METRICS = frozenset({"smd_pond_max", "nc_abs_z", "psi_max"})


def _finite_metrics(metrics: dict) -> tuple[dict[str, float], list[str]]:
    if not isinstance(metrics, dict):
        return {}, ["las métricas no forman un objeto"]
    values = {}
    invalid = []
    for name in REQUIRED_METRICS:
        if name not in metrics:
            invalid.append(f"{name} (ausente)")
            continue
        raw = metrics[name]
        if isinstance(raw, (str, bytes, bool)) or raw is None:
            invalid.append(f"{name} (tipo no numérico)")
            continue
        try:
            value = float(raw)
        except (TypeError, ValueError, OverflowError):
            invalid.append(f"{name} (mal formada)")
            continue
        if not math.isfinite(value):
            invalid.append(f"{name} (no finita)")
            continue
        if name in UNIT_INTERVAL_METRICS and not 0.0 <= value <= 1.0:
            invalid.append(f"{name} (fuera del dominio físico [0, 1])")
            continue
        if name in NONNEGATIVE_METRICS and value < 0.0:
            invalid.append(f"{name} (fuera del dominio físico [0, inf))")
            continue
        values[name] = value
    return values, invalid


def decide_action(metrics: dict, thresholds: MonitorThresholds = MonitorThresholds()) -> dict:
    """Apply the precedence rule only when all required evidence is valid."""
    m, invalid = _finite_metrics(metrics)
    if invalid:
        return {
            "accion": "abstenerse",
            "motivo": "evidencia de monitoreo ausente o inválida: " + ", ".join(invalid),
        }
    if m["frac_ps_extremo"] >= thresholds.frac_ps_fail:
        return {"accion": "abstenerse", "motivo": "positividad fuera de límite"}
    if m["ess_rel_min"] <= thresholds.ess_fail or m["smd_pond_max"] >= thresholds.smd_fail:
        return {"accion": "abstenerse", "motivo": "solapamiento o balance fuera de límite"}
    if abs(m["nc_abs_z"]) >= thresholds.nc_z:
        return {"accion": "revisar_identificacion", "motivo": "el control negativo rechaza"}
    effect_changed = abs(m["z_efecto"]) >= thresholds.z_effect
    drift_large = m["psi_max"] >= thresholds.psi_large
    drift_alert = m["psi_max"] >= thresholds.psi_alert or m["ks_max"] >= thresholds.ks_alert
    if effect_changed and not drift_large:
        return {"accion": "revisar_identificacion", "motivo": "cambió el efecto sin PSI grande"}
    if effect_changed and drift_large:
        return {"accion": "reentrenar", "motivo": "PSI grande y cambio del efecto"}
    if drift_large or drift_alert:
        return {"accion": "alertar", "motivo": "drift de covariables (PSI o KS); revisar soporte"}
    if m["ess_rel_min"] <= thresholds.ess_alert or m["smd_pond_max"] >= thresholds.smd_alert:
        return {"accion": "alertar", "motivo": "la puerta de overlap/balance está en alerta"}
    return {"accion": "continuar", "motivo": "sin señales"}


def simulate_monitor_table(
    *,
    n_windows: int = 12,
    window_size: int = 200,
    drift_start: int = 6,
    drift_strength: float = 0.8,
    effect_shift: float = 0.25,
    ks_threshold: float = 0.15,
    seed: int = 42,
    nc_abs_z: float | None = None,
) -> pd.DataFrame:
    """Create a deterministic teaching table from observed data only.

    ``nc_abs_z`` must come from an actual negative-control diagnostic. Leaving
    it absent forces abstention; a healthy-looking zero is never fabricated.
    """
    X_base, t_base, y_base = load_baseline_train()
    X = X_base.to_numpy(dtype=float)
    t = t_base.to_numpy(dtype=int)
    y = y_base.to_numpy(dtype=float)
    rng = np.random.default_rng(seed)
    n = len(X)
    baseline_proxy = _difference_in_means(y, t)
    rows = []
    for w in range(n_windows):
        idx = rng.integers(0, n, size=window_size)
        Xw, tw, yw = X[idx].copy(), t[idx].copy(), y[idx].copy()
        in_drift = w >= drift_start
        step = w - drift_start + 1 if in_drift else 0
        if in_drift:
            Xw[:, :3] += drift_strength * step
            p = np.clip(float(t.mean()) + 0.04 * step, 0.02, 0.98)
            tw = rng.binomial(1, p, size=window_size)
            yw = yw + effect_shift * step * tw
        base_idx = rng.integers(0, n, size=window_size)
        feature_idx = tuple(range(min(3, X.shape[1])))
        ks = ks_drift_report(X[base_idx], Xw, feature_idx)
        psi = psi_drift_report(X[base_idx], Xw, feature_idx)
        proxy = _difference_in_means(yw, tw)
        extreme, ess, smd = _simple_support_metrics(Xw, tw)
        z_effect = (proxy - baseline_proxy) / max(float(np.std(yw)) / math.sqrt(max(window_size, 1)), 1e-6)
        metrics = {
            "psi_max": psi["psi_max"],
            "ks_max": ks["ks_max"],
            "frac_ps_extremo": extreme,
            "ess_rel_min": ess,
            "smd_pond_max": smd,
            "z_efecto": float(z_effect),
            "nc_abs_z": nc_abs_z,
        }
        decision = decide_action(metrics, MonitorThresholds(ks_alert=ks_threshold))
        rows.append({
            "window": w,
            "treatment_rate": float(tw.mean()), "effect_proxy": proxy,
            "effect_proxy_delta": abs(proxy - baseline_proxy), "drift_injected": in_drift,
            **metrics, **decision, "alert": bool(ks["ks_max"] >= ks_threshold),
        })
    return pd.DataFrame(rows)


def simulate_and_count_alerts(
    *, n_windows: int = 12, window_size: int = 200, drift_start: int = 6,
    drift_strength: float = 0.8, ks_threshold: float = 0.15, seed: int = 42,
    nc_abs_z: float | None = None,
) -> Dict[str, float]:
    table = simulate_monitor_table(
        n_windows=n_windows, window_size=window_size, drift_start=drift_start,
        drift_strength=drift_strength, ks_threshold=ks_threshold, seed=seed,
        nc_abs_z=nc_abs_z,
    )
    after = table[table["window"] >= drift_start]
    return {
        "n_alerts": float(table["alert"].sum()),
        "max_ks_after_drift": float(after["ks_max"].max()) if len(after) else 0.0,
        "ks_threshold": ks_threshold,
    }
