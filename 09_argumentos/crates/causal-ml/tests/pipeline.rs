use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};

use causal_ml::contract::Contract;
use causal_ml::data::{hash_file, sha256_hex, HoldoutLedger};
use causal_ml::{estimate_from_paths, prepare, render_from_paths};

static TEST_ID: AtomicUsize = AtomicUsize::new(0);

fn work_directory(label: &str) -> PathBuf {
    let sequence = TEST_ID.fetch_add(1, Ordering::Relaxed);
    let directory = Path::new(env!("CARGO_MANIFEST_DIR"))
        .join("../../target/test-work")
        .join(format!("{label}-{}-{sequence}", std::process::id()));
    fs::create_dir_all(&directory).expect("create isolated test directory");
    directory
}

fn synthetic_case() -> (PathBuf, PathBuf, PathBuf) {
    let directory = work_directory("pipeline");
    let input = directory.join("synthetic.csv");
    let mut csv = "unit,treated,y,x\n".to_string();
    for index in 0..240 {
        let x = ((index * 37) % 101) as f64 / 10.0;
        let treatment = if index % 3 == 0 { 1 } else { 0 };
        let residual = ((index * 19) % 17) as f64 / 100.0;
        let outcome = 1.5 + 2.0 * x + 3.0 * treatment as f64 + residual;
        csv.push_str(&format!("u{index:03},{treatment},{outcome:.6},{x:.6}\n"));
    }
    fs::write(&input, csv.as_bytes()).expect("write synthetic input");

    let contract_path = directory.join("contract.json");
    let mut contract = Contract::load(
        Path::new(env!("CARGO_MANIFEST_DIR"))
            .join("../../config/test.contract.json")
            .as_path(),
    )
    .expect("load unit test contract");
    contract.source.expected_bytes = csv.len() as u64;
    contract.source.expected_sha256 = sha256_hex(csv.as_bytes());
    fs::write(
        &contract_path,
        format!(
            "{}\n",
            serde_json::to_string_pretty(&contract).expect("contract JSON")
        ),
    )
    .expect("write pinned test contract");
    let output = directory.join("output");
    (input, contract_path, output)
}

#[test]
fn pipeline_is_deterministic_and_holdout_cannot_be_reused() {
    let (input, contract, output) = synthetic_case();
    let first = prepare(&input, &contract, &output).expect("prepare synthetic case");
    assert_eq!(first.audit.status, "pass");
    assert!(first.audit.leakage_checks.entity_disjoint_verified);
    assert_eq!(first.audit.observation_count, 240);

    let second_output = output.with_extension("replica");
    let second = prepare(&input, &contract, &second_output).expect("reproduce synthetic audit");
    assert_eq!(
        fs::read(&first.audit_path).expect("first audit"),
        fs::read(&second.audit_path).expect("second audit")
    );
    assert_eq!(
        fs::read(&first.splits_path).expect("first splits"),
        fs::read(&second.splits_path).expect("second splits")
    );

    let report = estimate_from_paths(&input, &contract, &output).expect("one final evaluation");
    assert_eq!(report.status, "completed");
    assert!(report.holdout.is_some());
    assert!(!report.holdout_outcomes_used_for_model_selection);
    assert!(!report.scientific_causal_claim_verified);
    assert!(!report.calibration.outcome_used);
    assert!(!report.calibration.outcome_used_in_gate);
    assert!(report.calibration.outcomes_reported_descriptively);
    assert!(report.descriptive.contains_key("calibration"));
    assert!(report
        .calibration
        .outcome_use_semantics
        .contains("legacy outcome_used field mirrors outcome_used_in_gate"));
    assert_eq!(report.protocol.confidence_level, 0.95);
    assert_eq!(
        report.train_cross_fitted_aipw.normal_interval_label,
        "normal 95% interval"
    );

    let ledger: HoldoutLedger = serde_json::from_slice(
        &fs::read(output.join("holdout_ledger.json")).expect("read holdout ledger"),
    )
    .expect("valid ledger");
    assert_eq!(ledger.events.len(), 1);
    assert_eq!(
        ledger.events[0].report_sha256,
        hash_file(&output.join("causal_report.json")).expect("report hash")
    );
    let error = estimate_from_paths(&input, &contract, &output)
        .expect_err("a second holdout evaluation must fail");
    assert!(error.to_string().contains("already been accessed"));
    assert!(prepare(&input, &contract, &output)
        .expect_err("preparation must not erase a used ledger")
        .to_string()
        .contains("refusing to modify"));
}

#[test]
fn failed_gate_reports_calibration_outcomes_but_never_evaluates_holdout() {
    let (input, contract, output) = synthetic_case();
    let mut specification = Contract::load(&contract).expect("load generated test contract");
    specification.estimator.logistic_max_iterations = 1;
    fs::write(
        &contract,
        format!(
            "{}\n",
            serde_json::to_string_pretty(&specification).expect("contract JSON")
        ),
    )
    .expect("write forced-failure contract");
    prepare(&input, &contract, &output).expect("prepare forced-failure case");
    let report = estimate_from_paths(&input, &contract, &output)
        .expect("failed gate must still produce a report");
    assert_eq!(report.status, "stopped_before_holdout");
    assert!(!report.calibration.gate_passed);
    assert!(!report.calibration.outcome_used_in_gate);
    assert!(!report.calibration.outcome_used);
    assert!(report.calibration.outcomes_reported_descriptively);
    assert!(report.descriptive.contains_key("calibration"));
    assert!(!report.descriptive.contains_key("holdout"));
    assert!(!report.descriptive.contains_key("all_observations"));
    assert!(report.holdout.is_none());

    let ledger: HoldoutLedger = serde_json::from_slice(
        &fs::read(output.join("holdout_ledger.json")).expect("read untouched ledger"),
    )
    .expect("valid empty ledger");
    assert!(ledger.events.is_empty());

    let markdown_path = output.join("report.md");
    let typst_path = output.join("report.typ");
    render_from_paths(&output, &contract, &markdown_path, &typst_path)
        .expect("render failed-gate report");
    let markdown = fs::read_to_string(&markdown_path).expect("read failed-gate Markdown");
    assert!(markdown.contains("before holdout outcomes were evaluated or reported"));
    assert!(markdown.contains("Raw CSV parsing and all-record preparation summaries"));
    assert!(markdown.contains("descriptive calibration outcomes reported = `true`"));
    assert!(markdown.contains("Weak-overlap warning"));
    assert!(!markdown.contains("before holdout outcomes were accessed"));
    let typst = fs::read_to_string(&typst_path).expect("read failed-gate Typst");
    assert!(typst.contains("before holdout outcomes were evaluated or reported"));
    assert!(typst.contains("Weak-overlap warning"));
}

#[test]
fn changed_audit_json_is_rejected_before_estimation() {
    let (input, contract, output) = synthetic_case();
    let prepared = prepare(&input, &contract, &output).expect("prepare");
    let audit = fs::read_to_string(&prepared.audit_path).expect("read audit");
    fs::write(
        &prepared.audit_path,
        audit.replacen(
            "\"scientific_scope\": \"Data contract",
            "\"scientific_scope\": \"Tampered data contract",
            1,
        ),
    )
    .expect("tamper with test-only audit bytes");
    let error = estimate_from_paths(&input, &contract, &output)
        .expect_err("changed audit bytes must fail even when JSON semantics are compatible");
    assert!(error.to_string().contains("holdout ledger"));
    let ledger: HoldoutLedger = serde_json::from_slice(
        &fs::read(output.join("holdout_ledger.json")).expect("read untouched ledger"),
    )
    .expect("valid empty ledger");
    assert!(ledger.events.is_empty());
}

#[test]
fn changed_split_manifest_is_rejected_before_estimation() {
    let (input, contract, output) = synthetic_case();
    let prepared = prepare(&input, &contract, &output).expect("prepare");
    let mut manifest = fs::read_to_string(&prepared.splits_path).expect("read splits");
    manifest = manifest.replacen("holdout", "train", 1);
    fs::write(&prepared.splits_path, manifest).expect("tamper with test-only manifest");
    let error = estimate_from_paths(&input, &contract, &output)
        .expect_err("hash mismatch must stop estimation");
    assert!(error.to_string().contains("manifest changed"));
    let ledger: HoldoutLedger = serde_json::from_slice(
        &fs::read(output.join("holdout_ledger.json")).expect("read empty ledger"),
    )
    .expect("valid empty ledger");
    assert!(ledger.events.is_empty());
}
