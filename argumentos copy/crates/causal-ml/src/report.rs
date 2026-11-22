use std::fmt::Write as _;
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use serde::Serialize;

use crate::contract::Contract;
use crate::data::{hash_file, sha256_hex, AuditReport, HoldoutLedger};
use crate::estimate::{confidence_percentage, AipwEstimate, CausalReport};

#[derive(Debug, Clone, Serialize)]
pub struct RenderedReport {
    pub markdown_path: PathBuf,
    pub typst_path: PathBuf,
    pub report_sha256: String,
    pub scientific_causal_claim_verified: bool,
}

/// Render prose from verified artifacts. This command never opens the raw data,
/// fits a model, evaluates outcomes, or changes a holdout ledger.
pub fn render_from_paths(
    output_directory: &Path,
    contract_path: &Path,
    markdown_path: &Path,
    typst_path: &Path,
) -> Result<RenderedReport> {
    let contract = Contract::load(contract_path)?;
    let audit_path = output_directory.join("audit.json");
    let splits_path = output_directory.join("splits.csv");
    let report_path = output_directory.join("causal_report.json");
    let ledger_path = output_directory.join("holdout_ledger.json");
    let audit: AuditReport = serde_json::from_slice(&fs::read(&audit_path)?)
        .with_context(|| format!("parsing {}", audit_path.display()))?;
    let report_bytes = fs::read(&report_path)?;
    let report: CausalReport = serde_json::from_slice(&report_bytes)
        .with_context(|| format!("parsing {}", report_path.display()))?;
    let ledger: HoldoutLedger = serde_json::from_slice(&fs::read(&ledger_path)?)
        .with_context(|| format!("parsing {}", ledger_path.display()))?;
    let report_sha256 = verify_artifacts(
        &contract,
        &audit,
        &report,
        &ledger,
        &report_bytes,
        &audit_path,
        &splits_path,
        contract_path,
    )?;

    let markdown = markdown_report(&contract, &audit, &report, &ledger, &report_sha256)?;
    let typst = typst_fragment(&contract, &audit, &report, &report_sha256);
    write_text(markdown_path, &markdown)?;
    write_text(typst_path, &typst)?;
    Ok(RenderedReport {
        markdown_path: markdown_path.to_path_buf(),
        typst_path: typst_path.to_path_buf(),
        report_sha256,
        scientific_causal_claim_verified: report.scientific_causal_claim_verified,
    })
}

#[allow(clippy::too_many_arguments)]
fn verify_artifacts(
    contract: &Contract,
    audit: &AuditReport,
    report: &CausalReport,
    ledger: &HoldoutLedger,
    report_bytes: &[u8],
    audit_path: &Path,
    splits_path: &Path,
    contract_path: &Path,
) -> Result<String> {
    let actual_audit_sha256 = hash_file(audit_path)?;
    let actual_contract_sha256 = hash_file(contract_path)?;
    let actual_splits_sha256 = hash_file(splits_path)?;
    let report_sha256 = sha256_hex(report_bytes);
    if report.dataset_id != contract.dataset_id || audit.dataset_id != contract.dataset_id {
        bail!("artifact dataset IDs differ from the contract");
    }
    if report.contract_sha256 != actual_contract_sha256
        || audit.contract_sha256 != actual_contract_sha256
        || ledger.contract_sha256 != actual_contract_sha256
    {
        bail!("artifact contract SHA-256 mismatch");
    }
    if report.audit_sha256 != actual_audit_sha256 || ledger.audit_sha256 != actual_audit_sha256 {
        bail!("artifact audit SHA-256 mismatch");
    }
    if report.splits_sha256 != actual_splits_sha256
        || audit.split_manifest_sha256 != actual_splits_sha256
        || ledger.split_manifest_sha256 != actual_splits_sha256
    {
        bail!("artifact split-manifest SHA-256 mismatch");
    }
    if ledger.source_sha256 != audit.source.actual_sha256
        || !audit.source.bytes_match
        || !audit.source.sha256_matches
        || audit.source.expected_sha256 != contract.source.expected_sha256
    {
        bail!("artifact source pin mismatch");
    }
    if report.scientific_causal_claim_verified || report.holdout_outcomes_used_for_model_selection {
        bail!("report contains an impermissible scientific-validity or tuning assertion");
    }
    match (&report.holdout, ledger.events.as_slice()) {
        (Some(holdout), [event]) => {
            if event.report_sha256 != report_sha256
                || event.split_manifest_sha256 != actual_splits_sha256
                || event.event_id != holdout.ledger_event_id
                || event.model_changes_permitted
                || holdout.reused_for_tuning
            {
                bail!("final holdout evaluation does not match its ledger event");
            }
        }
        (None, []) if report.status == "stopped_before_holdout" => {}
        _ => bail!("holdout presence and ledger events are inconsistent"),
    }
    Ok(report_sha256)
}

fn markdown_report(
    contract: &Contract,
    audit: &AuditReport,
    report: &CausalReport,
    ledger: &HoldoutLedger,
    report_sha256: &str,
) -> Result<String> {
    let mut out = String::new();
    writeln!(
        out,
        "# Executable LaLonde case: audit and conditional AIPW\n"
    )?;
    writeln!(
        out,
        "> **Evidence boundary.** Raw group contrasts are associational. AIPW is an adjusted estimator whose causal interpretation requires assumptions that this dataset and software cannot establish path-by-path. `scientific_causal_claim_verified = {}`.\n",
        report.scientific_causal_claim_verified
    )?;
    writeln!(out, "## Frozen protocol and provenance\n")?;
    writeln!(out, "- Dataset ID: `{}`.", inline(&contract.dataset_id))?;
    writeln!(out, "- Data: {}.", inline(&contract.description))?;
    writeln!(out, "- Raw URL: <{}>.", contract.source.raw_url)?;
    writeln!(
        out,
        "- Documentation URL: <{}>.",
        contract.source.documentation_url
    )?;
    writeln!(
        out,
        "- Exact input: {} bytes; SHA-256 `{}`; byte match `{}`; digest match `{}`.",
        audit.source.actual_bytes,
        audit.source.actual_sha256,
        audit.source.bytes_match,
        audit.source.sha256_matches
    )?;
    writeln!(out, "- Contract SHA-256: `{}`.", report.contract_sha256)?;
    writeln!(out, "- Audit SHA-256: `{}`.", report.audit_sha256)?;
    writeln!(out, "- Split SHA-256: `{}`.", report.splits_sha256)?;
    writeln!(out, "- Causal report SHA-256: `{report_sha256}`.")?;
    writeln!(out, "- Data-value license status: `unresolved_upstream`; see `data/real/PROVENANCE.md`. This is not a new license grant.")?;
    writeln!(
        out,
        "- Estimator: `{}`; predeclared sensitivity clips `{:?}`; primary clip `{}`.",
        report.protocol.propensity_learner,
        report.protocol.sensitivity_clips,
        report.protocol.primary_propensity_clip
    )?;
    writeln!(out, "- Split roles: train for cross-fitting and deployed nuisance fitting; calibration for X/T-only computational and treatment-propensity gate diagnostics, with outcome means subsequently reported descriptively and never used for selection; holdout for one final external-nuisance evaluation." )?;
    writeln!(out, "- Split assignment: `{}`, fractions {:.2}/{:.2}/{:.2}; five-fold assignment occurs only in train.", contract.split.protocol_salt, contract.split.train_fraction, contract.split.calibration_fraction, contract.split.holdout_fraction)?;
    writeln!(out, "- Feature availability: only declared pre-treatment columns enter adjustment; `{}` is excluded as the post-treatment outcome.", contract.outcome.name)?;
    writeln!(
        out,
        "- Temporal governance: {}",
        sentence(&audit.temporal_governance)
    )?;
    writeln!(out, "\n## Data audit\n")?;
    writeln!(
        out,
        "- Observations: **{}**; treatment counts: `{:?}`.",
        audit.observation_count, audit.treatment_counts
    )?;
    writeln!(
        out,
        "- Split counts: `{:?}`; fold counts: `{:?}`.",
        audit.split_counts, audit.fold_counts
    )?;
    let missing = audit
        .columns
        .iter()
        .map(|column| column.missing)
        .sum::<usize>();
    writeln!(out, "- Required/optional missing cells across declared columns: **{missing}**. Exact duplicate rows: **{}**. Duplicate unit or unit/epoch keys: **{}**. Repeated measurement vectors excluding ID: **{}** (warning, not automatic duplication of persons).", audit.exact_duplicate_record_count, audit.duplicate_unit_or_unit_epoch_ids.len(), audit.duplicate_measurement_rows_excluding_id)?;
    writeln!(
        out,
        "- Leakage diagnostics: entity-disjoint `{}`, epoch-disjoint `{}`. {}",
        audit.leakage_checks.entity_disjoint_verified,
        audit.leakage_checks.epoch_disjoint_verified,
        sentence(&audit.leakage_checks.detail)
    )?;
    writeln!(
        out,
        "\n| Column | Declared type | Non-missing | Missing | Distinct | Minimum | Maximum |"
    )?;
    writeln!(out, "|---|---:|---:|---:|---:|---:|---:|")?;
    for column in &audit.columns {
        writeln!(
            out,
            "| `{}` | {:?} | {} | {} | {} | {} | {} |",
            inline(&column.name),
            column.declared_type,
            column.non_missing,
            column.missing,
            column.distinct,
            optional_number(column.minimum),
            optional_number(column.maximum)
        )?;
    }
    writeln!(out, "\n### Feature-availability contract\n")?;
    writeln!(
        out,
        "| Field | Available at | Role | Transform | Excluded from adjustment |"
    )?;
    writeln!(out, "|---|---|---|---|---:|")?;
    for feature in &audit.feature_availability {
        writeln!(
            out,
            "| `{}` | {} | {} | {:?} | {} |",
            inline(&feature.name),
            inline(&feature.available_at),
            inline(&feature.causal_role),
            feature.transform,
            feature.excluded_from_adjustment
        )?;
    }
    if !audit.issues.is_empty() {
        writeln!(out, "\n### Audit issues\n")?;
        for issue in &audit.issues {
            writeln!(
                out,
                "- **{} / {}**: {}",
                issue.severity,
                issue.code,
                sentence(&issue.detail)
            )?;
        }
    }
    writeln!(out, "\n## Descriptive contrasts — association only\n")?;
    writeln!(out, "The estimand below is `mean(Y | T=1) - mean(Y | T=0)` within each named subset. It is not an average treatment effect without identification. All dollar values are nominal source dollars; no deflation is applied.\n")?;
    writeln!(
        out,
        "| Scope | n | Treated n | Control n | Treated mean | Control mean | Difference |"
    )?;
    writeln!(out, "|---|---:|---:|---:|---:|---:|---:|")?;
    for (name, contrast) in &report.descriptive {
        writeln!(
            out,
            "| {} | {} | {} | {} | {} | {} | {} |",
            inline(name),
            contrast.observations,
            contrast.treated_observations,
            contrast.control_observations,
            money(contrast.treated_outcome_mean),
            money(contrast.control_outcome_mean),
            money(contrast.difference_in_outcome_means)
        )?;
    }
    writeln!(out, "\n## Cross-fitted AIPW and final holdout evaluation\n")?;
    writeln!(out, "The implemented score is `mu1(X)-mu0(X) + T(Y-mu1(X))/e(X) - (1-T)(Y-mu0(X))/(1-e(X))`. Models are main-effects logistic IRLS for propensity and separate ridge-linear outcome regressions. Train estimates use five-fold cross-fitting; holdout estimates use nuisances fitted on train only. Intervals are normal-reference influence-function approximations, not bounds on hidden confounding.\n")?;
    write_aipw_markdown(&mut out, &report.train_cross_fitted_aipw)?;
    if let Some(holdout) = &report.holdout {
        write_aipw_markdown(&mut out, &holdout.aipw)?;
        writeln!(
            out,
            "- Final holdout ledger event: `{}`; access sequence {}; reused for tuning: `{}`.",
            holdout.ledger_event_id, holdout.access_sequence, holdout.reused_for_tuning
        )?;
    } else {
        writeln!(out, "The predeclared calibration gate stopped the run before holdout outcomes were evaluated or reported. Raw CSV parsing and all-record preparation summaries are not zero literal data access, but they are not holdout outcome evaluation or model selection. No holdout estimate or holdout descriptive contrast exists.")?;
    }
    writeln!(out, "- Calibration: n = {}; log loss = {:.6}; Brier = {:.6}; gate passed = `{}`; outcomes used in gate = `{}`; descriptive calibration outcomes reported = `{}`.", report.calibration.observations, report.calibration.propensity_log_loss, report.calibration.propensity_brier_score, report.calibration.gate_passed, report.calibration.outcome_used_in_gate, report.calibration.outcomes_reported_descriptively)?;
    writeln!(
        out,
        "- Calibration outcome-use semantics: {}",
        sentence(&report.calibration.outcome_use_semantics)
    )?;
    writeln!(out, "- **Weak-overlap warning:** {}/{} calibration raw propensities ({:.2}%) fall outside [0.05, 0.95]. `{}` gate_passed is a computational X/T-only result, not scientific approval, positivity verification, or causal identification.", report.calibration.overlap.raw_propensity_outside_0_05_to_0_95, report.calibration.observations, 100.0 * report.calibration.overlap.share_outside_0_05_to_0_95, report.calibration.gate_passed)?;
    writeln!(out, "- Calibration overlap: min = {:.6}; p05 = {:.6}; median = {:.6}; p95 = {:.6}; max = {:.6}.", report.calibration.overlap.minimum_raw_propensity, report.calibration.overlap.p05_raw_propensity, report.calibration.overlap.median_raw_propensity, report.calibration.overlap.p95_raw_propensity, report.calibration.overlap.maximum_raw_propensity)?;
    writeln!(
        out,
        "- Deployed logistic fit: converged = `{}`; separation suspected = `{}`; iterations = {}.",
        report.deployed_nuisance_diagnostics.propensity.converged,
        report
            .deployed_nuisance_diagnostics
            .propensity
            .separation_suspected,
        report.deployed_nuisance_diagnostics.propensity.iterations
    )?;
    writeln!(out, "\n### Predeclared propensity-clipping sensitivity\n")?;
    writeln!(out, "These are fixed sensitivity calculations, not candidates for choosing a preferred answer and not sensitivity bounds for unmeasured confounding.\n")?;
    writeln!(
        out,
        "| Role | Clip | Adjusted difference | Normal {}% interval |",
        confidence_percentage(report.protocol.confidence_level)
    )?;
    writeln!(out, "|---|---:|---:|---:|")?;
    for item in &report.sensitivity {
        writeln!(
            out,
            "| {} | {:.2} | {} | [{}, {}] |",
            item.role,
            item.propensity_clip,
            money(item.adjusted_mean_difference),
            money(item.normal_interval_lower),
            money(item.normal_interval_upper)
        )?;
    }
    writeln!(out, "\n## Fold diagnostics\n")?;
    writeln!(out, "| Fold | Fit n | Evaluation n | Logistic converged | Separation suspected | Fit propensity min | Fit propensity max |")?;
    writeln!(out, "|---:|---:|---:|---:|---:|---:|---:|")?;
    for fold in &report.train_fold_diagnostics {
        writeln!(
            out,
            "| {} | {} | {} | {} | {} | {:.6} | {:.6} |",
            fold.fold,
            fold.fit_observations,
            fold.evaluation_observations,
            fold.nuisance.propensity.converged,
            fold.nuisance.propensity.separation_suspected,
            fold.nuisance.propensity.minimum_raw_probability,
            fold.nuisance.propensity.maximum_raw_probability
        )?;
    }
    writeln!(out, "\n## Warnings and scientific limitations\n")?;
    if report.warnings.is_empty() {
        writeln!(out, "- No computational gate warning was emitted. This does not verify any identification assumption.")?;
    } else {
        for warning in &report.warnings {
            writeln!(out, "- {}", sentence(warning))?;
        }
    }
    for limitation in &report.limitations {
        writeln!(out, "- {}", sentence(limitation))?;
    }
    writeln!(
        out,
        "- Required identifying assumptions declared in the report:"
    )?;
    for assumption in &report.estimand.required_assumptions {
        writeln!(out, "  - {}", sentence(assumption))?;
    }
    writeln!(out, "\n## Holdout-use ledger\n")?;
    writeln!(out, "The local ledger record is a reproducibility safeguard, not a tamper-proof timestamp authority. At rendering, it contains **{}** event(s). Repeating estimation in this protocol directory is refused. Markdown and Typst generation is read-only and does not create another access event.", ledger.events.len())?;
    writeln!(out, "\n_Reproducible output generated solely by `causal-ml report` from the JSON artifacts listed above._")?;
    Ok(out)
}

fn write_aipw_markdown(out: &mut String, estimate: &AipwEstimate) -> Result<()> {
    writeln!(
        out,
        "### {} (clip {:.2})\n",
        estimate.role, estimate.propensity_clip
    )?;
    writeln!(
        out,
        "- n = {}; treated = {}; control = {}.",
        estimate.observations, estimate.treated_observations, estimate.control_observations
    )?;
    writeln!(
        out,
        "- Adjusted mean difference: **{}**; IF standard error: **{}**; {}: **[{}, {}]**.",
        money(estimate.adjusted_mean_difference),
        money(estimate.influence_function_standard_error),
        estimate.normal_interval_label,
        money(estimate.normal_interval_lower),
        money(estimate.normal_interval_upper)
    )?;
    writeln!(
        out,
        "- Raw propensity min/p05/median/p95/max: {:.6} / {:.6} / {:.6} / {:.6} / {:.6}.",
        estimate.overlap.minimum_raw_propensity,
        estimate.overlap.p05_raw_propensity,
        estimate.overlap.median_raw_propensity,
        estimate.overlap.p95_raw_propensity,
        estimate.overlap.maximum_raw_propensity
    )?;
    writeln!(
        out,
        "- Outside [0.05, 0.95]: {} ({:.2}%); <= 0.01: {}; >= 0.99: {}.",
        estimate.overlap.raw_propensity_outside_0_05_to_0_95,
        100.0 * estimate.overlap.share_outside_0_05_to_0_95,
        estimate.overlap.raw_propensity_at_or_below_0_01,
        estimate.overlap.raw_propensity_at_or_above_0_99
    )?;
    writeln!(
        out,
        "- Interpretation: {}\n",
        sentence(&estimate.interpretation)
    )?;
    Ok(())
}

fn typst_fragment(
    contract: &Contract,
    audit: &AuditReport,
    report: &CausalReport,
    report_sha256: &str,
) -> String {
    let mut out = String::new();
    let interval_heading = format!(
        "Normal {}% interval",
        confidence_percentage(report.protocol.confidence_level)
    );
    out.push_str("// Generated by causal-ml report. Do not hand-edit empirical values.\n");
    out.push_str("== Executable protocol and data checks\n\n");
    out.push_str("The frozen protocol separates train, calibration, and final holdout roles. Raw contrasts are #emph[associational]. The adjusted estimator has a causal interpretation only under explicitly untested assumptions; structural checks do not certify identification.\n\n");
    let _ = writeln!(out, "#let source-sha = \"{}\"", audit.source.actual_sha256);
    let _ = writeln!(out, "#let report-sha = \"{report_sha256}\"");
    out.push_str("The exact source and causal-report SHA-256 digests are `#source-sha` and `#report-sha`. The data-value license status remains `unresolved_upstream`.\n\n");
    out.push_str("#figure(\n  table(\n    columns: (1.4fr, 0.7fr, 0.7fr, 0.7fr, 1fr, 1fr, 1fr),\n    inset: 4pt,\n    [Scope], [n], [T n], [C n], [Treated mean], [Control mean], [Difference],\n");
    for (name, contrast) in &report.descriptive {
        let _ = writeln!(
            out,
            "    [{}], [{}], [{}], [{}], [{}], [{}], [{}],",
            typst_text(name),
            contrast.observations,
            contrast.treated_observations,
            contrast.control_observations,
            money(contrast.treated_outcome_mean),
            money(contrast.control_outcome_mean),
            money(contrast.difference_in_outcome_means)
        );
    }
    out.push_str("  ),\n  caption: [Artifact-derived descriptive outcome contrasts. These are associations, not average treatment effects.],\n) \n\n");
    let _ = writeln!(out, "#figure(\n  table(\n    columns: (1.5fr, 0.55fr, 0.55fr, 1fr, 1fr, 1.6fr),\n    inset: 4pt,\n    [Role], [n], [Clip], [AIPW], [IF SE], [{interval_heading}],\n");
    let _ = writeln!(
        out,
        "    [{}], [{}], [{:.2}], [{}], [{}], [[{}, {}]],",
        report.train_cross_fitted_aipw.role,
        report.train_cross_fitted_aipw.observations,
        report.train_cross_fitted_aipw.propensity_clip,
        money(report.train_cross_fitted_aipw.adjusted_mean_difference),
        money(
            report
                .train_cross_fitted_aipw
                .influence_function_standard_error
        ),
        money(report.train_cross_fitted_aipw.normal_interval_lower),
        money(report.train_cross_fitted_aipw.normal_interval_upper)
    );
    if let Some(holdout) = &report.holdout {
        let _ = writeln!(
            out,
            "    [{}], [{}], [{:.2}], [{}], [{}], [[{}, {}]],",
            holdout.aipw.role,
            holdout.aipw.observations,
            holdout.aipw.propensity_clip,
            money(holdout.aipw.adjusted_mean_difference),
            money(holdout.aipw.influence_function_standard_error),
            money(holdout.aipw.normal_interval_lower),
            money(holdout.aipw.normal_interval_upper)
        );
    }
    out.push_str("  ),\n  caption: [Cross-fitted train AIPW and, when the X/T-only gate permits it, one final external-nuisance holdout evaluation. Nominal dollars; causal identification remains unverified.],\n)\n\n");
    if report.holdout.is_none() {
        out.push_str("The predeclared calibration gate stopped the run before holdout outcomes were evaluated or reported. Raw CSV parsing and all-record preparation summaries are not zero literal data access, but they are not holdout outcome evaluation or model selection. No holdout estimate or holdout descriptive contrast exists.\n\n");
    }
    let _ = writeln!(out, "Calibration used {} observations with log loss {:.6}, Brier score {:.6}, and gate passed = {}. Outcomes used in gate = {}; descriptive calibration outcomes reported = {}.", report.calibration.observations, report.calibration.propensity_log_loss, report.calibration.propensity_brier_score, report.calibration.gate_passed, report.calibration.outcome_used_in_gate, report.calibration.outcomes_reported_descriptively);
    let _ = writeln!(
        out,
        "{}",
        typst_text(&report.calibration.outcome_use_semantics)
    );
    let _ = writeln!(out, "#strong[Weak-overlap warning:] {}/{} calibration raw propensities ({:.2}%) fall outside [0.05, 0.95]. The computational X/T-only gate result is not scientific approval, positivity verification, or causal identification.", report.calibration.overlap.raw_propensity_outside_0_05_to_0_95, report.calibration.observations, 100.0 * report.calibration.overlap.share_outside_0_05_to_0_95);
    out.push_str("\n\n=== Overlap and sensitivity\n\n");
    out.push_str("#table(\n  columns: (1.5fr, 0.6fr, 0.65fr, 0.65fr, 0.65fr, 0.65fr, 0.65fr),\n  inset: 4pt,\n  [Role], [Minimum], [p05], [Median], [p95], [Maximum], [Outside 5--95%],\n");
    let _ = overlap_typst_row(&mut out, &report.train_cross_fitted_aipw);
    if let Some(holdout) = &report.holdout {
        let _ = overlap_typst_row(&mut out, &holdout.aipw);
    }
    out.push_str(")\n\n");
    out.push_str("Predeclared clip sensitivity (not model selection and not an unmeasured-confounding bound):\n\n");
    let _ = writeln!(out, "#table(\n  columns: (1.8fr, 0.6fr, 1fr, 1.8fr),\n  inset: 4pt,\n  [Role], [Clip], [Difference], [{interval_heading}],\n");
    for item in &report.sensitivity {
        let _ = writeln!(
            out,
            "  [{}], [{:.2}], [{}], [[{}, {}]],",
            item.role,
            item.propensity_clip,
            money(item.adjusted_mean_difference),
            money(item.normal_interval_lower),
            money(item.normal_interval_upper)
        );
    }
    out.push_str(")\n\n=== Limitations generated with the result\n\n");
    for limitation in &report.limitations {
        let _ = writeln!(out, "- {}", typst_text(limitation));
    }
    for warning in &report.warnings {
        let _ = writeln!(
            out,
            "- #strong[Computational warning:] {}",
            typst_text(warning)
        );
    }
    let _ = writeln!(out, "\nThe audit contains {} observations and {} missing cells across declared columns. Entity-disjoint = {}; epoch-disjoint = {}. {}", audit.observation_count, audit.columns.iter().map(|column| column.missing).sum::<usize>(), audit.leakage_checks.entity_disjoint_verified, audit.leakage_checks.epoch_disjoint_verified, typst_text(&audit.temporal_governance));
    let _ = writeln!(out, "The raw source is #link(\"{}\")[the pinned Rdatasets CSV] and its documentation is #link(\"{}\")[the pinned MatchIt page].", contract.source.raw_url, contract.source.documentation_url);
    out
}

fn overlap_typst_row(out: &mut String, estimate: &AipwEstimate) -> Result<()> {
    writeln!(
        out,
        "  [{}], [{:.6}], [{:.6}], [{:.6}], [{:.6}], [{:.6}], [{:.2}%],",
        estimate.role,
        estimate.overlap.minimum_raw_propensity,
        estimate.overlap.p05_raw_propensity,
        estimate.overlap.median_raw_propensity,
        estimate.overlap.p95_raw_propensity,
        estimate.overlap.maximum_raw_propensity,
        100.0 * estimate.overlap.share_outside_0_05_to_0_95
    )?;
    Ok(())
}

fn write_text(path: &Path, content: &str) -> Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(path, content).with_context(|| format!("writing {}", path.display()))
}

fn money(value: f64) -> String {
    format!("{value:.1}")
}

fn optional_number(value: Option<f64>) -> String {
    value.map_or_else(|| "—".to_string(), |number| format!("{number:.1}"))
}

fn inline(value: &str) -> String {
    value.replace(['\n', '\r'], " ").replace('|', "\\|")
}

fn sentence(value: &str) -> String {
    inline(value)
}

fn typst_text(value: &str) -> String {
    value
        .replace('\\', "\\\\")
        .replace('[', "\\[")
        .replace(']', "\\]")
        .replace('#', "\\#")
        .replace('*', "\\*")
        .replace('_', "\\_")
        .replace('`', "\\`")
        .replace(['\n', '\r'], " ")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn typst_user_text_is_escaped() {
        assert_eq!(typst_text("x_[bad] #1"), "x\\_\\[bad\\] \\#1");
    }
}
