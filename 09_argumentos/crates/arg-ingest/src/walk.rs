use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use walkdir::WalkDir;

use crate::classify::{classify, edition_for_root, Classification, Disposition};
use crate::config::{reject_symlink_components, CorpusConfig};
use crate::text::{extract, validate_raw_unit};
use crate::{
    sha256, slash_path, ExclusionRecord, SourceInventoryRecord, SourceRecord, SourceUnit,
    OUTPUT_SCHEMA_VERSION,
};

#[derive(Debug, Default)]
pub(crate) struct WalkedCorpus {
    pub(crate) inventory: Vec<SourceInventoryRecord>,
    pub(crate) sources: Vec<SourceRecord>,
    pub(crate) units: Vec<SourceUnit>,
    pub(crate) exclusions: Vec<ExclusionRecord>,
}

pub(crate) fn walk(config: &CorpusConfig, repository_root: &Path) -> Result<WalkedCorpus> {
    let mut output = WalkedCorpus::default();
    for collection in &config.collections {
        reject_symlink_components(repository_root, &collection.root)?;
        let root = repository_root.join(&collection.root);
        let edition = edition_for_root(&collection.root);
        let mut walker = WalkDir::new(&root)
            .follow_links(false)
            .sort_by_file_name()
            .into_iter();
        while let Some(entry) = walker.next() {
            let entry =
                entry.with_context(|| format!("walking declared root `{}`", collection.root))?;
            if entry.depth() == 0 {
                continue;
            }
            if entry.file_type().is_symlink() {
                bail!(
                    "symlink source inputs are forbidden: {}",
                    entry.path().display()
                );
            }
            let relative = entry
                .path()
                .strip_prefix(&root)
                .context("source entry escaped declared root before reading")?;
            let relative_string = relative
                .to_str()
                .context("source paths must be valid UTF-8")?
                .to_owned();
            if entry.file_type().is_dir() {
                if prune_name(&entry.file_name().to_string_lossy()) {
                    let repository_path = join_repository_path(&collection.root, &relative_string);
                    output.inventory.push(inventory_record(
                        "directory",
                        &collection.id,
                        &edition,
                        repository_path.clone(),
                        relative_string.clone(),
                        "directory",
                        "pruned_directory",
                        "excluded",
                        "out_of_scope",
                        None,
                        None,
                        "pruned_by_declared_policy_no_descendants_read",
                    ));
                    output.exclusions.push(exclusion_record(
                        "directory",
                        &collection.id,
                        &edition,
                        repository_path,
                        relative_string,
                        "directory",
                        "pruned_directory",
                        "out_of_scope",
                        None,
                        None,
                        "pruned_by_declared_policy_no_descendants_read",
                    ));
                    walker.skip_current_dir();
                }
                continue;
            }
            if !entry.file_type().is_file() {
                bail!(
                    "unsupported non-regular source input: {}",
                    entry.path().display()
                );
            }
            ingest_file(
                &collection.id,
                &collection.root,
                &edition,
                entry.path(),
                relative,
                &relative_string,
                entry.metadata()?.len(),
                &mut output,
            )?;
        }
    }

    output.inventory.sort_by(|left, right| {
        (&left.collection, &left.path, &left.entry_kind).cmp(&(
            &right.collection,
            &right.path,
            &right.entry_kind,
        ))
    });
    output.sources.sort_by(|left, right| {
        (&left.collection, &left.path).cmp(&(&right.collection, &right.path))
    });
    output.exclusions.sort_by(|left, right| {
        (&left.collection, &left.path).cmp(&(&right.collection, &right.path))
    });
    output.units.sort_by(|left, right| {
        (&left.collection, &left.path, left.span.byte_start, &left.id).cmp(&(
            &right.collection,
            &right.path,
            right.span.byte_start,
            &right.id,
        ))
    });
    Ok(output)
}

// Explicit path and classification inputs avoid hiding traversal state in a second context type.
#[allow(clippy::too_many_arguments)]
fn ingest_file(
    collection: &str,
    root: &str,
    edition: &str,
    absolute: &Path,
    relative: &Path,
    relative_string: &str,
    metadata_bytes: u64,
    output: &mut WalkedCorpus,
) -> Result<()> {
    let repository_path = join_repository_path(root, relative_string);
    let preliminary = classify(root, relative, metadata_bytes, None);
    let known_binary_exclusion = preliminary.disposition == Disposition::Excluded
        && preliminary.role != "unknown_binary_source";
    if known_binary_exclusion {
        push_excluded(
            output,
            collection,
            edition,
            repository_path,
            relative_string.to_owned(),
            preliminary,
            metadata_bytes,
        );
        return Ok(());
    }

    let bytes =
        fs::read(absolute).with_context(|| format!("reading source {}", absolute.display()))?;
    let text = std::str::from_utf8(&bytes).ok();
    let classification = classify(root, relative, bytes.len() as u64, Some(text.is_some()));
    if classification.disposition == Disposition::Excluded {
        push_excluded(
            output,
            collection,
            edition,
            repository_path,
            relative_string.to_owned(),
            classification,
            bytes.len() as u64,
        );
        return Ok(());
    }

    if classification.disposition == Disposition::Parsed && text.is_none() {
        bail!("parsed source is not valid UTF-8: {repository_path}");
    }
    if classification.role == "primary_manuscript" && bytes.is_empty() {
        bail!("empty primary manuscript fails documentary coverage: {repository_path}");
    }

    let digest = sha256(&bytes);
    let source_id = content_id(
        "source",
        &[collection.as_bytes(), repository_path.as_bytes()],
    );
    let parsed_kind = classification.parse_kind;
    let candidate_eligible = classification.candidate_eligible;
    let role = classification.role.clone();
    let record = SourceRecord {
        schema_version: OUTPUT_SCHEMA_VERSION.to_owned(),
        id: source_id.clone(),
        collection: collection.to_owned(),
        edition: edition.to_owned(),
        path: repository_path.clone(),
        collection_path: relative_string.to_owned(),
        format: classification.format.clone(),
        role: role.clone(),
        disposition: classification.disposition.as_str().to_owned(),
        source_status: classification.source_status.clone(),
        bytes: bytes.len() as u64,
        sha256: digest.clone(),
        reason: classification.reason.clone(),
        parse_kind: parsed_kind.map(|kind| kind.as_str().to_owned()),
        candidate_eligible,
    };
    output.inventory.push(inventory_record(
        "file",
        collection,
        edition,
        repository_path.clone(),
        relative_string.to_owned(),
        &record.format,
        &record.role,
        &record.disposition,
        &record.source_status,
        Some(record.bytes),
        Some(digest.clone()),
        &record.reason,
    ));

    if let Some(kind) = parsed_kind {
        let source = text.context("validated UTF-8 source unexpectedly unavailable")?;
        let extracted = extract(source, kind)
            .with_context(|| format!("extracting source units from `{repository_path}`"))?;
        for unit in extracted {
            validate_raw_unit(source, &unit)?;
            let span_key = format!(
                "{}:{}:{}",
                unit.span.byte_start, unit.span.byte_end, unit.raw_sha256
            );
            let unit_id = content_id("unit", &[source_id.as_bytes(), span_key.as_bytes()]);
            let coverage_status = if !candidate_eligible {
                format!("source_only:role_{}", role)
            } else if !unit.source_only_reason.is_empty() {
                format!("source_only:{}", unit.source_only_reason)
            } else {
                "pending_candidate_link".to_owned()
            };
            output.units.push(SourceUnit {
                schema_version: OUTPUT_SCHEMA_VERSION.to_owned(),
                id: unit_id,
                source_id: source_id.clone(),
                collection: collection.to_owned(),
                edition: edition.to_owned(),
                path: repository_path.clone(),
                collection_path: relative_string.to_owned(),
                source_revision: digest.clone(),
                format: record.format.clone(),
                role: role.clone(),
                source_status: record.source_status.clone(),
                span: unit.span,
                raw_sha256: unit.raw_sha256,
                raw_text: unit.raw_text,
                heading_trail: unit.heading_trail,
                structural_kind: unit.structural_kind,
                json_pointer: unit.json_pointer,
                coverage_status,
                candidate_id: None,
            });
        }
    }
    output.sources.push(record);
    Ok(())
}

fn push_excluded(
    output: &mut WalkedCorpus,
    collection: &str,
    edition: &str,
    repository_path: String,
    relative_string: String,
    classification: Classification,
    bytes: u64,
) {
    output.inventory.push(inventory_record(
        "file",
        collection,
        edition,
        repository_path.clone(),
        relative_string.clone(),
        &classification.format,
        &classification.role,
        "excluded",
        &classification.source_status,
        Some(bytes),
        None,
        &classification.reason,
    ));
    output.exclusions.push(exclusion_record(
        "file",
        collection,
        edition,
        repository_path,
        relative_string,
        &classification.format,
        &classification.role,
        &classification.source_status,
        Some(bytes),
        None,
        &classification.reason,
    ));
}

// Keeping every serialized field explicit makes schema drift visible at the construction site.
#[allow(clippy::too_many_arguments)]
fn inventory_record(
    entry_kind: &str,
    collection: &str,
    edition: &str,
    path: String,
    collection_path: String,
    format: &str,
    role: &str,
    disposition: &str,
    source_status: &str,
    bytes: Option<u64>,
    digest: Option<String>,
    reason: &str,
) -> SourceInventoryRecord {
    SourceInventoryRecord {
        schema_version: OUTPUT_SCHEMA_VERSION.to_owned(),
        entry_kind: entry_kind.to_owned(),
        collection: collection.to_owned(),
        edition: edition.to_owned(),
        path,
        collection_path,
        format: format.to_owned(),
        role: role.to_owned(),
        disposition: disposition.to_owned(),
        source_status: source_status.to_owned(),
        bytes,
        sha256: digest,
        reason: reason.to_owned(),
    }
}

// The independent constructor avoids coercing exclusions into included-source records.
#[allow(clippy::too_many_arguments)]
fn exclusion_record(
    entry_kind: &str,
    collection: &str,
    edition: &str,
    path: String,
    collection_path: String,
    format: &str,
    role: &str,
    source_status: &str,
    bytes: Option<u64>,
    digest: Option<String>,
    reason: &str,
) -> ExclusionRecord {
    ExclusionRecord {
        schema_version: OUTPUT_SCHEMA_VERSION.to_owned(),
        entry_kind: entry_kind.to_owned(),
        collection: collection.to_owned(),
        edition: edition.to_owned(),
        path,
        collection_path,
        format: format.to_owned(),
        role: role.to_owned(),
        source_status: source_status.to_owned(),
        bytes,
        sha256: digest,
        reason: reason.to_owned(),
    }
}

pub(crate) fn join_repository_path(root: &str, relative: &str) -> String {
    let root_path = PathBuf::from(root);
    if relative.is_empty() {
        slash_path(&root_path)
    } else {
        slash_path(&root_path.join(relative))
    }
}

fn prune_name(name: &str) -> bool {
    matches!(
        name,
        ".venv"
            | ".tmp"
            | ".pytest_cache"
            | ".mcp_causal_workspace"
            | "dist"
            | "target"
            | "__pycache__"
    ) || name.ends_with(".egg-info")
}

fn content_id(prefix: &str, parts: &[&[u8]]) -> String {
    let mut bytes = format!("arg-ingest-{prefix}-v1\0").into_bytes();
    for part in parts {
        bytes.extend_from_slice(part);
        bytes.push(0);
    }
    format!("{prefix}.{}", sha256(&bytes))
}
