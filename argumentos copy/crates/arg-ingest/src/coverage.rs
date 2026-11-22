use std::collections::{BTreeMap, BTreeSet};

use anyhow::{bail, Result};

use crate::{
    ArgumentCandidate, CollectionCoverage, CorpusConfig, CoverageGroup, CoverageReport,
    ExclusionRecord, RelationRecord, SourceInventoryRecord, SourceRecord, SourceUnit,
    OUTPUT_SCHEMA_VERSION,
};

pub(crate) fn assess(
    config: &CorpusConfig,
    inventory: &[SourceInventoryRecord],
    sources: &[SourceRecord],
    units: &[SourceUnit],
    candidates: &[ArgumentCandidate],
    relations: &[RelationRecord],
    exclusions: &[ExclusionRecord],
) -> Result<CoverageReport> {
    let regular_inventory = inventory
        .iter()
        .filter(|record| record.entry_kind == "file")
        .collect::<Vec<_>>();
    let discovered_regular_files = regular_inventory.len();
    let included_files = sources.len();
    let excluded_files = regular_inventory
        .iter()
        .filter(|record| record.disposition == "excluded")
        .count();
    let parsed_files = sources
        .iter()
        .filter(|source| source.disposition == "parsed")
        .count();
    let metadata_only_files = sources
        .iter()
        .filter(|source| source.disposition == "metadata_only")
        .count();
    let pruned_directories = exclusions
        .iter()
        .filter(|record| record.entry_kind == "directory")
        .count();
    let candidate_occurrences = candidates
        .iter()
        .map(|candidate| candidate.occurrences.len())
        .sum::<usize>();

    let mut errors = Vec::new();
    let discovered_accounted = discovered_regular_files == included_files + excluded_files;
    if !discovered_accounted {
        errors.push(format!(
            "discovered {discovered_regular_files} regular files but included {included_files} plus excluded {excluded_files}"
        ));
    }
    let unique_inventory_keys = regular_inventory
        .iter()
        .map(|record| (&record.collection, &record.path))
        .collect::<BTreeSet<_>>()
        .len();
    if unique_inventory_keys != discovered_regular_files {
        errors.push("a regular file was inventoried more than once".to_owned());
    }
    let all_included_hashed = sources.iter().all(|source| source.sha256.len() == 64);
    if !all_included_hashed {
        errors.push("an included source lacks its SHA-256 digest".to_owned());
    }

    let source_map = sources
        .iter()
        .map(|source| (source.id.as_str(), source))
        .collect::<BTreeMap<_, _>>();
    if source_map.len() != sources.len() {
        errors.push("source IDs are not unique".to_owned());
    }

    let inventory_map = regular_inventory
        .iter()
        .map(|record| ((record.collection.as_str(), record.path.as_str()), *record))
        .collect::<BTreeMap<_, _>>();
    let source_inventory_consistent = sources.iter().all(|source| {
        inventory_map
            .get(&(source.collection.as_str(), source.path.as_str()))
            .is_some_and(|record| inventory_matches_source(record, source))
    });
    if !source_inventory_consistent {
        errors.push("an included source does not match its inventory record".to_owned());
    }

    let file_exclusions = exclusions
        .iter()
        .filter(|record| record.entry_kind == "file")
        .collect::<Vec<_>>();
    let exclusion_map = file_exclusions
        .iter()
        .map(|record| ((record.collection.as_str(), record.path.as_str()), *record))
        .collect::<BTreeMap<_, _>>();
    let exclusion_accounting_complete = file_exclusions.len() == excluded_files
        && exclusion_map.len() == file_exclusions.len()
        && regular_inventory
            .iter()
            .filter(|record| record.disposition == "excluded")
            .all(|record| {
                exclusion_map
                    .get(&(record.collection.as_str(), record.path.as_str()))
                    .is_some_and(|exclusion| exclusion_matches_inventory(exclusion, record))
            });
    if !exclusion_accounting_complete {
        errors.push("excluded-file inventory and exclusion records disagree".to_owned());
    }

    let unit_map = units
        .iter()
        .map(|unit| (unit.id.as_str(), unit))
        .collect::<BTreeMap<_, _>>();
    if unit_map.len() != units.len() {
        errors.push("source unit IDs are not unique".to_owned());
    }
    let unit_source_ids = units
        .iter()
        .map(|unit| unit.source_id.clone())
        .collect::<BTreeSet<_>>();
    let unit_sources_resolve = units.iter().all(|unit| {
        source_map
            .get(unit.source_id.as_str())
            .is_some_and(|source| unit_matches_source(unit, source))
    });
    if !unit_sources_resolve {
        errors.push("a source unit does not resolve to its parsed source".to_owned());
    }

    let mut parsed_nonempty_have_units = true;
    for source in sources
        .iter()
        .filter(|source| source.disposition == "parsed")
    {
        if source.bytes > 0 && !unit_source_ids.contains(&source.id) {
            parsed_nonempty_have_units = false;
            errors.push(format!(
                "parsed nonempty source `{}` has no source units",
                source.path
            ));
        }
        if source.role == "primary_manuscript" && source.bytes == 0 {
            errors.push(format!("primary manuscript `{}` is empty", source.path));
        }
    }

    let mut candidate_links_resolve = true;
    let candidate_ids = candidates
        .iter()
        .map(|candidate| candidate.id.as_str())
        .collect::<BTreeSet<_>>();
    if candidate_ids.len() != candidates.len() {
        candidate_links_resolve = false;
        errors.push("candidate IDs are not unique".to_owned());
    }
    let mut linked_unit_ids = BTreeSet::new();
    let mut counted_occurrences = 0_usize;
    for candidate in candidates {
        if candidate.id != format!("cand.{}", candidate.statement_sha256)
            || candidate.statement_sha256 != crate::sha256(candidate.statement.as_bytes())
            || candidate.occurrences.is_empty()
        {
            candidate_links_resolve = false;
            errors.push(format!(
                "candidate `{}` has inconsistent content identity",
                candidate.id
            ));
        }
        for occurrence in &candidate.occurrences {
            counted_occurrences += 1;
            let Some(unit) = unit_map.get(occurrence.unit_id.as_str()) else {
                candidate_links_resolve = false;
                errors.push(format!(
                    "candidate `{}` references missing unit `{}`",
                    candidate.id, occurrence.unit_id
                ));
                continue;
            };
            if unit.candidate_id.as_deref() != Some(candidate.id.as_str())
                || unit.coverage_status != "candidate_linked"
                || unit.collection != occurrence.collection
                || unit.edition != occurrence.edition
                || unit.path != occurrence.path
                || unit.collection_path != occurrence.collection_path
                || unit.source_revision != occurrence.source_revision
                || unit.span != occurrence.span
                || unit.heading_trail != occurrence.heading_trail
                || crate::candidates::normalize_whitespace(&unit.raw_text) != candidate.statement
            {
                candidate_links_resolve = false;
                errors.push(format!(
                    "candidate `{}` does not round-trip to unit `{}`",
                    candidate.id, occurrence.unit_id
                ));
            }
            let scope_resolves = candidate.source_scopes.iter().any(|scope| {
                scope.collection == occurrence.collection
                    && scope.edition == occurrence.edition
                    && scope.source_status == unit.source_status
                    && scope.paths.contains(&occurrence.path)
            });
            if !scope_resolves {
                candidate_links_resolve = false;
                errors.push(format!(
                    "candidate `{}` has no matching source scope for unit `{}`",
                    candidate.id, occurrence.unit_id
                ));
            }
            if !linked_unit_ids.insert(occurrence.unit_id.clone()) {
                candidate_links_resolve = false;
                errors.push(format!(
                    "unit `{}` has multiple candidate occurrences",
                    occurrence.unit_id
                ));
            }
        }
    }
    if counted_occurrences != candidate_occurrences {
        errors.push("candidate occurrence accounting mismatch".to_owned());
    }

    let unit_accounting_complete = units.iter().all(|unit| {
        let source = source_map.get(unit.source_id.as_str());
        if unit.coverage_status == "candidate_linked" {
            source.is_some_and(|source| {
                source.candidate_eligible && source.source_status == "current"
            }) && unit.candidate_id.is_some()
                && linked_unit_ids.contains(&unit.id)
        } else if let Some(reason) = unit.coverage_status.strip_prefix("source_only:") {
            !reason.is_empty() && unit.candidate_id.is_none()
        } else {
            false
        }
    });
    if !unit_accounting_complete {
        errors.push("a source unit has unresolved or incomplete coverage accounting".to_owned());
    }

    let required_groups = required_groups(config, sources);
    let required_groups_complete = required_groups.iter().all(|group| group.status == "pass");
    for group in required_groups
        .iter()
        .filter(|group| group.status != "pass")
    {
        errors.push(format!(
            "required group `{}` expected {} included files but matched {}",
            group.id, group.expected_files, group.matched_files
        ));
    }

    let checks = BTreeMap::from([
        (
            "discovered_regular_files_equal_included_plus_excluded".to_owned(),
            discovered_accounted && unique_inventory_keys == discovered_regular_files,
        ),
        (
            "all_included_sources_hashed".to_owned(),
            all_included_hashed,
        ),
        (
            "source_inventory_consistent".to_owned(),
            source_inventory_consistent,
        ),
        (
            "exclusion_accounting_complete".to_owned(),
            exclusion_accounting_complete,
        ),
        ("unit_sources_resolve".to_owned(), unit_sources_resolve),
        (
            "parsed_nonempty_sources_have_units".to_owned(),
            parsed_nonempty_have_units,
        ),
        (
            "candidate_occurrence_links_resolve".to_owned(),
            candidate_links_resolve,
        ),
        (
            "unit_accounting_complete".to_owned(),
            unit_accounting_complete,
        ),
        (
            "required_groups_complete".to_owned(),
            required_groups_complete,
        ),
    ]);
    let documentary_coverage_complete = checks.values().all(|value| *value) && errors.is_empty();
    if !documentary_coverage_complete {
        bail!("documentary coverage failed:\n- {}", errors.join("\n- "));
    }

    let collections = collection_coverage(
        config,
        regular_inventory.as_slice(),
        sources,
        units,
        candidates,
        exclusions,
    );
    Ok(CoverageReport {
        schema_version: OUTPUT_SCHEMA_VERSION.to_owned(),
        corpus_id: config.corpus_id.clone(),
        collections,
        discovered_regular_files,
        included_files,
        excluded_files,
        parsed_files,
        metadata_only_files,
        source_units: units.len(),
        unique_candidates: candidates.len(),
        candidate_occurrences,
        pruned_directories,
        byte_identical_relations: relations
            .iter()
            .filter(|relation| relation.kind == "byte_identical")
            .count(),
        content_variant_relations: relations
            .iter()
            .filter(|relation| relation.kind == "content_variant")
            .count(),
        required_groups,
        checks,
        errors,
        documentary_coverage_complete,
        semantically_curated_corpus_complete: false,
    })
}

fn required_groups(config: &CorpusConfig, sources: &[SourceRecord]) -> Vec<CoverageGroup> {
    let mut groups = config
        .required_groups
        .iter()
        .map(|group| {
            let mut matched_paths = sources
                .iter()
                .filter(|source| source.collection == group.collection)
                .filter(|source| {
                    [&source.path, &source.collection_path].iter().any(|path| {
                        path.starts_with(&group.path_prefix) && path.ends_with(&group.path_suffix)
                    })
                })
                .map(|source| source.path.clone())
                .collect::<Vec<_>>();
            matched_paths.sort();
            matched_paths.dedup();
            CoverageGroup {
                id: group.id.clone(),
                collection: group.collection.clone(),
                path_prefix: group.path_prefix.clone(),
                path_suffix: group.path_suffix.clone(),
                expected_files: group.expected_files,
                matched_files: matched_paths.len(),
                matched_paths,
                status: String::new(),
            }
        })
        .collect::<Vec<_>>();
    for group in &mut groups {
        group.status = if group.matched_files == group.expected_files {
            "pass".to_owned()
        } else {
            "fail".to_owned()
        };
    }
    groups.sort_by(|left, right| left.id.cmp(&right.id));
    groups
}

fn collection_coverage(
    config: &CorpusConfig,
    inventory: &[&SourceInventoryRecord],
    sources: &[SourceRecord],
    units: &[SourceUnit],
    candidates: &[ArgumentCandidate],
    exclusions: &[ExclusionRecord],
) -> BTreeMap<String, CollectionCoverage> {
    let mut output = BTreeMap::new();
    for collection in &config.collections {
        let id = collection.id.as_str();
        let candidate_occurrences = candidates
            .iter()
            .flat_map(|candidate| candidate.occurrences.iter())
            .filter(|occurrence| occurrence.collection == id)
            .count();
        let candidates_present = candidates
            .iter()
            .filter(|candidate| {
                candidate
                    .occurrences
                    .iter()
                    .any(|occurrence| occurrence.collection == id)
            })
            .count();
        let entry = CollectionCoverage {
            discovered_regular_files: inventory
                .iter()
                .filter(|record| record.collection == id)
                .count(),
            included_files: sources
                .iter()
                .filter(|source| source.collection == id)
                .count(),
            excluded_files: exclusions
                .iter()
                .filter(|record| record.collection == id && record.entry_kind == "file")
                .count(),
            parsed_files: sources
                .iter()
                .filter(|source| source.collection == id && source.disposition == "parsed")
                .count(),
            metadata_only_files: sources
                .iter()
                .filter(|source| source.collection == id && source.disposition == "metadata_only")
                .count(),
            source_units: units.iter().filter(|unit| unit.collection == id).count(),
            candidate_occurrences,
            candidates_present,
            pruned_directories: exclusions
                .iter()
                .filter(|record| record.collection == id && record.entry_kind == "directory")
                .count(),
        };
        output.insert(collection.id.clone(), entry);
    }
    output
}

fn inventory_matches_source(inventory: &SourceInventoryRecord, source: &SourceRecord) -> bool {
    inventory.entry_kind == "file"
        && inventory.collection == source.collection
        && inventory.edition == source.edition
        && inventory.path == source.path
        && inventory.collection_path == source.collection_path
        && inventory.format == source.format
        && inventory.role == source.role
        && inventory.disposition == source.disposition
        && inventory.source_status == source.source_status
        && inventory.bytes == Some(source.bytes)
        && inventory.sha256.as_deref() == Some(source.sha256.as_str())
        && inventory.reason == source.reason
}

fn exclusion_matches_inventory(
    exclusion: &ExclusionRecord,
    inventory: &SourceInventoryRecord,
) -> bool {
    exclusion.entry_kind == "file"
        && inventory.entry_kind == "file"
        && inventory.disposition == "excluded"
        && exclusion.collection == inventory.collection
        && exclusion.edition == inventory.edition
        && exclusion.path == inventory.path
        && exclusion.collection_path == inventory.collection_path
        && exclusion.format == inventory.format
        && exclusion.role == inventory.role
        && exclusion.source_status == inventory.source_status
        && exclusion.bytes == inventory.bytes
        && exclusion.sha256 == inventory.sha256
        && exclusion.reason == inventory.reason
}

fn unit_matches_source(unit: &SourceUnit, source: &SourceRecord) -> bool {
    source.disposition == "parsed"
        && unit.source_id == source.id
        && unit.collection == source.collection
        && unit.edition == source.edition
        && unit.path == source.path
        && unit.collection_path == source.collection_path
        && unit.source_revision == source.sha256
        && unit.format == source.format
        && unit.role == source.role
        && unit.source_status == source.source_status
}
