use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};

/// Version of the deterministic artifact representation, not of the source corpus.
pub const OUTPUT_SCHEMA_VERSION: &str = "arg-ingest/1";

/// Complete set of files produced by both `build` and `verify`.
pub const ARTIFACT_NAMES: [&str; 10] = [
    "source_inventory.jsonl",
    "sources.jsonl",
    "source_units.jsonl",
    "argument_candidates.jsonl",
    "relations.jsonl",
    "exclusions.jsonl",
    "coverage.json",
    "REPORT.md",
    "manifest.json",
    "checksums.json",
];

/// An exact half-open byte range and its 1-based inclusive source lines.
#[derive(Debug, Clone, PartialEq, Eq, PartialOrd, Ord, Serialize, Deserialize)]
pub struct SourceSpan {
    pub byte_start: u64,
    pub byte_end: u64,
    pub line_start: u64,
    pub line_end: u64,
}

/// Inventory entry for a regular file or one explicitly pruned directory.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceInventoryRecord {
    pub schema_version: String,
    pub entry_kind: String,
    pub collection: String,
    pub edition: String,
    pub path: String,
    pub collection_path: String,
    pub format: String,
    pub role: String,
    pub disposition: String,
    pub source_status: String,
    pub bytes: Option<u64>,
    pub sha256: Option<String>,
    pub reason: String,
}

/// An included source, hashed even when its disposition is metadata-only.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceRecord {
    pub schema_version: String,
    pub id: String,
    pub collection: String,
    pub edition: String,
    pub path: String,
    pub collection_path: String,
    pub format: String,
    pub role: String,
    pub disposition: String,
    pub source_status: String,
    pub bytes: u64,
    pub sha256: String,
    pub reason: String,
    pub parse_kind: Option<String>,
    pub candidate_eligible: bool,
}

/// Exact raw source slice. JSON strings preserve UTF-8 bytes and CRLF on decode.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceUnit {
    pub schema_version: String,
    pub id: String,
    pub source_id: String,
    pub collection: String,
    pub edition: String,
    pub path: String,
    pub collection_path: String,
    pub source_revision: String,
    pub format: String,
    pub role: String,
    pub source_status: String,
    pub span: SourceSpan,
    pub raw_sha256: String,
    pub raw_text: String,
    pub heading_trail: Vec<String>,
    pub structural_kind: String,
    pub json_pointer: Option<String>,
    pub coverage_status: String,
    pub candidate_id: Option<String>,
}

/// One traceable occurrence of a content-deduplicated candidate.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CandidateOccurrence {
    pub unit_id: String,
    pub collection: String,
    pub edition: String,
    pub path: String,
    pub collection_path: String,
    pub source_revision: String,
    pub span: SourceSpan,
    pub heading_trail: Vec<String>,
}

/// A documentary scope shared by one or more candidate occurrences.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SourceScope {
    pub collection: String,
    pub edition: String,
    pub source_status: String,
    pub paths: Vec<String>,
}

/// Unreviewed verbatim candidate. Its ID is content-derived, not a curated ID.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ArgumentCandidate {
    pub schema_version: String,
    pub id: String,
    pub statement: String,
    pub statement_sha256: String,
    pub argument_kind: String,
    pub epistemic_status: String,
    pub review_status: String,
    pub source_status: String,
    pub candidate_origin: String,
    pub topics: Vec<String>,
    pub topic_review_status: String,
    pub occurrences: Vec<CandidateOccurrence>,
    pub source_scopes: Vec<SourceScope>,
    pub atomicity_status: String,
}

/// File-level byte identity or a same-path, different-byte monograph variant.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct RelationRecord {
    pub schema_version: String,
    pub kind: String,
    pub relative_path: String,
    pub canonical_path: String,
    pub canonical_sha256: String,
    pub related_path: String,
    pub related_sha256: String,
}

/// Excluded regular file or pruned directory. Pruning records no descendants.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct ExclusionRecord {
    pub schema_version: String,
    pub entry_kind: String,
    pub collection: String,
    pub edition: String,
    pub path: String,
    pub collection_path: String,
    pub format: String,
    pub role: String,
    pub source_status: String,
    pub bytes: Option<u64>,
    pub sha256: Option<String>,
    pub reason: String,
}

/// Exact included-file count for one declared required group.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CoverageGroup {
    pub id: String,
    pub collection: String,
    pub path_prefix: String,
    pub path_suffix: String,
    pub expected_files: usize,
    pub matched_files: usize,
    pub matched_paths: Vec<String>,
    pub status: String,
}

/// Deterministic per-collection documentary accounting.
#[derive(Debug, Clone, Default, Serialize, Deserialize)]
pub struct CollectionCoverage {
    pub discovered_regular_files: usize,
    pub included_files: usize,
    pub excluded_files: usize,
    pub parsed_files: usize,
    pub metadata_only_files: usize,
    pub source_units: usize,
    pub candidate_occurrences: usize,
    pub candidates_present: usize,
    pub pruned_directories: usize,
}

/// Coverage is documentary and declared-policy-relative, never semantic curation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CoverageReport {
    pub schema_version: String,
    pub corpus_id: String,
    pub collections: BTreeMap<String, CollectionCoverage>,
    pub discovered_regular_files: usize,
    pub included_files: usize,
    pub excluded_files: usize,
    pub parsed_files: usize,
    pub metadata_only_files: usize,
    pub source_units: usize,
    pub unique_candidates: usize,
    pub candidate_occurrences: usize,
    pub pruned_directories: usize,
    pub byte_identical_relations: usize,
    pub content_variant_relations: usize,
    pub required_groups: Vec<CoverageGroup>,
    pub checks: BTreeMap<String, bool>,
    pub errors: Vec<String>,
    pub documentary_coverage_complete: bool,
    pub semantically_curated_corpus_complete: bool,
}

/// Candidate stream filters. Only `contains` is case-insensitive.
#[derive(Debug, Clone, Default)]
pub struct QueryFilter {
    pub collection: Option<String>,
    pub topic: Option<String>,
    pub contains: Option<String>,
    pub limit: Option<usize>,
}
