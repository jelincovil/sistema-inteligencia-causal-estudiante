# Atom registry — `causal_ml.json`

The top-level `atoms` array in `causal_ml.json` is the closed registry of every
atom used by any claim expression in the corpus. Each entry maps one atom id to
the claim that defines it (`definition_claim`) and carries a short
plain-language `description`. The registry is content, not status: it has no
approval, replay, or scientific-support fields, and no atom may exist outside
it.

- An atom used in an expression but absent from the registry is a load error in
  the updated loader; an atom registered but never used is also rejected.
- `definition_claim` is the owning claim, not evidence the claim holds.
- Registry entries are validated as structure only. They never promote a claim.
- Schema 1.1, profile `scientific_audit`: no new major version was introduced.

## Registry by owning claim

| Atom | Owning claim | Meaning |
| --- | --- | --- |
| association_observed_distribution_only | C.taxonomy.association | Associational contrast = functional of observed joint distribution |
| prediction_not_counterfactual | C.taxonomy.prediction | Prediction concerns unseen draws, not intervention effects |
| counterfactual_requires_identification | C.taxonomy.counterfactual | Counterfactual claims need estimand + identification assumptions |
| operational_readiness_not_causal_validity | C.taxonomy.operational | Executable pipeline ≠ causal validity (boundary interpretation) |
| consistency | C.assumption.consistency | Y equals potential outcome for received treatment |
| noninterference | C.assumption.noninterference | No cross-unit potential-outcome dependence |
| conditional_mean_exchangeability | C.assumption.exchangeability | Mean exchangeability given declared baseline covariates (untestable) |
| positivity_on_target_support | C.assumption.positivity | Both treatment arms strictly possible on target support |
| valid_baseline_adjustment_set | C.identification.adjustment_set | Declared adjustment set blocks declared backdoor paths (substantive) |
| ate_identified_from_observed_distribution | C.identified | ATE identification, conditional on the full five-atom conjunction |
| cross_fitted_aipw_score | C.estimator.aipw | Implemented cross-fitted AIPW score definition |
| pinned_lalonde_bytes | C.data.provenance.pin | 27,509-byte CSV with pinned SHA-256 |
| pinned_lalonde_url | C.data.provenance.url | Commit-bound Rdatasets MatchIt locator URL |
| data_value_license_unresolved | C.data.license | Data-value license remains unresolved_upstream |
| lalonde_observation_count | C.data.schema.rows | audit.json observation_count = 614 |
| lalonde_declared_columns_present | C.data.schema.columns | Ten declared columns present, zero missing cells |
| lalonde_exact_duplicate_records_zero | C.data.schema.exact_duplicates | audit.json exact_duplicate_record_count = 0 |
| lalonde_duplicate_unit_ids_zero | C.data.schema.duplicate_ids | audit.json duplicate_unit_or_unit_epoch_ids = [] |
| lalonde_repeated_measurement_vectors | C.data.schema.repeated_measurements | Five repeated measurement vectors (warnings) |
| feature_availability_contract | C.data.feature_availability | Pre-1975 availability, pre_treatment_adjustment role |
| re78_excluded_from_adjustment | C.data.features.outcome_excluded | re78 is the outcome, not an adjustment feature |
| log1p_transform_frozen_re74_re75 | C.data.features.log1p_transform | Frozen log1p on re74/re75 only |
| entity_hash_split_roles | C.data.split_governance | Deterministic entity_hash under the protocol salt |
| split_fractions_060_020_020 | C.data.split.fractions | Declared 0.6/0.2/0.2 train/calibration/holdout |
| entity_disjoint_roles_zero_overlap | C.data.split.entity_disjoint | Cross-role unit overlaps are zero (audit leakage_checks) |
| temporal_governance_unavailable | C.data.epoch_unavailable | No epoch; temporal separation unavailable |
| frozen_cross_fitting_protocol | C.protocol.cross_fitting | Estimator cross_fitted_aipw_logistic_linear_v1, 5 folds |
| logistic_irls_propensity | C.protocol.propensity_fit | Main-effects logistic IRLS, max 100 iters, tol 1E-8, ridge 1E-6 |
| primary_propensity_clip_005 | C.protocol.primary_clip | Primary propensity clip 0.05 |
| sensitivity_propensity_clips_001_010 | C.protocol.sensitivity_clips | Predeclared sensitivity clips 0.01 and 0.1 |
| ridge_linear_outcome_models | C.protocol.outcome_models | Treatment-level ridge-linear least squares, no truncation |
| single_holdout_event | C.empirical.holdout.event | Ledger records one final-only event H001-final-only |
| holdout_access_sequence_1 | C.empirical.holdout.access | Report records access_sequence 1 |
| holdout_not_reused_for_tuning | C.empirical.holdout.tuning | Report records reused_for_tuning false |
| unadjusted_all_observation_contrast | C.empirical.unadjusted_all | All-observation unadjusted contrast, association only |
| train_aipw_005 | C.empirical.aipw_train | Train cross-fitted AIPW at clip 0.05 |
| holdout_aipw_005 | C.empirical.aipw_holdout | Holdout external-nuisance AIPW at clip 0.05 |
| holdout_aipw_clip_001 | C.empirical.aipw_holdout_clip_001 | Holdout external-nuisance AIPW at predeclared clip 0.01 |
| holdout_aipw_clip_010 | C.empirical.aipw_holdout_clip_010 | Holdout external-nuisance AIPW at predeclared clip 0.10 |
| weak_estimated_overlap_train | C.empirical.overlap.train | 138/366 train rows outside [0.05, 0.95] raw propensity |
| weak_estimated_overlap_holdout | C.empirical.overlap.holdout | 41/134 holdout rows outside [0.05, 0.95] raw propensity |
| nuisance_numerics_converged_train_folds | C.empirical.computational_train_folds | Five train-fold propensity fits converged, no separation |
| nuisance_numerics_converged_deployed | C.empirical.computational_deployed | Deployed propensity fit converged, no separation |
| hidden_confounding_unbounded_by_this_run | C.limit.unmeasured_confounding | Unmeasured selection not ruled out (limitation) |
| transport_not_identified | C.limit.transportability | No transport design; other populations not established |
| sampling_interval_omits_structural_uncertainty | C.limit.uncertainty | Intervals omit confounding/model/transport uncertainty |
| deployment_requires_external_monitoring | C.deployment.monitoring | Deployment needs monitoring/rollback; none here |
| argument_structure_is_not_claim_support | C.argument.reconstruction_limits | Dossier reconstructs dependencies, not support |
| conditional_causal_interpretation_only | C.claim.conditional_causal | Conditional split-specific interpretation; dossier only |

Compound dossier claims (`C.assumptions.conjunction`, `C.backdoor.theorem`,
`C.protocol.complete`) own no atoms; they compose registered atoms and are
listed here only to make the ownership boundary explicit.

This document describes the registry as of the corpus rewrite; it is not
scientific approval and not a license grant for the data values, which remain
`unresolved_upstream`.

## Base scope of the ATE dossier

Claims that participate in the two ATE-dossier derivations
(`A.assumptions.conjunction`, `A.backdoor.modus_ponens`,
`A.protocol.conjunction`, `A.causal.conditional_only`) carry the same four
base scope keys exactly:
`dataset=rdatasets-matchit-lalonde-pinned-v1`,
`protocol=causal-ml-lalonde-protocol-v1-no-outcome-tuning`, `estimand=ATE`,
`setting=single_timepoint_binary_treatment`.

Premises of the dossier arguments may additionally retain the checker's
aggregation keys (`role`, `clip`, `diagnostic`, `claim_class`) where the
specific fact is detail-specific (for example `C.empirical.aipw_train` keeps
`clip=0.05` and `role=train_cross_fitted`; `C.protocol.primary_clip` keeps
`clip=0.05`). Aggregation keys may be absent from a derivation conclusion.
Conjunctions and dossiers carry exactly the four base keys. Claims outside
the dossier derivations (taxonomy, schema-only audit facts,
`C.data.split.entity_disjoint`, deployment monitoring) keep their narrower
scopes unchanged.

Two honest consequences of the strict scope checker are recorded here:
`limitation` is not an aggregation key in the current checker
(`AGGREGATION_KEYS = role|clip|diagnostic|claim_class`), so the three
limitation claims carry exactly the four base keys and the limitation role is
carried by the claim id, atom and statement; and no premise carries
`claim_class`, so the counterfactual dossier conclusion drops `claim_class`
rather than fabricating a counterfactual category onto evidence claims.
