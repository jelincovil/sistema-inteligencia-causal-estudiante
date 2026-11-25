use std::collections::{BTreeMap, BTreeSet};
use std::fs;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use serde::Serialize;
use walkdir::WalkDir;

use crate::candidates::link_candidates;
use crate::coverage::assess;
use crate::relations::monograph_relations;
use crate::walk::walk;
use crate::{
    sha256, ArgumentCandidate, CoverageReport, ExclusionRecord, LoadedConfig, RelationRecord,
    SourceInventoryRecord, SourceRecord, SourceUnit, ARTIFACT_NAMES, OUTPUT_SCHEMA_VERSION,
};

/// Fully generated in-memory corpus and its deterministic artifact bytes.
#[derive(Debug)]
pub struct GeneratedCorpus {
    pub inventory: Vec<SourceInventoryRecord>,
    pub sources: Vec<SourceRecord>,
    pub units: Vec<SourceUnit>,
    pub candidates: Vec<ArgumentCandidate>,
    pub relations: Vec<RelationRecord>,
    pub exclusions: Vec<ExclusionRecord>,
    pub coverage: CoverageReport,
    pub artifacts: BTreeMap<String, Vec<u8>>,
}

/// Successful byte-for-byte verification summary.
#[derive(Debug)]
pub struct VerifyReport {
    pub artifacts_compared: usize,
    pub bytes_compared: u64,
    pub coverage: CoverageReport,
}

/// Regenerate every artifact in memory. Coverage or source errors return `Err`.
pub fn generate(config: &LoadedConfig, repository_root: &Path) -> Result<GeneratedCorpus> {
    let metadata = fs::symlink_metadata(repository_root)
        .with_context(|| format!("inspecting repository root {}", repository_root.display()))?;
    if metadata.file_type().is_symlink() {
        bail!(
            "symlink repository roots are forbidden: {}",
            repository_root.display()
        );
    }
    if !metadata.is_dir() {
        bail!("repository root is not a directory");
    }

    let mut walked = walk(&config.config, repository_root)?;
    let candidates = link_candidates(&mut walked.units);
    let relations = monograph_relations(&walked.sources);
    let coverage = assess(
        &config.config,
        &walked.inventory,
        &walked.sources,
        &walked.units,
        &candidates,
        &relations,
        &walked.exclusions,
    )?;
    let artifacts = render_artifacts(
        config,
        &walked.inventory,
        &walked.sources,
        &walked.units,
        &candidates,
        &relations,
        &walked.exclusions,
        &coverage,
    )?;
    Ok(GeneratedCorpus {
        inventory: walked.inventory,
        sources: walked.sources,
        units: walked.units,
        candidates,
        relations,
        exclusions: walked.exclusions,
        coverage,
        artifacts,
    })
}

/// Build deterministic artifacts only after complete documentary coverage passes.
pub fn build(
    config: &LoadedConfig,
    repository_root: &Path,
    output: &Path,
) -> Result<CoverageReport> {
    let generated = generate(config, repository_root)?;
    ensure_no_extra_output_files(output, &generated.artifacts)?;
    fs::create_dir_all(output)
        .with_context(|| format!("creating output directory {}", output.display()))?;
    for (name, bytes) in &generated.artifacts {
        let path = output.join(name);
        fs::write(&path, bytes).with_context(|| format!("writing artifact {}", path.display()))?;
    }
    Ok(generated.coverage)
}

/// Regenerate in memory and compare all expected bytes, rejecting missing,
/// drifted, and extra output artifacts.
pub fn verify(
    config: &LoadedConfig,
    repository_root: &Path,
    output: &Path,
) -> Result<VerifyReport> {
    let generated = generate(config, repository_root)?;
    reject_symlink_output_root(output)?;
    if !output.is_dir() {
        bail!("output directory is missing: {}", output.display());
    }
    let actual_files = output_files(output)?;
    let expected_names = generated
        .artifacts
        .keys()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let actual_names = actual_files
        .keys()
        .map(String::as_str)
        .collect::<BTreeSet<_>>();
    let mut failures = Vec::new();
    for name in expected_names.difference(&actual_names) {
        failures.push(format!("missing artifact `{name}`"));
    }
    for name in actual_names.difference(&expected_names) {
        failures.push(format!("extra artifact `{name}`"));
    }
    let mut bytes_compared = 0_u64;
    for (name, expected) in &generated.artifacts {
        let Some(relative) = actual_files.get(name) else {
            continue;
        };
        let actual = fs::read(output.join(relative))
            .with_context(|| format!("reading output artifact `{name}`"))?;
        bytes_compared += actual.len() as u64;
        if actual != *expected {
            failures.push(format!(
                "artifact `{name}` drifted: expected {} bytes, found {}",
                expected.len(),
                actual.len()
            ));
        }
    }
    if !failures.is_empty() {
        bail!("artifact verification failed:\n- {}", failures.join("\n- "));
    }
    Ok(VerifyReport {
        artifacts_compared: generated.artifacts.len(),
        bytes_compared,
        coverage: generated.coverage,
    })
}

fn ensure_no_extra_output_files(output: &Path, expected: &BTreeMap<String, Vec<u8>>) -> Result<()> {
    reject_symlink_output_root(output)?;
    if !output.exists() {
        return Ok(());
    }
    if !output.is_dir() {
        bail!("output exists and is not a directory: {}", output.display());
    }
    let actual = output_files(output)?;
    if let Some(extra) = actual.keys().find(|name| !expected.contains_key(*name)) {
        bail!(
            "output contains extra artifact `{extra}`; refusing to overwrite a nondeterministic scope"
        );
    }
    Ok(())
}

fn reject_symlink_output_root(output: &Path) -> Result<()> {
    match fs::symlink_metadata(output) {
        Ok(metadata) => {
            if metadata.file_type().is_symlink() {
                bail!("symlink output roots are forbidden: {}", output.display());
            }
            Ok(())
        }
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => Ok(()),
        Err(error) => {
            Err(error).with_context(|| format!("inspecting output root {}", output.display()))
        }
    }
}

fn output_files(output: &Path) -> Result<BTreeMap<String, PathBuf>> {
    let mut files = BTreeMap::new();
    for entry in WalkDir::new(output).follow_links(false).sort_by_file_name() {
        let entry = entry.with_context(|| format!("walking output {}", output.display()))?;
        if entry.depth() == 0 {
            continue;
        }
        if entry.file_type().is_symlink() {
            bail!(
                "symlink output artifacts are not accepted: {}",
                entry.path().display()
            );
        }
        if entry.file_type().is_file() {
            let relative = entry
                .path()
                .strip_prefix(output)
                .context("output entry escaped output root")?;
            let name = relative
                .to_str()
                .context("output artifact paths must be UTF-8")?
                .replace('\\', "/");
            if files.insert(name.clone(), relative.to_path_buf()).is_some() {
                bail!("duplicate output artifact path `{name}`");
            }
        } else if !entry.file_type().is_dir() {
            bail!("non-regular output entry: {}", entry.path().display());
        }
    }
    Ok(files)
}

// Rendering receives each artifact stream explicitly so no record can be silently omitted.
#[allow(clippy::too_many_arguments)]
fn render_artifacts(
    config: &LoadedConfig,
    inventory: &[SourceInventoryRecord],
    sources: &[SourceRecord],
    units: &[SourceUnit],
    candidates: &[ArgumentCandidate],
    relations: &[RelationRecord],
    exclusions: &[ExclusionRecord],
    coverage: &CoverageReport,
) -> Result<BTreeMap<String, Vec<u8>>> {
    let mut artifacts = BTreeMap::new();
    artifacts.insert("source_inventory.jsonl".to_owned(), json_lines(inventory)?);
    artifacts.insert("sources.jsonl".to_owned(), json_lines(sources)?);
    artifacts.insert("source_units.jsonl".to_owned(), json_lines(units)?);
    artifacts.insert(
        "argument_candidates.jsonl".to_owned(),
        json_lines(candidates)?,
    );
    artifacts.insert("relations.jsonl".to_owned(), json_lines(relations)?);
    artifacts.insert("exclusions.jsonl".to_owned(), json_lines(exclusions)?);
    artifacts.insert("coverage.json".to_owned(), pretty_json(coverage)?);
    artifacts.insert(
        "REPORT.md".to_owned(),
        report(config, coverage, exclusions).into_bytes(),
    );
    artifacts.insert(
        "manifest.json".to_owned(),
        pretty_json(&manifest(config, coverage))?,
    );

    let checksummed = artifacts
        .iter()
        .map(|(name, bytes)| (name.clone(), sha256(bytes)))
        .collect::<BTreeMap<_, _>>();
    artifacts.insert(
        "checksums.json".to_owned(),
        pretty_json(&serde_json::json!({
            "schema_version": OUTPUT_SCHEMA_VERSION,
            "algorithm": "sha256",
            "self_excluded": "checksums.json",
            "files": checksummed,
        }))?,
    );
    if artifacts.len() != ARTIFACT_NAMES.len()
        || ARTIFACT_NAMES
            .iter()
            .any(|name| !artifacts.contains_key(*name))
    {
        bail!("internal artifact set does not match the declared complete output names");
    }
    Ok(artifacts)
}

fn json_lines<T: Serialize>(records: &[T]) -> Result<Vec<u8>> {
    let mut output = Vec::new();
    for record in records {
        serde_json::to_writer(&mut output, record)?;
        output.push(b'\n');
    }
    Ok(output)
}

fn pretty_json<T: Serialize>(value: &T) -> Result<Vec<u8>> {
    let mut output = serde_json::to_vec_pretty(value)?;
    output.push(b'\n');
    Ok(output)
}

fn manifest(config: &LoadedConfig, coverage: &CoverageReport) -> serde_json::Value {
    serde_json::json!({
        "schema_version": OUTPUT_SCHEMA_VERSION,
        "corpus_id": config.config.corpus_id,
        "config_sha256": config.config_sha256,
        "tool": "argumentos-corpus",
        "tool_version": env!("CARGO_PKG_VERSION"),
        "extractor_version": config.config.extractor_version,
        "output_names": ARTIFACT_NAMES,
        "documentary_scope": {
            "declared_roots_walked": coverage.documentary_coverage_complete,
            "declared_pruning_policy_applied": coverage.documentary_coverage_complete,
            "all_discovered_regular_files_accounted": coverage.checks["discovered_regular_files_equal_included_plus_excluded"],
            "all_included_sources_hashed": coverage.checks["all_included_sources_hashed"],
            "source_inventory_consistent": coverage.checks["source_inventory_consistent"],
            "exclusion_accounting_complete": coverage.checks["exclusion_accounting_complete"],
            "unit_sources_resolve": coverage.checks["unit_sources_resolve"],
            "parsed_nonempty_sources_have_units": coverage.checks["parsed_nonempty_sources_have_units"],
            "candidate_occurrence_links_resolve": coverage.checks["candidate_occurrence_links_resolve"],
            "unit_accounting_complete": coverage.checks["unit_accounting_complete"],
            "required_groups_complete": coverage.checks["required_groups_complete"],
        },
        "documentary_coverage_complete": coverage.documentary_coverage_complete,
        "semantically_curated_corpus_complete": false,
        "scientific_validity_certified": false,
        "execution_replayed": false,
        "imported_code_executed": false,
        "legacy_kernel_claims_exported": 0,
        "candidate_ids_unreviewed_content_derived": true,
        "candidate_id_policy": "cand.<sha256(normalized_source_assertion)>; not durable curated semantic identity",
        "raw_sources_modified": false,
        "absolute_host_paths_recorded": false,
        "timestamps_recorded": false,
    })
}

fn report(
    config: &LoadedConfig,
    coverage: &CoverageReport,
    exclusions: &[ExclusionRecord],
) -> String {
    let mut output = String::new();
    output.push_str(&format!(
        "# Documentary corpus report: {}\n\n",
        config.config.corpus_id
    ));
    output.push_str("This is deterministic documentary ingestion, not scientific or semantic certification. Candidates are unreviewed, whitespace-normalized verbatim source assertions; exact raw units are authoritative. No Python, Typst, shell, or other imported source was executed. No legacy kernel claims were exported.\n\n");
    output.push_str("## Counts by collection\n\n");
    output.push_str("| Collection | Discovered files | Included | Excluded | Parsed | Metadata only | Units | Candidates present | Occurrences | Pruned directories |\n");
    output.push_str("|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n");
    for (collection, counts) in &coverage.collections {
        output.push_str(&format!(
            "| {} | {} | {} | {} | {} | {} | {} | {} | {} | {} |\n",
            collection,
            counts.discovered_regular_files,
            counts.included_files,
            counts.excluded_files,
            counts.parsed_files,
            counts.metadata_only_files,
            counts.source_units,
            counts.candidates_present,
            counts.candidate_occurrences,
            counts.pruned_directories
        ));
    }
    output.push_str(&format!(
        "\n**Unique candidates:** {}  \n**Candidate occurrences:** {}  \n**Byte-identical monograph relations:** {}  \n**Content-variant monograph relations:** {}\n\n",
        coverage.unique_candidates,
        coverage.candidate_occurrences,
        coverage.byte_identical_relations,
        coverage.content_variant_relations
    ));
    output.push_str("Exact normalized duplicate statements share one content-derived candidate ID and retain all occurrences, paths, source revisions, spans, and headings. `byte_identical` relations describe file bytes; `content_variant` lists same-relative-path monograph files whose hashes differ. Neither relation suppresses sources or units. Candidate deduplication is separate from byte-level file relations.\n\n");

    output.push_str("## Required groups\n\n| Group | Collection | Expected | Matched | Status |\n|---|---|---:|---:|---|\n");
    for group in &coverage.required_groups {
        output.push_str(&format!(
            "| {} | {} | {} | {} | {} |\n",
            group.id, group.collection, group.expected_files, group.matched_files, group.status
        ));
    }
    if coverage.required_groups.is_empty() {
        output.push_str("| _none declared_ | — | 0 | 0 | pass |\n");
    }

    let mut exclusion_counts = BTreeMap::<&str, usize>::new();
    for exclusion in exclusions {
        *exclusion_counts.entry(&exclusion.reason).or_default() += 1;
    }
    output.push_str("\n## Exclusions\n\n| Reason | Entries |\n|---|---:|\n");
    for (reason, count) in exclusion_counts {
        output.push_str(&format!("| `{reason}` | {count} |\n"));
    }
    output.push_str("\nPruned directories are recorded once and their descendants were not read. Excluded regular files remain inventoried. Included metadata-only files are SHA-256 hashed. Empty root placeholders are explicit exclusions.\n\n");

    output.push_str("## Coverage and limitations\n\n");
    output.push_str(&format!(
        "- `documentary_coverage_complete={}` is relative only to declared roots, required groups, and these policies.\n",
        coverage.documentary_coverage_complete
    ));
    output.push_str("- `semantically_curated_corpus_complete=false`.\n- `scientific_validity_certified=false` and `execution_replayed=false`.\n- `legacy_kernel_claims_exported=0`.\n- Candidate IDs are unreviewed content-derived `cand.<hash>` values, not durable curated semantic IDs.\n- Candidates do not assert atomicity, causal identification, scientific verification, or tested status.\n- Automatic topics are multi-label and unreviewed, with `uncategorized` fallback.\n- JSON document units have JSON pointer `/`; review JSONL is validated one exact line at a time; bibliography YAML is lexical only.\n\n");

    output.push_str("## Commands\n\nFrom `argumentos/`, using this checked-in configuration and its parent repository:\n\n```sh\ncargo run --locked -p arg-ingest -- build --config config/corpus-ingest.json --repository-root .. --output artifacts/documentary-corpus\ncargo run --locked -p arg-ingest -- verify --config config/corpus-ingest.json --repository-root .. --output artifacts/documentary-corpus\ncargo run --locked -p arg-ingest -- query --candidates artifacts/documentary-corpus/argument_candidates.jsonl --collection 02_production_monograph --topic monitoring --contains \"causal\" --limit 20\n```\n");
    output
}
