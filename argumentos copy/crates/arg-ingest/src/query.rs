use std::fs;
use std::path::Path;

use anyhow::{Context, Result};
use serde::de::DeserializeOwned;

use crate::{ArgumentCandidate, QueryFilter};

/// Read a JSONL candidate stream, ignoring blank lines and failing on malformed JSON.
pub fn load_candidates(path: &Path) -> Result<Vec<ArgumentCandidate>> {
    let bytes = fs::read(path).with_context(|| format!("reading candidates {}", path.display()))?;
    let text = std::str::from_utf8(&bytes).context("candidate JSONL must be UTF-8")?;
    let mut candidates: Vec<ArgumentCandidate> = Vec::new();
    for (index, line) in text.lines().enumerate() {
        if line.trim().is_empty() {
            continue;
        }
        candidates.push(parse_line(line).with_context(|| {
            format!("parsing candidate line {} in {}", index + 1, path.display())
        })?);
    }
    candidates.sort_by(|left, right| left.id.cmp(&right.id));
    validate_candidate_ids(&candidates)?;
    Ok(candidates)
}

fn parse_line<T: DeserializeOwned>(line: &str) -> Result<T> {
    Ok(serde_json::from_str(line)?)
}

fn validate_candidate_ids(candidates: &[ArgumentCandidate]) -> Result<()> {
    for pair in candidates.windows(2) {
        if pair[0].id == pair[1].id {
            anyhow::bail!("duplicate candidate record ID `{}`", pair[0].id);
        }
    }
    Ok(())
}

/// Filter and deterministically order candidates without changing their JSON fields.
pub fn query_candidates(
    candidates: &[ArgumentCandidate],
    filter: &QueryFilter,
) -> Vec<ArgumentCandidate> {
    let needed = filter.contains.as_ref().map(|value| value.to_lowercase());
    let mut selected = candidates
        .iter()
        .filter(|candidate| {
            filter.collection.as_ref().is_none_or(|collection| {
                candidate
                    .occurrences
                    .iter()
                    .any(|occurrence| occurrence.collection.contains(collection))
            })
        })
        .filter(|candidate| {
            filter.topic.as_ref().is_none_or(|topic| {
                candidate
                    .topics
                    .iter()
                    .any(|candidate_topic| candidate_topic.contains(topic))
            })
        })
        .filter(|candidate| {
            needed
                .as_ref()
                .is_none_or(|needle| candidate.statement.to_lowercase().contains(needle))
        })
        .cloned()
        .collect::<Vec<_>>();
    selected.sort_by(|left, right| left.id.cmp(&right.id));
    if let Some(limit) = filter.limit {
        selected.truncate(limit);
    }
    selected
}
