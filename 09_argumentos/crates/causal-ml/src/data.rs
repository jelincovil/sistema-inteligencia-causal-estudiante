use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::io::{Read, Write};
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::contract::{ColumnContract, Contract, DataType, NumericTransform, SplitStrategy};
use crate::split::{deterministic_assignments, leakage_checks, Assignment, LeakageChecks};

#[derive(Debug, Clone)]
pub struct Record {
    pub row_number: usize,
    pub unit_id: String,
    pub epoch: Option<i64>,
    pub treatment: f64,
    pub outcome: f64,
    pub features: Vec<f64>,
}

impl Record {
    #[cfg(test)]
    pub fn for_test(unit_id: &str, epoch: Option<i64>) -> Self {
        Self {
            row_number: 2,
            unit_id: unit_id.to_string(),
            epoch,
            treatment: 0.0,
            outcome: 0.0,
            features: vec![0.0],
        }
    }
}

#[derive(Debug, Clone)]
pub struct Dataset {
    pub records: Vec<Record>,
    pub columns: Vec<ColumnAudit>,
    pub duplicate_measurement_rows_excluding_id: usize,
    pub exact_duplicate_record_count: usize,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditReport {
    pub schema_version: String,
    pub generated_by: String,
    pub status: String,
    pub dataset_id: String,
    pub input_path: String,
    pub contract_sha256: String,
    pub source: SourceAudit,
    pub observation_count: usize,
    pub columns: Vec<ColumnAudit>,
    pub outcome_summary: NumericSummary,
    pub treatment_counts: BTreeMap<String, usize>,
    pub duplicate_unit_or_unit_epoch_ids: Vec<String>,
    pub exact_duplicate_record_count: usize,
    pub duplicate_measurement_rows_excluding_id: usize,
    pub feature_availability: Vec<FeatureAvailabilityAudit>,
    pub split_manifest_sha256: String,
    pub split_counts: BTreeMap<String, usize>,
    pub fold_counts: BTreeMap<String, usize>,
    pub leakage_checks: LeakageChecks,
    pub temporal_governance: String,
    pub issues: Vec<AuditIssue>,
    pub scientific_scope: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceAudit {
    pub raw_url: String,
    pub documentation_url: String,
    pub expected_bytes: u64,
    pub actual_bytes: u64,
    pub expected_sha256: String,
    pub actual_sha256: String,
    pub bytes_match: bool,
    pub sha256_matches: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ColumnAudit {
    pub name: String,
    pub declared_type: DataType,
    pub required: bool,
    pub present: bool,
    pub non_missing: usize,
    pub missing: usize,
    pub distinct: usize,
    pub minimum: Option<f64>,
    pub maximum: Option<f64>,
    pub observed_categories: BTreeMap<String, usize>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct NumericSummary {
    pub count: usize,
    pub mean: Option<f64>,
    pub standard_deviation: Option<f64>,
    pub minimum: Option<f64>,
    pub maximum: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeatureAvailabilityAudit {
    pub name: String,
    pub available_at: String,
    pub causal_role: String,
    pub transform: NumericTransform,
    pub excluded_from_adjustment: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AuditIssue {
    pub severity: String,
    pub code: String,
    pub row: Option<usize>,
    pub detail: String,
}

#[derive(Debug)]
pub struct Preparation {
    pub audit: AuditReport,
    pub audit_path: PathBuf,
    pub splits_path: PathBuf,
}

pub(crate) fn read_dataset_path(input: &Path, contract: &Contract) -> Result<Dataset> {
    let file = fs::File::open(input).with_context(|| format!("opening {}", input.display()))?;
    let mut dataset = parse_dataset(file, contract)?;
    dataset.records.sort_by(|left, right| {
        (&left.unit_id, left.epoch, left.row_number).cmp(&(
            &right.unit_id,
            right.epoch,
            right.row_number,
        ))
    });
    Ok(dataset)
}

pub fn prepare(input: &Path, contract_path: &Path, output_directory: &Path) -> Result<Preparation> {
    let contract = Contract::load(contract_path)?;
    let ledger_path = output_directory.join("holdout_ledger.json");
    if ledger_path.exists() {
        let previous: HoldoutLedger = serde_json::from_slice(&fs::read(&ledger_path)?)?;
        if !previous.events.is_empty() {
            bail!(
                "refusing to modify a protocol directory with a nonempty holdout ledger {}",
                ledger_path.display()
            );
        }
    }
    let contract_bytes = fs::read(contract_path)?;
    let contract_sha256 = sha256_hex(&contract_bytes);
    let metadata = fs::metadata(input).with_context(|| format!("reading {}", input.display()))?;
    let actual_sha256 = hash_file(input)?;
    let source = SourceAudit {
        raw_url: contract.source.raw_url.clone(),
        documentation_url: contract.source.documentation_url.clone(),
        expected_bytes: contract.source.expected_bytes,
        actual_bytes: metadata.len(),
        expected_sha256: contract.source.expected_sha256.clone(),
        actual_sha256,
        bytes_match: metadata.len() == contract.source.expected_bytes,
        sha256_matches: hash_file(input)? == contract.source.expected_sha256,
    };
    let dataset = read_dataset_path(input, &contract)?;
    let assignments = deterministic_assignments(&dataset.records, &contract)?;
    let leakage = leakage_checks(&dataset.records, &assignments);
    let mut issues = validate_records(&dataset.records, &contract, &source, &dataset, &leakage);
    let outcome_summary = numeric_summary(
        &dataset
            .records
            .iter()
            .map(|record| record.outcome)
            .collect::<Vec<_>>(),
    );
    let mut treatment_counts = BTreeMap::new();
    for record in &dataset.records {
        *treatment_counts
            .entry(if record.treatment == 1.0 { "1" } else { "0" }.to_string())
            .or_insert(0) += 1;
    }
    let split_counts = counts_by(&assignments, |assignment| {
        assignment.role.as_str().to_string()
    });
    let fold_counts = counts_by(
        &assignments
            .iter()
            .filter(|assignment| assignment.fold.is_some())
            .cloned()
            .collect::<Vec<_>>(),
        |assignment| assignment.fold.expect("filtered").to_string(),
    );
    let feature_availability = std::iter::once(FeatureAvailabilityAudit {
        name: contract.outcome.name.clone(),
        available_at: "post-treatment outcome; never an adjustment feature".to_string(),
        causal_role: "outcome".to_string(),
        transform: NumericTransform::Identity,
        excluded_from_adjustment: true,
    })
    .chain(
        contract
            .features
            .iter()
            .map(|feature| FeatureAvailabilityAudit {
                name: feature.column.name.clone(),
                available_at: feature.available_at.clone(),
                causal_role: feature.causal_role.clone(),
                transform: feature.transform,
                excluded_from_adjustment: false,
            }),
    )
    .collect();
    fs::create_dir_all(output_directory)
        .with_context(|| format!("creating {}", output_directory.display()))?;
    let splits_path = output_directory.join("splits.csv");
    write_splits(&splits_path, &assignments)?;
    let split_manifest_sha256 = hash_file(&splits_path)?;
    let temporal_governance = match (contract.split.strategy, contract.epoch.is_some()) {
        (SplitStrategy::EntityHash, false) => {
            "No epoch is available. Stable IDs provide entity-disjoint splits only; temporal leakage cannot be assessed.".to_string()
        }
        (SplitStrategy::EntityHash, true) => {
            "Stable IDs provide entity-disjoint splits. Calendar epochs may overlap across different entities; this is not a global temporal holdout.".to_string()
        }
        (SplitStrategy::EpochDisjoint, _) => {
            "Epochs are globally disjoint; inspect entity-overlap fields separately for repeated units.".to_string()
        }
    };
    if outcome_summary.count == 0 {
        issues.push(issue("error", "empty_data", None, "No observations."));
    }
    issues.sort_by(|left, right| {
        (&left.severity, &left.code, left.row, &left.detail).cmp(&(
            &right.severity,
            &right.code,
            right.row,
            &right.detail,
        ))
    });
    let failed = issues.iter().any(|issue| issue.severity == "error");
    let audit = AuditReport {
        schema_version: "1.0".to_string(),
        generated_by: format!("causal-ml {}", env!("CARGO_PKG_VERSION")),
        status: if failed { "fail" } else { "pass" }.to_string(),
        dataset_id: contract.dataset_id.clone(),
        input_path: input.display().to_string(),
        contract_sha256,
        source,
        observation_count: dataset.records.len(),
        columns: dataset.columns,
        outcome_summary,
        treatment_counts,
        duplicate_unit_or_unit_epoch_ids: duplicate_ids(&dataset.records, &contract),
        exact_duplicate_record_count: dataset.exact_duplicate_record_count,
        duplicate_measurement_rows_excluding_id: dataset.duplicate_measurement_rows_excluding_id,
        feature_availability,
        split_manifest_sha256,
        split_counts,
        fold_counts,
        leakage_checks: leakage,
        temporal_governance,
        issues,
        scientific_scope: "Data contract, provenance and split checks only. No causal identification assumption is verified.".to_string(),
    };
    let audit_path = output_directory.join("audit.json");
    write_json(&audit_path, &audit)?;
    write_json(
        &ledger_path,
        &HoldoutLedger::new(&contract.dataset_id, &audit, hash_file(&audit_path)?),
    )?;
    if failed {
        bail!(
            "data audit failed ({}); inspect {}",
            audit_path.display(),
            audit_path.display()
        );
    }
    Ok(Preparation {
        audit,
        audit_path,
        splits_path,
    })
}

pub fn audit_path(path: &Path) -> Result<AuditReport> {
    Ok(serde_json::from_slice(&fs::read(path)?)?)
}

fn parse_dataset(input: impl Read, contract: &Contract) -> Result<Dataset> {
    let mut reader = csv::ReaderBuilder::new()
        .has_headers(true)
        .flexible(false)
        .from_reader(input);
    let headers = reader.headers()?.clone();
    let mut unique_headers = BTreeSet::new();
    for header in &headers {
        if header.is_empty() || !unique_headers.insert(header.to_string()) {
            bail!("CSV contains empty or duplicate header `{header}`");
        }
    }
    let declared = all_columns(contract);
    for column in &declared {
        if !headers.iter().any(|header| header == column.name.as_str()) {
            bail!("CSV is missing declared column {}", column.name);
        }
    }
    for header in &headers {
        if !declared.iter().any(|column| column.name.as_str() == header) {
            bail!("CSV contains undeclared column {header}");
        }
    }
    let mut records = Vec::new();
    let mut statistics = declared
        .iter()
        .map(ColumnStatistics::new)
        .collect::<Vec<_>>();
    let mut exact_rows = BTreeMap::<Vec<String>, usize>::new();
    let mut measurement_rows = BTreeMap::<Vec<String>, usize>::new();
    let mut duplicate_measurement_rows_excluding_id = 0;
    let mut exact_duplicate_record_count = 0;
    for (index, result) in reader.records().enumerate() {
        let row_number = index + 2;
        let row = result.with_context(|| format!("parsing CSV near row {row_number}"))?;
        if row.len() != headers.len() {
            bail!(
                "row {row_number} has {} fields, expected {}",
                row.len(),
                headers.len()
            );
        }
        let values = headers.iter().zip(row.iter()).collect::<BTreeMap<_, _>>();
        let raw = row.iter().map(str::to_string).collect::<Vec<_>>();
        if exact_rows.insert(raw, row_number).is_some() {
            exact_duplicate_record_count += 1;
        }
        let measurement = headers
            .iter()
            .zip(row.iter())
            .filter(|(name, _)| **name != contract.unit_id.name)
            .map(|(_, value)| value.to_string())
            .collect::<Vec<_>>();
        if measurement_rows.insert(measurement, row_number).is_some() {
            duplicate_measurement_rows_excluding_id += 1;
        }
        for statistic in &mut statistics {
            let value = values[statistic.column.name.as_str()];
            if !value.is_empty() {
                validate_value(statistic.column, value, row_number)?;
            }
            statistic.observe(value);
        }
        let unit_id = required_value(&values, &contract.unit_id, row_number)?.to_string();
        let epoch = contract
            .epoch
            .as_ref()
            .map(|column| parse_integer(required_value(&values, column, row_number)?, row_number))
            .transpose()?;
        let treatment = parse_number(required_value(&values, &contract.treatment, row_number)?)?;
        if treatment != 0.0 && treatment != 1.0 {
            bail!("row {row_number} treatment is not binary");
        }
        let outcome = parse_number(required_value(&values, &contract.outcome, row_number)?)?;
        let mut features = Vec::new();
        for feature in &contract.features {
            let value = required_value(&values, &feature.column, row_number)?;
            if feature.column.dtype == DataType::Categorical {
                let categories = feature.column.categories.as_ref().expect("validated");
                for category in categories.iter().skip(1) {
                    features.push(if value == category { 1.0 } else { 0.0 });
                }
            } else {
                let mut number = parse_number(value)?;
                if feature.transform == NumericTransform::Log1p {
                    number = number.ln_1p();
                }
                features.push(number);
            }
        }
        records.push(Record {
            row_number,
            unit_id,
            epoch,
            treatment,
            outcome,
            features,
        });
    }
    Ok(Dataset {
        records,
        columns: statistics
            .into_iter()
            .map(ColumnStatistics::finish)
            .collect(),
        duplicate_measurement_rows_excluding_id,
        exact_duplicate_record_count,
    })
}

fn validate_records(
    records: &[Record],
    contract: &Contract,
    source: &SourceAudit,
    dataset: &Dataset,
    leakage: &LeakageChecks,
) -> Vec<AuditIssue> {
    let mut issues = Vec::new();
    if !source.bytes_match || !source.sha256_matches {
        issues.push(issue(
            "error",
            "source_pin_mismatch",
            None,
            "Input bytes or SHA-256 differ from the immutable contract pin.",
        ));
    }
    for column in &dataset.columns {
        if column.missing > 0 {
            issues.push(issue(
                if column.required { "error" } else { "warning" },
                "missing_values",
                None,
                &format!("{} has {} missing values", column.name, column.missing),
            ));
        }
    }
    for id in duplicate_ids(records, contract) {
        issues.push(issue(
            "error",
            "duplicate_identifier",
            None,
            &format!("Duplicate unit/entity key: {id}"),
        ));
    }
    if dataset.exact_duplicate_record_count > 0 {
        issues.push(issue(
            "error",
            "duplicate_record",
            None,
            "Exact duplicate raw records are forbidden.",
        ));
    }
    if dataset.duplicate_measurement_rows_excluding_id > 0 {
        issues.push(issue(
            "warning",
            "duplicate_measurements",
            None,
            "Repeated measurement vectors excluding ID are counted but not automatically errors.",
        ));
    }
    match contract.split.strategy {
        SplitStrategy::EntityHash if !leakage.entity_disjoint_verified => issues.push(issue(
            "error",
            "entity_leakage",
            None,
            "One or more IDs occur in more than one split.",
        )),
        SplitStrategy::EpochDisjoint if !leakage.epoch_disjoint_verified => issues.push(issue(
            "error",
            "epoch_leakage",
            None,
            "One or more epochs occur in more than one split.",
        )),
        _ => {}
    }
    issues
}

fn all_columns(contract: &Contract) -> Vec<ColumnContract> {
    std::iter::once(contract.unit_id.clone())
        .chain(std::iter::once(contract.treatment.clone()))
        .chain(std::iter::once(contract.outcome.clone()))
        .chain(contract.epoch.clone())
        .chain(
            contract
                .features
                .iter()
                .map(|feature| feature.column.clone()),
        )
        .collect()
}

fn required_value<'a>(
    values: &BTreeMap<&str, &'a str>,
    column: &ColumnContract,
    row: usize,
) -> Result<&'a str> {
    let value = values[column.name.as_str()];
    if value.is_empty() && column.required {
        bail!("row {row} has missing required column {}", column.name);
    }
    Ok(value)
}

fn parse_number(value: &str) -> Result<f64> {
    let parsed = value.parse::<f64>()?;
    if !parsed.is_finite() {
        bail!("non-finite numeric value `{value}`");
    }
    Ok(parsed)
}

fn parse_integer(value: &str, row: usize) -> Result<i64> {
    value
        .parse::<i64>()
        .with_context(|| format!("row {row} has invalid integer `{value}`"))
}

fn validate_value(column: &ColumnContract, value: &str, row: usize) -> Result<()> {
    let number = match column.dtype {
        DataType::String => return Ok(()),
        DataType::Integer => parse_integer(value, row).map(|number| number as f64)?,
        DataType::Number | DataType::Binary => parse_number(value)?,
        DataType::Categorical => {
            let categories = column.categories.as_ref().expect("validated");
            if !categories.iter().any(|category| category == value) {
                bail!(
                    "row {row} column {} has unknown category `{value}`",
                    column.name
                );
            }
            return Ok(());
        }
    };
    if column.minimum.is_some_and(|minimum| number < minimum)
        || column.maximum.is_some_and(|maximum| number > maximum)
    {
        bail!(
            "row {row} column {} is outside its declared range",
            column.name
        );
    }
    if column.dtype == DataType::Binary && number != 0.0 && number != 1.0 {
        bail!("row {row} column {} must be zero or one", column.name);
    }
    Ok(())
}

struct ColumnStatistics<'a> {
    column: &'a ColumnContract,
    present: bool,
    non_missing: usize,
    missing: usize,
    distinct: BTreeSet<String>,
    minimum: Option<f64>,
    maximum: Option<f64>,
    categories: BTreeMap<String, usize>,
}

impl<'a> ColumnStatistics<'a> {
    fn new(column: &'a ColumnContract) -> Self {
        Self {
            column,
            present: true,
            non_missing: 0,
            missing: 0,
            distinct: BTreeSet::new(),
            minimum: None,
            maximum: None,
            categories: BTreeMap::new(),
        }
    }

    fn observe(&mut self, value: &str) {
        if value.is_empty() {
            self.missing += 1;
            return;
        }
        self.non_missing += 1;
        self.distinct.insert(value.to_string());
        if self.column.dtype == DataType::Categorical {
            *self.categories.entry(value.to_string()).or_insert(0) += 1;
        }
        if matches!(
            self.column.dtype,
            DataType::Integer | DataType::Number | DataType::Binary
        ) {
            if let Ok(number) = parse_number(value) {
                self.minimum = Some(self.minimum.map_or(number, |old| old.min(number)));
                self.maximum = Some(self.maximum.map_or(number, |old| old.max(number)));
            }
        }
    }

    fn finish(self) -> ColumnAudit {
        ColumnAudit {
            name: self.column.name.clone(),
            declared_type: self.column.dtype,
            required: self.column.required,
            present: self.present,
            non_missing: self.non_missing,
            missing: self.missing,
            distinct: self.distinct.len(),
            minimum: self.minimum,
            maximum: self.maximum,
            observed_categories: self.categories,
        }
    }
}

fn duplicate_ids(records: &[Record], contract: &Contract) -> Vec<String> {
    let mut seen = BTreeSet::new();
    let mut duplicates = BTreeSet::new();
    for record in records {
        let key = match contract.split.strategy {
            _ if contract.epoch.is_none() => record.unit_id.clone(),
            _ => format!("{}|{}", record.unit_id, record.epoch.expect("validated")),
        };
        if !seen.insert(key.clone()) {
            duplicates.insert(key);
        }
    }
    duplicates.into_iter().collect()
}

fn numeric_summary(values: &[f64]) -> NumericSummary {
    if values.is_empty() {
        return NumericSummary::default();
    }
    let count = values.len();
    let mean = values.iter().sum::<f64>() / count as f64;
    let standard_deviation = if count > 1 {
        Some(
            (values
                .iter()
                .map(|value| (value - mean).powi(2))
                .sum::<f64>()
                / (count - 1) as f64)
                .sqrt(),
        )
    } else {
        None
    };
    NumericSummary {
        count,
        mean: Some(mean),
        standard_deviation,
        minimum: values.iter().copied().reduce(f64::min),
        maximum: values.iter().copied().reduce(f64::max),
    }
}

fn counts_by(
    assignments: &[Assignment],
    key: impl Fn(&Assignment) -> String,
) -> BTreeMap<String, usize> {
    let mut counts = BTreeMap::new();
    for assignment in assignments {
        *counts.entry(key(assignment)).or_insert(0) += 1;
    }
    counts
}

fn issue(severity: &str, code: &str, row: Option<usize>, detail: &str) -> AuditIssue {
    AuditIssue {
        severity: severity.to_string(),
        code: code.to_string(),
        row,
        detail: detail.to_string(),
    }
}

fn write_splits(path: &Path, assignments: &[Assignment]) -> Result<()> {
    let mut writer = csv::Writer::from_path(path)?;
    writer.write_record(["unit_id", "epoch", "role", "fold"])?;
    for assignment in assignments {
        writer.write_record([
            assignment.unit_id.as_str(),
            assignment
                .epoch
                .map_or(String::new(), |epoch| epoch.to_string())
                .as_str(),
            assignment.role.as_str(),
            assignment
                .fold
                .map_or(String::new(), |fold| fold.to_string())
                .as_str(),
        ])?;
    }
    writer.flush()?;
    Ok(())
}

pub fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<()> {
    let bytes = serde_json::to_vec_pretty(value)?;
    let mut file = fs::File::create(path)?;
    file.write_all(&bytes)?;
    file.write_all(b"\n")?;
    Ok(())
}

pub fn hash_file(path: &Path) -> Result<String> {
    let mut file = fs::File::open(path)?;
    let mut hash = Sha256::new();
    let mut buffer = [0_u8; 8192];
    loop {
        let count = file.read(&mut buffer)?;
        if count == 0 {
            break;
        }
        hash.update(&buffer[..count]);
    }
    Ok(format!("{:x}", hash.finalize()))
}

pub fn sha256_hex(bytes: &[u8]) -> String {
    format!("{:x}", Sha256::digest(bytes))
}

#[derive(Debug, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HoldoutLedger {
    pub schema_version: String,
    pub dataset_id: String,
    pub source_sha256: String,
    pub contract_sha256: String,
    pub audit_sha256: String,
    pub split_manifest_sha256: String,
    pub events: Vec<HoldoutEvent>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct HoldoutEvent {
    pub event_id: String,
    pub purpose: String,
    pub accessed_at_unix_seconds: u64,
    pub report_sha256: String,
    pub split_manifest_sha256: String,
    pub model_changes_permitted: bool,
}

impl HoldoutLedger {
    fn new(dataset_id: &str, audit: &AuditReport, audit_sha256: String) -> Self {
        Self {
            schema_version: "2.0".to_string(),
            dataset_id: dataset_id.to_string(),
            source_sha256: audit.source.actual_sha256.clone(),
            contract_sha256: audit.contract_sha256.clone(),
            audit_sha256,
            split_manifest_sha256: audit.split_manifest_sha256.clone(),
            events: Vec::new(),
        }
    }
}

#[cfg(test)]
mod tests {
    use std::path::Path;

    use super::*;

    fn contract() -> Contract {
        Contract::load(Path::new("../../config/test.contract.json")).expect("test contract")
    }

    #[test]
    fn parses_quoted_commas_and_newlines() {
        let bytes = b"unit,treated,y,x\n\"u,1\",0,\"2.5\",1\nu2,1,3,2\n";
        let data = parse_dataset(&bytes[..], &contract()).expect("valid CSV");
        assert_eq!(data.records.len(), 2);
        assert_eq!(data.records[0].unit_id, "u,1");
    }

    #[test]
    fn malformed_csv_is_an_error() {
        let bytes = b"unit,treated,y,x\nu1,0\n";
        let error = parse_dataset(&bytes[..], &contract()).expect_err("short row must fail");
        assert!(error.to_string().contains("CSV"), "{error:#}");
    }

    #[test]
    fn duplicate_id_is_detected() {
        let bytes = b"unit,treated,y,x\nu1,0,2.5,1\nu1,1,3,2\n";
        let data = parse_dataset(&bytes[..], &contract()).expect("parse");
        assert_eq!(duplicate_ids(&data.records, &contract()), vec!["u1"]);
    }

    #[test]
    fn non_finite_value_is_rejected() {
        let bytes = b"unit,treated,y,x\nu1,0,NaN,1\n";
        assert!(parse_dataset(&bytes[..], &contract()).is_err());
    }

    #[test]
    fn missing_undeclared_and_duplicate_headers_are_rejected() {
        assert!(parse_dataset(&b"unit,treated,x\nu1,0,1\n"[..], &contract()).is_err());
        assert!(parse_dataset(&b"unit,treated,y,x,extra\nu1,0,2,1,9\n"[..], &contract()).is_err());
        assert!(parse_dataset(&b"unit,treated,y,x,x\nu1,0,2,1,1\n"[..], &contract()).is_err());
    }

    #[test]
    fn required_missing_values_and_ranges_are_enforced() {
        assert!(parse_dataset(&b"unit,treated,y,x\nu1,0,,1\n"[..], &contract()).is_err());
        let mut bounded = contract();
        bounded.outcome.minimum = Some(0.0);
        bounded.outcome.maximum = Some(10.0);
        assert!(parse_dataset(&b"unit,treated,y,x\nu1,0,11,1\n"[..], &bounded).is_err());
        assert!(parse_dataset(&b"unit,treated,y,x\nu1,2,5,1\n"[..], &bounded).is_err());
    }

    #[test]
    fn unknown_categories_are_rejected_and_reference_encoding_is_stable() {
        let mut categorical = contract();
        categorical.features[0].column.dtype = DataType::Categorical;
        categorical.features[0].column.categories =
            Some(vec!["reference".to_string(), "level_b".to_string()]);
        let valid = b"unit,treated,y,x\nu1,0,2,reference\nu2,1,3,level_b\n";
        let dataset = parse_dataset(&valid[..], &categorical).expect("valid categorical data");
        assert_eq!(dataset.records[0].features, vec![0.0]);
        assert_eq!(dataset.records[1].features, vec![1.0]);
        let invalid = b"unit,treated,y,x\nu1,0,2,unseen\n";
        assert!(parse_dataset(&invalid[..], &categorical).is_err());
    }

    #[test]
    fn exact_and_excluding_id_duplicates_are_counted_separately() {
        let bytes = b"unit,treated,y,x\nu1,0,2.5,1\nu1,0,2.5,1\nu2,0,2.5,1\n";
        let dataset = parse_dataset(&bytes[..], &contract()).expect("parse duplicate fixture");
        assert_eq!(dataset.exact_duplicate_record_count, 1);
        assert_eq!(dataset.duplicate_measurement_rows_excluding_id, 2);
    }
}
