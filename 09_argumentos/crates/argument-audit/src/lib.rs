//! Administrative checker for typed argument documents.
//!
//! This crate does not call Lean, Python, a language model, or a network.
//! A structurally valid argument still has open obligations until a separate
//! admission step, which this version never converts into `claim_supported`.

mod admit;
mod check;
mod graph;
pub mod obligations;
mod profile;
mod report;
mod scope;
mod ssch;
mod support;

pub use admit::{
    admit_receipt, Admission, ByteVerification, TargetOutcome, REASON_ARTIFACT_MISSING,
    REASON_ARTIFACT_REJECTED, REASON_ARTIFACT_STALE, REASON_ATTESTATION_NOT_CONFIGURED,
    REASON_EXECUTION_NOT_PASSED, REASON_INPUT_TARGET_MISSING, REASON_INPUT_TARGET_REJECTED,
    REASON_INPUT_TARGET_STALE, REASON_RECEIPT_INCONSISTENT, REASON_REPLAY_NOT_WITNESSED,
    REASON_SPEC_HASH_MISMATCH, REASON_UNTRUSTED_IMPORT,
};
pub use check::check;
pub use graph::{
    explain, ArgumentNode, AuditGraph, ClaimNode, EvidenceNode, Explanation, FindingNode,
    GraphEdge, GraphError, GraphNode, ReferenceNode, Relation, Trace, EXPLANATION_SCHEMA_VERSION,
    GRAPH_SCHEMA_VERSION, GRAPH_SOURCE_NOTE,
};
pub use profile::allows;
pub use report::{
    ArgumentFinding, CheckReport, ClaimFinding, Decision, Diagnostic, Severity, StatusAxis,
};
pub use ssch::{ssch_one_decision_exact_v1, Ratio, SschInstance};

pub const CHECKER_VERSION: &str = "0.1.0";

pub const LIMITS: &str = "Administrative structure only. No Lean export, no process replay, no semantic equivalence, no statistical law, no clinical claim. A receipt cannot promote a claim. SOFTWARE_READY and CORPUS_CLOSED are not implied.";
