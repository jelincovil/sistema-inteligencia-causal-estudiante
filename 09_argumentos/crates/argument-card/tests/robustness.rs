//! Adversarial reading-layer tests.
//!
//! The card is a line-based format with a formal projection inside it.
//! These tests attack line endings, delimiter handling, nesting depth,
//! scope encoding, lexicon keys, and stale pins.

use argument_card::{
    check_quote, parse_card, render, review_card, review_prose, Language, Lexicon, Outcome,
    SpeakError,
};
use argument_document::{Kernel, LoadedArgument, Rule};

fn kernel_text() -> String {
    r#"{
      "schema_version":"1.1",
      "profile":"structural",
      "claims":[
        {"id":"C.P","kind":"formal","statement":"Premisa P.","expression":{"op":"atom","id":"P"},"scope":{"domain":"finite"},"assumptions":[]},
        {"id":"C.PQ","kind":"formal","statement":"Si P, entonces Q.","expression":{"op":"implies","antecedent":{"op":"atom","id":"P"},"consequent":{"op":"atom","id":"Q"}},"scope":{"domain":"finite"},"assumptions":[]},
        {"id":"C.Q","kind":"formal","statement":"Conclusión Q.","expression":{"op":"atom","id":"Q"},"scope":{"domain":"finite"},"assumptions":[]}
      ],
      "arguments":[{"id":"A.Q","conclusion":"C.Q","premises":["C.P","C.PQ"],"rule":"MODUS_PONENS","evidence_specs":[]}],
      "evidence_specs":[]
    }"#
    .to_string()
}

fn kernel() -> Kernel {
    Kernel::load_str(&kernel_text()).expect("kernel")
}

#[test]
fn a_crlf_card_parses_to_the_same_projection_as_lf() {
    let kernel = kernel();
    let reading = render(&kernel, &Lexicon::empty(Language::En), Language::En).expect("render");
    let crlf = reading.card.replace('\n', "\r\n");
    assert_eq!(
        parse_card(&reading.card).expect("lf parse"),
        parse_card(&crlf).expect("crlf parse")
    );
}

#[test]
fn crlf_does_not_disable_the_premise_coverage_check() {
    let kernel = kernel();
    let reading = render(&kernel, &Lexicon::empty(Language::En), Language::En).expect("render");
    let body_removed = reading
        .card
        .replace("Premises: C.P; C.PQ.", "Premises: unnamed.");
    assert_ne!(body_removed, reading.card);
    for text in [body_removed.clone(), body_removed.replace('\n', "\r\n")] {
        let report = review_card(&kernel, &text, &Lexicon::empty(Language::En), Language::En)
            .expect("review");
        assert!(
            report
                .findings
                .iter()
                .any(|item| item.code == "reading_omits_premise"),
            "{report:?}"
        );
    }
}

#[test]
fn an_open_claim_with_multiple_assumptions_round_trips() {
    let text = r#"{
      "schema_version":"1.1",
      "profile":"structural",
      "claims":[
        {"id":"C.A","kind":"factual","statement":"A.","expression":{"op":"atom","id":"A"},"scope":{"domain":"notes"},"assumptions":[]},
        {"id":"C.B","kind":"factual","statement":"B.","expression":{"op":"atom","id":"B"},"scope":{"domain":"notes"},"assumptions":[]},
        {"id":"C.open","kind":"factual","statement":"Open.","expression":{"op":"atom","id":"O"},"scope":{"domain":"notes"},"assumptions":["C.A","C.B"]}
      ],
      "arguments":[],
      "evidence_specs":[]
    }"#;
    let kernel = Kernel::load_str(text).expect("kernel");
    let formal = argument_card::project(&kernel).expect("project");
    let reading = render(&kernel, &Lexicon::empty(Language::En), Language::En).expect("render");
    assert!(
        reading.card.contains("assumptions=C.A, C.B"),
        "{}",
        reading.card
    );
    let parsed = parse_card(&reading.card).expect("the rendered card must parse");
    assert_eq!(parsed, formal);
    let report = review_card(
        &kernel,
        &reading.card,
        &Lexicon::empty(Language::En),
        Language::En,
    )
    .expect("review");
    assert_eq!(report.outcome, Outcome::NoBlockingProblem);
}

#[test]
fn deeply_nested_expressions_error_instead_of_overflowing() {
    let depth = 500;
    let mut expression = "atom:A".to_string();
    for _ in 0..depth {
        expression = format!("implies({expression}, atom:B)");
    }
    let card = format!(
        "argument-card 0.1.0\nlanguage: en\nkernel_sha256: deadbeef\nclaim_supported: false\nalignment_guaranteed: false\n\nargument: A.x\nconclusion: C.x\nkind: formal\nrule: MODUS_PONENS\nexpression: {expression}\npremises: -\nevidence: -\nscope: -\nassumptions: -\n",
    );
    let err = parse_card(&card).unwrap_err();
    assert!(matches!(&err, SpeakError::Card(_)), "{err}");
}

#[test]
fn card_expression_ids_follow_the_kernel_id_contract() {
    for expression in [
        "atom:1abc",
        "atom:foo!bar",
        "atom:cafÉ",
        "atom:",
        "atom:has space",
    ] {
        let card = format!(
            "argument-card 0.1.0\nlanguage: en\nkernel_sha256: deadbeef\n\nargument: A.x\nconclusion: C.x\nkind: formal\nrule: MODUS_PONENS\nexpression: {expression}\npremises: -\nevidence: -\nscope: -\nassumptions: -\n",
        );
        assert!(parse_card(&card).is_err(), "{expression} must not parse");
    }
    let card = "argument-card 0.1.0\nlanguage: en\nkernel_sha256: deadbeef\n\nargument: A.x\nconclusion: C.x\nkind: formal\nrule: MODUS_PONENS\nexpression: atom:A.B_C-1\npremises: -\nevidence: -\nscope: -\nassumptions: -\n";
    parse_card(card).expect("a well-shaped atom id parses");
}

#[test]
fn render_refuses_scope_values_that_break_the_line_format() {
    for (key, value) in [
        ("domain", "fin\nite"),
        ("domain", "a,b"),
        ("", "empty-key"),
        ("domain", "a=b"),
    ] {
        let mut base = kernel();
        let conclusion = base
            .claims
            .iter_mut()
            .find(|claim| claim.id == "C.Q")
            .expect("conclusion claim");
        conclusion.scope.insert(key.to_string(), value.to_string());
        let err = render(&base, &Lexicon::empty(Language::En), Language::En).unwrap_err();
        assert!(matches!(&err, SpeakError::Card(_)), "{key}={value}: {err}");
    }
}

#[test]
fn render_reports_every_unresolved_atom_id_in_the_expression() {
    let text = r#"{
      "schema_version":"1.1",
      "profile":"structural",
      "claims":[
        {"id":"C.and","kind":"factual","statement":"Conjunction.","expression":{"op":"and","items":[{"op":"atom","id":"ALPHA"},{"op":"implies","antecedent":{"op":"atom","id":"BETA"},"consequent":{"op":"atom","id":"ALPHA"}}]},"scope":{"domain":"notes"},"assumptions":[]}
      ],
      "arguments":[],
      "evidence_specs":[]
    }"#;
    // Add an argument concluding the conjunction; the reading layer only
    // collects atoms reachable from argument paragraphs.
    let text = text.replacen(
        r#""arguments":[],"#,
        r#""arguments":[{"id":"A.and","conclusion":"C.and","premises":[],"rule":"AND_INTRO","evidence_specs":[]}],"#,
        1,
    );
    let kernel = Kernel::load_str(&text).expect("kernel");
    let reading = render(&kernel, &Lexicon::empty(Language::En), Language::En).expect("render");
    assert_eq!(
        reading.glosses_pending,
        vec!["ALPHA".to_string(), "BETA".to_string()]
    );
}

#[test]
fn a_lexicon_with_duplicate_json_keys_is_rejected() {
    let duplicate = r#"{"schema_version":"1.0","language":"en","language":"es","entries":[]}"#;
    let err = Lexicon::load(duplicate.as_bytes()).unwrap_err();
    assert!(matches!(&err, SpeakError::Lexicon(_)), "{err}");

    let escape_equivalent =
        r#"{"schema_version":"1.0","language":"en","\u006canguage":"es","entries":[]}"#;
    let err = Lexicon::load(escape_equivalent.as_bytes()).unwrap_err();
    assert!(matches!(&err, SpeakError::Lexicon(_)), "{err}");
}

#[test]
fn a_stale_card_is_a_blocking_problem() {
    let kernel = kernel();
    let reading = render(&kernel, &Lexicon::empty(Language::En), Language::En).expect("render");
    let kernel_changed =
        Kernel::load_str(&kernel_text().replacen("Conclusión Q.", "Conclusión Q, reworded.", 1))
            .expect("changed kernel");
    let report = review_card(
        &kernel_changed,
        &reading.card,
        &Lexicon::empty(Language::En),
        Language::En,
    )
    .expect("review");
    assert_eq!(report.outcome, Outcome::BlockingProblem);
    assert!(report
        .findings
        .iter()
        .any(|item| item.code == "stale_reading" && item.blocking));
    assert!(!report.claim_supported);
}

#[test]
fn an_unclosed_reading_fence_is_a_card_error() {
    let kernel = kernel();
    let reading = render(&kernel, &Lexicon::empty(Language::En), Language::En).expect("render");
    let broken = reading.card.replace(">>>\n", "");
    assert_ne!(broken, reading.card);
    let err = parse_card(&broken).unwrap_err();
    assert!(matches!(&err, SpeakError::Card(_)), "{err}");
}

#[test]
fn a_header_only_card_is_not_a_card() {
    let err = parse_card("argument-card 0.1.0\nkernel_sha256: deadbeef\nclaim_supported: false\n")
        .unwrap_err();
    assert!(matches!(&err, SpeakError::Card(_)), "{err}");
}

#[test]
fn a_card_with_an_unknown_rule_is_a_blocking_problem() {
    let kernel = kernel();
    let reading = render(&kernel, &Lexicon::empty(Language::En), Language::En).expect("render");
    let edited = reading
        .card
        .replace("rule: MODUS_PONENS", "rule: FANTASY_RULE");
    let report = review_card(
        &kernel,
        &edited,
        &Lexicon::empty(Language::En),
        Language::En,
    )
    .expect("review");
    assert_eq!(report.outcome, Outcome::BlockingProblem);
    assert!(report
        .findings
        .iter()
        .any(|item| item.code == "changed_argument" && item.blocking));
}

#[test]
fn a_card_with_an_extra_argument_is_a_blocking_problem() {
    let kernel = kernel();
    let reading = render(&kernel, &Lexicon::empty(Language::En), Language::En).expect("render");
    let extra = "argument: A.extra\nconclusion: C.ghost\nkind: formal\nrule: MODUS_PONENS\nexpression: atom:GHOST\npremises: -\nevidence: -\nscope: domain=finite\nassumptions: -\nreading:\n<<<\nAn argument the kernel does not contain.\n>>>\n";
    let card = format!("{}{}", reading.card, extra);
    let report =
        review_card(&kernel, &card, &Lexicon::empty(Language::En), Language::En).expect("review");
    assert_eq!(report.outcome, Outcome::BlockingProblem);
    assert!(report
        .findings
        .iter()
        .any(|item| item.code == "unsupported_claim" && item.blocking));
}

#[test]
fn render_fails_cleanly_when_an_argument_points_at_a_missing_claim() {
    let mut kernel = kernel();
    kernel.arguments.push(LoadedArgument {
        id: "A.ghost".to_string(),
        conclusion: "C.ghost".to_string(),
        premises: vec![],
        rule: Rule::ModusPonens,
        evidence_specs: vec![],
    });
    let err = render(&kernel, &Lexicon::empty(Language::En), Language::En).unwrap_err();
    assert!(matches!(&err, SpeakError::Card(_)), "{err}");
}

#[test]
fn quote_checks_reject_reversed_and_out_of_bounds_ranges() {
    let source = "Premisa P.";
    assert!(check_quote(source, 5, 1, "false").is_err());
    assert!(check_quote(source, 0, source.len() + 1, "Premisa P.").is_err());
    assert!(check_quote(source, 1, 3, "rem").is_err());
}

#[test]
fn prose_that_names_the_premises_gets_no_absence_finding() {
    let kernel = kernel();
    let report = review_prose(
        &kernel,
        "The informal account names C.P and C.PQ before drawing the conclusion.",
        &Lexicon::empty(Language::En),
    )
    .expect("review");
    assert!(!report
        .findings
        .iter()
        .any(|item| item.code == "id_absent_from_prose"));
    assert!(report
        .findings
        .iter()
        .any(|item| item.code == "unresolved_mapping"));
    assert_eq!(report.outcome, Outcome::Unresolved);
}

#[test]
fn prose_that_omits_a_premise_gets_a_non_blocking_absence_finding() {
    let kernel = kernel();
    let report = review_prose(
        &kernel,
        "The informal account names C.P only.",
        &Lexicon::empty(Language::En),
    )
    .expect("review");
    assert!(report
        .findings
        .iter()
        .any(|item| item.code == "id_absent_from_prose" && item.subject == "C.PQ"));
    assert!(!report.claim_supported);
}

#[test]
fn an_authored_gloss_counts_as_a_mention_in_prose() {
    let body = r#"{"schema_version":"1.0","language":"en","entries":[{"id":"P","gloss":"the premise P"}]}"#;
    let lexicon = Lexicon::load(body.as_bytes()).expect("lexicon");
    let kernel = kernel();
    let report = review_prose(
        &kernel,
        "The informal account leans on the premise P throughout, without using the raw id.",
        &lexicon,
    )
    .expect("review");
    assert!(!report
        .findings
        .iter()
        .any(|item| item.code == "id_absent_from_prose" && item.subject == "C.P"));
}
