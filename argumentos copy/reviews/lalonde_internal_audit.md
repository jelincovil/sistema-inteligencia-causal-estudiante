# Internal LaLonde / NSW–PSID protocol audit

**Mode:** read-only, internal, non-certifying audit of supplied bytes and declarations. No new model selection, estimate correction, or holdout re-use is performed here.
**Auditor role:** implementation assistance, not an independent scientific referee.
**Decision question:** may the adjusted contrast in `artifacts/lalonde/causal_report.json` be interpreted as a verified program effect in the population rather than as a frozen, split-specific conditional dossier?

## Overall finding

**NO for causal certification.** The project is internally reproducible and correctly bounded in its own claim vocabulary, but the decisive conditions for causal interpretation remain unestablished. The audit does not authorize reinterpreting after inspection of holdout outcomes.

Blocking conditions for a stronger claim:

1. NSW/PSID assignment is nonexperimental, so conditional exchangeability is unverifiable from the CSV.
2. Estimated overlap is weak: 138/366 training rows (37.70%) and 41/134 holdout rows (30.60%) have raw propensity outside `[0.05, 0.95]`.
3. The holdout is consumed; tuning on it now would contaminate the frozen record.
4. The ledger is local, author-editable, and not externally witnessed.
5. Upstream data-value license status remains `unresolved_upstream`.
6. External replay/replication, independent identification review, and hidden-confounding analysis are absent.

## Scope and inputs

- Raw data pin: `data/real/lalonde.csv`, 27,509 bytes, SHA-256 `a49703ca0233ba0a27fa9cda959a38a07f6825def0f7743cf2380ce4e57dd3ef`.
- Frozen contract: `config/lalonde.contract.json`.
- Generated report: `artifacts/lalonde/causal_report.json`.
- Local ledger: `artifacts/lalonde/holdout_ledger.json`.
- Provenance: `data/real/PROVENANCE.md`.
- Structural corpus dossier: `corpus/causal_ml.json` and `artifacts/corpus_audit.json`.
- Clean replay directory recorded in project reports: `build/review-fixes-20261122/lalonde`.
- Literature background: `book/LITERATURE_MATRIX.md`.

No file in this review modifies source data or prior analysis outputs.

## Findings

| Check | Status | Severity | Localized evidence | Rationale |
|---|---|---|---|---|
| Unit and population | NO VERIFICABLE | blocking | `data/real/PROVENANCE.md:15-20`; `artifacts/lalonde/causal_report.json:estimand` | Source row IDs define the sample; no target population, treatment version, or sampling frame supporting external inference is supplied. |
| Feature availability | PASA at declaration level | important | `config/lalonde.contract.json:features`; `causal_report.json:feature_availability` | Baseline features are pre-treatment, and the outcome earnings variable is not an adjustment feature. Implementation inspection is still required for future changes. |
| Entity split governance | PASA at declaration level | important | `config/lalonde.contract.json:split`; `audit.json:leakage_checks`; `artifacts/lalonde/splits.csv` | Entity-disjoint partition is declared and verified by local checks: 366 train, 114 calibration, 134 holdout. This does not establish temporal separation or longitudinal identity. |
| Temporal governance | NO VERIFICABLE | important | `data/real/lalonde.csv` schema; `artifacts/lalonde/audit.json:leakage_checks` | No epoch is present. Temporal split testing is therefore unavailable, not successful. Entity separation is the only implemented role separation. |
| Split independence | PASS as a declared implementation check | important | `audit.json:leakage_checks`, project report clean-replay comparison | Train, calibration, and holdout role assignments and hash manifests are deterministic and have not changed with the holdout after the frozen result. The evidence is internal, not externally witnessed. |
| Feature transformations | PASA at computation level | minor | `config/lalonde.contract.json:estimator`; `causal_report.json:feature_availability` | Declared `log1p` transformation applies only to re74 and re75; fold-local standardization is captured in code and artifact production. This is computational evidence, not identification evidence. |
| Treatment propensity model | NO VERIFICABLE causally | important | `config/lalonde.contract.json:estimator`; `causal_report.json:train_fold_diagnostics` | Main-effects logistic IRLS is a fit diagnostic, not evidence that measured covariates capture assignment. |
| Outcome model | NO VERIFICABLE | important | source code and frozen learner family | Separate ridge-linear regressions are implemented and audited for convergence; linearity and support are not causal correctness. |
| Positivity/overlap | FALLA for the strong case | blocking | `causal_report.json:train_cross_fitted_aipw.overlap`; `causal_report.json:holdout.aipw.overlap` | Clipping does not repair nonpositivity. The case must be read as estimable only on restricted observed support, not as evidence of broad-population positivity. |
| Identification | NO VERIFICABLE | blocking | `corpus/causal_ml.json`; `PROVENANCE.md:28-36`; no DAG/selection design review | Measured pre-treatment covariates do not establish unconfoundedness for NSW/PSID selection. |
| AIPW diagnostic | PASA for numerical convergence only | important | `causal_report.json:train_fold_diagnostics`; `causal_report.json:deployed_nuisance_diagnostics` | All recorded fit diagnostics report convergence and no suspected separation. Numerical convergence is not model correctness. |
| Holdout purpose | NO VERIFICABLE externally | blocking | `artifacts/lalonde/holdout_ledger.json:events`; `causal_report.json:holdout` | One byte-pinned local event is recorded as final-only. The ledger itself is author-editable and not externally signed. |
| Holdout tuning | PASA for no observed integrated revision; not independently witnessed | important | frozen protocol and ledger; clean-replay history | No outcome-based selection, threshold revision, learner replacement, or contract change is represented. External witness is absent. |
| Sensitivity | PARTIAL / FALLA for robust claim | important | `causal_report.json:sensitivity`; `C.empirical.aipw_holdout_clip_001` and `C.empirical.aipw_holdout_clip_010` in `corpus/causal_ml.json` | Clipping at 0.01, 0.05, and 0.10 is encoded; none is hidden-confounding sensitivity. |
| Hidden confounding | NO VERIFICABLE | blocking | no quantitative confounding-bound artifact under project scope | The frozen file and arms cannot rule out selection on unmeasured variables. This prevents certificate-grade causal wording. |
| License/redistribution | NO VERIFICABLE | blocking for redistribution | `data/real/PROVENANCE.md:License/status` | The reviewed rights statements do not establish dataset-specific permission. This project pins bytes rather than granting a license. |
| Evidence replay | NO VERIFICABLE externally | blocking | `artifacts/corpus_audit.json` | `candidate` specs and current-byte inventories are not externally observed executions. |
| Literature alignment | PASS as documentation, not as replay | minor | `book/LITERATURE_MATRIX.md` | The sources support the methods and warnings used, but do not validate the substantive analysis on new data. |
| Production governance | NO VERIFICABLE | blocking | `C.deployment.monitoring`; no monitored service/rollback evidence | The case is a research artifact, not a deployment-ready population policy. |

## Regime and information boundary

There is no forecasting origin or horizon in this case. The nearest analogous boundary is:

- Baseline features available before intervention: age, educ, race, married, nodegree, re74, re75 (with frozen log1p transform for earnings).
- Outcome of interest: 1978 earnings.
- Treatment version: NSW enrollment comparison among the supplied treated NSW rows versus PSID comparison rows.
- Adjustment uses baseline measured variables only.
- No epoch, routing time, or dynamic treatment stage is present.

## Selection and holdout chronology

The project freezes a 60/20/20 train/calibration/holdout assignment by salted entity hash. Cross-fitted AIPW nuisances are trained only on train folds; the calibration gate is X/T-based computation and propensity diagnostics, not an outcome-based alternative-selection mechanism. It reaches the single final holdout event with `reused_for_tuning:false` in the generated report.

This project must continue to report the comparison as an exploratory cohort contrast unless an independent, newly reviewed or newly sampled dataset supports a stronger design.

## Metrics and uncertainty

The evaluated contrast is nominal-dollar 1978 earnings. The reported sampling uncertainty is a normal-reference influence-function interval around AIPW:

- train: `-269.3`, normal 95% interval `[-2274.4, 1735.9]`;
- holdout: `426.3`, normal 95% interval `[-3144.6, 3997.3]`;
- all-observation unadjusted contrast: `-635.0` nominal dollars, explicitly associational.

These intervals reflect one sampling approximation under fitted nuisances. They omit hidden-confounding, dataset construction, model selection, transport, support, version ambiguity, and licensing uncertainty. They do not make sign reversal across train and holdout irrelevant; they expose rather than conceal incompatibility across partitions.

## Claim boundaries

| Claim | Type | Audit status |
|---|---|---|
| The CSV is the pinned 27,509-byte MatchIt/Rdatasets artifact | provenance/factual | Structural and hash checks pass; license absent. |
| The sample is not the randomized NSW benchmark | design claim | Supported by current provenance; no population transport. |
| Re78 contrasts are observable associations | associational | Supported; explicit association labeling retained. |
| Cross-fitted AIPW returns an adjusted sample contrast under stated assumptions | counterfactual conditional | Computationally reproduced; identification unverified. |
| AIPW proves the NSW program benefited participants | causal | Unsupported. |
| The holdout score validates deployment | operational/confirmatory | Unsupported. |

## Assumptions

- **Verified at local computation level:** exact input bytes, split allocation, fold-local nuisance diagnostics, fit convergence, and byte-pinned artifact production.
- **Contradicted as an automatic claim:** "numerical convergence proves causal identification."
- **NO VERIFICABLE:** conditional exchangeability, selection-on-observables validity, broad support, scale-invariance of estimand, population transportability, data-value rights, external replay.

## Answer to the decision question

**No.** A project that has frozen arithmetic, rare honesty artifacts, and current-byte hashes is a strong evidence dossier; it is not an independently replicated causal evaluation and not a deployment warranty for this comparison.

## One next action

**Obtain a signed, documentary identification and redistribution review from a qualified external reviewer, using a new independently governed validation dataset or a legally cleared exact replica for fresh outcome-independent confirmation.** Do not re-open this holdout to chase a better estimate. The methodological risk is that another comparison reuses the same design choices and relabels a locally reproducible artifact as scientific confirmation.
