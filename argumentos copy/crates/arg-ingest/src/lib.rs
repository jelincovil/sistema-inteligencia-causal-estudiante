//! Deterministic, source-complete documentary corpus ingestion.
//!
//! This crate inventories declared sources, anchors exact raw text units, and
//! emits content-derived argument candidates. It does not execute imported
//! code, certify claims, or export the legacy typed claim kernel.

mod artifacts;
mod candidates;
mod classify;
mod config;
mod coverage;
mod model;
mod query;
mod relations;
mod text;
mod walk;

pub use artifacts::{build, generate, verify, GeneratedCorpus, VerifyReport};
pub use config::{load_config, CollectionConfig, CorpusConfig, LoadedConfig, RequiredGroup};
pub use model::{
    ArgumentCandidate, CandidateOccurrence, CollectionCoverage, CoverageGroup, CoverageReport,
    ExclusionRecord, QueryFilter, RelationRecord, SourceInventoryRecord, SourceRecord, SourceScope,
    SourceSpan, SourceUnit, ARTIFACT_NAMES, OUTPUT_SCHEMA_VERSION,
};
pub use query::{load_candidates, query_candidates};

use sha2::{Digest, Sha256};

pub(crate) fn sha256(bytes: &[u8]) -> String {
    let mut hasher = Sha256::new();
    hasher.update(bytes);
    format!("{:x}", hasher.finalize())
}

pub(crate) fn slash_path(path: &std::path::Path) -> String {
    path.components()
        .map(|component| component.as_os_str().to_string_lossy())
        .collect::<Vec<_>>()
        .join("/")
}
