= Data Contracts, Split Governance, and Deployment

== Real-data engineering is part of the scientific protocol

Causal notation begins with variables, but computation begins with bytes, column labels, timestamps, joins, identifiers, and role assignments. A real-data pipeline must make those transformations inspectable. It must also preserve the distinction between data cleanliness and causal validity: zero missing values can coexist with invalid measurement, wrong eligibility, or severe confounding.

The Rust `causal-ml` command reads the comma-separated source with a structured CSV parser, validates records against a typed contract, and emits a reproducible JSON audit. Parsing is streaming at the CSV-record boundary, while validated typed rows are retained for duplicate analysis, splits, statistics, and model fitting; the end-to-end memory footprint is therefore not constant.

#figure(
  table(
    columns: (1.05fr, 2fr, 1.25fr),
    table.header([Check], [Rule], [Relevant failure behavior]),
    [Shape], [Required headers are present once; every record matches header width], [Malformed CSV or a contract mismatch is rejected],
    [Types], [Strings, categorical levels, binary flags, integers, and finite numbers follow declared dtypes], [Invalid or nonfinite values are rejected],
    [Missingness], [Required fields cannot be empty; actual missing cells are counted], [Required missingness is an audit error],
    [Ranges], [Numeric values respect declared minima and maxima], [Out-of-contract values are errors],
    [Identifiers], [Unit and, when declared, unit/epoch keys are unique], [Duplicate keys are errors],
    [Duplicate records], [Exact repeated records and repeated measurement vectors are distinguished], [Exact duplicates are errors; repeated measurement vectors remain warnings],
    [Source identity], [Actual bytes and SHA-256 match pinned expectations], [Changed upstream or local bytes are rejected],
  ),
  caption: [Data checks test the explicit contract; they do not infer semantic correctness from successful parsing.],
) <tab:data-checks>

Categorical levels preserve their legitimate uncertainty instead of silently mapping unknown values into a reference category. Numeric parsing rejects values that could contaminate deterministic regression arithmetic. The saved audit distinguishes errors from warnings and records column-level missingness, distinct counts, ranges, duplicate diagnostics, and source digests.

== Feature availability and point-in-time correctness <feature-availability>

A feature can be accurate in the raw database and still be causal leakage. If it is measured after treatment, influenced by treatment, or unavailable at the decision time, including it changes the scientific question or deployment setting.

Each adjustment feature should therefore declare:

+ a semantic definition and unit of measurement;
+ an `available_at` event or time expression relative to treatment/prediction origin;
+ its causal role, such as pre-treatment adjustment, treatment, outcome, or excluded variable;
+ a deterministic transform and category map; and
+ rules for missingness and future schema changes.

The LaLonde contract declares baseline and pre-assignment labels for its selected covariates, applies fixed transformations, and marks `re78` as a post-treatment outcome excluded from adjustment. These declarations document the intended point-in-time model; the static CSV cannot independently prove every field's historical availability.

For a production point-in-time join, an available feature $X_j$ must satisfy $"event_time"(X_j) <= "decision_time"$ and $"system_ingestion_time"(X_j) <= "decision_time"$ when late-arriving corrections matter. Backfilled or revised fields need their own versioning, not merely an earlier business timestamp. Neither production joins nor online feature stores are implemented here.

== Entity, epoch, and role-separated evaluation

Let $I_r$ denote entity IDs assigned to role $r$. Entity-disjoint splitting requires

$ I_"train" inter I_"calibration" = I_"train" inter I_"holdout" = I_"calibration" inter I_"holdout" = emptyset. $ <eq:entity-disjoint>

This prevents the same entity appearing in multiple roles when stable IDs are available. If repeated records per person exist, they move with the entity; otherwise one person's history can leak into the evaluation of another fold.

A temporal protocol additionally anchors each row to an epoch and orders training, validation, and final evaluation windows, for example

$ max("epoch"_"train") < min("epoch"_"calibration") <= max("epoch"_"calibration") < min("epoch"_"holdout"). $ <eq:epoch-order>

Entity separation and temporal separation answer different leakage questions. A rolling-origin or forward-chaining design may be appropriate for deployment prediction, while an entity holdout may target new-entity generalization. The estimand and target use determine which is needed.

The supplied LaLonde CSV has no epoch. Its report truthfully marks epoch-disjoint verification false and explains *unavailable*, not “temporal control failed” and certainly not “temporal control passed.” No previous or future observation date is reconstructed from the `NSW…` and `PSID…` row labels.

== Train, calibration, and holdout have different permissions

#figure(
  table(
    columns: (0.85fr, 2.4fr, 1.4fr),
    table.header([Role], [Permitted use in the frozen case], [Forbidden use]),
    [Train], [Cross-fit train AIPW, fit transformations and nuisance models, observe train outcomes], [Final untouched-performance claim],
    [Calibration], [X/T-only gate, treatment loss and overlap checks; subsequent descriptive outcome means for association reporting], [Outcome-driven gate decisions or feature, model, clip, and threshold selection],
    [Holdout], [One final evaluation with train-fitted nuisances after the gate permits execution], [Repeated tuning, choosing sensitivity variants, or reassigning disappointing rows],
  ),
  caption: [Split roles are authorization rules, not just row counts.],
) <tab:split-permissions>

The calibration gate does not evaluate its outcomes; descriptive calibration outcome means are reported separately and are not model-selection inputs. If that gate fails, evaluation stops before holdout outcomes are evaluated or reported. Raw CSV parsing and all-record preparation summaries still occur and must not be misdescribed as zero literal access. The holdout ledger binds the source, contract, audit, and split hashes, assigns a final-only event identity and access sequence, and records whether outcomes were reused for tuning. Repeat estimation into the same protocol directory is refused. Markdown or Typst rendering reads the report without adding another access event.

This local mechanism is not a cryptographic append-only log, independent timestamp, or global registry. File hashes establish that a particular report refers to particular current bytes; they cannot establish who changed a file before an audit or what happened outside the project. A more stringent multi-analyst study would need signed manifests, centralized event authorization, and independent replay.

== Reproducible preprocessing and manifests

A reproducible run pins at least:

- raw URL and content digest rather than an unpinned `latest` reference;
- contract JSON including columns, dtypes, ranges, causal roles, transforms, formula choices, split salt, folds, clips, and interval level;
- source/audit/splits/report digests in the ledger;
- deterministic identifiers and role assignments stored in `splits.csv`;
- Cargo dependency lockfile and versioned command lines; and
- artifact-generated reporting rather than manually rounded hand-entered results.

A changed input or configuration should trigger a new protocol/output identity. A changed scientific hypothesis is not an implementation patch. These conventions make the current LaLonde execution inspectable without pretending that a reader may safely rerun final estimation against the consumed artifacts.

== Monitoring after an executable artifact <monitoring>

There is no deployed service in this project. Nevertheless, a future treatment-support system would need monitoring tailored to both operational and causal failure modes.

#figure(
  table(
    columns: (1.05fr, 1.85fr, 1.6fr),
    table.header([Layer], [Signals], [Required response]),
    [Schema/ingestion], [Missing columns, dtype changes, unknown levels, digest changes, delayed joins], [Stop evaluation or quarantine the batch; do not coerce silently],
    [Population], [Entity mix, baseline distributions, epoch coverage, missingness and selection shifts], [Reassess estimand and transportability, not merely predictive calibration],
    [Treatment assignment], [Propensity quantiles, overlap tails, policy/version changes], [Check positivity and intervention definition; suspend unsupported recommendations],
    [Nuisance/output], [Convergence, coefficient drift, predicted-outcome distributions, negative or impossible predictions], [Blocking diagnostics with a versioned incident record],
    [Outcomes], [Delayed labels, missing follow-up, calibration and performance when outcomes arrive], [State observation lag; never impute live counterfactual ground truth],
    [Decision impact], [Overrides, capacity, costs, fairness constraints, downstream outcomes], [Prespecified pause, human review, rollback, and fresh evaluation protocol],
  ),
  caption: [Monitoring requirements for any future deployment; these checks are not implemented as a live service.],
) <tab:monitoring>

Predictive drift is not synonymous with causal drift. Treatment-effect heterogeneity can change while $P(Y mid X,T)$ remains superficially stable; conversely, outcome prediction can shift because of baseline incidence while an additive effect remains stable. Counterfactual outcomes remain unobserved in production, so deployment monitoring must gather new identification evidence where necessary rather than labeling predicted treatment effects as observed truth.

== Release and evidence limits

A release candidate should pass formatting, compilation, linting, deterministic tests, malformed-input tests, duplicate/leakage failure tests, fixture validation, corpus audit, book compilation, and checked-in artifact inspection. It should also disclose unresolved data licensing, missing temporal design, unmeasured confounding, weak overlap, model restrictions, lack of independent replay, and unavailable causal certification.

“Software checks passed” and “scientific claim supported” are separate statuses. The first can be true for this project while the second remains false. Keeping both visible is a release feature, not a blemish.
