use argument_card::{
    check_quote, parse_card, project, render, review_card, review_prose, Language, Lexicon,
    Outcome, SpeakError,
};
use argument_document::Kernel;

fn kernel() -> Kernel {
    Kernel::load_str(
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
        }"#,
    )
    .expect("kernel")
}

fn lexicon(language: &str) -> Lexicon {
    let body = format!(
        r#"{{
          "schema_version":"1.0",
          "language":"{language}",
          "entries":[
            {{"id":"P","gloss":"the premise P"}},
            {{"id":"Q","gloss":"the conclusion Q"}}
          ]
        }}"#
    );
    Lexicon::load(body.as_bytes()).expect("lexicon")
}

#[test]
fn card_round_trips_the_formal_projection_in_both_languages() {
    let kernel = kernel();
    let formal = project(&kernel).expect("project");
    for language in [Language::En, Language::Es] {
        let reading = render(&kernel, &Lexicon::empty(language), language).expect("render");
        assert!(!reading.claim_supported);
        assert!(!reading.alignment_guaranteed);
        assert!(reading.glosses_pending.iter().any(|id| id == "P"));
        let parsed = parse_card(&reading.card).expect("parse");
        assert_eq!(parsed, formal);
    }
}

#[test]
fn an_exact_card_has_no_blocking_problem_and_is_not_endorsed() {
    let kernel = kernel();
    let reading = render(&kernel, &lexicon("en"), Language::En).expect("render");
    assert!(reading.glosses_pending.is_empty());
    let report = review_card(&kernel, &reading.card, &lexicon("en"), Language::En).expect("review");
    assert_eq!(report.outcome, Outcome::NoBlockingProblem);
    assert_eq!(report.endorsement, "not_endorsed");
    assert!(!report.claim_supported);
    assert!(!report.alignment_guaranteed);
    assert!(report.findings.is_empty());
}

#[test]
fn dropping_a_premise_is_a_blocking_problem_not_a_score() {
    let kernel = kernel();
    let reading = render(&kernel, &Lexicon::empty(Language::En), Language::En).expect("render");
    let edited = reading
        .card
        .replace("premises: C.P, C.PQ", "premises: C.PQ");
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
    assert!(!report.claim_supported);
    let encoded = serde_json::to_string(&report).expect("json");
    assert!(!encoded.contains("\"score\""));
}

#[test]
fn free_prose_stays_unresolved() {
    let kernel = kernel();
    let report = review_prose(
        &kernel,
        "The author says Q follows, without naming the premises.",
        &Lexicon::empty(Language::En),
    )
    .expect("prose");
    assert_eq!(report.outcome, Outcome::Unresolved);
    assert!(report
        .findings
        .iter()
        .any(|item| item.code == "unresolved_mapping"));
    assert!(!report.claim_supported);
    let err = parse_card("The author says Q follows.").unwrap_err();
    assert!(matches!(err, SpeakError::Card(_)));
}

#[test]
fn quote_offsets_are_utf8_bytes() {
    let source = "Premisa P. café";
    let quote = "café";
    let start = source.find(quote).expect("slice");
    check_quote(source, start, start + quote.len(), quote).expect("bytes");
    let scalar_start = source.chars().position(|ch| ch == 'c').expect("char");
    assert!(check_quote(
        source,
        scalar_start,
        scalar_start + quote.chars().count(),
        quote
    )
    .is_err());
}

#[test]
fn lexicon_rejects_an_approval_field() {
    let body = r#"{"schema_version":"1.0","language":"en","entries":[],"approved":true}"#;
    let err = Lexicon::load(body.as_bytes()).unwrap_err();
    assert!(matches!(err, SpeakError::Lexicon(_)));
}
