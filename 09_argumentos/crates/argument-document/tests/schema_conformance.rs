//! Loader/schema-conformance regressions.
//!
//! The docs-site schema (`schemas/kernel.schema.json`) documents the wire
//! format but is not the enforcement point; the Rust loader is. This file
//! pins the known, accepted divergences between the two so they fail
//! loudly instead of widening silently. The schema file itself is not
//! modified by these tests or by this crate.
//!
//! Known divergences under test:
//!
//! 1. `verified` is not a legal `kind` or `availability` anywhere. The
//!    schema's enums say so and so does the loader: a document that writes
//!    `verified` self-approves itself, which the loader rejects as
//!    `ContractError::SelfApproval`. It can never round-trip into an
//!    accepted kernel.
//! 2. The `atoms` registry is documented only for the 1.1 line, but the
//!    loader accepts it in legacy 1.0 documents too. Registry presence is
//!    always enforced when present, regardless of version: an unregistered
//!    atom, an unused registry entry, or a `definition_claim` that does
//!    not resolve are all load-time contract failures.
//! 3. Schema 1.0 omits `profile`, `corpus`, and `source`; the loader
//!    accepts those documents with compiled-in defaults and never lets a
//!    document pick a new rule set.

use argument_document::{ContractError, Kernel, ProfileId, SchemaVersion};

fn minimal_1_0(claims: &str, arguments: &str, evidence: &str) -> String {
    format!(
        r#"{{"schema_version":"1.0","claims":[{claims}],"arguments":[{arguments}],"evidence_specs":[{evidence}]}}"#
    )
}

fn formal_claim(id: &str, atom: &str) -> String {
    format!(
        r#"{{"id":"{id}","book_key":null,"kind":"formal","statement":"s","expression":{{"op":"atom","id":"{atom}"}},"scope":{{}},"assumptions":[]}}"#
    )
}

#[test]
fn verified_claim_kind_cannot_self_approve_in_any_version() {
    for version in ["1.0", "1.1"] {
        let body = format!(
            r#"{{"schema_version":"{version}","claims":[{{"id":"C.P","kind":"verified","statement":"x","expression":{{"op":"atom","id":"P"}},"scope":{{}},"assumptions":[]}}],"arguments":[],"evidence_specs":[]}}"#
        );
        assert!(
            matches!(Kernel::load_str(&body), Err(ContractError::SelfApproval(_))),
            "schema {version}: verified claim kind must not self-approve"
        );
    }
}

#[test]
fn verified_availability_cannot_self_approve() {
    for version in ["1.0", "1.1"] {
        let body = format!(
            r#"{{"schema_version":"{version}","claims":[],"arguments":[],"evidence_specs":[{{"id":"E.x","kind":"python","claim_id":"C.P","runner_id":"r","target":"t","scope":{{}},"availability":"verified"}}]}}"#
        );
        assert!(
            matches!(Kernel::load_str(&body), Err(ContractError::SelfApproval(_))),
            "schema {version}: verified availability must not self-approve"
        );
    }
}

#[test]
fn verified_evidence_kind_is_rejected_not_registered() {
    // In 1.1 `verified` is an unknown evidence kind and is still not a
    // certificate; in 1.0 it is rejected outright. Neither path reaches
    // `EvidenceKind`.
    let v11 = r#"{"schema_version":"1.1","claims":[],"arguments":[],"evidence_specs":[{"id":"E.x","kind":"verified","claim_id":"C.P","runner_id":"r","target":"t","scope":{},"availability":"pending"}]}"#;
    assert!(matches!(
        Kernel::load_str(v11),
        Err(ContractError::SelfApproval(_)) | Err(ContractError::Invalid(_))
    ));
    let v10 = r#"{"schema_version":"1.0","claims":[],"arguments":[],"evidence_specs":[{"id":"E.x","kind":"verified","claim_id":"C.P","runner_id":"r","target":"t","scope":{},"availability":"pending"}]}"#;
    assert!(matches!(
        Kernel::load_str(v10),
        Err(ContractError::SelfApproval(_)) | Err(ContractError::Invalid(_))
    ));
}

#[test]
fn schema_1_0_without_atoms_loads_with_compiled_defaults() {
    // The 1.0 legacy fixture shape: no profile, no corpus, no source, no
    // atoms. It loads, and atoms stay absent.
    let body = minimal_1_0(&formal_claim("C.P", "P"), "", "");
    let kernel = Kernel::load_str(&body).expect("legacy 1.0 without atoms must load");
    assert_eq!(kernel.schema_version, SchemaVersion::V1_0);
    assert_eq!(kernel.profile, ProfileId::ScientificAudit);
    assert!(kernel.atoms.is_none());
}

#[test]
fn schema_1_0_atoms_registry_is_enforced_when_present() {
    // The 1.0 schema section is silent about `atoms`, but the loader
    // accepts the field and enforces it: the registry is fail-closed in
    // both versions.
    let body = format!(
        r#"{{"schema_version":"1.0","claims":[{}],"arguments":[],"evidence_specs":[],"atoms":[{{"id":"P","definition_claim":"C.P","description":"d"}}]}}"#,
        formal_claim("C.P", "P")
    );
    let kernel = Kernel::load_str(&body).expect("1.0 with a consistent atoms registry loads");
    assert!(kernel.atoms.is_some());

    // An atom used by a claim but missing from the registry is rejected.
    let body = format!(
        r#"{{"schema_version":"1.0","claims":[{}],"arguments":[],"evidence_specs":[],"atoms":[{{"id":"OTHER","definition_claim":"C.P","description":"d"}}]}}"#,
        formal_claim("C.P", "P")
    );
    let error = Kernel::load_str(&body).expect_err("unregistered atom must fail");
    assert!(matches!(
        error,
        ContractError::AtomNotRegistered { .. } | ContractError::UnusedAtom { .. }
    ));

    // A registry entry no claim expression uses is rejected.
    let body = r#"{"schema_version":"1.0","claims":[{"id":"C.P","book_key":null,"kind":"formal","statement":"s","expression":{"op":"atom","id":"P"},"scope":{},"assumptions":[]}],"arguments":[],"evidence_specs":[],"atoms":[{"id":"P","definition_claim":"C.P","description":"d"},{"id":"Q","definition_claim":"C.P","description":"d"}]}"#;
    let error = Kernel::load_str(body).expect_err("unused atom must fail");
    assert!(matches!(error, ContractError::UnusedAtom { .. }));

    // A definition claim that does not resolve is rejected.
    let body = r#"{"schema_version":"1.0","claims":[{"id":"C.P","book_key":null,"kind":"formal","statement":"s","expression":{"op":"atom","id":"P"},"scope":{},"assumptions":[]}],"arguments":[],"evidence_specs":[],"atoms":[{"id":"P","definition_claim":"C.ABSENT","description":"d"}]}"#;
    let error = Kernel::load_str(body).expect_err("dangling definition claim must fail");
    assert!(matches!(error, ContractError::AtomDefinitionClaim { .. }));
}

#[test]
fn schema_version_must_be_present_and_a_string() {
    // Absent: explicitly the "missing" contract error.
    let absent = r#"{"claims":[],"arguments":[],"evidence_specs":[]}"#;
    assert!(matches!(
        Kernel::load_str(absent),
        Err(ContractError::SchemaVersion(message)) if message == "missing"
    ));
    // Present but not a string: never reported as "missing".
    for (body, what) in [
        (
            r#"{"schema_version":1.1,"claims":[],"arguments":[],"evidence_specs":[]}"#,
            "a number",
        ),
        (
            r#"{"schema_version":true,"claims":[],"arguments":[],"evidence_specs":[]}"#,
            "a boolean",
        ),
        (
            r#"{"schema_version":null,"claims":[],"arguments":[],"evidence_specs":[]}"#,
            "null",
        ),
        (
            r#"{"schema_version":["1.1"],"claims":[],"arguments":[],"evidence_specs":[]}"#,
            "an array",
        ),
        (
            r#"{"schema_version":{"x":"1.1"},"claims":[],"arguments":[],"evidence_specs":[]}"#,
            "an object",
        ),
    ] {
        match Kernel::load_str(body) {
            Err(ContractError::SchemaVersionNonString(got)) => {
                assert_eq!(got, what, "{body}");
            }
            other => panic!("present non-string schema_version must not say missing: {other:?}"),
        }
    }
}

#[test]
fn legacy_documents_never_gain_an_invented_book_source() {
    // A claim without locator and without book_key must not gain
    // {system: "book", key: null}; the honest default is system "unknown".
    let body = r#"{"schema_version":"1.0","claims":[{"id":"C.P","kind":"formal","statement":"s","expression":{"op":"atom","id":"P"},"scope":{},"assumptions":[]}],"arguments":[],"evidence_specs":[]}"#;
    let kernel = Kernel::load_str(body).expect("loads");
    let source = kernel.claims[0].source.as_ref().expect("defaulted source");
    assert_eq!(source.system, "unknown");
    assert_eq!(source.key, None);

    // A claim with a book_key keeps the book system with its key.
    let body = r#"{"schema_version":"1.0","claims":[{"id":"C.P","book_key":"ssch-one-decision","kind":"formal","statement":"s","expression":{"op":"atom","id":"P"},"scope":{},"assumptions":[]}],"arguments":[],"evidence_specs":[]}"#;
    let kernel = Kernel::load_str(body).expect("loads");
    let source = kernel.claims[0].source.as_ref().expect("defaulted source");
    assert_eq!(source.system, "book");
    assert_eq!(source.key.as_deref(), Some("ssch-one-decision"));
}
