use std::collections::BTreeSet;
use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};

use arg_ingest::{build, generate, load_config, verify, CorpusConfig};
use serde_json::json;
use sha2::{Digest, Sha256};

static NEXT_DIR: AtomicU64 = AtomicU64::new(0);

struct TestDir(PathBuf);

impl TestDir {
    fn new(name: &str) -> Self {
        let sequence = NEXT_DIR.fetch_add(1, Ordering::Relaxed);
        let path = std::env::temp_dir().join(format!(
            "arg-ingest-{name}-{}-{sequence}",
            std::process::id()
        ));
        if path.exists() {
            fs::remove_dir_all(&path).unwrap();
        }
        fs::create_dir_all(&path).unwrap();
        Self(path)
    }

    fn repository(&self) -> PathBuf {
        self.0.join("repository")
    }

    fn output(&self) -> PathBuf {
        self.0.join("output")
    }

    fn write_source(&self, relative: &str, contents: impl AsRef<[u8]>) {
        let path = self.repository().join(relative);
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(path, contents).unwrap();
    }

    fn write_config(&self, config: &CorpusConfig) -> PathBuf {
        let path = self.0.join("config.json");
        fs::write(&path, serde_json::to_vec_pretty(config).unwrap()).unwrap();
        path
    }
}

impl Drop for TestDir {
    fn drop(&mut self) {
        let _ = fs::remove_dir_all(&self.0);
    }
}

fn config() -> CorpusConfig {
    serde_json::from_value(json!({
        "schema_version": "1",
        "corpus_id": "test-corpus",
        "extractor_version": "test-v1",
        "collections": [
            {"id": "production", "root": "02_causal AI en produccion", "language": "es"},
            {"id": "technical", "root": "05_contenido_tecnico", "language": "es"},
            {"id": "mcp", "root": "08_mcp-agentes-causales", "language": "es"}
        ],
        "required_groups": [
            {
                "id": "production-main",
                "collection": "production",
                "path_prefix": "Causal_AI/main.typ",
                "path_suffix": "",
                "expected_files": 1
            },
            {
                "id": "technical-main",
                "collection": "technical",
                "path_prefix": "Causal_AI/main.typ",
                "path_suffix": ".typ",
                "expected_files": 1
            },
            {
                "id": "mcp-knowledge",
                "collection": "mcp",
                "path_prefix": "src/mcp_causal/resources/knowledge/",
                "path_suffix": ".json",
                "expected_files": 1
            }
        ]
    }))
    .unwrap()
}

fn write_standard_sources(test: &TestDir) {
    let shared = "# Resultado\n\nA source assertion remains unverified.\n";
    test.write_source("02_causal AI en produccion/Causal_AI/main.typ", shared);
    test.write_source("05_contenido_tecnico/Causal_AI/main.typ", shared);
    test.write_source(
        "08_mcp-agentes-causales/src/mcp_causal/resources/knowledge/iv.json",
        "{\"name\":\"iv\",\"summary\":\"Instrumental variable source documentation\"}\n",
    );
}

#[test]
fn duplicate_candidates_trace_all_occurrences_and_builds_are_deterministic() {
    let test = TestDir::new("deterministic");
    write_standard_sources(&test);
    let config = load_config(&test.write_config(&config())).unwrap();
    let output = test.output();

    build(&config, &test.repository(), &output).unwrap();
    let first = generate(&config, &test.repository()).unwrap();
    assert_eq!(first.coverage.unique_candidates, 2);
    let shared = first
        .candidates
        .iter()
        .find(|candidate| candidate.statement == "A source assertion remains unverified.")
        .unwrap();
    assert_eq!(shared.occurrences.len(), 2);
    assert!(shared
        .occurrences
        .iter()
        .any(|occurrence| occurrence.collection == "production"));
    assert!(shared
        .occurrences
        .iter()
        .any(|occurrence| occurrence.collection == "technical"));
    assert!(shared
        .occurrences
        .iter()
        .all(|occurrence| first.units.iter().any(|unit| unit.id == occurrence.unit_id)));
    assert!(first
        .relations
        .iter()
        .any(|relation| relation.kind == "byte_identical"
            && relation.canonical_path.starts_with("02_")));

    let original_bytes = first.artifacts.clone();
    build(&config, &test.repository(), &output).unwrap();
    verify(&config, &test.repository(), &output).unwrap();
    for (name, expected) in original_bytes {
        assert_eq!(fs::read(output.join(name)).unwrap(), expected);
    }

    fs::write(output.join("coverage.json"), b"drift\n").unwrap();
    assert!(verify(&config, &test.repository(), &output).is_err());
}

#[test]
fn verify_rejects_missing_and_extra_artifacts() {
    let test = TestDir::new("artifact-set");
    write_standard_sources(&test);
    let config = load_config(&test.write_config(&config())).unwrap();
    let output = test.output();
    build(&config, &test.repository(), &output).unwrap();

    fs::remove_file(output.join("sources.jsonl")).unwrap();
    let missing = verify(&config, &test.repository(), &output).unwrap_err();
    assert!(format!("{missing:#}").contains("missing artifact `sources.jsonl`"));

    build(&config, &test.repository(), &output).unwrap();
    fs::write(output.join("unexpected.json"), b"extra\n").unwrap();
    let extra = verify(&config, &test.repository(), &output).unwrap_err();
    assert!(format!("{extra:#}").contains("extra artifact `unexpected.json`"));
}

#[test]
fn coverage_failure_writes_no_output() {
    let test = TestDir::new("coverage-failure");
    write_standard_sources(&test);
    let mut config_value = config();
    config_value.required_groups[0].expected_files = 2;
    let config = load_config(&test.write_config(&config_value)).unwrap();
    let error = build(&config, &test.repository(), &test.output()).unwrap_err();
    assert!(format!("{error:#}").contains("required group"));
    assert!(!test.output().exists());
}

#[test]
fn absolute_parent_and_symlink_roots_are_rejected() {
    for unsafe_root in ["../outside", "/absolute/source", ".", "./"] {
        let test = TestDir::new("unsafe-root");
        let mut value = config();
        value.collections[0].root = unsafe_root.to_owned();
        assert!(load_config(&test.write_config(&value)).is_err());
    }

    #[cfg(unix)]
    {
        use std::os::unix::fs::symlink;

        let test = TestDir::new("symlink-root");
        write_standard_sources(&test);
        symlink(
            test.repository().join("08_mcp-agentes-causales"),
            test.repository().join("linked-mcp"),
        )
        .unwrap();
        let mut value = config();
        value.collections[2].root = "linked-mcp".to_owned();
        let config = load_config(&test.write_config(&value)).unwrap();
        assert!(generate(&config, &test.repository()).is_err());
    }
}

#[cfg(unix)]
#[test]
fn symlink_source_files_are_rejected() {
    use std::os::unix::fs::symlink;

    let test = TestDir::new("symlink-file");
    write_standard_sources(&test);
    symlink(
        test.repository()
            .join("08_mcp-agentes-causales/src/mcp_causal/resources/knowledge/iv.json"),
        test.repository().join("08_mcp-agentes-causales/README.md"),
    )
    .unwrap();
    let config = load_config(&test.write_config(&config())).unwrap();
    assert!(generate(&config, &test.repository()).is_err());
}

#[cfg(unix)]
#[test]
fn symlink_output_roots_are_rejected() {
    use std::os::unix::fs::symlink;

    let test = TestDir::new("symlink-output");
    write_standard_sources(&test);
    symlink(test.repository(), test.output()).unwrap();
    let config = load_config(&test.write_config(&config())).unwrap();
    let build_error = build(&config, &test.repository(), &test.output()).unwrap_err();
    assert!(format!("{build_error:#}").contains("symlink output roots"));
    let verify_error = verify(&config, &test.repository(), &test.output()).unwrap_err();
    assert!(format!("{verify_error:#}").contains("symlink output roots"));
}

#[test]
fn malformed_review_jsonl_fails_source_ingestion() {
    let test = TestDir::new("bad-jsonl");
    write_standard_sources(&test);
    test.write_source(
        "05_contenido_tecnico/Causal_AI/verificacion/review.jsonl",
        b"{\"status\":\"ok\"}\nnot-json\n",
    );
    let config = load_config(&test.write_config(&config())).unwrap();
    let error = generate(&config, &test.repository()).unwrap_err();
    assert!(format!("{error:#}").contains("invalid JSONL line 2"));
}

#[test]
fn pruned_directories_are_recorded_once_without_descendant_inventory() {
    let test = TestDir::new("pruning");
    write_standard_sources(&test);
    test.write_source(
        "08_mcp-agentes-causales/.venv/private/ignored.txt",
        b"must not be read",
    );
    let config = load_config(&test.write_config(&config())).unwrap();
    let generated = generate(&config, &test.repository()).unwrap();
    assert_eq!(
        generated
            .exclusions
            .iter()
            .filter(|record| {
                record.path.ends_with("/.venv") && record.entry_kind == "directory"
            })
            .count(),
        1
    );
    assert!(!generated
        .inventory
        .iter()
        .any(|record| record.path.contains("/.venv/")));
}

#[test]
fn query_filters_are_deterministic_and_contains_ignores_case() {
    let test = TestDir::new("query");
    write_standard_sources(&test);
    let config = load_config(&test.write_config(&config())).unwrap();
    let generated = generate(&config, &test.repository()).unwrap();
    let filter = arg_ingest::QueryFilter {
        collection: Some("production".to_owned()),
        topic: None,
        contains: Some("SOURCE ASSERTION".to_owned()),
        limit: Some(1),
    };
    let selected = arg_ingest::query_candidates(&generated.candidates, &filter);
    assert_eq!(selected.len(), 1);
    assert_eq!(
        selected[0].statement,
        "A source assertion remains unverified."
    );
}

#[test]
fn included_empty_source_is_still_hashed() {
    let test = TestDir::new("empty-included");
    write_standard_sources(&test);
    test.write_source("08_mcp-agentes-causales/examples/empty.py", b"");
    let config = load_config(&test.write_config(&config())).unwrap();
    let generated = generate(&config, &test.repository()).unwrap();
    let source = generated
        .sources
        .iter()
        .find(|source| source.path.ends_with("examples/empty.py"))
        .unwrap();
    assert_eq!(source.bytes, 0);
    assert_eq!(source.sha256.len(), 64);
}

#[test]
fn paths_preserve_spaces_and_utf8() {
    let test = TestDir::new("utf8-path");
    write_standard_sources(&test);
    test.write_source(
        "02_causal AI en produccion/Causal_AI/capitulos/capítulo acción.typ",
        "Una afirmación documental.\n",
    );
    let config = load_config(&test.write_config(&config())).unwrap();
    let generated = generate(&config, &test.repository()).unwrap();
    assert!(generated
        .sources
        .iter()
        .any(|source| source.path.ends_with("capitulos/capítulo acción.typ")));
}

#[test]
fn required_groups_apply_both_affixes_to_every_included_source() {
    let test = TestDir::new("required-group-affixes");
    write_standard_sources(&test);
    for path in [
        "02_causal AI en produccion/Causal_AI/capitulos/cap01.typ",
        "02_causal AI en produccion/Causal_AI/capitulos/cap02.typ",
        "02_causal AI en produccion/Causal_AI/capitulos/cap03.typ.txt",
        "02_causal AI en produccion/Causal_AI/capitulos_extra/cap04.typ",
        "02_causal AI en produccion/Causal_AI/nested/Causal_AI/capitulos/cap05.typ",
        "05_contenido_tecnico/Causal_AI/capitulos/cap06.typ",
    ] {
        test.write_source(path, "A documentary chapter assertion.\n");
    }
    let mut value = config();
    value.required_groups.push(
        serde_json::from_value(json!({
            "id": "production-chapters",
            "collection": "production",
            "path_prefix": "Causal_AI/capitulos/",
            "path_suffix": ".typ",
            "expected_files": 2
        }))
        .unwrap(),
    );
    let config = load_config(&test.write_config(&value)).unwrap();
    let generated = generate(&config, &test.repository()).unwrap();
    let group = generated
        .coverage
        .required_groups
        .iter()
        .find(|group| group.id == "production-chapters")
        .unwrap();

    assert_eq!(group.status, "pass");
    assert_eq!(group.matched_files, 2);
    assert_eq!(
        group.matched_paths,
        vec![
            "02_causal AI en produccion/Causal_AI/capitulos/cap01.typ".to_owned(),
            "02_causal AI en produccion/Causal_AI/capitulos/cap02.typ".to_owned(),
        ]
    );
}

#[test]
fn every_unit_round_trips_to_its_original_bytes_and_hash() {
    let test = TestDir::new("raw-span-round-trip");
    write_standard_sources(&test);
    test.write_source(
        "02_causal AI en produccion/Causal_AI/capitulos/capítulo acción.typ",
        "Primera afirmación con acción.\r\n\r\nSegunda afirmación con ﬁ.\r\n",
    );
    let config = load_config(&test.write_config(&config())).unwrap();
    let generated = generate(&config, &test.repository()).unwrap();
    let mut sources_with_units = BTreeSet::new();

    for unit in &generated.units {
        let source = generated
            .sources
            .iter()
            .find(|source| source.id == unit.source_id)
            .unwrap();
        let bytes = fs::read(test.repository().join(&source.path)).unwrap();
        let start = usize::try_from(unit.span.byte_start).unwrap();
        let end = usize::try_from(unit.span.byte_end).unwrap();
        let raw = bytes.get(start..end).unwrap();

        assert_eq!(raw, unit.raw_text.as_bytes());
        assert_eq!(format!("{:x}", Sha256::digest(raw)), unit.raw_sha256);
        assert_eq!(format!("{:x}", Sha256::digest(&bytes)), source.sha256);
        sources_with_units.insert(&unit.source_id);
    }

    let parsed_sources = generated
        .sources
        .iter()
        .filter(|source| source.disposition == "parsed")
        .map(|source| &source.id)
        .collect::<BTreeSet<_>>();
    assert_eq!(sources_with_units, parsed_sources);
}

#[test]
fn excluded_files_have_exact_inventory_and_exclusion_records() {
    let test = TestDir::new("exclusion-round-trip");
    write_standard_sources(&test);
    test.write_source(
        "02_causal AI en produccion/Causal_AI/figure.pdf",
        b"%PDF-test",
    );
    test.write_source("08_mcp-agentes-causales/.gitkeep", b"");
    test.write_source("02_causal AI en produccion/.DS_Store", [0xff, 0x00]);
    let config = load_config(&test.write_config(&config())).unwrap();
    let generated = generate(&config, &test.repository()).unwrap();
    let exclusions = generated
        .exclusions
        .iter()
        .filter(|record| record.entry_kind == "file")
        .collect::<Vec<_>>();

    assert_eq!(exclusions.len(), 3);
    let mut reasons = exclusions
        .iter()
        .map(|record| record.reason.as_str())
        .collect::<Vec<_>>();
    reasons.sort();
    assert_eq!(
        reasons,
        vec![
            "binary_or_generated_asset_excluded_but_inventoried",
            "explicit_empty_root_placeholder",
            "unknown_non_utf8_or_unsupported_asset_excluded_but_inventoried",
        ]
    );
    for exclusion in exclusions {
        let inventory = generated
            .inventory
            .iter()
            .find(|record| record.entry_kind == "file" && record.path == exclusion.path)
            .unwrap();
        assert_eq!(inventory.disposition, "excluded");
        assert_eq!(inventory.bytes, exclusion.bytes);
        assert_eq!(inventory.sha256, exclusion.sha256);
        assert_eq!(inventory.reason, exclusion.reason);
        assert!(!generated
            .sources
            .iter()
            .any(|source| source.path == exclusion.path));
    }
}
