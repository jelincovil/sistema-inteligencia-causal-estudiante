//! Scope comparison for premise → conclusion flow.
//!
//! The rule is exact equality with two documented exceptions, and nothing
//! else:
//!
//! 1. The declared aggregation keys `role`, `clip`, `diagnostic`,
//!    `claim_class`, and `limitation` may be absent from the conclusion.
//!    One conditional dossier can aggregate distinct limitations, so a
//!    conclusion that carries none of these keys is not missing anything.
//!    If present on both sides they must match exactly: no case/whitespace
//!    normalization, no revalue. Absent in the premise but present in the
//!    conclusion is an error, exactly like any other key.
//! 2. The keys `domain` and `observations` form a finite → countable →
//!    infinite lattice. Values compare case/whitespace-insensitively
//!    against the lattice — and only those keys may do so — and only those
//!    keys may move along the lattice (`scope_widened` in the
//!    conditional-application path). Narrowing is an error; off-lattice
//!    values compare byte-exactly.
//!
//! Everything else — including the context keys `dataset`, `protocol`,
//! `estimand`, `setting`, `scenario`, and `population` — must match
//! exactly, in both directions: a premise key absent from the conclusion, a
//! conclusion key absent from the premise, or any value difference is an
//! error.
//!
//! Heterogeneous categories are expressed by *omitting* the aggregation
//! key, never by inventing a joint value. A dossier whose premises carry
//! `claim_class: association` and `claim_class: prediction` may conclude
//! with no `claim_class` at all, or with the shared one — but an aggregate
//! value such as `analogical` that appears in no premise is a revalue, not
//! an aggregate tag, and stays a `scope_mismatch` error. Likewise an added
//! key on the conclusion side is an error. This keeps context keys and the
//! category keys fail-closed; nothing about unknown added keys is
//! permitted.
//!
//! Normalization (ASCII case folding, whitespace collapse) applies only to
//! lattice values. All other keys and values compare byte-exactly.

use std::collections::BTreeMap;

pub(crate) const AGGREGATION_KEYS: &[&str] =
    &["role", "clip", "diagnostic", "claim_class", "limitation"];
pub(crate) const LATTICE_KEYS: &[&str] = &["domain", "observations"];

#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct ScopeFinding {
    pub key: String,
    pub detail: String,
    /// True only for finite/countable/infinite lattice widenings. Used to
    /// select the `scope_widened` code in the conditional-application path.
    pub lattice_widening: bool,
}

fn normalize_lattice(value: &str) -> String {
    value
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
        .to_ascii_lowercase()
}

fn lattice_rank(value: &str) -> Option<u8> {
    match normalize_lattice(value).as_str() {
        "finite" => Some(0),
        "countable" => Some(1),
        "infinite" => Some(2),
        _ => None,
    }
}

pub(crate) fn scope_differences(
    premise: &BTreeMap<String, String>,
    conclusion: &BTreeMap<String, String>,
) -> Vec<ScopeFinding> {
    let mut findings = Vec::new();
    let mut keys: Vec<&String> = premise.keys().collect();
    for key in conclusion.keys() {
        if !premise.contains_key(key) {
            keys.push(key);
        }
    }
    keys.sort();
    for key in keys {
        let from = premise.get(key);
        let to = conclusion.get(key);
        if AGGREGATION_KEYS.contains(&key.as_str()) {
            match (from, to) {
                (Some(_), None) => continue, // may be absent from the conclusion
                (Some(from), Some(to)) if from == to => {}
                (Some(from), Some(to)) => findings.push(finding(
                    key,
                    format!("scope key `{key}` changed from `{from}` to `{to}`"),
                    false,
                )),
                (None, Some(to)) => findings.push(finding(
                    key,
                    format!("conclusion scope key `{key}` is absent from the premise (`{to}`)"),
                    false,
                )),
                // Unreachable: `key` comes from the union of both maps.
                (None, None) => {}
            }
            continue;
        }
        if LATTICE_KEYS.contains(&key.as_str()) {
            match (from, to) {
                (Some(from), Some(to)) => match (lattice_rank(from), lattice_rank(to)) {
                    (Some(left), Some(right)) => {
                        if left == right {
                            // equal, up to case/whitespace
                        } else if left < right {
                            findings.push(finding(
                                key,
                                format!("scope key `{key}` widened from `{from}` to `{to}`"),
                                true,
                            ));
                        } else {
                            findings.push(finding(
                                key,
                                format!("scope key `{key}` narrowed from `{from}` to `{to}`"),
                                false,
                            ));
                        }
                    }
                    _ => {
                        if from != to {
                            findings.push(finding(
                                key,
                                format!("scope key `{key}` changed from `{from}` to `{to}`"),
                                false,
                            ));
                        }
                    }
                },
                (Some(from), None) => findings.push(finding(
                    key,
                    format!("premise scope key `{key}` is absent from the conclusion (`{from}`)"),
                    false,
                )),
                (None, Some(to)) => findings.push(finding(
                    key,
                    format!("conclusion scope key `{key}` is absent from the premise (`{to}`)"),
                    false,
                )),
                // Unreachable: `key` comes from the union of both maps.
                (None, None) => {}
            }
            continue;
        }
        match (from, to) {
            (Some(from), Some(to)) if from == to => {}
            (Some(from), Some(to)) => findings.push(finding(
                key,
                format!("scope key `{key}` changed from `{from}` to `{to}`"),
                false,
            )),
            (Some(from), None) => findings.push(finding(
                key,
                format!("premise scope key `{key}` is absent from the conclusion (`{from}`)"),
                false,
            )),
            (None, Some(to)) => findings.push(finding(
                key,
                format!("conclusion scope key `{key}` is absent from the premise (`{to}`)"),
                false,
            )),
            // Unreachable: `key` comes from the union of both maps.
            (None, None) => {}
        }
    }
    findings
}

fn finding(key: &str, detail: String, lattice_widening: bool) -> ScopeFinding {
    ScopeFinding {
        key: key.to_string(),
        detail,
        lattice_widening,
    }
}
