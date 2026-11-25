use std::collections::{BTreeMap, BTreeSet};

use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};

use crate::contract::{Contract, SplitStrategy};
use crate::data::Record;

#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SplitRole {
    Train,
    Calibration,
    Holdout,
}

impl SplitRole {
    pub fn as_str(self) -> &'static str {
        match self {
            Self::Train => "train",
            Self::Calibration => "calibration",
            Self::Holdout => "holdout",
        }
    }
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct Assignment {
    pub unit_id: String,
    pub epoch: Option<i64>,
    pub role: SplitRole,
    pub fold: Option<usize>,
}

#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct LeakageChecks {
    pub train_calibration_unit_overlap: usize,
    pub train_holdout_unit_overlap: usize,
    pub calibration_holdout_unit_overlap: usize,
    pub train_calibration_epoch_overlap: usize,
    pub train_holdout_epoch_overlap: usize,
    pub calibration_holdout_epoch_overlap: usize,
    pub epoch_disjoint_verified: bool,
    pub entity_disjoint_verified: bool,
    pub detail: String,
}

pub fn deterministic_assignments(
    records: &[Record],
    contract: &Contract,
) -> Result<Vec<Assignment>> {
    if records.is_empty() {
        bail!("cannot split an empty dataset");
    }
    let mut assignments: Vec<Assignment> = match contract.split.strategy {
        SplitStrategy::EntityHash => records
            .iter()
            .map(|record| {
                let role = match bucket(&contract.split.protocol_salt, &record.unit_id) {
                    value if value < contract.split.train_fraction => SplitRole::Train,
                    value
                        if value
                            < contract.split.train_fraction
                                + contract.split.calibration_fraction =>
                    {
                        SplitRole::Calibration
                    }
                    _ => SplitRole::Holdout,
                };
                Assignment {
                    unit_id: record.unit_id.clone(),
                    epoch: record.epoch,
                    role,
                    fold: None,
                }
            })
            .collect(),
        SplitStrategy::EpochDisjoint => {
            let epochs = records
                .iter()
                .filter_map(|record| record.epoch)
                .collect::<BTreeSet<_>>()
                .into_iter()
                .collect::<Vec<_>>();
            if epochs.len() < 3 {
                bail!("epoch splitting requires at least three distinct epochs");
            }
            let train_end = ((epochs.len() as f64 * contract.split.train_fraction).floor()
                as usize)
                .clamp(1, epochs.len() - 2);
            let calibration_end = (train_end
                + (epochs.len() as f64 * contract.split.calibration_fraction).floor() as usize)
                .clamp(train_end + 1, epochs.len() - 1);
            let role_for_epoch = |epoch: i64| {
                let index = epochs.binary_search(&epoch).expect("epoch came from set");
                if index < train_end {
                    SplitRole::Train
                } else if index < calibration_end {
                    SplitRole::Calibration
                } else {
                    SplitRole::Holdout
                }
            };
            records
                .iter()
                .map(|record| Assignment {
                    unit_id: record.unit_id.clone(),
                    epoch: record.epoch,
                    role: role_for_epoch(record.epoch.expect("epoch strategy validated")),
                    fold: None,
                })
                .collect()
        }
    };
    for assignment in &mut assignments {
        if assignment.role == SplitRole::Train {
            // Cross-fitting keeps every measurement of an entity in one fold.
            let key = assignment.unit_id.clone();
            assignment.fold =
                Some((stable_u64(&format!("fold|{key}")) as usize) % contract.estimator.folds);
        }
    }
    assignments.sort_by(|left, right| {
        (&left.unit_id, left.epoch)
            .cmp(&(&right.unit_id, right.epoch))
            .then(left.role.cmp(&right.role))
    });
    validate_assignments_for_contract(records, assignments.clone(), contract)?;
    Ok(assignments)
}

/// Validate manifest shape, fold ranges, and the split strategy's leakage invariants.
pub fn validate_assignments_for_contract(
    records: &[Record],
    assignments: Vec<Assignment>,
    contract: &Contract,
) -> Result<()> {
    validate_assignments(records, &assignments, contract.estimator.folds)?;
    let leakage = leakage_checks(records, &assignments);
    match contract.split.strategy {
        SplitStrategy::EntityHash if !leakage.entity_disjoint_verified => {
            bail!("split manifest has entity overlap across roles")
        }
        SplitStrategy::EpochDisjoint if !leakage.epoch_disjoint_verified => {
            bail!("split manifest has epoch overlap across roles")
        }
        _ => {}
    }
    Ok(())
}

pub fn validate_assignments(
    records: &[Record],
    assignments: &[Assignment],
    folds: usize,
) -> Result<()> {
    if folds < 2 {
        bail!("cross-fitting requires at least two folds");
    }
    if records.len() != assignments.len() {
        bail!("split manifest row count differs from data");
    }
    let expected = records
        .iter()
        .map(|record| (record.unit_id.clone(), record.epoch))
        .collect::<BTreeSet<_>>();
    let actual = assignments
        .iter()
        .map(|assignment| (assignment.unit_id.clone(), assignment.epoch))
        .collect::<BTreeSet<_>>();
    if actual.len() != assignments.len() {
        bail!("split manifest contains duplicate unit/epoch assignments");
    }
    if expected != actual {
        bail!("split manifest identifiers do not exactly match data identifiers");
    }
    let counts = assignments
        .iter()
        .map(|assignment| assignment.role)
        .collect::<BTreeSet<_>>();
    for required in [SplitRole::Train, SplitRole::Calibration, SplitRole::Holdout] {
        if !counts.contains(&required) {
            bail!("split manifest omits {} role", required.as_str());
        }
    }
    if assignments
        .iter()
        .any(|assignment| (assignment.role == SplitRole::Train) != assignment.fold.is_some())
    {
        bail!("only training assignments may have a fold, and every one must have one");
    }
    if assignments
        .iter()
        .filter_map(|assignment| assignment.fold)
        .any(|fold| fold >= folds)
    {
        bail!("split manifest fold index is outside the configured fold range");
    }
    Ok(())
}

pub fn leakage_checks(records: &[Record], assignments: &[Assignment]) -> LeakageChecks {
    let role_by_key = assignments
        .iter()
        .map(|assignment| {
            (
                (assignment.unit_id.clone(), assignment.epoch),
                assignment.role,
            )
        })
        .collect::<BTreeMap<_, _>>();
    let mut units = BTreeMap::<SplitRole, BTreeSet<String>>::new();
    let mut epochs = BTreeMap::<SplitRole, BTreeSet<i64>>::new();
    for record in records {
        let role = role_by_key[&(record.unit_id.clone(), record.epoch)];
        units
            .entry(role)
            .or_default()
            .insert(record.unit_id.clone());
        if let Some(epoch) = record.epoch {
            epochs.entry(role).or_default().insert(epoch);
        }
    }
    let unit = |a: SplitRole, b: SplitRole| intersection_len(&units[&a], &units[&b]);
    let epoch = |a: SplitRole, b: SplitRole| match (epochs.get(&a), epochs.get(&b)) {
        (Some(left), Some(right)) => intersection_len(left, right),
        _ => 0,
    };
    let train_calibration_epoch_overlap = epoch(SplitRole::Train, SplitRole::Calibration);
    let train_holdout_epoch_overlap = epoch(SplitRole::Train, SplitRole::Holdout);
    let calibration_holdout_epoch_overlap = epoch(SplitRole::Calibration, SplitRole::Holdout);
    let train_calibration_unit_overlap = unit(SplitRole::Train, SplitRole::Calibration);
    let train_holdout_unit_overlap = unit(SplitRole::Train, SplitRole::Holdout);
    let calibration_holdout_unit_overlap = unit(SplitRole::Calibration, SplitRole::Holdout);
    let entity_disjoint_verified = train_calibration_unit_overlap == 0
        && train_holdout_unit_overlap == 0
        && calibration_holdout_unit_overlap == 0;
    let epoch_disjoint_verified = !epochs.is_empty()
        && train_calibration_epoch_overlap == 0
        && train_holdout_epoch_overlap == 0
        && calibration_holdout_epoch_overlap == 0;
    let detail = match (
        epoch_disjoint_verified,
        entity_disjoint_verified,
        epochs.is_empty(),
    ) {
        (_, _, true) => {
            "No epoch column: temporal separation is unavailable, not inferred.".to_string()
        }
        (true, true, false) => {
            "Epoch-disjoint and entity-disjoint assignments verified.".to_string()
        }
        (true, false, false) => {
            "Epoch separation verified; repeated entities may cross splits by design.".to_string()
        }
        (false, true, false) => {
            "Entity separation verified; epochs may overlap across different entities.".to_string()
        }
        (false, false, false) => {
            "Neither epoch nor entity separation is verified; inspect overlap counts.".to_string()
        }
    };
    LeakageChecks {
        train_calibration_unit_overlap,
        train_holdout_unit_overlap,
        calibration_holdout_unit_overlap,
        train_calibration_epoch_overlap,
        train_holdout_epoch_overlap,
        calibration_holdout_epoch_overlap,
        epoch_disjoint_verified,
        entity_disjoint_verified,
        detail,
    }
}

fn intersection_len<T: Ord>(left: &BTreeSet<T>, right: &BTreeSet<T>) -> usize {
    left.intersection(right).count()
}

fn bucket(salt: &str, unit_id: &str) -> f64 {
    stable_u64(&format!("role|{salt}|{unit_id}")) as f64 / (u64::MAX as f64)
}

fn stable_u64(key: &str) -> u64 {
    let digest = Sha256::digest(key.as_bytes());
    u64::from_be_bytes(digest[..8].try_into().expect("eight digest bytes"))
}

#[cfg(test)]
mod tests {
    use std::path::Path;

    use super::*;
    use crate::contract::{ColumnContract, DataType};

    fn assignment(record: &Record, role: SplitRole, fold: Option<usize>) -> Assignment {
        Assignment {
            unit_id: record.unit_id.clone(),
            epoch: record.epoch,
            role,
            fold,
        }
    }

    fn contract(strategy: SplitStrategy, with_epoch: bool) -> Contract {
        let path = Path::new(env!("CARGO_MANIFEST_DIR")).join("../../config/test.contract.json");
        let mut contract = Contract::load(&path).expect("load test contract");
        contract.split.strategy = strategy;
        contract.epoch = with_epoch.then(|| ColumnContract {
            name: "epoch".to_string(),
            dtype: DataType::Integer,
            required: true,
            minimum: None,
            maximum: None,
            categories: None,
        });
        contract.validate().expect("valid test strategy");
        contract
    }

    fn panel_records() -> Vec<Record> {
        ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"]
            .into_iter()
            .flat_map(|unit| (0..6).map(move |epoch| Record::for_test(unit, Some(epoch))))
            .collect()
    }

    #[test]
    fn hashes_do_not_depend_on_input_order() {
        assert_eq!(stable_u64("unit-7"), stable_u64("unit-7"));
        assert_ne!(stable_u64("unit-7"), stable_u64("unit-8"));
    }

    #[test]
    fn fold_assignment_is_independent_of_protocol_salt() {
        let records = (0..240)
            .map(|index| Record::for_test(&format!("unit-{index:03}"), None))
            .collect::<Vec<_>>();
        let original_contract = contract(SplitStrategy::EntityHash, false);
        let original = deterministic_assignments(&records, &original_contract)
            .expect("original deterministic assignments");
        let mut changed_contract = original_contract.clone();
        changed_contract.split.protocol_salt = "independent-role-salt".to_string();
        let changed = deterministic_assignments(&records, &changed_contract)
            .expect("changed-salt deterministic assignments");
        assert_ne!(original, changed, "the salt must still govern split roles");

        let original_train_folds = original
            .iter()
            .filter(|assignment| assignment.role == SplitRole::Train)
            .map(|assignment| (&assignment.unit_id, assignment.fold))
            .collect::<BTreeMap<_, _>>();
        let changed_train_folds = changed
            .iter()
            .filter(|assignment| assignment.role == SplitRole::Train)
            .map(|assignment| (&assignment.unit_id, assignment.fold))
            .collect::<BTreeMap<_, _>>();
        let common = original_train_folds
            .keys()
            .filter(|unit| changed_train_folds.contains_key(*unit))
            .count();
        assert!(
            common > 20,
            "test needs entities assigned to train under both salts"
        );
        for (unit, fold) in &original_train_folds {
            if let Some(changed_fold) = changed_train_folds.get(*unit) {
                assert_eq!(fold, changed_fold, "fold changed for stable ID {unit}");
            }
        }
    }

    #[test]
    fn duplicate_assignments_are_rejected() {
        let records = vec![Record::for_test("u1", None), Record::for_test("u2", None)];
        let one = assignment(&records[0], SplitRole::Train, Some(0));
        let error = validate_assignments(&records, &[one.clone(), one], 2)
            .expect_err("duplicates must fail");
        assert!(error.to_string().contains("duplicate unit/epoch"));
    }

    #[test]
    fn missing_roles_unknown_ids_and_fold_ranges_are_rejected() {
        let records = vec![Record::for_test("u1", None), Record::for_test("u2", None)];
        let assignments = vec![
            assignment(&records[0], SplitRole::Train, Some(0)),
            assignment(&records[1], SplitRole::Calibration, None),
        ];
        assert!(validate_assignments(&records, &assignments, 2)
            .expect_err("holdout missing")
            .to_string()
            .contains("holdout"));

        let records = vec![
            Record::for_test("u1", None),
            Record::for_test("u2", None),
            Record::for_test("u3", None),
        ];
        let mut assignments = vec![
            assignment(&records[0], SplitRole::Train, Some(9)),
            assignment(&records[1], SplitRole::Calibration, None),
            assignment(&records[2], SplitRole::Holdout, None),
        ];
        assert!(validate_assignments(&records, &assignments, 2)
            .expect_err("out-of-range fold")
            .to_string()
            .contains("fold index"));
        assignments[0].fold = Some(0);
        assignments[2].unit_id = "unknown".to_string();
        assert!(validate_assignments(&records, &assignments, 2)
            .expect_err("unknown identifier")
            .to_string()
            .contains("exactly match"));
    }

    #[test]
    fn entity_panel_split_keeps_all_entity_epochs_and_folds_together() {
        let records = panel_records();
        let contract = contract(SplitStrategy::EntityHash, true);
        let assignments =
            deterministic_assignments(&records, &contract).expect("panel assignments");
        let leakage = leakage_checks(&records, &assignments);
        assert!(leakage.entity_disjoint_verified);
        assert!(!leakage.epoch_disjoint_verified);
        for unit in ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l"] {
            let roles = assignments
                .iter()
                .filter(|assignment| assignment.unit_id == unit)
                .map(|assignment| assignment.role)
                .collect::<BTreeSet<_>>();
            assert_eq!(roles.len(), 1);
        }
    }

    #[test]
    fn epoch_split_is_ordered_and_globally_epoch_disjoint() {
        let records = panel_records();
        let contract = contract(SplitStrategy::EpochDisjoint, true);
        let assignments =
            deterministic_assignments(&records, &contract).expect("epoch assignments");
        let leakage = leakage_checks(&records, &assignments);
        assert!(leakage.epoch_disjoint_verified);
        for assignment in &assignments {
            let epoch = assignment.epoch.expect("panel epoch");
            match assignment.role {
                SplitRole::Train => assert!(epoch < 3),
                SplitRole::Calibration => assert_eq!(epoch, 3),
                SplitRole::Holdout => assert!(epoch >= 4),
            }
        }
    }

    #[test]
    fn explicit_entity_and_epoch_leakage_fail_contract_validation() {
        let records = vec![
            Record::for_test("u1", Some(0)),
            Record::for_test("u1", Some(1)),
            Record::for_test("u2", Some(2)),
        ];
        let assignments = vec![
            assignment(&records[0], SplitRole::Train, Some(0)),
            assignment(&records[1], SplitRole::Calibration, None),
            assignment(&records[2], SplitRole::Holdout, None),
        ];
        let error = validate_assignments_for_contract(
            &records,
            assignments,
            &contract(SplitStrategy::EntityHash, true),
        )
        .expect_err("entity overlap must fail");
        assert!(error.to_string().contains("entity overlap"));

        let records = vec![
            Record::for_test("u1", Some(0)),
            Record::for_test("u2", Some(1)),
            Record::for_test("u3", Some(1)),
            Record::for_test("u4", Some(2)),
        ];
        let assignments = vec![
            assignment(&records[0], SplitRole::Train, Some(0)),
            assignment(&records[1], SplitRole::Train, Some(1)),
            assignment(&records[2], SplitRole::Calibration, None),
            assignment(&records[3], SplitRole::Holdout, None),
        ];
        let error = validate_assignments_for_contract(
            &records,
            assignments,
            &contract(SplitStrategy::EpochDisjoint, true),
        )
        .expect_err("epoch overlap must fail");
        assert!(error.to_string().contains("epoch overlap"));
    }
}
