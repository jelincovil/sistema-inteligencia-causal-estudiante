//! Deterministic regression tests for the hardening rules:
//! deep inputs, duplicate and certified-self receipts, scope accounting,
//! the atom registry, global support cycles, and factual pending axes.

use argument_audit::{admit_receipt, check, ByteVerification, Decision, StatusAxis};
use argument_document::{
    ContractError, Kernel, Receipt, MAX_COLLECTION, MAX_DOCUMENT_BYTES, MAX_JSON_DEPTH,
};

fn kernel(claims: &str, arguments: &str, evidence: &str) -> String {
    format!(
        r#"{{"schema_version":"1.1","profile":"scientific_audit","claims":[{claims}],"arguments":[{arguments}],"evidence_specs":[{evidence}]}}"#
    )
}

fn load(body: &str) -> Kernel {
    Kernel::load_str(body).unwrap_or_else(|error| panic!("load failed: {error}"))
}

fn formal_claim(id: &str, atom: &str, scope: &str) -> String {
    format!(
        r#"{{"id":"{id}","kind":"formal","statement":"s {id}","expression":{{"op":"atom","id":"{atom}"}},"scope":{scope},"assumptions":[]}}"#
    )
}

#[test]
fn deeply_nested_expression_json_fails_closed() {
    let mut expression = String::from(r#"{"op":"atom","id":"P"}"#);
    for _ in 0..(MAX_JSON_DEPTH + 10) {
        expression = format!(
            r#"{{"op":"implies","antecedent":{expression},"consequent":{{"op":"atom","id":"Q"}}}}"#
        );
    }
    let body = kernel(
        &format!(
            r#"{{"id":"C.P","kind":"formal","statement":"deep","expression":{expression},"scope":{{}},"assumptions":[]}}"#
        ),
        "",
        "",
    );
    let error = Kernel::load_str(&body).expect_err("deep expression must not load");
    assert!(matches!(
        error,
        ContractError::JsonTooDeep { .. } | ContractError::JsonTooManyNodes { .. }
    ));
}

#[test]
fn deeply_nested_arrays_fail_with_typed_error() {
    let mut body = String::from("[");
    for _ in 0..(MAX_JSON_DEPTH + 10) {
        body.push('[');
    }
    for _ in 0..(MAX_JSON_DEPTH + 10) {
        body.push(']');
    }
    body.push(']');
    let error = Kernel::load_str(&body).expect_err("deep array must not load");
    assert!(matches!(error, ContractError::JsonTooDeep { .. }));
    let receipt_error =
        Receipt::load_all(body.as_bytes()).expect_err("deep receipts must not load");
    assert!(matches!(receipt_error, ContractError::JsonTooDeep { .. }));
}

#[test]
fn oversized_document_fails_before_parsing() {
    let bytes = vec![b' '; (MAX_DOCUMENT_BYTES + 1) as usize];
    assert!(matches!(
        Kernel::load(&bytes),
        Err(ContractError::InputTooLarge { .. })
    ));
}

#[test]
fn long_assumption_chain_does_not_overflow_the_stack() {
    let depth = 2000;
    let mut claims = Vec::with_capacity(depth);
    for index in 0..depth {
        let assumptions = if index + 1 < depth {
            format!(r#"["C.{:05}"]"#, index + 1)
        } else {
            "[]".to_string()
        };
        claims.push(format!(
            r#"{{"id":"C.{index:05}","kind":"formal","statement":"s","expression":{{"op":"atom","id":"A{index}"}},"scope":{{}},"assumptions":{assumptions}}}"#
        ));
    }
    let body = kernel(&claims.join(","), "", "");
    let loaded = load(&body);
    let report = check(&loaded);
    assert_ne!(report.decision, Decision::Rejected);

    // Now close the chain into a deep assumption cycle; traversal must
    // still terminate without overflowing.
    let mut claims = Vec::with_capacity(depth);
    for index in 0..depth {
        let next = format!("C.{:05}", (index + 1) % depth);
        claims.push(format!(
            r#"{{"id":"C.{index:05}","kind":"formal","statement":"s","expression":{{"op":"atom","id":"A{index}"}},"scope":{{}},"assumptions":["{next}"]}}"#
        ));
    }
    let body = kernel(&claims.join(","), "", "");
    let loaded = load(&body);
    let report = check(&loaded);
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report.diagnostics.iter().any(|item| item.code == "cycle"));
}

#[test]
fn too_many_receipts_fail_closed() {
    let receipt = r#"{
        "schema_version":"1.0","id":"R.x","spec_id":"E.x","spec_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "source_commit":"local","environment_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "checker_version":"0.1.0","command_argv":["cargo","test"],"working_directory":".",
        "input_hashes":{},"started_at":"2026-11-04T00:00:00Z","finished_at":"2026-11-04T00:00:01Z",
        "exit_status":0,"termination":"completed",
        "stdout_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "stderr_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "artifacts":[],"execution_passed":true,"scientific_criterion_met":null,
        "observed_checks":[],"trust_mode":"locally_reproduced"
    }"#;
    let mut receipts = String::from("[");
    for index in 0..=argument_document::MAX_RECEIPTS {
        if index > 0 {
            receipts.push(',');
        }
        let unique = receipt.replace("\"R.x\"", &format!("\"R.{index}\""));
        receipts.push_str(&unique);
    }
    receipts.push(']');
    let error = Receipt::load_all(receipts.as_bytes()).expect_err("too many receipts");
    assert!(matches!(
        error,
        ContractError::CollectionTooLarge {
            what: "receipts",
            ..
        }
    ));
}

fn receipt_body(execution_passed: bool, started: &str, finished: &str, observed: &str) -> String {
    format!(
        r#"{{
        "schema_version":"1.0","id":"R.test","spec_id":"E.x","spec_hash":"{hash}",
        "source_commit":"local","environment_hash":"{hash}","checker_version":"0.1.0",
        "command_argv":["cargo","test"],"working_directory":".",
        "input_hashes":{{}},"started_at":"{started}","finished_at":"{finished}",
        "exit_status":{exit},"termination":"completed",
        "stdout_sha256":"{hash}","stderr_sha256":"{hash}",
        "artifacts":[],"execution_passed":{execution_passed},"scientific_criterion_met":null,
        "observed_checks":{observed},"trust_mode":"locally_reproduced"
    }}"#,
        hash = "ab".repeat(32),
        exit = if execution_passed { "0" } else { "1" },
    )
}

#[test]
fn duplicate_receipt_ids_are_rejected() {
    let body = receipt_body(false, "2026-11-04T00:00:00Z", "2026-11-04T00:00:01Z", "[]");
    let pair = format!("[{body},{body}]");
    let error = Receipt::load_all(pair.as_bytes()).expect_err("duplicate ids must fail");
    assert!(matches!(error, ContractError::DuplicateId(id) if id == "R.test"));
}

#[test]
fn receipt_timestamps_must_be_rfc3339_utc_and_ordered() {
    for (label, started, finished) in [
        (
            "offset is not UTC",
            "2026-11-04T00:00:00+02:00",
            "2026-11-04T00:00:01Z",
        ),
        (
            "lowercase z rejected",
            "2026-11-04T00:00:00z",
            "2026-11-04T00:00:01Z",
        ),
        (
            "month out of range",
            "2026-13-04T00:00:00Z",
            "2026-11-04T00:00:01Z",
        ),
        (
            "february 30 does not exist",
            "2026-02-30T00:00:00Z",
            "2026-11-04T00:00:01Z",
        ),
        (
            "hour out of range",
            "2026-11-04T24:00:00Z",
            "2026-11-04T00:00:01Z",
        ),
        (
            "second 60 rejected",
            "2026-11-04T00:00:60Z",
            "2026-11-04T00:00:01Z",
        ),
        (
            "finished before started",
            "2026-11-04T00:00:02Z",
            "2026-11-04T00:00:01Z",
        ),
    ] {
        let body = receipt_body(false, started, finished, "[]");
        assert!(
            Receipt::load(body.as_bytes()).is_err(),
            "case `{label}` must be rejected"
        );
    }
    // Fractional seconds and equal instants are legal.
    let ok = receipt_body(
        false,
        "2026-11-04T00:00:00.250Z",
        "2026-11-04T00:00:00.250Z",
        "[]",
    );
    assert!(Receipt::load(ok.as_bytes()).is_ok());
    let leap = receipt_body(false, "2024-02-29T00:00:00Z", "2024-02-29T00:00:01Z", "[]");
    assert!(Receipt::load(leap.as_bytes()).is_ok());
    let not_leap = receipt_body(false, "2026-02-29T00:00:00Z", "2026-02-29T00:00:01Z", "[]");
    assert!(Receipt::load(not_leap.as_bytes()).is_err());
    let nanos = receipt_body(
        false,
        "2026-11-04T00:00:00.123456789Z",
        "2026-11-04T00:00:01Z",
        "[]",
    );
    assert!(Receipt::load(nanos.as_bytes()).is_ok());
}

#[test]
fn execution_passed_cannot_hide_a_failed_or_pending_check() {
    let failed = receipt_body(
        true,
        "2026-11-04T00:00:00Z",
        "2026-11-04T00:00:01Z",
        r#"[{"id":"check.a","status":"fail","detail":"boom"}]"#,
    );
    assert!(Receipt::load(failed.as_bytes()).is_err());
    let pending = receipt_body(
        true,
        "2026-11-04T00:00:00Z",
        "2026-11-04T00:00:01Z",
        r#"[{"id":"check.a","status":"pending","detail":"waiting"}]"#,
    );
    assert!(Receipt::load(pending.as_bytes()).is_err());
    let skipped = receipt_body(
        true,
        "2026-11-04T00:00:00Z",
        "2026-11-04T00:00:01Z",
        r#"[{"id":"check.a","status":"skip","detail":"not applicable"}]"#,
    );
    assert!(Receipt::load(skipped.as_bytes()).is_ok());
}

#[test]
fn unknown_variants_that_certify_are_self_approval() {
    for variant in [
        "approved",
        "verified",
        "claim_supported",
        "corpus_closed",
        "scientific_validity_certified",
        "reproduced",
        "evidence_replayed",
        "admitted",
        "trusted",
        "certified",
    ] {
        let body = kernel(
            &format!(
                r#"{{"id":"C.P","kind":"{variant}","statement":"s","expression":{{"op":"atom","id":"P"}},"scope":{{}},"assumptions":[]}}"#
            ),
            "",
            "",
        );
        assert!(
            matches!(Kernel::load_str(&body), Err(ContractError::SelfApproval(_))),
            "kind `{variant}` must be self-approval"
        );
    }
    // A certifying availability value is the same class of failure.
    let body = kernel(
        &formal_claim("C.P", "P", "{}"),
        "",
        r#"{"id":"E.x","kind":"python","claim_id":"C.P","runner_id":"r","target":"t","scope":{},"availability":"verified"}"#,
    );
    assert!(matches!(
        Kernel::load_str(&body),
        Err(ContractError::SelfApproval(_))
    ));
    // Certifying scope keys and values fail closed too.
    let body = kernel(
        r#"{"id":"C.P","kind":"factual","statement":"s","expression":{"op":"atom","id":"P"},"scope":{"approved":"yes"},"assumptions":[]}"#,
        "",
        "",
    );
    assert!(matches!(
        Kernel::load_str(&body),
        Err(ContractError::SelfApproval(_))
    ));
    let body = kernel(
        r#"{"id":"C.P","kind":"factual","statement":"s","expression":{"op":"atom","id":"P"},"scope":{"domain":"certified"},"assumptions":[]}"#,
        "",
        "",
    );
    assert!(matches!(
        Kernel::load_str(&body),
        Err(ContractError::SelfApproval(_))
    ));
}

fn registry_kernel(atoms: &str) -> String {
    format!(
        r#"{{"schema_version":"1.1","profile":"scientific_audit","atoms":{atoms},
        "claims":[
            {{"id":"C.P","kind":"formal","statement":"P is defined here","expression":{{"op":"atom","id":"P"}},"scope":{{}},"assumptions":[]}},
            {{"id":"C.Q","kind":"formal","statement":"Q uses P","expression":{{"op":"implies","antecedent":{{"op":"atom","id":"P"}},"consequent":{{"op":"atom","id":"P"}}}},"scope":{{}},"assumptions":[]}}
        ],"arguments":[],"evidence_specs":[]}}"#
    )
}

#[test]
fn atoms_is_enforced_when_present() {
    let body = registry_kernel(r#"[{"id":"P","definition_claim":"C.P"}]"#);
    let kernel = load(&body);
    assert!(kernel.atoms.is_some());

    // An atom used in an expression but absent from the registry.
    let body = registry_kernel(r#"[{"id":"Other","definition_claim":"C.P"}]"#);
    assert!(matches!(
        Kernel::load_str(&body),
        Err(ContractError::AtomNotRegistered { atom }) if atom == "P"
    ));

    // A definition_claim that does not resolve.
    let body = registry_kernel(r#"[{"id":"P","definition_claim":"C.absent"}]"#);
    assert!(matches!(
        Kernel::load_str(&body),
        Err(ContractError::AtomDefinitionClaim { atom, claim }) if atom == "P" && claim == "C.absent"
    ));

    // Registry keys must be valid ids.
    let body = registry_kernel(r#"[{"id":"1bad","definition_claim":"C.P"}]"#);
    assert!(matches!(
        Kernel::load_str(&body),
        Err(ContractError::BadId(_))
    ));

    // A registered atom no expression uses is rejected too (closed registry).
    let body = registry_kernel(
        r#"[{"id":"P","definition_claim":"C.P"},{"id":"Extra","definition_claim":"C.P"}]"#,
    );
    assert!(matches!(
        Kernel::load_str(&body),
        Err(ContractError::UnusedAtom { atom }) if atom == "Extra"
    ));

    // Duplicate atoms are rejected.
    let body = registry_kernel(
        r#"[{"id":"P","definition_claim":"C.P"},{"id":"P","definition_claim":"C.P"}]"#,
    );
    assert!(matches!(
        Kernel::load_str(&body),
        Err(ContractError::DuplicateId(id)) if id == "P"
    ));

    // The legacy array entries may carry an optional description.
    let body =
        registry_kernel(r#"[{"id":"P","definition_claim":"C.P","description":"what P means"}]"#);
    let kernel = load(&body);
    let description = kernel
        .atoms
        .as_ref()
        .and_then(|registry| registry.get("P"))
        .and_then(|entry| entry.description.as_deref());
    assert_eq!(description, Some("what P means"));

    // Unknown entry fields are rejected.
    let body = registry_kernel(r#"[{"id":"P","definition_claim":"C.P","status":"verified"}]"#);
    assert!(matches!(
        Kernel::load_str(&body),
        Err(ContractError::SelfApproval(_))
    ));
}

#[test]
fn atoms_is_part_of_the_canonical_kernel() {
    let with_registry = load(&registry_kernel(r#"[{"id":"P","definition_claim":"C.P"}]"#));
    let canonical = argument_document::canonical_kernel(&with_registry).expect("canonical");
    let text = String::from_utf8(canonical).expect("utf8");
    assert!(text.contains("\"atoms\""));
    assert!(text.contains("\"definition_claim\":\"C.P\""));

    let without_registry = load(&kernel(&formal_claim("C.P", "P", "{}"), "", ""));
    assert_ne!(
        with_registry.content_sha256().expect("hash"),
        without_registry.content_sha256().expect("hash")
    );
}

fn conditional_application(premise_scope: &str, conclusion_scope: &str) -> String {
    format!(
        r#"{{"schema_version":"1.1","profile":"scientific_audit","claims":[
            {{"id":"C.H","kind":"formal","statement":"H","expression":{{"op":"atom","id":"H"}},"scope":{premise_scope},"assumptions":[]}},
            {{"id":"C.S","kind":"conditional","statement":"H here","expression":{{"op":"atom","id":"S"}},"scope":{conclusion_scope},"assumptions":["C.H"]}}
        ],"arguments":[{{"id":"A.S","conclusion":"C.S","premises":["C.H"],"rule":"CONDITIONAL_APPLICATION","evidence_specs":[]}}],"evidence_specs":[]}}"#
    )
}

#[test]
fn conditional_application_rejects_revalued_and_dropped_scope() {
    // Revalued scenario the premise declared: still an error.
    let report = check(&load(&conditional_application(
        r#"{"domain":"finite","scenario":"lab"}"#,
        r#"{"domain":"finite","scenario":"field"}"#,
    )));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_mismatch" && item.detail.contains("`scenario`")));

    // Dropped scenario: an aggregated conclusion cannot smuggle one away.
    let report = check(&load(&conditional_application(
        r#"{"domain":"finite","scenario":"lab"}"#,
        r#"{"domain":"finite"}"#,
    )));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_mismatch" && item.detail.contains("`scenario`")));

    // Dropped domain: an error.
    let report = check(&load(&conditional_application(
        r#"{"domain":"finite","scenario":"lab"}"#,
        r#"{"scenario":"lab"}"#,
    )));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_mismatch"));

    // Lattice widening is the named scope_widened error.
    let report = check(&load(&conditional_application(
        r#"{"domain":"finite","observations":"finite"}"#,
        r#"{"domain":"countable","observations":"infinite"}"#,
    )));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_widened"));

    // Narrowing is an error, not a free pass.
    let report = check(&load(&conditional_application(
        r#"{"domain":"infinite"}"#,
        r#"{"domain":"countable"}"#,
    )));
    assert_eq!(report.decision, Decision::Rejected);

    // Aggregation keys may be absent from the conclusion.
    let report = check(&load(&conditional_application(
        r#"{"domain":"finite","role":"train","clip":"0.05","diagnostic":"overlap","claim_class":"association","limitation":"unmeasured_confounding"}"#,
        r#"{"domain":"finite"}"#,
    )));
    assert_eq!(report.decision, Decision::StructurallyValid);

    // ...but an aggregation key that is present must match exactly.
    let report = check(&load(&conditional_application(
        r#"{"domain":"finite","claim_class":"association"}"#,
        r#"{"domain":"finite","claim_class":"counterfactual"}"#,
    )));
    assert_eq!(report.decision, Decision::Rejected);

    // Adding a scenario the generic premise did not declare is not exact
    // equality, so it is an error like any other added key.
    let report = check(&load(&conditional_application(
        r#"{"domain":"finite"}"#,
        r#"{"domain":"finite","scenario":"lab"}"#,
    )));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_mismatch" && item.detail.contains("`scenario`")));
}

#[test]
fn conditional_application_passes_with_equal_declared_scope() {
    let report = check(&load(&conditional_application(
        r#"{"domain":"finite","scenario":"lab"}"#,
        r#"{"domain":"finite","scenario":"lab"}"#,
    )));
    assert_eq!(report.decision, Decision::StructurallyValid);
}

#[test]
fn limitations_may_be_aggregated_away_from_the_conclusion() {
    // One conditional dossier can aggregate distinct limitations: the
    // conclusion may omit `limitation` entirely even though the premises
    // declare none.
    let claims = [
        r#"{"id":"C.unc","kind":"formal","statement":"confounding is not ruled out","expression":{"op":"atom","id":"L1"},"scope":{"limitation":"unmeasured_confounding"},"assumptions":[]}"#,
        r#"{"id":"C.trp","kind":"formal","statement":"transport not identified","expression":{"op":"atom","id":"L2"},"scope":{"limitation":"transportability"},"assumptions":[]}"#,
        r#"{"id":"C.unc2","kind":"formal","statement":"uncertainty omitted","expression":{"op":"atom","id":"L3"},"scope":{"limitation":"uncertainty"},"assumptions":[]}"#,
        r#"{"id":"C.S","kind":"conditional","statement":"aggregate dossier","expression":{"op":"and","items":[{"op":"atom","id":"L1"},{"op":"atom","id":"L2"},{"op":"atom","id":"L3"}]},"scope":{},"assumptions":["C.unc","C.trp","C.unc2"]}"#,
    ];
    let arguments = [
        r#"{"id":"A.S","conclusion":"C.S","premises":["C.unc","C.trp","C.unc2"],"rule":"AND_INTRO","evidence_specs":[]}"#,
    ];
    let report = check(&load(&kernel(&claims.join(","), &arguments.join(","), "")));
    assert_eq!(report.decision, Decision::StructurallyValid, "{report:?}");
    assert!(!report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_mismatch"));

    // A `limitation` the both sides carry must match exactly; a revalue
    // is a scope_mismatch, not an aggregate tag.
    let report = check(&load(&conditional_application(
        r#"{"limitation":"unmeasured_confounding"}"#,
        r#"{"limitation":"transportability"}"#,
    )));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_mismatch" && item.detail.contains("`limitation`")));
}

#[test]
fn aggregation_keys_absent_in_premise_are_errors() {
    let report = check(&load(&conditional_application(
        r#"{"domain":"finite"}"#,
        r#"{"domain":"finite","claim_class":"counterfactual"}"#,
    )));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_mismatch" && item.detail.contains("`claim_class`")));
}

#[test]
fn lattice_comparison_normalizes_case_and_whitespace() {
    let report = check(&load(&conditional_application(
        r#"{"domain":" Finite "}"#,
        r#"{"domain":"finite"}"#,
    )));
    assert_eq!(report.decision, Decision::StructurallyValid);
    // Off-lattice values compare byte-exactly.
    let report = check(&load(&conditional_application(
        r#"{"domain":"Finite Group"}"#,
        r#"{"domain":"finite group"}"#,
    )));
    assert_eq!(report.decision, Decision::Rejected);
    // Case-only lattice difference under modus ponens is fine.
    let report = check(&load(&kernel(
        &formal_claim("C.P", "P", r#"{"domain":"FINITE"}"#),
        r#"{"id":"A.x","conclusion":"C.P","premises":[],"rule":"LEAN_ANCHOR","evidence_specs":[]}"#,
        "",
    )));
    assert!(!report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_mismatch"));
}

fn mp_claim(id: &str, expression: &str) -> String {
    format!(
        r#"{{"id":"{id}","kind":"formal","statement":"s","expression":{expression},"scope":{{"domain":"finite"}},"assumptions":[]}}"#
    )
}

fn mutual_mp_kernel() -> String {
    let claims = [
        mp_claim("C.a", r#"{"op":"atom","id":"A"}"#),
        mp_claim(
            "C.ab",
            r#"{"op":"implies","antecedent":{"op":"atom","id":"A"},"consequent":{"op":"atom","id":"B"}}"#,
        ),
        mp_claim("C.b", r#"{"op":"atom","id":"B"}"#),
        mp_claim(
            "C.ba",
            r#"{"op":"implies","antecedent":{"op":"atom","id":"B"},"consequent":{"op":"atom","id":"A"}}"#,
        ),
    ];
    let arguments = [
        r#"{"id":"A.ab","conclusion":"C.b","premises":["C.a","C.ab"],"rule":"MODUS_PONENS","evidence_specs":[]}"#.to_string(),
        r#"{"id":"A.ba","conclusion":"C.a","premises":["C.b","C.ba"],"rule":"MODUS_PONENS","evidence_specs":[]}"#.to_string(),
    ];
    kernel(&claims.join(","), &arguments.join(","), "")
}

#[test]
fn mutual_modus_ponens_is_a_support_cycle_and_is_rejected() {
    let report = check(&load(&mutual_mp_kernel()));
    assert_eq!(report.decision, Decision::Rejected);
    let support: Vec<&argument_audit::Diagnostic> = report
        .diagnostics
        .iter()
        .filter(|item| item.code == "support_cycle")
        .collect();
    assert_eq!(support.len(), 2, "both mutual derivations must be flagged");
    assert_eq!(report.arguments[0].structure, StatusAxis::Invalid);
    assert_eq!(report.arguments[1].structure, StatusAxis::Invalid);
}

#[test]
fn an_acyclic_alternative_derivation_survives_a_support_cycle() {
    let claims = [
        mp_claim("C.a", r#"{"op":"atom","id":"A"}"#),
        mp_claim(
            "C.ab",
            r#"{"op":"implies","antecedent":{"op":"atom","id":"A"},"consequent":{"op":"atom","id":"B"}}"#,
        ),
        mp_claim("C.b", r#"{"op":"atom","id":"B"}"#),
        mp_claim(
            "C.ba",
            r#"{"op":"implies","antecedent":{"op":"atom","id":"B"},"consequent":{"op":"atom","id":"A"}}"#,
        ),
        mp_claim("C.d", r#"{"op":"atom","id":"D"}"#),
        mp_claim(
            "C.db",
            r#"{"op":"implies","antecedent":{"op":"atom","id":"D"},"consequent":{"op":"atom","id":"B"}}"#,
        ),
    ];
    let arguments = [
        r#"{"id":"A.ab","conclusion":"C.b","premises":["C.a","C.ab"],"rule":"MODUS_PONENS","evidence_specs":[]}"#,
        r#"{"id":"A.ba","conclusion":"C.a","premises":["C.b","C.ba"],"rule":"MODUS_PONENS","evidence_specs":[]}"#,
        r#"{"id":"A.alt","conclusion":"C.b","premises":["C.d","C.db"],"rule":"MODUS_PONENS","evidence_specs":[]}"#,
    ];
    let report = check(&load(&kernel(&claims.join(","), &arguments.join(","), "")));
    assert_eq!(report.decision, Decision::Rejected);
    let alt = report
        .arguments
        .iter()
        .find(|item| item.id == "A.alt")
        .expect("alt");
    assert_eq!(alt.structure, StatusAxis::Valid);
    let claim = report
        .claims
        .iter()
        .find(|item| item.id == "C.b")
        .expect("C.b");
    assert_eq!(claim.structure, StatusAxis::Valid);
}

#[test]
fn three_hop_mutual_derivation_is_a_support_cycle() {
    // Identical expressions and scopes, so alias-exact passes locally; only
    // the cross-argument support cycle can reject this kernel.
    let atom = r#"{"op":"atom","id":"P"}"#;
    let claims = [
        mp_claim("C.x", atom),
        mp_claim("C.y", atom),
        mp_claim("C.z", atom),
    ];
    let arguments = [
        r#"{"id":"A.z","conclusion":"C.z","premises":["C.y"],"rule":"ALIAS_EXACT","evidence_specs":[]}"#,
        r#"{"id":"A.x","conclusion":"C.x","premises":["C.z"],"rule":"ALIAS_EXACT","evidence_specs":[]}"#,
        r#"{"id":"A.y","conclusion":"C.y","premises":["C.x"],"rule":"ALIAS_EXACT","evidence_specs":[]}"#,
    ];
    let report = check(&load(&kernel(&claims.join(","), &arguments.join(","), "")));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .arguments
        .iter()
        .all(|item| item.diagnostic_codes.contains(&"support_cycle".to_string())));
    assert!(report
        .arguments
        .iter()
        .all(|item| item.diagnostic_codes == vec!["support_cycle".to_string()]));
}

#[test]
fn factual_claims_accumulate_a_pending_axis() {
    let body = kernel(
        &[
            r#"{"id":"C.note","kind":"factual","statement":"a recorded note","expression":{"op":"atom","id":"N"},"scope":{},"assumptions":[]}"#,
            r#"{"id":"C.proof","kind":"formal","statement":"a formal statement","expression":{"op":"atom","id":"F"},"scope":{},"assumptions":[]}"#,
        ]
        .join(","),
        "",
        "",
    );
    let report = check(&load(&body));
    assert_eq!(report.claim_pending_axes, 2);
    assert_eq!(report.argument_obligations, 0);
    assert_eq!(report.pending_count, 2);
    let factual = report
        .claims
        .iter()
        .find(|item| item.id == "C.note")
        .expect("factual");
    assert_eq!(factual.empirical, StatusAxis::Pending);
    assert_eq!(factual.formal, StatusAxis::NotApplicable);
    assert_ne!(factual.empirical, StatusAxis::NotApplicable);
    assert!(!report.claim_supported);
}

#[test]
fn mixed_dossier_text_names_any_mixed_kinds() {
    let claims = [
        r#"{"id":"C.formal","kind":"formal","statement":"f","expression":{"op":"atom","id":"F"},"scope":{"domain":"d"},"assumptions":[]}"#,
        r#"{"id":"C.emp","kind":"empirical","statement":"e","expression":{"op":"atom","id":"E"},"scope":{"domain":"d"},"assumptions":[]}"#,
        r#"{"id":"C.both","kind":"conditional","statement":"b","expression":{"op":"and","items":[{"op":"atom","id":"F"},{"op":"atom","id":"E"}]},"scope":{"domain":"d"},"assumptions":[]}"#,
    ];
    let arguments = [
        r#"{"id":"A.mix","conclusion":"C.both","premises":["C.formal","C.emp"],"rule":"AND_INTRO","evidence_specs":[]}"#,
    ];
    let report = check(&load(&kernel(&claims.join(","), &arguments.join(","), "")));
    let finding = report
        .arguments
        .iter()
        .find(|item| item.id == "A.mix")
        .expect("finding");
    let dossier = finding
        .obligations
        .iter()
        .find(|item| item.starts_with("MIXED_DOSSIER"))
        .expect("mixed dossier obligation");
    assert!(
        dossier.contains("mixed claim kinds (empirical, formal)"),
        "{dossier}"
    );
}

#[test]
fn admission_reports_byte_level_staleness_with_stable_reasons() {
    let kernel = load(&kernel(
        &formal_claim("C.P", "P", "{}"),
        "",
        r#"{"id":"E.x","kind":"python","claim_id":"C.P","runner_id":"r","target":"synthetic:x","scope":{},"availability":"pending"}"#,
    ));
    let spec = kernel.evidence_specs[0].clone();
    let hash = "cd".repeat(32);
    let body = receipt_body(true, "2026-11-04T00:00:00Z", "2026-11-04T00:00:01Z", "[]")
        .replace(&"ab".repeat(32), &hash);
    let receipt = Receipt::load(body.as_bytes()).expect("receipt loads");

    // Stale spec: the hash the receipt carries is not the current spec hash.
    let wrong_hash = "ee".repeat(32);
    let clean = ByteVerification::default();
    let admission = admit_receipt(&receipt, &spec, &wrong_hash, &clean, &clean);
    assert_eq!(admission.reason, "spec_hash_mismatch");
    assert!(!admission.spec_hash_matches);

    // Registered input changed: stable reason input_target_stale.
    let stale = ByteVerification {
        checked: 1,
        matched: 0,
        missing: 0,
        mismatched: 1,
        rejected: 0,
    };
    let admission = admit_receipt(&receipt, &spec, &hash, &stale, &clean);
    assert_eq!(admission.reason, "input_target_stale");
    assert_eq!(admission.input_hashes.mismatched, 1);

    // Registered input is gone: stable reason input_target_missing.
    let missing = ByteVerification {
        checked: 1,
        matched: 0,
        missing: 1,
        mismatched: 0,
        rejected: 0,
    };
    let admission = admit_receipt(&receipt, &spec, &hash, &missing, &clean);
    assert_eq!(admission.reason, "input_target_missing");

    // A registered target that is a symlink or an escape is rejected.
    let rejected = ByteVerification {
        checked: 1,
        matched: 0,
        missing: 0,
        mismatched: 0,
        rejected: 1,
    };
    let admission = admit_receipt(&receipt, &spec, &hash, &rejected, &clean);
    assert_eq!(admission.reason, "input_target_rejected");

    // Artifact drift is reported as artifact_stale.
    let stale_artifact = ByteVerification {
        checked: 1,
        matched: 0,
        missing: 0,
        mismatched: 1,
        rejected: 0,
    };
    let admission = admit_receipt(&receipt, &spec, &hash, &clean, &stale_artifact);
    assert_eq!(admission.reason, "artifact_stale");

    // The honest terminal state: everything coherent, still no witness.
    let admission = admit_receipt(&receipt, &spec, &hash, &clean, &clean);
    assert_eq!(admission.reason, "replay_not_witnessed");
    assert!(admission.targets_verified);
    assert!(!admission.claim_supported);
    assert!(!admission.replay_witnessed);
}

#[test]
fn the_pinned_corpus_loads_and_its_registry_is_enforced() {
    let path = std::path::Path::new(env!("CARGO_MANIFEST_DIR")).join("../../corpus/causal_ml.json");
    let bytes = std::fs::read(&path).expect("read pinned corpus");
    let kernel = Kernel::load(&bytes).expect("pinned corpus must load with its atom registry");
    let registry = kernel.atoms.as_ref().expect("corpus carries atoms");
    assert_eq!(registry.len(), 49);
    for entry in registry.values() {
        assert!(kernel
            .claims
            .iter()
            .any(|claim| claim.id == entry.definition_claim));
    }

    let mut value: serde_json::Value = serde_json::from_slice(&bytes).expect("corpus json");
    let atoms = value["atoms"].as_array_mut().expect("atoms array");
    atoms.remove(0);
    let rendered = serde_json::to_string(&value).expect("render");
    let error = Kernel::load_str(&rendered).expect_err("a used, unregistered atom must fail");
    assert!(matches!(error, ContractError::AtomNotRegistered { .. }));
}

#[test]
fn registered_evidence_requires_schema_1_1() {
    let body = r#"{
        "schema_version":"1.0",
        "claims":[],
        "arguments":[],
        "evidence_specs":[{"id":"E.x","kind":"registered","claim_id":"C.P","runner_id":"r","target":"synthetic:x","scope":{},"availability":"pending"}]
    }"#;
    assert!(matches!(
        Kernel::load_str(body),
        Err(ContractError::Invalid(_))
    ));
}

#[test]
fn duplicate_premises_and_argv_are_rejected() {
    let body = kernel(
        &formal_claim("C.P", "P", "{}"),
        r#"{"id":"A.x","conclusion":"C.P","premises":["C.P","C.P"],"rule":"ALIAS_EXACT","evidence_specs":[]}"#,
        "",
    );
    assert!(Kernel::load_str(&body).is_err());

    let argv = r#"{
        "schema_version":"1.0","id":"R.a","spec_id":"E.x","spec_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "source_commit":"local","environment_hash":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "checker_version":"0.1.0","command_argv":[],"working_directory":".",
        "input_hashes":{},"started_at":"2026-11-04T00:00:00Z","finished_at":"2026-11-04T00:00:01Z",
        "exit_status":0,"termination":"completed",
        "stdout_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "stderr_sha256":"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
        "artifacts":[],"execution_passed":true,"scientific_criterion_met":null,
        "observed_checks":[],"trust_mode":"locally_reproduced"
    }"#;
    assert!(Receipt::load(argv.as_bytes()).is_err());
}

#[test]
fn admission_reason_strings_are_stable() {
    assert_eq!(
        argument_audit::REASON_RECEIPT_INCONSISTENT,
        "receipt_inconsistent"
    );
    assert_eq!(
        argument_audit::REASON_SPEC_HASH_MISMATCH,
        "spec_hash_mismatch"
    );
    assert_eq!(
        argument_audit::REASON_INPUT_TARGET_MISSING,
        "input_target_missing"
    );
    assert_eq!(
        argument_audit::REASON_INPUT_TARGET_STALE,
        "input_target_stale"
    );
    assert_eq!(
        argument_audit::REASON_INPUT_TARGET_REJECTED,
        "input_target_rejected"
    );
    assert_eq!(argument_audit::REASON_ARTIFACT_MISSING, "artifact_missing");
    assert_eq!(argument_audit::REASON_ARTIFACT_STALE, "artifact_stale");
    assert_eq!(
        argument_audit::REASON_ARTIFACT_REJECTED,
        "artifact_rejected"
    );
    assert_eq!(argument_audit::REASON_UNTRUSTED_IMPORT, "untrusted_import");
    assert_eq!(
        argument_audit::REASON_ATTESTATION_NOT_CONFIGURED,
        "attestation_policy_not_configured"
    );
    assert_eq!(
        argument_audit::REASON_EXECUTION_NOT_PASSED,
        "execution_not_passed"
    );
    assert_eq!(
        argument_audit::REASON_REPLAY_NOT_WITNESSED,
        "replay_not_witnessed"
    );
}

#[test]
fn collections_over_limit_are_rejected() {
    let claims: Vec<String> = (0..(MAX_COLLECTION + 1))
        .map(|index| formal_claim(&format!("C.{index}"), &format!("A{index}"), "{}"))
        .collect();
    let body = kernel(&claims.join(","), "", "");
    assert!(matches!(
        Kernel::load_str(&body),
        Err(ContractError::CollectionTooLarge { what: "claims", .. })
    ));
}
