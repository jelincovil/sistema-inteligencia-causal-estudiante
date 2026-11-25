use argument_document::{EvidenceSpec, Receipt, TrustMode};
use serde::Serialize;

/// Byte-level outcome of checking the files a receipt points at.
///
/// Built by the caller (the CLI), which is the only layer with a resolved
/// root. Every registered target and every artifact is accounted for:
/// `checked == matched + missing + mismatched + rejected`.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq, Serialize)]
pub struct ByteVerification {
    pub checked: u32,
    pub matched: u32,
    pub missing: u32,
    pub mismatched: u32,
    /// Rejected before reading (absolute path, parent escape, symlink
    /// component, directory, oversize, or I/O error).
    pub rejected: u32,
}

impl ByteVerification {
    /// True when everything that was checked matched the registered hash.
    /// Vacuously true for an empty set; the empty set is not a witness,
    /// as `replay_witnessed: false` keeps saying.
    pub const fn all_matched(&self) -> bool {
        self.missing == 0 && self.mismatched == 0 && self.rejected == 0
    }

    pub fn absorb(&mut self, outcome: TargetOutcome) {
        self.checked += 1;
        match outcome {
            TargetOutcome::Matched => self.matched += 1,
            TargetOutcome::Mismatched => self.mismatched += 1,
            TargetOutcome::Missing => self.missing += 1,
            TargetOutcome::Rejected => self.rejected += 1,
        }
    }
}

/// Result of checking one registered target or artifact against current bytes.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TargetOutcome {
    Matched,
    Mismatched,
    Missing,
    Rejected,
}

/// The strongest outcome this base will emit for a receipt.
///
/// `claim_supported` is a constant false and `replay_witnessed` is a
/// constant false. Replaying a process, or an explicit attestation policy,
/// has to be a different type that this function does not accept from JSON.
///
/// Field semantics:
/// - `receipt_internally_consistent`: the receipt is coherent with itself
///   (termination, exit status, observed checks, timestamps). This is not
///   proof that anything ran, and it is not an admission.
/// - `input_hashes` / `artifacts`: byte-level verification against the
///   caller-resolved root. Counts, not vibes.
/// - `targets_verified`: every registered target and artifact that was
///   checked matched its registered hash. Vacuously true when nothing was
///   registered; it never promotes a claim.
/// - `receipt_scientific_criterion_met`: the receipt's own self-attestation,
///   passed through untouched and never promoted by this checker.
#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Admission {
    pub receipt_id: String,
    pub spec_id: String,
    pub receipt_internally_consistent: bool,
    pub spec_hash_matches: bool,
    pub trust_mode: String,
    pub input_hashes: ByteVerification,
    pub artifacts: ByteVerification,
    pub targets_verified: bool,
    pub receipt_scientific_criterion_met: Option<bool>,
    pub replay_witnessed: bool,
    pub claim_supported: bool,
    pub reason: String,
}

/// Stable reason strings. The set is closed; additions are a software change.
pub const REASON_RECEIPT_INCONSISTENT: &str = "receipt_inconsistent";
pub const REASON_SPEC_HASH_MISMATCH: &str = "spec_hash_mismatch";
pub const REASON_INPUT_TARGET_MISSING: &str = "input_target_missing";
pub const REASON_INPUT_TARGET_STALE: &str = "input_target_stale";
pub const REASON_INPUT_TARGET_REJECTED: &str = "input_target_rejected";
pub const REASON_ARTIFACT_MISSING: &str = "artifact_missing";
pub const REASON_ARTIFACT_STALE: &str = "artifact_stale";
pub const REASON_ARTIFACT_REJECTED: &str = "artifact_rejected";
pub const REASON_UNTRUSTED_IMPORT: &str = "untrusted_import";
pub const REASON_ATTESTATION_NOT_CONFIGURED: &str = "attestation_policy_not_configured";
pub const REASON_EXECUTION_NOT_PASSED: &str = "execution_not_passed";
pub const REASON_REPLAY_NOT_WITNESSED: &str = "replay_not_witnessed";

pub fn admit_receipt(
    receipt: &Receipt,
    spec: &EvidenceSpec,
    expected_spec_hash: &str,
    input_hashes: &ByteVerification,
    artifacts: &ByteVerification,
) -> Admission {
    let receipt_internally_consistent = receipt.internally_consistent();
    let spec_hash_matches = receipt.spec_id == spec.id && receipt.spec_hash == expected_spec_hash;
    let targets_verified = input_hashes.all_matched() && artifacts.all_matched();
    let reason = if !receipt_internally_consistent {
        REASON_RECEIPT_INCONSISTENT
    } else if !spec_hash_matches {
        REASON_SPEC_HASH_MISMATCH
    } else if input_hashes.missing > 0 {
        REASON_INPUT_TARGET_MISSING
    } else if input_hashes.mismatched > 0 {
        REASON_INPUT_TARGET_STALE
    } else if input_hashes.rejected > 0 {
        REASON_INPUT_TARGET_REJECTED
    } else if artifacts.missing > 0 {
        REASON_ARTIFACT_MISSING
    } else if artifacts.mismatched > 0 {
        REASON_ARTIFACT_STALE
    } else if artifacts.rejected > 0 {
        REASON_ARTIFACT_REJECTED
    } else if receipt.trust_mode == TrustMode::UntrustedImport {
        REASON_UNTRUSTED_IMPORT
    } else if receipt.trust_mode == TrustMode::AttestedByConfiguredPolicy {
        REASON_ATTESTATION_NOT_CONFIGURED
    } else if !receipt.execution_passed {
        REASON_EXECUTION_NOT_PASSED
    } else {
        REASON_REPLAY_NOT_WITNESSED
    };
    Admission {
        receipt_id: receipt.id.clone(),
        spec_id: receipt.spec_id.clone(),
        receipt_internally_consistent,
        spec_hash_matches,
        trust_mode: trust_label(receipt.trust_mode).to_string(),
        input_hashes: *input_hashes,
        artifacts: *artifacts,
        targets_verified,
        receipt_scientific_criterion_met: receipt.scientific_criterion_met,
        replay_witnessed: false,
        claim_supported: false,
        reason: reason.to_string(),
    }
}

fn trust_label(mode: TrustMode) -> &'static str {
    match mode {
        TrustMode::LocallyReproduced => "locally_reproduced",
        TrustMode::UntrustedImport => "untrusted_import",
        TrustMode::AttestedByConfiguredPolicy => "attested_by_configured_policy",
    }
}
