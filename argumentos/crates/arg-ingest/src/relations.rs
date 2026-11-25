use std::collections::BTreeMap;

use crate::{RelationRecord, SourceRecord, OUTPUT_SCHEMA_VERSION};

pub(crate) fn monograph_relations(sources: &[SourceRecord]) -> Vec<RelationRecord> {
    let mut paths: BTreeMap<String, Vec<&SourceRecord>> = BTreeMap::new();
    for source in sources {
        if let Some(relative) = monograph_relative_path(source) {
            paths.entry(relative).or_default().push(source);
        }
    }

    let mut relations = Vec::new();
    for (relative, mut group) in paths {
        group.sort_by(|left, right| {
            canonical_rank(left)
                .cmp(&canonical_rank(right))
                .then_with(|| left.path.cmp(&right.path))
        });
        group.dedup_by(|left, right| left.path == right.path);
        if group.len() < 2 {
            continue;
        }
        let canonical = group[0];
        for related in group.into_iter().skip(1) {
            let kind = if canonical.sha256 == related.sha256 {
                "byte_identical"
            } else {
                "content_variant"
            };
            relations.push(RelationRecord {
                schema_version: OUTPUT_SCHEMA_VERSION.to_owned(),
                kind: kind.to_owned(),
                relative_path: relative.clone(),
                canonical_path: canonical.path.clone(),
                canonical_sha256: canonical.sha256.clone(),
                related_path: related.path.clone(),
                related_sha256: related.sha256.clone(),
            });
        }
    }
    relations.sort_by(|left, right| {
        (&left.kind, &left.relative_path, &left.related_path).cmp(&(
            &right.kind,
            &right.relative_path,
            &right.related_path,
        ))
    });
    relations
}

fn canonical_rank(source: &SourceRecord) -> u8 {
    if source.edition == "02" {
        0
    } else {
        1
    }
}

fn monograph_relative_path(source: &SourceRecord) -> Option<String> {
    if source.edition != "02" && source.edition != "05" {
        return None;
    }
    let components = source.collection_path.split('/').collect::<Vec<_>>();
    let index = components.iter().position(|part| *part == "Causal_AI")?;
    let relative = components.get(index + 1..)?.join("/");
    if relative.is_empty() {
        None
    } else {
        Some(relative)
    }
}
