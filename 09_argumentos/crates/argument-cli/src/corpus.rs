use std::collections::BTreeMap;
use std::fs;
use std::path::{Component, Path, PathBuf};
use std::process::ExitCode;

use anyhow::{Context, Result};
use argument_audit::{check, Decision};
use argument_document::{
    sha256_file_capped, sha256_hex, Availability, ClaimKind, EvidenceKind, Kernel,
    MAX_DOCUMENT_BYTES, MAX_LOCAL_FILE_BYTES,
};
use serde_json::{json, Value};

/// Read one JSON document with the same byte cap the loader enforces,
/// so the CLI never materializes an oversized file before checking it.
///
/// I/O failures carry the path in the error chain. A document larger
/// than [`MAX_DOCUMENT_BYTES`] is reported as the same typed
/// [`argument_document::ContractError::InputTooLarge`] kernel loading produces,
/// wrapped in `anyhow`; the CLI prints it as a `contract:` line and
/// exits 2. The cap is enforced once, here, before the loader's own
/// check ever runs.
pub(crate) fn read_document_capped(path: &Path) -> Result<Vec<u8>> {
    use std::io::Read;
    let metadata = fs::metadata(path).with_context(|| format!("reading {}", path.display()))?;
    if metadata.len() > MAX_DOCUMENT_BYTES {
        return Err(argument_document::ContractError::InputTooLarge {
            limit: MAX_DOCUMENT_BYTES,
            actual: metadata.len(),
        }
        .into());
    }
    // The file may grow between the stat and the read; cap what we read.
    let file = fs::File::open(path).with_context(|| format!("reading {}", path.display()))?;
    let mut bytes = Vec::with_capacity(metadata.len() as usize);
    file.take(MAX_DOCUMENT_BYTES + 1)
        .read_to_end(&mut bytes)
        .with_context(|| format!("reading {}", path.display()))?;
    if bytes.len() as u64 > MAX_DOCUMENT_BYTES {
        return Err(argument_document::ContractError::InputTooLarge {
            limit: MAX_DOCUMENT_BYTES,
            actual: bytes.len() as u64,
        }
        .into());
    }
    Ok(bytes)
}

/// Audits self-contained JSON kernels without admitting or replaying evidence.
pub fn audit(dir: &Path, root: Option<&Path>, output: Option<&Path>) -> Result<ExitCode> {
    let inferred_root = dir
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."));
    let project_root = root.unwrap_or(inferred_root);
    let canonical_root = canonical_root(project_root)?;
    let mut files = Vec::new();
    let mut skipped_entries = Vec::new();
    collect_json_files(dir, &mut files, &mut skipped_entries, project_root)?;
    files.sort();
    skipped_entries.sort_by(|left, right| left["path"].as_str().cmp(&right["path"].as_str()));

    let mut file_reports = Vec::new();
    let mut claim_reports = Vec::new();
    let mut evidence_reports = Vec::new();
    let mut artifact_reports = Vec::new();
    let mut source_reports = Vec::new();
    let mut load_errors = Vec::new();
    let mut duplicate_ids = Vec::new();
    let mut origins = BTreeMap::<String, String>::new();
    let mut claim_kinds = BTreeMap::<String, u64>::new();
    let mut evidence_availability = BTreeMap::<String, u64>::new();
    let mut rejected_files = 0_u64;
    let mut argument_obligations = 0_u64;
    let mut claim_pending_axes = 0_u64;
    let mut pending_obligations = 0_u64;
    let mut cycle_diagnostics = 0_u64;
    let mut diagnostic_codes = BTreeMap::<String, u64>::new();
    let mut missing_artifacts = 0_u64;
    let mut missing_sources = 0_u64;
    let mut source_system_counts = BTreeMap::<String, u64>::new();
    let mut unchecked_sources = Vec::<Value>::new();

    for path in &files {
        let name = display_path(project_root, path);
        let bytes = match read_document_capped(path) {
            Ok(bytes) => bytes,
            Err(error) => {
                load_errors.push(json!({"file": name, "error": error.to_string()}));
                continue;
            }
        };
        let file_sha256 = sha256_hex(&bytes);
        let kernel = match Kernel::load(&bytes) {
            Ok(kernel) => kernel,
            Err(error) => {
                load_errors.push(json!({"file": name, "error": error.to_string()}));
                continue;
            }
        };
        let canonical_sha256 = kernel.content_sha256()?;
        let report = check(&kernel);
        if report.decision == Decision::Rejected {
            rejected_files += 1;
        }
        argument_obligations += u64::from(report.argument_obligations);
        claim_pending_axes += u64::from(report.claim_pending_axes);
        pending_obligations += u64::from(report.pending_count);
        for diagnostic in &report.diagnostics {
            *diagnostic_codes.entry(diagnostic.code.clone()).or_default() += 1;
            if diagnostic.code == "cycle" || diagnostic.code == "support_cycle" {
                cycle_diagnostics += 1;
            }
        }

        for claim in &kernel.claims {
            remember_origin(&mut origins, &claim.id, &name, &mut duplicate_ids);
            let kind = claim_kind(claim.kind);
            *claim_kinds.entry(kind.to_string()).or_default() += 1;
            match &claim.source {
                Some(source) if source.system != "local" => {
                    // Non-local sources are never byte-verified here.
                    // Tally them per system and list each one honestly.
                    *source_system_counts
                        .entry(source.system.clone())
                        .or_default() += 1;
                    unchecked_sources.push(json!({
                        "claim_id": claim.id,
                        "system": source.system,
                        "key": source.key,
                        "reason": "non_local_source",
                    }));
                }
                None => {
                    *source_system_counts
                        .entry("unknown".to_string())
                        .or_default() += 1;
                    unchecked_sources.push(json!({
                        "claim_id": claim.id,
                        "system": "unknown",
                        "key": Value::Null,
                        "reason": "no_source_locator",
                    }));
                }
                Some(source) => {
                    let (exists, sha256, bytes, anchor, source_path, error) =
                        match source.key.as_deref() {
                            Some(key) => match local_file(&canonical_root, key) {
                                Ok((path, anchor)) => {
                                    let resolved = display_path(&canonical_root, &path);
                                    match inspect_bytes(&path, &resolved) {
                                        Ok((sha256, byte_count)) => (
                                            true,
                                            Some(sha256),
                                            Some(byte_count),
                                            anchor,
                                            resolved,
                                            None,
                                        ),
                                        Err(error) => {
                                            (false, None, None, anchor, resolved, Some(error))
                                        }
                                    }
                                }
                                Err(error) => (false, None, None, None, error, None),
                            },
                            None => (
                                false,
                                None,
                                None,
                                None,
                                "missing local source key".to_string(),
                                None,
                            ),
                        };
                    if !exists {
                        missing_sources += 1;
                    }
                    source_reports.push(json!({
                        "claim_id": claim.id,
                        "locator": source.key,
                        "path": source_path,
                        "anchor": anchor,
                        "anchor_verified": false,
                        "exists": exists,
                        "bytes": bytes,
                        "sha256": sha256,
                        "error": error,
                    }));
                }
            }
            let finding = report.claims.iter().find(|finding| finding.id == claim.id);
            claim_reports.push(json!({
                "file": name,
                "id": claim.id,
                "kind": kind,
                "source": claim.source,
                "statement": claim.statement,
                "finding": finding,
            }));
        }

        for argument in &kernel.arguments {
            remember_origin(&mut origins, &argument.id, &name, &mut duplicate_ids);
        }

        for spec in &kernel.evidence_specs {
            remember_origin(&mut origins, &spec.id, &name, &mut duplicate_ids);
            let availability = availability(spec.availability);
            *evidence_availability
                .entry(availability.to_string())
                .or_default() += 1;
            evidence_reports.push(json!({
                "file": name,
                "id": spec.id,
                "claim_id": spec.claim_id,
                "kind": spec.kind.as_str(),
                "runner_id": spec.runner_id,
                "target": spec.target,
                "availability": availability,
                "scientific_status": "unverified",
            }));
            if spec.kind == EvidenceKind::Registered {
                let artifact = local_file(&canonical_root, &spec.target);
                let (exists, path, anchor, sha256, byte_count, error) = match artifact {
                    Ok((path, anchor)) => {
                        match inspect_bytes(&path, &display_path(&canonical_root, &path)) {
                            Ok((sha256, byte_count)) => (
                                true,
                                display_path(&canonical_root, &path),
                                anchor,
                                Some(sha256),
                                Some(byte_count),
                                None,
                            ),
                            Err(error) => (
                                false,
                                display_path(&canonical_root, &path),
                                anchor,
                                None,
                                None,
                                Some(error),
                            ),
                        }
                    }
                    Err(error) => (false, error, None, None, None, None),
                };
                if !exists {
                    missing_artifacts += 1;
                }
                artifact_reports.push(json!({
                    "evidence_id": spec.id,
                    "target": spec.target,
                    "path": path,
                    "anchor": anchor,
                    "exists": exists,
                    "bytes": byte_count,
                    "sha256": sha256,
                    "error": error,
                    "binding": "current bytes only; not an execution replay or scientific validation"
                }));
            }
        }

        file_reports.push(json!({
            "file": name,
            "file_sha256": file_sha256,
            "canonical_sha256": canonical_sha256,
            "profile": kernel.profile.as_str(),
            "decision": report.decision,
            "claims": kernel.claims.len(),
            "arguments": kernel.arguments.len(),
            "evidence_specs": kernel.evidence_specs.len(),
            "argument_obligations": report.argument_obligations,
            "claim_pending_axes": report.claim_pending_axes,
            "pending_obligations": report.pending_count,
            "claim_supported": report.claim_supported,
            "diagnostics": report.diagnostics,
        }));
    }

    claim_reports.sort_by(|left, right| left["id"].as_str().cmp(&right["id"].as_str()));
    evidence_reports.sort_by(|left, right| left["id"].as_str().cmp(&right["id"].as_str()));
    artifact_reports.sort_by(|left, right| {
        left["evidence_id"]
            .as_str()
            .cmp(&right["evidence_id"].as_str())
    });
    source_reports
        .sort_by(|left, right| left["claim_id"].as_str().cmp(&right["claim_id"].as_str()));
    unchecked_sources.sort_by(|left, right| {
        (
            left["claim_id"].as_str(),
            left["system"].as_str(),
            left["key"].as_str(),
        )
            .cmp(&(
                right["claim_id"].as_str(),
                right["system"].as_str(),
                right["key"].as_str(),
            ))
    });

    // `unchecked_sources` and `source_system_counts` never count as checked
    // and do not mask missing local sources: they are reported, not
    // certified. Symlinked JSON corpus entries are rejected explicitly
    // below and do fail the audit.
    let failed = files.is_empty()
        || !load_errors.is_empty()
        || !duplicate_ids.is_empty()
        || rejected_files > 0
        || missing_artifacts > 0
        || missing_sources > 0
        || !skipped_entries.is_empty();
    let summary = json!({
        "schema_version": "1.0",
        "status": if failed { "fail" } else { "pass" },
        "scope": "structural corpus catalog and current local-byte inventory",
        "corpus_closed": false,
        "scientific_validity_certified": false,
        "claim_supported": false,
        "evidence_replayed": false,
        "file_count": files.len(),
        "claim_count": claim_reports.len(),
        "argument_count": file_reports.iter().filter_map(|file| file["arguments"].as_u64()).sum::<u64>(),
        "evidence_count": evidence_reports.len(),
        "rejected_files": rejected_files,
        "argument_obligations": argument_obligations,
        "claim_pending_axes": claim_pending_axes,
        "pending_obligations": pending_obligations,
        "cycle_diagnostics": cycle_diagnostics,
        "claim_kinds": claim_kinds,
        "evidence_availability": evidence_availability,
        "diagnostic_codes": diagnostic_codes,
        "missing_local_sources": missing_sources,
        "missing_registered_artifacts": missing_artifacts,
        "source_system_counts": source_system_counts,
        "unchecked_sources": unchecked_sources,
        "skipped_entries": skipped_entries,
        "cross_file_duplicate_ids": duplicate_ids,
        "load_errors": load_errors,
        "files": file_reports,
        "claims": claim_reports,
        "evidence": evidence_reports,
        "local_sources": source_reports,
        "registered_artifacts": artifact_reports,
        "limits": "Passing structure does not verify prose anchors, identification, computations, or scientific claims. Candidate and pending evidence remain unverified. Current hashes are not trusted timestamps. Source systems other than `local` are tallied in source_system_counts and listed in unchecked_sources; they are never byte-verified. Symlinked JSON corpus entries are rejected and listed in skipped_entries."
    });
    let rendered = format!("{}\n", serde_json::to_string_pretty(&summary)?);
    if let Some(output) = output {
        fs::write(output, rendered).with_context(|| format!("writing {}", output.display()))?;
    } else {
        print!("{rendered}");
    }
    Ok(if failed {
        ExitCode::from(3)
    } else {
        ExitCode::SUCCESS
    })
}

/// Recurse into `dir` collecting JSON documents.
///
/// Symlinks are never followed: a symlink whose name ends in `.json`
/// is rejected explicitly as a `skipped_entries` record instead of being
/// silently dropped. Directories (real ones) are recursed as usual.
fn collect_json_files(
    dir: &Path,
    output: &mut Vec<PathBuf>,
    skipped: &mut Vec<Value>,
    display_root: &Path,
) -> Result<()> {
    let mut entries = fs::read_dir(dir)
        .with_context(|| format!("reading {}", dir.display()))?
        .collect::<std::io::Result<Vec<_>>>()?;
    entries.sort_by_key(|entry| entry.file_name());
    for entry in entries {
        let path = entry.path();
        let file_type = entry.file_type()?;
        if file_type.is_symlink() {
            let is_json = path.extension().and_then(|extension| extension.to_str()) == Some("json");
            if is_json {
                skipped.push(json!({
                    "path": display_path(display_root, &path),
                    "reason": "symlink",
                }));
            }
            continue;
        }
        if file_type.is_dir() {
            collect_json_files(&path, output, skipped, display_root)?;
        } else if file_type.is_file()
            && path.extension().and_then(|extension| extension.to_str()) == Some("json")
        {
            output.push(path);
        }
    }
    Ok(())
}

fn remember_origin(
    origins: &mut BTreeMap<String, String>,
    id: &str,
    file: &str,
    duplicates: &mut Vec<Value>,
) {
    if let Some(previous) = origins.insert(id.to_string(), file.to_string()) {
        duplicates.push(json!({"id": id, "first_file": previous, "second_file": file}));
    }
}

/// Outcome of resolving and hashing one registered target locator.
#[derive(Debug, Clone, PartialEq, Eq)]
pub(crate) struct TargetCheck {
    pub outcome: argument_audit::TargetOutcome,
    pub actual_sha256: Option<String>,
    pub reason: Option<String>,
}

/// Canonicalize the root a receipt's targets are resolved against.
///
/// The root must exist and be a directory; it is resolved once and the
/// canonical path is what every target check uses.
pub(crate) fn canonical_root(root: &Path) -> Result<PathBuf> {
    let canonical =
        fs::canonicalize(root).with_context(|| format!("resolving root {}", root.display()))?;
    if !canonical.is_dir() {
        anyhow::bail!("receipts root {} is not a directory", canonical.display());
    }
    Ok(canonical)
}

/// Verify the current bytes at `locator` against `expected_sha256`.
///
/// Rejects absolute locators, parent escapes, every symlink component, and
/// directories; reports missing, changed (stale), and unreadable bytes.
/// Hashing streams in fixed-size chunks and stops at
/// [`MAX_LOCAL_FILE_BYTES`].
pub(crate) fn verify_registered(root: &Path, locator: &str, expected_sha256: &str) -> TargetCheck {
    match locate(root, locator) {
        Locate::File(path, _anchor) => match inspect_bytes(&path, &display_path(root, &path)) {
            Ok((actual, _bytes)) => {
                let outcome = if actual == expected_sha256 {
                    argument_audit::TargetOutcome::Matched
                } else {
                    argument_audit::TargetOutcome::Mismatched
                };
                TargetCheck {
                    outcome,
                    actual_sha256: Some(actual),
                    reason: None,
                }
            }
            Err(reason) => TargetCheck {
                outcome: argument_audit::TargetOutcome::Rejected,
                actual_sha256: None,
                reason: Some(reason),
            },
        },
        Locate::Missing => TargetCheck {
            outcome: argument_audit::TargetOutcome::Missing,
            actual_sha256: None,
            reason: None,
        },
        Locate::Rejected(reason) => TargetCheck {
            outcome: argument_audit::TargetOutcome::Rejected,
            actual_sha256: None,
            reason: Some(reason),
        },
    }
}

/// Split a `path#anchor` locator into its path and anchor parts.
fn split_anchor(locator: &str) -> (&str, Option<&str>) {
    match locator.split_once('#') {
        Some((path, anchor)) => (path, Some(anchor)),
        None => (locator, None),
    }
}

enum Locate {
    File(PathBuf, Option<String>),
    Missing,
    Rejected(String),
}

/// Resolve `locator` (relative to `root`, which must already be canonical)
/// to an existing regular file, rejecting escapes and symlink components.
///
/// `root` must be the canonical path returned by [`canonical_root`].
fn locate(root: &Path, locator: &str) -> Locate {
    let (path_part, anchor) = split_anchor(locator);
    let anchor = anchor.map(str::to_string);
    if path_part.is_empty() || path_part.bytes().any(|byte| byte == 0) || path_part.contains('\\') {
        return Locate::Rejected(format!("unsafe or empty local locator: {locator}"));
    }
    let relative = Path::new(path_part);
    if relative.is_absolute()
        || relative.components().any(|component| {
            matches!(
                component,
                Component::ParentDir | Component::RootDir | Component::Prefix(_)
            )
        })
    {
        return Locate::Rejected(format!("unsafe or empty local locator: {locator}"));
    }
    let mut current = root.to_path_buf();
    let components: Vec<Component<'_>> = relative.components().collect();
    for (index, component) in components.iter().enumerate() {
        match component {
            Component::Normal(part) => {
                current.push(part);
                let metadata = match fs::symlink_metadata(&current) {
                    Ok(metadata) => metadata,
                    Err(error) if error.kind() == std::io::ErrorKind::NotFound => {
                        return Locate::Missing;
                    }
                    Err(error) => {
                        return Locate::Rejected(format!("cannot stat {path_part}: {error}"));
                    }
                };
                if metadata.file_type().is_symlink() {
                    return Locate::Rejected(format!(
                        "symlink component `{}` in local locator: {locator}",
                        part.to_string_lossy()
                    ));
                }
                let last = index + 1 == components.len();
                if last {
                    if metadata.is_dir() {
                        return Locate::Rejected(format!(
                            "local locator `{locator}` is a directory, not a file"
                        ));
                    }
                    if !metadata.file_type().is_file() {
                        return Locate::Rejected(format!(
                            "local locator `{locator}` is not a regular file"
                        ));
                    }
                } else if !metadata.is_dir() {
                    return Locate::Rejected(format!(
                        "local locator `{locator}` is not a directory at `{}`",
                        part.to_string_lossy()
                    ));
                }
            }
            Component::CurDir => {}
            other => {
                return Locate::Rejected(format!(
                    "unsafe local locator `{locator}` (unexpected component {other:?})"
                ));
            }
        }
    }
    if components.is_empty() {
        return Locate::Rejected(format!("unsafe or empty local locator: {locator}"));
    }
    Locate::File(current, anchor)
}

fn inspect_bytes(path: &Path, display: &str) -> std::result::Result<(String, u64), String> {
    match sha256_file_capped(path, MAX_LOCAL_FILE_BYTES) {
        Ok(Some((hash, byte_count))) => Ok((hash, byte_count)),
        Ok(None) => Err(format!(
            "file exceeds the {MAX_LOCAL_FILE_BYTES}-byte hashing cap"
        )),
        Err(error) => Err(format!("cannot read {display}: {error}")),
    }
}

fn local_file(
    root: &Path,
    locator: &str,
) -> std::result::Result<(PathBuf, Option<String>), String> {
    match locate(root, locator) {
        Locate::File(path, anchor) => Ok((path, anchor)),
        Locate::Missing => Err(format!("local locator `{locator}` does not exist")),
        Locate::Rejected(reason) => Err(reason),
    }
}

fn display_path(root: &Path, path: &Path) -> String {
    path.strip_prefix(root)
        .unwrap_or(path)
        .to_string_lossy()
        .replace('\\', "/")
}

const fn claim_kind(kind: ClaimKind) -> &'static str {
    match kind {
        ClaimKind::Formal => "formal",
        ClaimKind::Empirical => "empirical",
        ClaimKind::Conditional => "conditional",
        ClaimKind::Factual => "factual",
    }
}

const fn availability(availability: Availability) -> &'static str {
    match availability {
        Availability::Pending => "pending",
        Availability::Candidate => "candidate",
    }
}

#[cfg(test)]
mod tests {
    use super::{local_file, verify_registered};
    use argument_audit::TargetOutcome;
    use std::fs;
    use std::path::PathBuf;
    use std::sync::atomic::{AtomicU64, Ordering};

    static COUNTER: AtomicU64 = AtomicU64::new(0);

    struct TempTree(PathBuf);

    impl TempTree {
        fn new() -> Self {
            let unique = COUNTER.fetch_add(1, Ordering::Relaxed);
            let path = std::env::temp_dir().join(format!(
                "argument-audit-corpus-test-{}-{unique}",
                std::process::id()
            ));
            fs::create_dir_all(&path).expect("create temp tree");
            Self(path)
        }

        fn root(&self) -> PathBuf {
            fs::canonicalize(&self.0).expect("canonical temp root")
        }
    }

    impl Drop for TempTree {
        fn drop(&mut self) {
            let _ = fs::remove_dir_all(&self.0);
        }
    }

    #[test]
    fn local_locators_cannot_escape_the_project() {
        let tree = TempTree::new();
        let root = tree.root();
        fs::write(root.join("real.txt"), b"payload").expect("write");
        assert!(local_file(&root, "real.txt#anchor").is_ok());
        assert!(local_file(&root, "../outside.json").is_err());
        assert!(local_file(&root, "/absolute.json").is_err());
        assert!(local_file(&root, "").is_err());
        assert!(local_file(&root, "real.txt/../real.txt").is_err());
    }

    #[test]
    fn internal_symlink_components_are_rejected() {
        let tree = TempTree::new();
        let root = tree.root();
        fs::create_dir_all(root.join("sub")).expect("mkdir");
        fs::write(root.join("real.txt"), b"payload").expect("write");
        std::os::unix::fs::symlink(root.join("real.txt"), root.join("link.txt")).expect("symlink");
        // A symlink pointing outside the root.
        let outside = tree.0.join("outside.txt");
        fs::write(&outside, b"outside").expect("outside");
        std::os::unix::fs::symlink(&outside, root.join("outlink.txt")).expect("symlink");
        // A symlinked directory inside the root.
        std::os::unix::fs::symlink(root.join("sub"), root.join("dirlink")).expect("symlink");

        let internal = local_file(&root, "link.txt");
        assert!(internal.is_err(), "internal symlink must be rejected");
        let escaping = local_file(&root, "outlink.txt");
        assert!(escaping.is_err(), "outside-root symlink must be rejected");
        let nested = local_file(&root, "dirlink/real.txt");
        assert!(
            nested.is_err(),
            "symlinked directory component must be rejected"
        );
    }

    #[test]
    fn directories_and_missing_files_are_not_files() {
        let tree = TempTree::new();
        let root = tree.root();
        fs::create_dir_all(root.join("sub")).expect("mkdir");
        let dir = local_file(&root, "sub");
        assert!(dir.is_err(), "a directory is not a file target");
        let missing = local_file(&root, "absent.json");
        assert!(missing.is_err(), "a missing file is not a file target");
    }

    #[test]
    fn verify_registered_reports_current_bytes() {
        let tree = TempTree::new();
        let root = tree.root();
        fs::write(root.join("data.bin"), b"payload").expect("write");
        let hash = argument_document::sha256_hex(b"payload");
        let matched = verify_registered(&root, "data.bin", &hash);
        assert_eq!(matched.outcome, TargetOutcome::Matched);
        let stale = verify_registered(&root, "data.bin", &"ab".repeat(32));
        assert_eq!(stale.outcome, TargetOutcome::Mismatched);
        let missing = verify_registered(&root, "absent.bin", &hash);
        assert_eq!(missing.outcome, TargetOutcome::Missing);
        let escaped = verify_registered(&root, "../outside.bin", &hash);
        assert_eq!(escaped.outcome, TargetOutcome::Rejected);
    }
}
