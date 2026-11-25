//! Typed documents for an argument kernel.
//!
//! The types are corpus-agnostic. A book is one profile and one source
//! system, not a special case baked into the checker. Nothing in this crate
//! assigns `lean_checked`, `reproduced`, or `claim_supported`. Those are
//! outputs of a checker that has actually admitted evidence, and this loader
//! refuses documents that try to write them in.
//!
//! Input limits are enforced on every load path; see [`limits`] and the
//! `MAX_*` constants re-exported there. Documents that exceed a limit fail
//! with a typed [`ContractError`] before any rule runs.

mod canonical;
mod dup;
mod error;
mod limits;
mod model;
mod receipt;

pub use canonical::{
    canonical_kernel, evidence_spec_sha256, kernel_sha256, sha256_file_capped, sha256_hex,
};
pub use dup::reject_duplicate_keys;
pub use error::ContractError;
pub use limits::*;
pub use model::{
    is_id, AtomEntry, Availability, Claim, ClaimKind, Corpus, CorpusKind, EvidenceKind,
    EvidenceSpec, Expression, Kernel, LoadedArgument, ProfileId, Rule, SchemaVersion,
    SourceLocator, ID_HELP,
};
pub use receipt::{Artifact, CheckStatus, ObservedCheck, Receipt, Termination, TrustMode};
