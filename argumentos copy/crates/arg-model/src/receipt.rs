use std::collections::{BTreeMap, HashSet};

use serde::Deserialize;
use serde_json::Value;

use crate::dup::reject_duplicate_keys;
use crate::error::ContractError;
use crate::limits::{
    MAX_COMMAND_ARGV, MAX_COMMAND_ARG_BYTES, MAX_DOCUMENT_BYTES, MAX_RECEIPTS,
    MAX_RECEIPT_ARTIFACTS, MAX_RECEIPT_TARGETS, MAX_TARGET_LOCATOR_BYTES,
};
use crate::model::is_id;

/// A receipt is a candidate record of a run.
///
/// Loading one does not admit it. `execution_passed` is not
/// `scientific_criterion_met`, and neither is `claim_supported`.
/// There is deliberately no field that can set a claim to proved.
///
/// Documents are bounded; see [`crate::limits`]. Timestamps must be
/// RFC3339-compatible UTC of the shape `YYYY-MM-DDTHH:MM:SS[.fraction]Z`
/// (uppercase `T` and `Z` only, no offset, no leap-second `60`), and
/// `started_at` must not be after `finished_at`. No external calendar
/// dependency is used; leap days are validated against the proleptic
/// Gregorian calendar.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Receipt {
    pub schema_version: String,
    pub id: String,
    pub spec_id: String,
    pub spec_hash: String,
    pub source_commit: String,
    pub environment_hash: String,
    pub checker_version: String,
    pub command_argv: Vec<String>,
    pub working_directory: String,
    pub input_hashes: BTreeMap<String, String>,
    pub started_at: String,
    pub finished_at: String,
    pub exit_status: Option<i32>,
    pub termination: Termination,
    pub stdout_sha256: String,
    pub stderr_sha256: String,
    pub artifacts: Vec<Artifact>,
    pub execution_passed: bool,
    pub scientific_criterion_met: Option<bool>,
    pub observed_checks: Vec<ObservedCheck>,
    pub trust_mode: TrustMode,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Artifact {
    pub path: String,
    pub sha256: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ObservedCheck {
    pub id: String,
    pub status: CheckStatus,
    pub detail: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum CheckStatus {
    Pass,
    Fail,
    Skip,
    Pending,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Termination {
    Completed,
    Timeout,
    ResourceLimit,
    LaunchFailed,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum TrustMode {
    LocallyReproduced,
    UntrustedImport,
    AttestedByConfiguredPolicy,
}

impl Receipt {
    /// The document byte cap applies to receipt files, before any parsing.
    fn check_document_size(bytes: &[u8]) -> Result<(), ContractError> {
        if bytes.len() as u64 > MAX_DOCUMENT_BYTES {
            return Err(ContractError::InputTooLarge {
                limit: MAX_DOCUMENT_BYTES,
                actual: bytes.len() as u64,
            });
        }
        Ok(())
    }

    pub fn load(bytes: &[u8]) -> Result<Self, ContractError> {
        Self::check_document_size(bytes)?;
        let text = std::str::from_utf8(bytes).map_err(|_| ContractError::Utf8)?;
        reject_duplicate_keys(text)?;
        let value: Value = serde_json::from_str(text).map_err(ContractError::from_serde)?;
        let receipt: Self = serde_json::from_value(value).map_err(ContractError::from_serde)?;
        receipt.validate_shape()?;
        Ok(receipt)
    }

    pub fn load_all(bytes: &[u8]) -> Result<Vec<Self>, ContractError> {
        Self::check_document_size(bytes)?;
        let text = std::str::from_utf8(bytes).map_err(|_| ContractError::Utf8)?;
        reject_duplicate_keys(text)?;
        let value: Value = serde_json::from_str(text).map_err(ContractError::from_serde)?;
        let items = value.as_array().ok_or_else(|| {
            ContractError::Invalid("receipt file must be a JSON array".to_string())
        })?;
        if items.len() > MAX_RECEIPTS {
            return Err(ContractError::CollectionTooLarge {
                what: "receipts",
                limit: MAX_RECEIPTS,
                actual: items.len(),
            });
        }
        let mut ids = HashSet::with_capacity(items.len());
        let mut receipts = Vec::with_capacity(items.len());
        for item in items.iter().cloned() {
            let receipt: Self = serde_json::from_value(item).map_err(ContractError::from_serde)?;
            receipt.validate_shape()?;
            if !ids.insert(receipt.id.clone()) {
                return Err(ContractError::DuplicateId(receipt.id));
            }
            receipts.push(receipt);
        }
        Ok(receipts)
    }

    /// Defense-in-depth recomputation of receipt-local coherence.
    ///
    /// `execution_passed` must agree with termination and exit status and
    /// must not contradict any observed check with status fail or pending;
    /// timestamps must parse as RFC3339 UTC and be ordered. Callers treat
    /// this as a necessary-but-not-sufficient condition for anything else.
    pub fn internally_consistent(&self) -> bool {
        // Same rule the loader enforces, recomputed, plus timestamp order.
        // The converse (clean exit but execution_passed=false) is legitimate:
        // a runner may decline to claim a pass without a failed exit.
        let exit_ok = self.termination == Termination::Completed && self.exit_status == Some(0);
        let argument_ok = !self.execution_passed || exit_ok;
        let observed_ok = !self.execution_passed
            || self
                .observed_checks
                .iter()
                .all(|check| !matches!(check.status, CheckStatus::Fail | CheckStatus::Pending));
        let time_ok = match (
            parse_rfc3339_utc(&self.started_at),
            parse_rfc3339_utc(&self.finished_at),
        ) {
            (Ok(started), Ok(finished)) => started <= finished,
            _ => false,
        };
        observed_ok && argument_ok && time_ok
    }

    fn validate_shape(&self) -> Result<(), ContractError> {
        if self.schema_version != "1.0" {
            return Err(ContractError::SchemaVersion(self.schema_version.clone()));
        }
        if !is_id(&self.id) {
            return Err(ContractError::BadId(self.id.clone()));
        }
        if !is_id(&self.spec_id) {
            return Err(ContractError::BadId(self.spec_id.clone()));
        }
        if self.working_directory.trim().is_empty() {
            return Err(ContractError::Invalid(
                "working_directory must not be empty".to_string(),
            ));
        }
        for hash in [
            &self.spec_hash,
            &self.environment_hash,
            &self.stdout_sha256,
            &self.stderr_sha256,
        ] {
            require_sha256(hash)?;
        }
        if self.input_hashes.len() > MAX_RECEIPT_TARGETS {
            return Err(ContractError::CollectionTooLarge {
                what: "input_hashes",
                limit: MAX_RECEIPT_TARGETS,
                actual: self.input_hashes.len(),
            });
        }
        for (locator, hash) in &self.input_hashes {
            if locator.trim().is_empty()
                || locator.len() > MAX_TARGET_LOCATOR_BYTES
                || locator.bytes().any(|byte| byte == 0)
            {
                return Err(ContractError::Invalid(format!(
                    "input_hashes locator `{locator}` is empty, too long, or contains NUL"
                )));
            }
            require_sha256(hash)?;
        }
        if self.artifacts.len() > MAX_RECEIPT_ARTIFACTS {
            return Err(ContractError::CollectionTooLarge {
                what: "artifacts",
                limit: MAX_RECEIPT_ARTIFACTS,
                actual: self.artifacts.len(),
            });
        }
        for artifact in &self.artifacts {
            require_sha256(&artifact.sha256)?;
            if artifact.path.trim().is_empty()
                || artifact.path.len() > MAX_TARGET_LOCATOR_BYTES
                || artifact.path.bytes().any(|byte| byte == 0)
            {
                return Err(ContractError::Invalid(
                    "artifact path is empty, too long, or contains NUL".to_string(),
                ));
            }
        }
        if self.command_argv.is_empty() || self.command_argv.len() > MAX_COMMAND_ARGV {
            return Err(ContractError::CollectionTooLarge {
                what: "command_argv",
                limit: MAX_COMMAND_ARGV,
                actual: self.command_argv.len(),
            });
        }
        for part in &self.command_argv {
            if part.is_empty() || part.len() > MAX_COMMAND_ARG_BYTES {
                return Err(ContractError::Invalid(
                    "command_argv entries must be non-empty and bounded; never a shell string"
                        .to_string(),
                ));
            }
        }
        let started = parse_rfc3339_utc(&self.started_at)?;
        let finished = parse_rfc3339_utc(&self.finished_at)?;
        if started > finished {
            return Err(ContractError::TimestampOrder);
        }
        for check in &self.observed_checks {
            if check.id.trim().is_empty() {
                return Err(ContractError::Invalid(
                    "observed_checks id must not be empty".to_string(),
                ));
            }
        }
        if self.execution_passed {
            if !(self.termination == Termination::Completed && self.exit_status == Some(0)) {
                return Err(ContractError::Invalid(
                    "execution_passed requires termination=completed and exit_status=0".to_string(),
                ));
            }
            if self
                .observed_checks
                .iter()
                .any(|check| matches!(check.status, CheckStatus::Fail | CheckStatus::Pending))
            {
                return Err(ContractError::Invalid(
                    "execution_passed requires no observed check with status fail or pending"
                        .to_string(),
                ));
            }
        }
        Ok(())
    }
}

fn require_sha256(value: &str) -> Result<(), ContractError> {
    let ok = value.len() == 64
        && value
            .bytes()
            .all(|byte| byte.is_ascii_hexdigit() && !byte.is_ascii_uppercase());
    if ok {
        Ok(())
    } else {
        Err(ContractError::Invalid(format!(
            "expected lowercase SHA-256, found `{value}`"
        )))
    }
}

/// One parsed RFC3339-compatible UTC timestamp.
///
/// Field tuple is only used for ordering and equality; no epoch math, no
/// time zone database, no external dependency.
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord)]
struct Timestamp(u32, u32, u32, u32, u32, u32, u32);

fn parse_rfc3339_utc(text: &str) -> Result<Timestamp, ContractError> {
    let bytes = text.as_bytes();
    // YYYY-MM-DDTHH:MM:SS = 19 bytes, optional ".fraction", trailing 'Z'.
    let bail = || ContractError::BadTimestamp(text.to_string());
    if bytes.len() < 20 || bytes[4] != b'-' || bytes[7] != b'-' || bytes[10] != b'T' {
        return Err(bail());
    }
    let digit = |index: usize| -> Result<u32, ContractError> {
        match bytes[index] {
            b @ b'0'..=b'9' => Ok(u32::from(b - b'0')),
            _ => Err(ContractError::BadTimestamp(text.to_string())),
        }
    };
    let number = |start: usize, len: usize| -> Result<u32, ContractError> {
        let mut value = 0_u32;
        for offset in 0..len {
            value = value * 10 + digit(start + offset)?;
        }
        Ok(value)
    };
    let year = number(0, 4)?;
    let month = number(5, 2)?;
    let day = number(8, 2)?;
    if bytes[13] != b':' || bytes[16] != b':' {
        return Err(bail());
    }
    let hour = number(11, 2)?;
    let minute = number(14, 2)?;
    let second = number(17, 2)?;

    let mut nanos = 0_u32;
    let mut index = 19;
    if index < bytes.len() && bytes[index] == b'.' {
        index += 1;
        let mut digits = 0_usize;
        let mut fraction = 0_u32;
        while index < bytes.len() && bytes[index].is_ascii_digit() {
            if digits < 9 {
                fraction = fraction * 10 + u32::from(bytes[index] - b'0');
                digits += 1;
            }
            // Extra digits beyond nanosecond precision are accepted but
            // do not increase the resolution used for ordering.
            index += 1;
        }
        if digits == 0 {
            return Err(bail());
        }
        while digits < 9 {
            fraction *= 10;
            digits += 1;
        }
        nanos = fraction;
    }
    if index != bytes.len() - 1 || bytes[index] != b'Z' {
        return Err(bail());
    }

    if !(1..=12).contains(&month) {
        return Err(bail());
    }
    let leap = (year % 4 == 0 && year % 100 != 0) || year % 400 == 0;
    let days_in_month = match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 if leap => 29,
        2 => 28,
        _ => return Err(bail()),
    };
    if day < 1 || day > days_in_month {
        return Err(bail());
    }
    if hour > 23 || minute > 59 || second > 59 {
        return Err(bail());
    }
    Ok(Timestamp(year, month, day, hour, minute, second, nanos))
}
