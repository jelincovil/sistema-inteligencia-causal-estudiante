use std::collections::BTreeMap;
use std::fs;
use std::path::Path;
use std::time::{SystemTime, UNIX_EPOCH};

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};

use crate::contract::Contract;
use crate::data::{
    audit_path, hash_file, read_dataset_path, sha256_hex, write_json, AuditReport, HoldoutEvent,
    HoldoutLedger, Record,
};
use crate::numeric::{
    normal_critical_value, NuisanceDiagnostics, NuisanceModels, NuisancePrediction,
};
use crate::split::{
    deterministic_assignments, validate_assignments_for_contract, Assignment, SplitRole,
};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CausalReport {
    pub schema_version: String,
    pub generated_by: String,
    pub status: String,
    pub dataset_id: String,
    pub contract_sha256: String,
    pub audit_sha256: String,
    pub splits_sha256: String,
    pub causal_identification_status: String,
    pub scientific_causal_claim_verified: bool,
    pub estimand: Estimand,
    pub protocol: ProtocolReport,
    pub descriptive: BTreeMap<String, DescriptiveContrast>,
    pub train_cross_fitted_aipw: AipwEstimate,
    pub train_fold_diagnostics: Vec<FoldDiagnostic>,
    pub deployed_nuisance_diagnostics: NuisanceDiagnostics,
    pub calibration: CalibrationReport,
    pub holdout: Option<HoldoutEvaluation>,
    pub sensitivity: Vec<SensitivityEstimate>,
    pub warnings: Vec<String>,
    pub limitations: Vec<String>,
    pub holdout_outcomes_used_for_model_selection: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Estimand {
    pub label: String,
    pub formula: String,
    pub interpretation: String,
    pub required_assumptions: Vec<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ProtocolReport {
    pub specification_frozen_before_holdout: bool,
    pub confidence_level: f64,
    pub adjustment_features: Vec<String>,
    pub outcome_excluded_from_adjustment: bool,
    pub propensity_learner: String,
    pub outcome_learner: String,
    pub train_folds: usize,
    pub primary_propensity_clip: f64,
    pub sensitivity_clips: Vec<f64>,
    pub calibration_use: String,
    pub holdout_use: String,
    pub standardization: String,
    pub dollar_deflation_applied: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct DescriptiveContrast {
    pub claim_type: String,
    pub observations: usize,
    pub treated_observations: usize,
    pub control_observations: usize,
    pub treated_outcome_mean: f64,
    pub control_outcome_mean: f64,
    pub difference_in_outcome_means: f64,
    pub formula: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AipwEstimate {
    pub role: String,
    pub observations: usize,
    pub treated_observations: usize,
    pub control_observations: usize,
    pub adjusted_mean_difference: f64,
    pub influence_function_standard_error: f64,
    pub confidence_level: f64,
    pub normal_interval_label: String,
    pub normal_interval_lower: f64,
    pub normal_interval_upper: f64,
    /// Compatibility mirror emitted only when the configured level is 0.95.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub normal_95_interval_lower: Option<f64>,
    /// Compatibility mirror emitted only when the configured level is 0.95.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub normal_95_interval_upper: Option<f64>,
    pub propensity_clip: f64,
    pub overlap: OverlapDiagnostics,
    pub interpretation: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OverlapDiagnostics {
    pub minimum_raw_propensity: f64,
    pub maximum_raw_propensity: f64,
    pub mean_raw_propensity: f64,
    pub p05_raw_propensity: f64,
    pub median_raw_propensity: f64,
    pub p95_raw_propensity: f64,
    pub raw_propensity_at_or_below_0_01: usize,
    pub raw_propensity_at_or_above_0_99: usize,
    pub raw_propensity_outside_0_05_to_0_95: usize,
    pub share_outside_0_05_to_0_95: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FoldDiagnostic {
    pub fold: usize,
    pub fit_observations: usize,
    pub evaluation_observations: usize,
    pub nuisance: NuisanceDiagnostics,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CalibrationReport {
    pub observations: usize,
    pub propensity_log_loss: f64,
    pub propensity_brier_score: f64,
    pub overlap: OverlapDiagnostics,
    pub gate_passed: bool,
    pub gate_reasons: Vec<String>,
    pub permitted_use: String,
    /// Legacy alias for `outcome_used_in_gate`, not a claim that outcomes are never read.
    pub outcome_used: bool,
    pub outcome_used_in_gate: bool,
    pub outcomes_reported_descriptively: bool,
    pub outcome_use_semantics: String,
    pub gate_interpretation: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HoldoutEvaluation {
    pub aipw: AipwEstimate,
    pub ledger_event_id: String,
    pub access_sequence: usize,
    pub reused_for_tuning: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SensitivityEstimate {
    pub role: String,
    pub propensity_clip: f64,
    pub adjusted_mean_difference: f64,
    pub confidence_level: f64,
    pub normal_interval_label: String,
    pub normal_interval_lower: f64,
    pub normal_interval_upper: f64,
    /// Compatibility mirror emitted only when the configured level is 0.95.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub normal_95_interval_lower: Option<f64>,
    /// Compatibility mirror emitted only when the configured level is 0.95.
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub normal_95_interval_upper: Option<f64>,
    pub selection_rule: String,
}

pub fn estimate_from_paths(
    input: &Path,
    contract_path: &Path,
    output_directory: &Path,
) -> Result<CausalReport> {
    let contract = Contract::load(contract_path)?;
    let output_audit_path = output_directory.join("audit.json");
    let splits_path = output_directory.join("splits.csv");
    let ledger_path = output_directory.join("holdout_ledger.json");
    let report_path = output_directory.join("causal_report.json");
    let audit = audit_path(&output_audit_path)?;
    verify_preparation(input, contract_path, &audit, &splits_path)?;

    let mut ledger: HoldoutLedger = serde_json::from_slice(&fs::read(&ledger_path)?)
        .with_context(|| format!("parsing {}", ledger_path.display()))?;
    if ledger.dataset_id != contract.dataset_id || !ledger.events.is_empty() {
        bail!("holdout has already been accessed or ledger dataset differs; use a new protocol/output directory, never a silent reset");
    }
    if ledger.audit_sha256 != hash_file(&output_audit_path)?
        || ledger.contract_sha256 != audit.contract_sha256
        || ledger.source_sha256 != audit.source.actual_sha256
        || ledger.split_manifest_sha256 != audit.split_manifest_sha256
    {
        bail!("preparation audit or its byte pins differ from the holdout ledger");
    }

    let data = read_dataset_path(input, &contract)?;
    if data.records.len() != audit.observation_count {
        bail!("current data row count differs from audit");
    }
    let assignments = read_assignments(&splits_path)?;
    validate_assignments_for_contract(&data.records, assignments.clone(), &contract)?;
    let expected = deterministic_assignments(&data.records, &contract)?;
    if assignments != expected {
        bail!("split manifest differs from deterministic contract assignments");
    }

    let train = records_for(&data.records, &assignments, SplitRole::Train);
    let calibration = records_for(&data.records, &assignments, SplitRole::Calibration);
    let holdout = records_for(&data.records, &assignments, SplitRole::Holdout);
    let fold_by_id = assignments
        .iter()
        .filter_map(|assignment| {
            assignment
                .fold
                .map(|fold| ((assignment.unit_id.as_str(), assignment.epoch), fold))
        })
        .collect::<BTreeMap<_, _>>();

    let mut train_scored = Vec::new();
    let mut fold_diagnostics = Vec::new();
    for fold in 0..contract.estimator.folds {
        let fit = train
            .iter()
            .copied()
            .filter(|record| fold_by_id[&(record.unit_id.as_str(), record.epoch)] != fold)
            .collect::<Vec<_>>();
        let evaluation = train
            .iter()
            .copied()
            .filter(|record| fold_by_id[&(record.unit_id.as_str(), record.epoch)] == fold)
            .collect::<Vec<_>>();
        if evaluation.is_empty() {
            bail!("cross-fitting fold {fold} is empty");
        }
        let models = NuisanceModels::fit(&fit, &contract.estimator)
            .with_context(|| format!("fitting cross-fit nuisance models for fold {fold}"))?;
        fold_diagnostics.push(FoldDiagnostic {
            fold,
            fit_observations: fit.len(),
            evaluation_observations: evaluation.len(),
            nuisance: models.diagnostics.clone(),
        });
        for record in evaluation {
            train_scored.push(Scored {
                record,
                prediction: models.predict(record),
            });
        }
    }
    train_scored.sort_by(|left, right| {
        (
            &left.record.unit_id,
            left.record.epoch,
            left.record.row_number,
        )
            .cmp(&(
                &right.record.unit_id,
                right.record.epoch,
                right.record.row_number,
            ))
    });
    let train_aipw = aipw_estimate(
        "train_cross_fitted",
        &train_scored,
        contract.estimator.primary_propensity_clip,
        contract.estimator.confidence_level,
    )?;

    // Only train-fitted X/T predictions and calibration X/T measurements enter the gate.
    let deployed = NuisanceModels::fit(&train, &contract.estimator)?;
    let calibration_scored = score(&calibration, &deployed);
    let gate = calibration_gate(&calibration_scored, &deployed.diagnostics)?;
    let calibration_report = CalibrationReport {
        observations: calibration_scored.len(),
        propensity_log_loss: log_loss(&calibration_scored),
        propensity_brier_score: brier_score(&calibration_scored),
        overlap: overlap(&calibration_scored),
        gate_passed: gate.is_empty(),
        gate_reasons: gate.clone(),
        permitted_use: "Computational and treatment-propensity gate using X/T only; descriptive calibration outcome means may subsequently be reported, never used for model selection or recalibration.".to_string(),
        outcome_used: false,
        outcome_used_in_gate: false,
        outcomes_reported_descriptively: true,
        outcome_use_semantics: "The legacy outcome_used field mirrors outcome_used_in_gate. Descriptive calibration outcome means are computed after the gate and reported as associations only; neither the gate nor descriptive reporting selects or revises models.".to_string(),
        gate_interpretation: "gate_passed is a computational X/T-only result, not scientific approval, positivity verification, or causal identification; inspect the weak-overlap counts beside it.".to_string(),
    };

    let mut warnings = Vec::new();
    for diagnostic in &fold_diagnostics {
        if !diagnostic.nuisance.propensity.converged {
            warnings.push(format!(
                "fold {} logistic IRLS did not converge",
                diagnostic.fold
            ));
        }
        if diagnostic.nuisance.propensity.separation_suspected {
            warnings.push(format!(
                "fold {} propensity fit has suspected separation/extreme probabilities",
                diagnostic.fold
            ));
        }
    }
    if deployed.diagnostics.propensity.separation_suspected {
        warnings.push(
            "Deployed train propensity fit has suspected separation/extreme probabilities."
                .to_string(),
        );
    }
    warnings.extend(gate.iter().cloned());

    let holdout_evaluation = if gate.is_empty() {
        // This is the sole branch that computes an estimate using holdout outcomes.
        let holdout_scored = score(&holdout, &deployed);
        Some(HoldoutEvaluation {
            aipw: aipw_estimate(
                "holdout_external_nuisance",
                &holdout_scored,
                contract.estimator.primary_propensity_clip,
                contract.estimator.confidence_level,
            )?,
            ledger_event_id: "H001-final-only".to_string(),
            access_sequence: 1,
            reused_for_tuning: false,
        })
    } else {
        None
    };
    let holdout_scored = if gate.is_empty() {
        score(&holdout, &deployed)
    } else {
        Vec::new()
    };
    let mut sensitivity = Vec::new();
    for clip in &contract.estimator.sensitivity_propensity_clips {
        let development = aipw_estimate(
            "train_cross_fitted",
            &train_scored,
            *clip,
            contract.estimator.confidence_level,
        )?;
        sensitivity.push(SensitivityEstimate {
            role: development.role.clone(),
            propensity_clip: *clip,
            adjusted_mean_difference: development.adjusted_mean_difference,
            confidence_level: development.confidence_level,
            normal_interval_label: development.normal_interval_label.clone(),
            normal_interval_lower: development.normal_interval_lower,
            normal_interval_upper: development.normal_interval_upper,
            normal_95_interval_lower: development.normal_95_interval_lower,
            normal_95_interval_upper: development.normal_95_interval_upper,
            selection_rule:
                "Predeclared sensitivity output; never choose a preferred clip by results."
                    .to_string(),
        });
        if gate.is_empty() {
            let final_estimate = aipw_estimate(
                "holdout_external_nuisance",
                &holdout_scored,
                *clip,
                contract.estimator.confidence_level,
            )?;
            sensitivity.push(SensitivityEstimate {
                role: final_estimate.role.clone(),
                propensity_clip: *clip,
                adjusted_mean_difference: final_estimate.adjusted_mean_difference,
                confidence_level: final_estimate.confidence_level,
                normal_interval_label: final_estimate.normal_interval_label.clone(),
                normal_interval_lower: final_estimate.normal_interval_lower,
                normal_interval_upper: final_estimate.normal_interval_upper,
                normal_95_interval_lower: final_estimate.normal_95_interval_lower,
                normal_95_interval_upper: final_estimate.normal_95_interval_upper,
                selection_rule:
                    "Predeclared sensitivity output; never choose a preferred clip by results."
                        .to_string(),
            });
        }
    }

    let descriptive = if gate.is_empty() {
        [
            ("all_observations", data.records.iter().collect::<Vec<_>>()),
            ("train", train.clone()),
            ("calibration", calibration.clone()),
            ("holdout", holdout.clone()),
        ]
        .into_iter()
        .map(|(name, records)| descriptive(&records).map(|contrast| (name.to_string(), contrast)))
        .collect::<Result<BTreeMap<_, _>>>()?
    } else {
        [
            ("train", train.clone()),
            ("calibration", calibration.clone()),
        ]
        .into_iter()
        .map(|(name, records)| descriptive(&records).map(|contrast| (name.to_string(), contrast)))
        .collect::<Result<BTreeMap<_, _>>>()?
    };
    let report = CausalReport {
        schema_version: "1.0".to_string(),
        generated_by: format!("causal-ml {}", env!("CARGO_PKG_VERSION")),
        status: if gate.is_empty() { "completed" } else { "stopped_before_holdout" }.to_string(),
        dataset_id: contract.dataset_id.clone(),
        contract_sha256: audit.contract_sha256.clone(),
        audit_sha256: hash_file(&output_audit_path)?,
        splits_sha256: audit.split_manifest_sha256.clone(),
        causal_identification_status: "conditional_assumptions_not_verified".to_string(),
        scientific_causal_claim_verified: false,
        estimand: Estimand {
            label: "Sample average adjusted treatment-contrast on each explicitly named split".to_string(),
            formula: "E[mu1(X)-mu0(X) + T(Y-mu1(X))/e(X) - (1-T)(Y-mu0(X))/(1-e(X))]".to_string(),
            interpretation: "Under consistency, noninterference, conditional mean exchangeability given the documented baseline covariates, positivity, and correct estimation protocol, this targets a split-specific ATE. These assumptions are neither tested nor certified here.".to_string(),
            required_assumptions: vec![
                "Consistency: observed Y equals the potential outcome for received treatment.".to_string(),
                "No relevant interference between NSW/PSID units.".to_string(),
                "Conditional mean exchangeability given only age, education, race, marital status, degree status, and 1974/1975 earnings.".to_string(),
                "Positivity over the target covariate support; clipping does not repair structural nonpositivity.".to_string(),
                "Well-defined NSW treatment and target population for the nonexperimental PSID comparison.".to_string(),
            ],
        },
        protocol: ProtocolReport {
            specification_frozen_before_holdout: true,
            confidence_level: contract.estimator.confidence_level,
            adjustment_features: contract.encoded_feature_names(),
            outcome_excluded_from_adjustment: true,
            propensity_learner: "Main-effects logistic IRLS with standardized contract features, unpenalized intercept and fixed ridge on other coefficients.".to_string(),
            outcome_learner: "Separate treatment-level linear least squares with standardized contract features and fixed ridge; predictions are not truncated to nonnegative earnings.".to_string(),
            train_folds: contract.estimator.folds,
            primary_propensity_clip: contract.estimator.primary_propensity_clip,
            sensitivity_clips: contract.estimator.sensitivity_propensity_clips.clone(),
            calibration_use: "One computational/treatment-propensity gate using calibration X and T only; descriptive calibration outcome means are subsequently computed and reported as associations, never for model selection or revision.".to_string(),
            holdout_use: "One final external-nuisance evaluation after the gate; append-only local ledger forbids repeat use in this protocol directory.".to_string(),
            standardization: "Feature means and population standard deviations recomputed on each fold's fit rows; constant columns use scale one.".to_string(),
            dollar_deflation_applied: false,
        },
        descriptive,
        train_cross_fitted_aipw: train_aipw.clone(),
        train_fold_diagnostics: fold_diagnostics,
        deployed_nuisance_diagnostics: deployed.diagnostics,
        calibration: calibration_report,
        holdout: holdout_evaluation,
        sensitivity,
        warnings,
        limitations: vec![
            "Unadjusted group differences are associational and include measured and unmeasured selection.".to_string(),
            "The NSW treated and PSID comparison samples do not create random assignment; unconfoundedness remains unverifiable.".to_string(),
            "Normal-reference influence-function intervals quantify a particular sampling approximation, not uncertainty from unmeasured confounding, dataset construction, model choice, or target-population transport.".to_string(),
            "Clipping changes inverse-probability weights and can hide weak overlap or introduce bias; sensitivity clips are not bias bounds.".to_string(),
            "Linear outcome models can predict negative earnings; model misspecification remains possible despite double robustness.".to_string(),
            "There are no repeated epochs, cluster-robust intervals, inflation adjustment, individual treatment-effect estimates, policy thresholds, or deployment claims.".to_string(),
        ],
        holdout_outcomes_used_for_model_selection: false,
    };

    let mut report_bytes = serde_json::to_vec_pretty(&report)?;
    report_bytes.push(b'\n');
    let report_sha256 = sha256_hex(&report_bytes);
    if holdout_evaluation_is_present(&report) {
        let accessed_at_unix_seconds = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .context("system clock precedes Unix epoch")?
            .as_secs();
        ledger.events.push(HoldoutEvent {
            event_id: "H001-final-only".to_string(),
            purpose:
                "Final predeclared external-nuisance AIPW evaluation; no subsequent model changes."
                    .to_string(),
            accessed_at_unix_seconds,
            report_sha256,
            split_manifest_sha256: audit.split_manifest_sha256.clone(),
            model_changes_permitted: false,
        });
        // Conservative crash behavior: record access before publishing the result.
        write_json(&ledger_path, &ledger)?;
    }
    fs::write(&report_path, report_bytes)?;
    Ok(report)
}

fn verify_preparation(
    input: &Path,
    contract_path: &Path,
    audit: &AuditReport,
    splits_path: &Path,
) -> Result<()> {
    if audit.status != "pass" {
        bail!("preparation audit did not pass");
    }
    if audit.issues.iter().any(|issue| issue.severity == "error") {
        bail!("preparation audit contains errors");
    }
    if audit.source.actual_sha256 != hash_file(input)?
        || !audit.source.bytes_match
        || !audit.source.sha256_matches
    {
        bail!("current source differs from audited byte pin");
    }
    if audit.contract_sha256 != hash_file(contract_path)? {
        bail!("contract changed after preparation");
    }
    if audit.split_manifest_sha256 != hash_file(splits_path)? {
        bail!("split manifest changed after preparation");
    }
    Ok(())
}

fn read_assignments(path: &Path) -> Result<Vec<Assignment>> {
    let mut reader = csv::Reader::from_path(path)?;
    let mut assignments = Vec::new();
    for row in reader.records() {
        let row = row?;
        if row.len() != 4 {
            bail!("split manifest needs unit_id, epoch, role, fold");
        }
        let role = match &row[2] {
            "train" => SplitRole::Train,
            "calibration" => SplitRole::Calibration,
            "holdout" => SplitRole::Holdout,
            other => bail!("invalid split role {other}"),
        };
        assignments.push(Assignment {
            unit_id: row[0].to_string(),
            epoch: empty_none(&row[1]).map(str::parse).transpose()?,
            role,
            fold: empty_none(&row[3]).map(str::parse).transpose()?,
        });
    }
    assignments.sort_by(|left, right| {
        (&left.unit_id, left.epoch)
            .cmp(&(&right.unit_id, right.epoch))
            .then(left.role.cmp(&right.role))
    });
    Ok(assignments)
}

fn empty_none(value: &str) -> Option<&str> {
    if value.is_empty() {
        None
    } else {
        Some(value)
    }
}

fn records_for<'a>(
    records: &'a [Record],
    assignments: &[Assignment],
    role: SplitRole,
) -> Vec<&'a Record> {
    let ids = assignments
        .iter()
        .filter(|assignment| assignment.role == role)
        .map(|assignment| (assignment.unit_id.as_str(), assignment.epoch))
        .collect::<std::collections::BTreeSet<_>>();
    records
        .iter()
        .filter(|record| ids.contains(&(record.unit_id.as_str(), record.epoch)))
        .collect()
}

#[derive(Clone)]
struct Scored<'a> {
    record: &'a Record,
    prediction: NuisancePrediction,
}

fn score<'a>(records: &[&'a Record], models: &NuisanceModels) -> Vec<Scored<'a>> {
    records
        .iter()
        .map(|record| Scored {
            record,
            prediction: models.predict(record),
        })
        .collect()
}

fn calibration_gate(scores: &[Scored], diagnostics: &NuisanceDiagnostics) -> Result<Vec<String>> {
    if scores.is_empty() {
        bail!("calibration role is empty");
    }
    let mut reasons = Vec::new();
    if !diagnostics.propensity.converged {
        reasons.push("Train propensity IRLS did not converge.".to_string());
    }
    if scores.iter().any(|score| {
        let p = score.prediction.raw_propensity;
        !p.is_finite()
            || !score.prediction.outcome_control.is_finite()
            || !score.prediction.outcome_treated.is_finite()
    }) {
        reasons.push("Non-finite calibration nuisance prediction.".to_string());
    }
    if !scores.iter().any(|score| score.record.treatment == 0.0)
        || !scores.iter().any(|score| score.record.treatment == 1.0)
    {
        reasons.push("Calibration role lacks a treatment level.".to_string());
    }
    Ok(reasons)
}

fn aipw_estimate(
    role: &str,
    scores: &[Scored],
    clip: f64,
    confidence: f64,
) -> Result<AipwEstimate> {
    if scores.len() < 2 {
        bail!("AIPW requires at least two observations in role {role}");
    }
    let mut terms = Vec::new();
    for score in scores {
        let e = score.prediction.raw_propensity.clamp(clip, 1.0 - clip);
        let t = score.record.treatment;
        let y = score.record.outcome;
        let contrast = score.prediction.outcome_treated - score.prediction.outcome_control;
        let residual = t * (y - score.prediction.outcome_treated) / e
            - (1.0 - t) * (y - score.prediction.outcome_control) / (1.0 - e);
        let value = contrast + residual;
        if !value.is_finite() {
            bail!("non-finite AIPW score in role {role}");
        }
        terms.push(value);
    }
    let estimate = terms.iter().sum::<f64>() / terms.len() as f64;
    let variance = terms
        .iter()
        .map(|term| (term - estimate).powi(2))
        .sum::<f64>()
        / (terms.len() - 1) as f64;
    let standard_error = (variance / terms.len() as f64).sqrt();
    let critical = normal_critical_value(confidence);
    let lower = estimate - critical * standard_error;
    let upper = estimate + critical * standard_error;
    let emit_legacy_95_fields = (confidence - 0.95).abs() < f64::EPSILON;
    Ok(AipwEstimate {
        role: role.to_string(),
        observations: scores.len(),
        treated_observations: scores.iter().filter(|score| score.record.treatment == 1.0).count(),
        control_observations: scores.iter().filter(|score| score.record.treatment == 0.0).count(),
        adjusted_mean_difference: estimate,
        influence_function_standard_error: standard_error,
        confidence_level: confidence,
        normal_interval_label: normal_interval_label(confidence),
        normal_interval_lower: lower,
        normal_interval_upper: upper,
        normal_95_interval_lower: emit_legacy_95_fields.then_some(lower),
        normal_95_interval_upper: emit_legacy_95_fields.then_some(upper),
        propensity_clip: clip,
        overlap: overlap(scores),
        interpretation: "Adjusted sample contrast, causal only under the stated untestable identification assumptions; interval omits confounding and transport uncertainty.".to_string(),
    })
}

pub fn confidence_percentage(confidence: f64) -> String {
    format!("{}", 100.0 * confidence)
}

pub fn normal_interval_label(confidence: f64) -> String {
    format!("normal {}% interval", confidence_percentage(confidence))
}

fn descriptive(records: &[&Record]) -> Result<DescriptiveContrast> {
    let treated = records
        .iter()
        .filter(|record| record.treatment == 1.0)
        .map(|record| record.outcome)
        .collect::<Vec<_>>();
    let control = records
        .iter()
        .filter(|record| record.treatment == 0.0)
        .map(|record| record.outcome)
        .collect::<Vec<_>>();
    if treated.is_empty() || control.is_empty() {
        bail!("descriptive contrast requires both treatment groups");
    }
    let treated_outcome_mean = mean(&treated);
    let control_outcome_mean = mean(&control);
    Ok(DescriptiveContrast {
        claim_type: "association_only".to_string(),
        observations: records.len(),
        treated_observations: treated.len(),
        control_observations: control.len(),
        treated_outcome_mean,
        control_outcome_mean,
        difference_in_outcome_means: treated_outcome_mean - control_outcome_mean,
        formula: "mean(Y | T=1) - mean(Y | T=0); not E[Y(1)-Y(0)] without identification"
            .to_string(),
    })
}

fn overlap(scores: &[Scored]) -> OverlapDiagnostics {
    let mut probabilities = scores
        .iter()
        .map(|score| score.prediction.raw_propensity)
        .collect::<Vec<_>>();
    probabilities.sort_by(f64::total_cmp);
    let outside = probabilities
        .iter()
        .filter(|value| **value < 0.05 || **value > 0.95)
        .count();
    OverlapDiagnostics {
        minimum_raw_propensity: probabilities[0],
        maximum_raw_propensity: probabilities[probabilities.len() - 1],
        mean_raw_propensity: mean(&probabilities),
        p05_raw_propensity: quantile(&probabilities, 0.05),
        median_raw_propensity: quantile(&probabilities, 0.50),
        p95_raw_propensity: quantile(&probabilities, 0.95),
        raw_propensity_at_or_below_0_01: probabilities.iter().filter(|p| **p <= 0.01).count(),
        raw_propensity_at_or_above_0_99: probabilities.iter().filter(|p| **p >= 0.99).count(),
        raw_propensity_outside_0_05_to_0_95: outside,
        share_outside_0_05_to_0_95: outside as f64 / probabilities.len() as f64,
    }
}

fn log_loss(scores: &[Scored]) -> f64 {
    -scores
        .iter()
        .map(|score| {
            let p = score.prediction.raw_propensity.clamp(1e-15, 1.0 - 1e-15);
            score.record.treatment * p.ln() + (1.0 - score.record.treatment) * (1.0 - p).ln()
        })
        .sum::<f64>()
        / scores.len() as f64
}

fn brier_score(scores: &[Scored]) -> f64 {
    scores
        .iter()
        .map(|score| (score.record.treatment - score.prediction.raw_propensity).powi(2))
        .sum::<f64>()
        / scores.len() as f64
}

fn quantile(sorted: &[f64], probability: f64) -> f64 {
    let position = probability * (sorted.len() - 1) as f64;
    let lower = position.floor() as usize;
    let upper = position.ceil() as usize;
    sorted[lower] + (position - lower as f64) * (sorted[upper] - sorted[lower])
}

fn mean(values: &[f64]) -> f64 {
    values.iter().sum::<f64>() / values.len() as f64
}

fn holdout_evaluation_is_present(report: &CausalReport) -> bool {
    report.holdout.is_some()
}

#[cfg(test)]
mod tests {
    use super::*;

    fn constant_effect_records() -> Vec<Record> {
        (0..20)
            .map(|index| Record {
                row_number: index + 2,
                unit_id: format!("u{index}"),
                epoch: None,
                treatment: (index % 2) as f64,
                outcome: if index % 2 == 0 { 2.0 } else { 5.0 },
                features: vec![0.0],
            })
            .collect()
    }

    fn constant_effect_scores(records: &[Record]) -> Vec<Scored<'_>> {
        records
            .iter()
            .map(|record| Scored {
                record,
                prediction: NuisancePrediction {
                    raw_propensity: 0.5,
                    outcome_control: 2.0,
                    outcome_treated: 5.0,
                },
            })
            .collect()
    }

    #[test]
    fn influence_function_recovers_constant_outcome_effect() {
        let records = constant_effect_records();
        let scores = constant_effect_scores(&records);
        let result = aipw_estimate("test", &scores, 0.05, 0.95).expect("AIPW");
        assert!((result.adjusted_mean_difference - 3.0).abs() < 1e-12);
        assert!(result.influence_function_standard_error < 1e-12);
        assert_eq!(result.confidence_level, 0.95);
        assert_eq!(result.normal_interval_label, "normal 95% interval");
        assert_eq!(
            result.normal_95_interval_lower,
            Some(result.normal_interval_lower)
        );
        assert_eq!(
            result.normal_95_interval_upper,
            Some(result.normal_interval_upper)
        );
    }

    #[test]
    fn configured_confidence_drives_interval_labels_and_legacy_fields() {
        let records = constant_effect_records();
        let scores = constant_effect_scores(&records);
        let result = aipw_estimate("test", &scores, 0.05, 0.90).expect("90% AIPW");
        assert_eq!(result.confidence_level, 0.90);
        assert_eq!(result.normal_interval_label, "normal 90% interval");
        assert_eq!(result.normal_95_interval_lower, None);
        assert_eq!(result.normal_95_interval_upper, None);
        let expected_margin =
            normal_critical_value(0.90) * result.influence_function_standard_error;
        assert!((result.normal_interval_lower - (3.0 - expected_margin)).abs() < 1e-12);
        assert!((result.normal_interval_upper - (3.0 + expected_margin)).abs() < 1e-12);

        let json = serde_json::to_value(&result).expect("serialize 90% estimate");
        let object = json.as_object().expect("estimate object");
        assert!(!object.contains_key("normal_95_interval_lower"));
        assert!(!object.contains_key("normal_95_interval_upper"));
        assert_eq!(
            object.get("normal_interval_label"),
            Some(&serde_json::Value::String(
                "normal 90% interval".to_string()
            ))
        );
    }

    #[test]
    fn quantiles_interpolate_deterministically() {
        assert_eq!(quantile(&[0.0, 1.0], 0.5), 0.5);
        assert_eq!(quantile(&[0.0, 1.0], 0.25), 0.25);
    }
}
