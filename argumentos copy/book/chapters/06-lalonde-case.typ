= Executable LaLonde / NSW Case <evidence-boundary>

== Data lineage and scientific design

The real-data input is the unmodified MatchIt `lalonde` CSV distributed by Rdatasets at a commit-bound URL. The source documentation describes NSW treated people and a nonexperimental PSID comparison group, as analyzed by Dehejia and Wahba following LaLonde and reviewed as a labor-market-program evaluation design in @heckman1999 @dehejia1999 @lalonde1986. The case therefore studies the Dehejia–Wahba-style nonexperimental comparison, not the NSW randomized benchmark and not synthetic or IHDP data.

The observation unit is a source-row individual identified by `rownames`; treatment is `treat`; outcome is nominal-dollar 1978 earnings `re78`. Candidate baseline features are age, education, race, marital status, degree status, and 1974/1975 earnings. The feature contract declares their pre-treatment availability and excludes `re78` from adjustment. No epoch column is supplied. Stable IDs allow deterministic entity separation but do not enable a temporal split or prove a correct historical point-in-time join.

Source provenance is pinned in `data/real/PROVENANCE.md`: exact URL, retrieval time, source-document links, byte count, SHA-256, and an explicit `unresolved_upstream` status for the license of the data values. Package-level licensing statements are not silently assigned to those values. The included artifact is a reproducibility pin, not a new legal grant.

== Frozen protocol before final holdout use

The configuration `config/lalonde.contract.json` freezes the roles and computation:

+ deterministic 60/20/20 train/calibration/holdout assignment by salted entity hash;
+ five deterministic folds within train only;
+ declared transforms and fold-specific standardization;
+ main-effects logistic IRLS propensity with fixed ridge on non-intercept coefficients;
+ separate ridge-linear treated and control outcome models;
+ primary propensity clip 0.05 and fixed sensitivity clips 0.01 and 0.10;
+ a calibration gate using only features and treatment, followed by descriptive calibration outcome means reported as associations and never used for selection or revision; and
+ one final holdout evaluation with nuisances fitted on train only.

No holdout outcome is used to select features, learners, fold counts, ridge strength, clipping, or a preferred sensitivity result. Train cross-fitting answers the training protocol; holdout evaluation is external to nuisance fitting but remains part of the same observational study and identification limitations. If the gate fails, the run stops before holdout outcomes are evaluated or reported; raw CSV parsing and all-record preparation summaries still occur, but they are not outcome evaluation or model selection. The local holdout ledger records use and refuses a repeat estimation in the same protocol directory. It is reproducibility bookkeeping, not a tamper-proof external timestamp.

Report generation is a separate read-only transformation of pinned artifacts into Markdown and Typst. The fragment in this chapter is selected from `book/generated/lalonde.typ`, so its rounded empirical values and intervals come from pipeline output rather than manual transcription.

== Artifact-generated computational record

#include "../generated/lalonde.typ"

== Interpretation after the artifact

Three distinctions are essential when reading these results.

First, the descriptive treated-minus-control differences are *associational summaries*. They are not experimental NSW effects and should not be compared naively with a randomized estimate as if both shared the same target and assignment mechanism.

Second, the AIPW values are *adjusted sample contrasts under a frozen estimator*. A causal reading would require consistency, noninterference, conditional exchangeability given the declared baseline features, positivity on the target support, correct treatment definition, and a defensible target and observation model. The CSV cannot prove these. Estimated overlap weakness and sensitivity to clipping are substantive computational warnings, not model-selection invitations.

Third, the normal-reference intervals describe a particular sampling approximation conditional on this protocol. Their labels and generic bounds use the configured `confidence_level` (0.95 here); legacy `normal_95_*` fields are compatibility aliases emitted only at 0.95. They do not incorporate hidden-confounding bias, dataset-construction uncertainty, or transport to other workers, periods, or training programs. Numerical convergence and the absence of suspected separation similarly do not establish causal identification or outcome-model correctness. A passing gate is only computational; the adjacent weak-overlap warning does not disappear when the gate passes.

The saved causal report therefore keeps `scientific_causal_claim_verified = false`. A defensible conclusion is limited: this exact source, contract, and code reproducibly generated these descriptive and adjusted summaries, with the documented numerical and support diagnostics. They do not establish a deployable treatment policy or a verified population causal effect.
