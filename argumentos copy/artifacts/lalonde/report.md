# Executable LaLonde case: audit and conditional AIPW

> **Evidence boundary.** Raw group contrasts are associational. AIPW is an adjusted estimator whose causal interpretation requires assumptions that this dataset and software cannot establish path-by-path. `scientific_causal_claim_verified = false`.

## Frozen protocol and provenance

- Dataset ID: `rdatasets-matchit-lalonde-pinned-v1`.
- Data: Rdatasets MatchIt LaLonde NSW treated and PSID comparison sample; observational cross-source comparison, not the NSW randomized benchmark..
- Raw URL: <https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/1dcc2bf5f955cc1224a3e1307256e1fe86b68dae/csv/MatchIt/lalonde.csv>.
- Documentation URL: <https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/1dcc2bf5f955cc1224a3e1307256e1fe86b68dae/doc/MatchIt/lalonde.html>.
- Exact input: 27509 bytes; SHA-256 `a49703ca0233ba0a27fa9cda959a38a07f6825def0f7743cf2380ce4e57dd3ef`; byte match `true`; digest match `true`.
- Contract SHA-256: `f66da858ea890ec4b89eb0fd2e4e4a167dd4a7815e450cd64acdcea8c23e5f86`.
- Audit SHA-256: `6756aa706657f74b16abeae26b54df28281555bfac2de13470e3e4d1da19520c`.
- Split SHA-256: `d50097fadd29eca6e39dbd9aee8410a65e6f34233e6a057b975ba7f54b70c17f`.
- Causal report SHA-256: `9193ea4574ab202e0b771cc0b5db7f4f74c6ddd6f24c676dd0850dfb7beba70b`.
- Data-value license status: `unresolved_upstream`; see `data/real/PROVENANCE.md`. This is not a new license grant.
- Estimator: `Main-effects logistic IRLS with standardized contract features, unpenalized intercept and fixed ridge on other coefficients.`; predeclared sensitivity clips `[0.01, 0.1]`; primary clip `0.05`.
- Split roles: train for cross-fitting and deployed nuisance fitting; calibration for X/T-only computational and treatment-propensity gate diagnostics, with outcome means subsequently reported descriptively and never used for selection; holdout for one final external-nuisance evaluation.
- Split assignment: `causal-ml-lalonde-protocol-v1-no-outcome-tuning`, fractions 0.60/0.20/0.20; five-fold assignment occurs only in train.
- Feature availability: only declared pre-treatment columns enter adjustment; `re78` is excluded as the post-treatment outcome.
- Temporal governance: No epoch is available. Stable IDs provide entity-disjoint splits only; temporal leakage cannot be assessed.

## Data audit

- Observations: **614**; treatment counts: `{"0": 429, "1": 185}`.
- Split counts: `{"calibration": 114, "holdout": 134, "train": 366}`; fold counts: `{"0": 74, "1": 91, "2": 64, "3": 68, "4": 69}`.
- Required/optional missing cells across declared columns: **0**. Exact duplicate rows: **0**. Duplicate unit or unit/epoch keys: **0**. Repeated measurement vectors excluding ID: **5** (warning, not automatic duplication of persons).
- Leakage diagnostics: entity-disjoint `true`, epoch-disjoint `false`. No epoch column: temporal separation is unavailable, not inferred.

| Column | Declared type | Non-missing | Missing | Distinct | Minimum | Maximum |
|---|---:|---:|---:|---:|---:|---:|
| `rownames` | String | 614 | 0 | 614 | — | — |
| `treat` | Binary | 614 | 0 | 2 | 0.0 | 1.0 |
| `re78` | Number | 614 | 0 | 457 | 0.0 | 60307.9 |
| `age` | Integer | 614 | 0 | 40 | 16.0 | 55.0 |
| `educ` | Integer | 614 | 0 | 19 | 0.0 | 18.0 |
| `race` | Categorical | 614 | 0 | 3 | — | — |
| `married` | Binary | 614 | 0 | 2 | 0.0 | 1.0 |
| `nodegree` | Binary | 614 | 0 | 2 | 0.0 | 1.0 |
| `re74` | Number | 614 | 0 | 358 | 0.0 | 35040.1 |
| `re75` | Number | 614 | 0 | 356 | 0.0 | 25142.2 |

### Feature-availability contract

| Field | Available at | Role | Transform | Excluded from adjustment |
|---|---|---|---|---:|
| `re78` | post-treatment outcome; never an adjustment feature | outcome | Identity | true |
| `age` | baseline_before_NSW_assignment | pre_treatment_adjustment | Identity | false |
| `educ` | baseline_before_NSW_assignment | pre_treatment_adjustment | Identity | false |
| `race` | baseline_before_NSW_assignment | pre_treatment_adjustment | Identity | false |
| `married` | baseline_before_NSW_assignment | pre_treatment_adjustment | Identity | false |
| `nodegree` | baseline_before_NSW_assignment | pre_treatment_adjustment | Identity | false |
| `re74` | calendar_year_1974_before_NSW_assignment | pre_treatment_adjustment | Log1p | false |
| `re75` | calendar_year_1975_before_NSW_assignment | pre_treatment_adjustment | Log1p | false |

### Audit issues

- **warning / duplicate_measurements**: Repeated measurement vectors excluding ID are counted but not automatically errors.

## Descriptive contrasts — association only

The estimand below is `mean(Y | T=1) - mean(Y | T=0)` within each named subset. It is not an average treatment effect without identification. All dollar values are nominal source dollars; no deflation is applied.

| Scope | n | Treated n | Control n | Treated mean | Control mean | Difference |
|---|---:|---:|---:|---:|---:|---:|
| all_observations | 614 | 185 | 429 | 6349.1 | 6984.2 | -635.0 |
| calibration | 114 | 37 | 77 | 4827.5 | 7622.8 | -2795.3 |
| holdout | 134 | 44 | 90 | 5932.4 | 6739.6 | -807.3 |
| train | 366 | 104 | 262 | 7066.8 | 6880.5 | 186.3 |

## Cross-fitted AIPW and final holdout evaluation

The implemented score is `mu1(X)-mu0(X) + T(Y-mu1(X))/e(X) - (1-T)(Y-mu0(X))/(1-e(X))`. Models are main-effects logistic IRLS for propensity and separate ridge-linear outcome regressions. Train estimates use five-fold cross-fitting; holdout estimates use nuisances fitted on train only. Intervals are normal-reference influence-function approximations, not bounds on hidden confounding.

### train_cross_fitted (clip 0.05)

- n = 366; treated = 104; control = 262.
- Adjusted mean difference: **-269.3**; IF standard error: **1023.1**; normal 95% interval: **[-2274.4, 1735.9]**.
- Raw propensity min/p05/median/p95/max: 0.003982 / 0.010534 / 0.122134 / 0.841023 / 0.915724.
- Outside [0.05, 0.95]: 138 (37.70%); <= 0.01: 14; >= 0.99: 0.
- Interpretation: Adjusted sample contrast, causal only under the stated untestable identification assumptions; interval omits confounding and transport uncertainty.

### holdout_external_nuisance (clip 0.05)

- n = 134; treated = 44; control = 90.
- Adjusted mean difference: **426.3**; IF standard error: **1821.9**; normal 95% interval: **[-3144.6, 3997.3]**.
- Raw propensity min/p05/median/p95/max: 0.007054 / 0.012561 / 0.154671 / 0.848377 / 0.883931.
- Outside [0.05, 0.95]: 41 (30.60%); <= 0.01: 4; >= 0.99: 0.
- Interpretation: Adjusted sample contrast, causal only under the stated untestable identification assumptions; interval omits confounding and transport uncertainty.

- Final holdout ledger event: `H001-final-only`; access sequence 1; reused for tuning: `false`.
- Calibration: n = 114; log loss = 0.394993; Brier = 0.124629; gate passed = `true`; outcomes used in gate = `false`; descriptive calibration outcomes reported = `true`.
- Calibration outcome-use semantics: The legacy outcome_used field mirrors outcome_used_in_gate. Descriptive calibration outcome means are computed after the gate and reported as associations only; neither the gate nor descriptive reporting selects or revises models.
- **Weak-overlap warning:** 44/114 calibration raw propensities (38.60%) fall outside [0.05, 0.95]. `true` gate_passed is a computational X/T-only result, not scientific approval, positivity verification, or causal identification.
- Calibration overlap: min = 0.003562; p05 = 0.012052; median = 0.118933; p95 = 0.844957; max = 0.875259.
- Deployed logistic fit: converged = `true`; separation suspected = `false`; iterations = 7.

### Predeclared propensity-clipping sensitivity

These are fixed sensitivity calculations, not candidates for choosing a preferred answer and not sensitivity bounds for unmeasured confounding.

| Role | Clip | Adjusted difference | Normal 95% interval |
|---|---:|---:|---:|
| train_cross_fitted | 0.01 | -261.5 | [-2263.7, 1740.7] |
| holdout_external_nuisance | 0.01 | 1137.4 | [-3173.6, 5448.3] |
| train_cross_fitted | 0.10 | 98.6 | [-1687.3, 1884.4] |
| holdout_external_nuisance | 0.10 | 75.5 | [-2443.2, 2594.3] |

## Fold diagnostics

| Fold | Fit n | Evaluation n | Logistic converged | Separation suspected | Fit propensity min | Fit propensity max |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 292 | 74 | true | false | 0.005376 | 0.902336 |
| 1 | 275 | 91 | true | false | 0.009351 | 0.905193 |
| 2 | 302 | 64 | true | false | 0.009478 | 0.898417 |
| 3 | 298 | 68 | true | false | 0.004697 | 0.898921 |
| 4 | 297 | 69 | true | false | 0.004910 | 0.911679 |

## Warnings and scientific limitations

- No computational gate warning was emitted. This does not verify any identification assumption.
- Unadjusted group differences are associational and include measured and unmeasured selection.
- The NSW treated and PSID comparison samples do not create random assignment; unconfoundedness remains unverifiable.
- Normal-reference influence-function intervals quantify a particular sampling approximation, not uncertainty from unmeasured confounding, dataset construction, model choice, or target-population transport.
- Clipping changes inverse-probability weights and can hide weak overlap or introduce bias; sensitivity clips are not bias bounds.
- Linear outcome models can predict negative earnings; model misspecification remains possible despite double robustness.
- There are no repeated epochs, cluster-robust intervals, inflation adjustment, individual treatment-effect estimates, policy thresholds, or deployment claims.
- Required identifying assumptions declared in the report:
  - Consistency: observed Y equals the potential outcome for received treatment.
  - No relevant interference between NSW/PSID units.
  - Conditional mean exchangeability given only age, education, race, marital status, degree status, and 1974/1975 earnings.
  - Positivity over the target covariate support; clipping does not repair structural nonpositivity.
  - Well-defined NSW treatment and target population for the nonexperimental PSID comparison.

## Holdout-use ledger

The local ledger record is a reproducibility safeguard, not a tamper-proof timestamp authority. At rendering, it contains **1** event(s). Repeating estimation in this protocol directory is refused. Markdown and Typst generation is read-only and does not create another access event.

_Reproducible output generated solely by `causal-ml report` from the JSON artifacts listed above._
