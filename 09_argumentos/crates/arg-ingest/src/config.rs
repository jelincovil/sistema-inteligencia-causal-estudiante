use std::collections::BTreeSet;
use std::fs;
use std::path::{Component, Path, PathBuf};

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};

use crate::sha256;

/// Top-level JSON ingestion contract.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CorpusConfig {
    pub schema_version: String,
    pub corpus_id: String,
    pub extractor_version: String,
    pub collections: Vec<CollectionConfig>,
    #[serde(default)]
    pub required_groups: Vec<RequiredGroup>,
}

/// One declared repository-relative collection root.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct CollectionConfig {
    pub id: String,
    pub root: String,
    pub language: String,
}

/// Exact checked count among included sources for a scoped path prefix/suffix.
#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RequiredGroup {
    pub id: String,
    pub collection: String,
    pub path_prefix: String,
    pub path_suffix: String,
    pub expected_files: usize,
}

/// Validated configuration plus a digest of its exact input bytes.
#[derive(Debug, Clone)]
pub struct LoadedConfig {
    pub config: CorpusConfig,
    pub config_sha256: String,
}

/// Load strict JSON configuration and reject unsafe or ambiguous source roots.
pub fn load_config(path: &Path) -> Result<LoadedConfig> {
    let bytes = fs::read(path).with_context(|| format!("reading config {}", path.display()))?;
    let config: CorpusConfig =
        serde_json::from_slice(&bytes).context("parsing ingestion config JSON")?;
    validate_config(&config)?;
    Ok(LoadedConfig {
        config,
        config_sha256: sha256(&bytes),
    })
}

pub(crate) fn validate_config(config: &CorpusConfig) -> Result<()> {
    if config.schema_version.trim().is_empty()
        || config.corpus_id.trim().is_empty()
        || config.extractor_version.trim().is_empty()
    {
        bail!("schema_version, corpus_id, and extractor_version must be nonempty");
    }
    if config.collections.is_empty() {
        bail!("at least one collection is required");
    }

    let mut collection_ids = BTreeSet::new();
    let mut roots = BTreeSet::new();
    for collection in &config.collections {
        if collection.id.trim().is_empty() || collection.language.trim().is_empty() {
            bail!("collection id and language must be nonempty");
        }
        if !collection_ids.insert(collection.id.clone()) {
            bail!("duplicate collection id `{}`", collection.id);
        }
        validate_relative_root(&collection.root)
            .with_context(|| format!("unsafe root for collection `{}`", collection.id))?;
        let normalized = normalized_root(&collection.root);
        if normalized.is_empty() {
            bail!("collection root must not resolve to the entire repository");
        }
        if !roots.insert(normalized.clone()) {
            bail!("duplicate collection root `{normalized}`");
        }
    }

    let mut normalized_roots = roots.into_iter().collect::<Vec<_>>();
    normalized_roots.sort();
    for (index, root) in normalized_roots.iter().enumerate() {
        for other in normalized_roots.iter().skip(index + 1) {
            if other.starts_with(&format!("{root}/")) {
                bail!("nested collection roots are ambiguous: `{root}` and `{other}`");
            }
        }
    }

    let mut group_ids = BTreeSet::new();
    for group in &config.required_groups {
        if group.id.trim().is_empty() || !group_ids.insert(group.id.clone()) {
            bail!(
                "required group IDs must be nonempty and unique: `{}`",
                group.id
            );
        }
        if !collection_ids.contains(&group.collection) {
            bail!(
                "required group `{}` references unknown collection `{}`",
                group.id,
                group.collection
            );
        }
    }
    Ok(())
}

fn validate_relative_root(root: &str) -> Result<()> {
    if root.trim().is_empty() || root.as_bytes().contains(&0) {
        bail!("root must be nonempty and contain no NUL");
    }
    let windows_drive =
        root.len() >= 2 && root.as_bytes()[0].is_ascii_alphabetic() && root.as_bytes()[1] == b':';
    if root.starts_with('/') || root.starts_with('\\') || windows_drive {
        bail!("absolute and drive/UNC roots are forbidden: `{root}`");
    }
    if root.split(['/', '\\']).any(|part| part == "..") {
        bail!("parent-directory roots are forbidden: `{root}`");
    }
    for component in Path::new(root).components() {
        if matches!(
            component,
            Component::ParentDir | Component::RootDir | Component::Prefix(_)
        ) {
            bail!("root must be repository-relative without parent components: `{root}`");
        }
    }
    Ok(())
}

pub(crate) fn normalized_root(root: &str) -> String {
    let mut output = PathBuf::new();
    for component in Path::new(root).components() {
        if let Component::Normal(value) = component {
            output.push(value);
        } else if matches!(component, Component::CurDir) {
            continue;
        }
    }
    crate::slash_path(&output)
}

pub(crate) fn reject_symlink_components(repository_root: &Path, root: &str) -> Result<()> {
    let mut current = repository_root.to_path_buf();
    for component in Path::new(root).components() {
        if let Component::Normal(value) = component {
            current.push(value);
            let metadata = fs::symlink_metadata(&current).with_context(|| {
                format!("inspecting source root component {}", current.display())
            })?;
            if metadata.file_type().is_symlink() {
                bail!("symlink source roots are forbidden: {}", current.display());
            }
        }
    }
    let metadata = fs::symlink_metadata(repository_root.join(root))
        .with_context(|| format!("inspecting declared source root `{root}`"))?;
    if !metadata.is_dir() {
        bail!("declared source root is not a directory: `{root}`");
    }
    Ok(())
}
