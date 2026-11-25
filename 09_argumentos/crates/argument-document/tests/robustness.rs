//! Adversarial loading tests for the argument kernel.
//!
//! Every document here is hostile in a small, specific way: duplicate keys,
//! escape tricks, malformed numbers, path escapes, impossible receipts.
//! The contract must reject them for the right reason, not crash, and must
//! never report a structural verdict on a document it did not accept.

use argument_document::{canonical_kernel, evidence_spec_sha256, ContractError, Kernel, Receipt};

const V11_HEAD: &str = r#"{"schema_version":"1.1","profile":"structural","corpus":{"id":"lab","kind":"specification"},"claims":["#;
const V11_TAIL: &str = r#"],"arguments":[],"evidence_specs":[]}"#;

fn kernel_with_claim(claim: &str) -> String {
    format!("{V11_HEAD}{claim}{V11_TAIL}")
}

fn valid_claim(id: &str) -> String {
    format!(
        r#"{{"id":"{id}","kind":"factual","statement":"S of {id}.","expression":{{"op":"atom","id":"ATOM"}},"scope":{{"domain":"finite"}},"assumptions":[]}}"#
    )
}

fn claim_with_assumptions(id: &str, assumptions: &[&str]) -> String {
    let list = assumptions
        .iter()
        .map(|item| format!(r#""{item}""#))
        .collect::<Vec<_>>()
        .join(",");
    valid_claim(id).replacen(
        r#""assumptions":[]"#,
        &format!(r#""assumptions":[{list}]"#),
        1,
    )
}

fn receipt_body() -> String {
    let hash = "ab".repeat(32);
    format!(
        r#"{{
          "schema_version":"1.0",
          "id":"R.x",
          "spec_id":"E.x",
          "spec_hash":"{hash}",
          "source_commit":"local",
          "environment_hash":"{hash}",
          "checker_version":"0.1.0",
          "command_argv":["argument-audit","check"],
          "working_directory":".",
          "input_hashes":{{}},
          "started_at":"2026-11-04T00:00:00Z",
          "finished_at":"2026-11-04T00:00:01Z",
          "exit_status":0,
          "termination":"completed",
          "stdout_sha256":"{hash}",
          "stderr_sha256":"{hash}",
          "artifacts":[],
          "execution_passed":false,
          "scientific_criterion_met":null,
          "observed_checks":[],
          "trust_mode":"untrusted_import"
        }}"#
    )
}

#[test]
fn duplicate_keys_in_nested_objects_are_rejected() {
    let body = kernel_with_claim(&valid_claim("C.dup")).replacen(
        r#""corpus":{"id":"lab","kind":"specification"}"#,
        r#""corpus":{"id":"lab","id":"other","kind":"specification"}"#,
        1,
    );
    let err = Kernel::load_str(&body).unwrap_err();
    assert!(matches!(&err, ContractError::DuplicateKey { .. }), "{err}");
}

#[test]
fn escape_equivalent_duplicate_keys_are_rejected() {
    // "\u0069d" decodes to "id"; the duplicate must be caught after decoding.
    let body = kernel_with_claim(&valid_claim("C.dup")).replacen(
        r#""corpus":{"id":"lab","kind":"specification"}"#,
        r#""corpus":{"id":"lab","\u0069d":"lab","kind":"specification"}"#,
        1,
    );
    let err = Kernel::load_str(&body).unwrap_err();
    match err {
        ContractError::DuplicateKey { key, .. } => assert_eq!(key, "id"),
        other => panic!("expected duplicate key, got {other}"),
    }
}

#[test]
fn trailing_data_after_the_document_is_rejected() {
    let body = kernel_with_claim(&valid_claim("C.tail"));
    let err = Kernel::load_str(&format!("{body} {{}}")).unwrap_err();
    assert!(matches!(&err, ContractError::Json(_)), "{err}");
}

#[test]
fn leading_zero_numbers_are_rejected() {
    let body = receipt_body().replacen(r#""exit_status":0"#, r#""exit_status":01"#, 1);
    let err = Receipt::load(body.as_bytes()).unwrap_err();
    match err {
        ContractError::Json(message) => assert!(message.contains("leading zeros"), "{message}"),
        other => panic!("expected a JSON grammar error, got {other}"),
    }
}

#[test]
fn lone_utf16_surrogate_escapes_are_rejected() {
    let claim = valid_claim("C.sur").replacen("S of C.sur.", "S \\uD800 of C.sur.", 1);
    let err = Kernel::load_str(&kernel_with_claim(&claim)).unwrap_err();
    assert!(matches!(&err, ContractError::Json(_)), "{err}");

    let claim = valid_claim("C.sur2").replacen("S of C.sur2.", "S \\uD83D of C.sur2.", 1);
    let err = Kernel::load_str(&kernel_with_claim(&claim)).unwrap_err();
    assert!(matches!(&err, ContractError::Json(_)), "{err}");
}

#[test]
fn a_valid_surrogate_pair_loads() {
    let claim = valid_claim("C.joy").replacen("S of C.joy.", "smile \\uD83D\\uDE00 done", 1);
    let kernel = Kernel::load_str(&kernel_with_claim(&claim)).expect("valid pair loads");
    assert_eq!(kernel.claims[0].statement, "smile 😀 done");
}

#[test]
fn raw_control_characters_in_strings_are_rejected() {
    let claim = valid_claim("C.ctrl").replacen("S of C.ctrl.", "first\nsecond", 1);
    let err = Kernel::load_str(&kernel_with_claim(&claim)).unwrap_err();
    assert!(matches!(&err, ContractError::Json(_)), "{err}");
}

#[test]
fn whitespace_only_statements_are_rejected() {
    let claim = valid_claim("C.ws").replacen("S of C.ws.", "   ", 1);
    let err = Kernel::load_str(&kernel_with_claim(&claim)).unwrap_err();
    assert!(
        matches!(&err, ContractError::EmptyStatement(id) if id.as_str() == "C.ws"),
        "{err}"
    );
}

#[test]
fn empty_scope_keys_and_control_characters_are_rejected() {
    let claim = valid_claim("C.sk").replacen(
        r#""scope":{"domain":"finite"}"#,
        r#""scope":{"":"finite"}"#,
        1,
    );
    let err = Kernel::load_str(&kernel_with_claim(&claim)).unwrap_err();
    assert!(matches!(&err, ContractError::Invalid(_)), "{err}");

    // The \n escape decodes to a control character in the value.
    let claim = valid_claim("C.sv").replacen(
        r#""scope":{"domain":"finite"}"#,
        r#""scope":{"domain":"fin\nite"}"#,
        1,
    );
    let err = Kernel::load_str(&kernel_with_claim(&claim)).unwrap_err();
    assert!(matches!(&err, ContractError::Invalid(_)), "{err}");
}

#[test]
fn and_expressions_need_two_items() {
    let claim = valid_claim("C.and1").replacen(
        r#"{"op":"atom","id":"ATOM"}"#,
        r#"{"op":"and","items":[{"op":"atom","id":"ONLY"}]}"#,
        1,
    );
    let err = Kernel::load_str(&kernel_with_claim(&claim)).unwrap_err();
    assert!(
        matches!(&err, ContractError::AndArity(id) if id.as_str() == "C.and1"),
        "{err}"
    );
}

#[test]
fn claim_argument_and_evidence_share_one_identifier_namespace() {
    let claim = valid_claim("C.shared");
    let body = kernel_with_claim(&claim).replacen(
        r#""arguments":[]"#,
        r#""arguments":[{"id":"C.shared","conclusion":"C.shared","premises":[],"rule":"ALIAS_EXACT","evidence_specs":[]}]"#,
        1,
    );
    let err = Kernel::load_str(&body).unwrap_err();
    assert!(
        matches!(&err, ContractError::DuplicateId(id) if id.as_str() == "C.shared"),
        "{err}"
    );
}

#[test]
fn evidence_ids_must_not_alias_a_claim_id() {
    let body = kernel_with_claim(&valid_claim("C.one")).replacen(
        r#""evidence_specs":[]"#,
        r#""evidence_specs":[{"id":"C.one","kind":"lean","claim_id":"C.one","runner_id":"runner.one","target":"proofs/one.lean","scope":{"domain":"finite"},"availability":"pending"}]"#,
        1,
    );
    let err = Kernel::load_str(&body).unwrap_err();
    assert!(
        matches!(&err, ContractError::DuplicateId(id) if id.as_str() == "C.one"),
        "{err}"
    );
}

#[test]
fn duplicate_premises_are_rejected() {
    let body = kernel_with_claim(&valid_claim("C.a")).replacen(
        r#""arguments":[]"#,
        r#""arguments":[{"id":"A.a","conclusion":"C.a","premises":["C.a","C.a"],"rule":"ALIAS_EXACT","evidence_specs":[]}]"#,
        1,
    );
    let err = Kernel::load_str(&body).unwrap_err();
    assert!(
        matches!(&err, ContractError::Invalid(message) if message.contains("duplicate premise")),
        "{err}"
    );
}

#[test]
fn unresolvable_assumption_loads_and_stays_visible_to_the_checker() {
    let claim = claim_with_assumptions("C.dangling", &["C.nowhere"]);
    let kernel = Kernel::load_str(&kernel_with_claim(&claim)).expect("the document loads");
    assert_eq!(kernel.claims[0].assumptions, vec!["C.nowhere".to_string()]);
}

#[test]
fn evidence_targets_must_not_escape_the_repository() {
    // Note: the target is JSON-decoded first, so a literal backslash must
    // be written escaped in the document.
    for target in ["../secret.lean", "/etc/passwd", "results\\\\run.txt"] {
        let body = kernel_with_claim(&valid_claim("C.t")).replacen(
            r#""evidence_specs":[]"#,
            &format!(
                r#""evidence_specs":[{{"id":"E.t","kind":"lean","claim_id":"C.t","runner_id":"runner.one","target":"{target}","scope":{{"domain":"finite"}},"availability":"pending"}}]"#
            ),
            1,
        );
        let err = Kernel::load_str(&body).unwrap_err();
        assert!(
            matches!(&err, ContractError::Invalid(message) if message.contains("escapes")),
            "{target}: {err}"
        );
    }

    let body = kernel_with_claim(&valid_claim("C.t2")).replacen(
        r#""evidence_specs":[]"#,
        r#""evidence_specs":[{"id":"E.t2","kind":"lean","claim_id":"C.t2","runner_id":"runner.one","target":"proofs/ok.lean","scope":{"domain":"finite"},"availability":"pending"}]"#,
        1,
    );
    Kernel::load_str(&body).expect("a repository-relative target is fine");
}

#[test]
fn self_approval_spellings_are_all_rejected() {
    // Unknown fields whose names collide with a verdict must be rejected,
    // not ignored. The extra field is injected into the claim object.
    for extra in [
        r#""status":"approved","#,
        r#""claim_supported":true,"#,
        r#""structure":"valid","#,
        r#""decision":"accept","#,
        r#""verified":true,"#,
    ] {
        let claim = valid_claim("C.sa").replacen(
            r#"{"id":"C.sa","#,
            &format!(r#"{{"id":"C.sa",{extra}"#),
            1,
        );
        assert!(claim.contains(extra), "injection must keep {extra}");
        let err = Kernel::load_str(&kernel_with_claim(&claim)).unwrap_err();
        assert!(
            matches!(&err, ContractError::SelfApproval(_)),
            "{extra} -> {err}"
        );
    }
}

#[test]
fn v10_rejects_registered_and_v11_rejects_unknown_profiles_and_versions() {
    let v10 = r#"{"schema_version":"1.0","claims":[{"id":"C.a","book_key":null,"kind":"formal","statement":"s","expression":{"op":"atom","id":"A"},"scope":{"domain":"finite"},"assumptions":[]}],"arguments":[],"evidence_specs":[{"id":"E.a","kind":"registered","claim_id":"C.a","runner_id":"runner.one","target":"ok","scope":{"domain":"finite"},"availability":"candidate"}]}"#;
    let err = Kernel::load_str(v10).unwrap_err();
    assert!(
        matches!(&err, ContractError::Invalid(message) if message.contains("1.1")),
        "{err}"
    );

    let err = Kernel::load_str(
        r#"{"schema_version":"1.1","profile":"book","claims":[],"arguments":[],"evidence_specs":[]}"#,
    )
    .unwrap_err();
    assert!(matches!(&err, ContractError::Profile(_)), "{err}");

    let err = Kernel::load_str(
        r#"{"schema_version":"2.0","claims":[],"arguments":[],"evidence_specs":[]}"#,
    )
    .unwrap_err();
    assert!(matches!(&err, ContractError::SchemaVersion(_)), "{err}");

    let err = Kernel::load_str(
        r#"{"schema_version":"1.1","claims":[],"arguments":[],"evidence_specs":[],"extra":true}"#,
    )
    .unwrap_err();
    assert!(matches!(&err, ContractError::Json(_)), "{err}");
}

#[test]
fn ascii_only_ids_are_accepted_and_unicode_ids_are_rejected() {
    let kernel = Kernel::load_str(&kernel_with_claim(&valid_claim("A.B-C_D:E.F"))).expect("shape");
    assert_eq!(kernel.claims[0].id, "A.B-C_D:E.F");

    let err = Kernel::load_str(&kernel_with_claim(&valid_claim("café"))).unwrap_err();
    assert!(
        matches!(&err, ContractError::BadId(id) if id.as_str() == "café"),
        "{err}"
    );

    let err = Kernel::load_str(&kernel_with_claim(&valid_claim("1starts-with-digit"))).unwrap_err();
    assert!(matches!(&err, ContractError::BadId(_)), "{err}");

    let claim = valid_claim("C.at").replacen(r#""id":"ATOM""#, r#""id":"cafÉ_atom""#, 1);
    let err = Kernel::load_str(&kernel_with_claim(&claim)).unwrap_err();
    assert!(matches!(&err, ContractError::BadId(_)), "{err}");
}

#[test]
fn kernel_hash_ignores_set_like_order_but_not_content() {
    let first = Kernel::load_str(&kernel_with_claim(&claim_with_assumptions(
        "C.a",
        &["C.b", "C.c"],
    )))
    .expect("first");
    let second = Kernel::load_str(&kernel_with_claim(&claim_with_assumptions(
        "C.a",
        &["C.c", "C.b"],
    )))
    .expect("second");
    assert_eq!(
        first.content_sha256().expect("hash one"),
        second.content_sha256().expect("hash two"),
        "assumption order is part of the expression only through the sorted set"
    );

    let changed =
        kernel_with_claim(&valid_claim("C.a")).replacen("S of C.a.", "S of C.a, changed.", 1);
    let third = Kernel::load_str(&changed).expect("changed");
    assert_ne!(
        first.content_sha256().expect("hash one"),
        third.content_sha256().expect("hash three")
    );
}

#[test]
fn evidence_spec_hash_is_stable_and_sensitive_to_its_inputs() {
    let body = kernel_with_claim(&valid_claim("C.h")).replacen(
        r#""evidence_specs":[]"#,
        r#""evidence_specs":[{"id":"E.h","kind":"lean","claim_id":"C.h","runner_id":"runner.one","target":"proofs/h.lean","scope":{"domain":"finite"},"availability":"pending"}]"#,
        1,
    );
    let kernel = Kernel::load_str(&body).expect("hash kernel");
    let spec = &kernel.evidence_specs[0];
    let first = evidence_spec_sha256(spec).expect("spec hash");
    let second = evidence_spec_sha256(spec).expect("spec hash again");
    assert_eq!(first, second);
    assert_eq!(first.len(), 64);

    let changed = body.replacen("proofs/h.lean", "proofs/h2.lean", 1);
    let kernel_changed = Kernel::load_str(&changed).expect("changed spec");
    let third = evidence_spec_sha256(&kernel_changed.evidence_specs[0]).expect("changed hash");
    assert_ne!(first, third);
}

#[test]
fn receipt_contract_rejects_impossible_or_sloppy_runs() {
    let uppercase = receipt_body().replacen(r#""spec_hash":"abab"#, r#""spec_hash":"ABAB"#, 1);
    let err = Receipt::load(uppercase.as_bytes()).unwrap_err();
    assert!(
        matches!(&err, ContractError::Invalid(message) if message.contains("SHA-256")),
        "{err}"
    );

    let passed_with_timeout = receipt_body()
        .replacen(
            r#""execution_passed":false"#,
            r#""execution_passed":true"#,
            1,
        )
        .replacen(
            r#""termination":"completed""#,
            r#""termination":"timeout""#,
            1,
        );
    let err = Receipt::load(passed_with_timeout.as_bytes()).unwrap_err();
    assert!(
        matches!(&err, ContractError::Invalid(message) if message.contains("execution_passed")),
        "{err}"
    );

    let passed_with_nonzero = receipt_body()
        .replacen(
            r#""execution_passed":false"#,
            r#""execution_passed":true"#,
            1,
        )
        .replacen(r#""exit_status":0"#, r#""exit_status":1"#, 1);
    let err = Receipt::load(passed_with_nonzero.as_bytes()).unwrap_err();
    assert!(matches!(&err, ContractError::Invalid(_)), "{err}");

    let empty_argv = receipt_body().replacen(
        r#""command_argv":["argument-audit","check"]"#,
        r#""command_argv":[]"#,
        1,
    );
    let err = Receipt::load(empty_argv.as_bytes()).unwrap_err();
    assert!(matches!(&err, ContractError::Invalid(_)), "{err}");

    let empty_part = receipt_body().replacen(
        r#""command_argv":["argument-audit","check"]"#,
        r#""command_argv":["argument-audit",""]"#,
        1,
    );
    let err = Receipt::load(empty_part.as_bytes()).unwrap_err();
    assert!(matches!(&err, ContractError::Invalid(_)), "{err}");

    let receipts = Receipt::load_all(b"[]").expect("an empty array loads");
    assert!(receipts.is_empty());

    let err = Receipt::load_all(br#"{"schema_version":"1.0"}"#).unwrap_err();
    assert!(matches!(&err, ContractError::Invalid(_)), "{err}");
}

#[test]
fn top_level_values_must_be_objects() {
    for body in ["[]", r#""a string""#, "42", "null", "true"] {
        let err = Kernel::load_str(body).unwrap_err();
        assert!(matches!(&err, ContractError::NotObject), "{body} -> {err}");
    }
}

#[test]
fn canonical_form_is_byte_identical_across_loads_of_the_same_document() {
    let text = kernel_with_claim(&valid_claim("C.canon"));
    let first = Kernel::load_str(&text).expect("first");
    let second = Kernel::load_str(&text).expect("second");
    assert_eq!(
        canonical_kernel(&first).expect("canonical one"),
        canonical_kernel(&second).expect("canonical two")
    );
}
