//! Adversarial checker tests: cycles, scope games, runner mixups.
//!
//! The checker must never bless a cyclic or mixed dossier, and must fail
//! for the reason stated in the diagnostic, not incidentally.

use argument_audit::{check, Decision, Ratio, StatusAxis};
use argument_document::{Kernel, MAX_COLLECTION};

fn doc(claims: &str, arguments: &str, evidence: &str) -> String {
    format!(
        r#"{{"schema_version":"1.1","profile":"scientific_audit","claims":[{claims}],"arguments":[{arguments}],"evidence_specs":[{evidence}]}}"#
    )
}

fn formal_claim(id: &str, assumption: Option<&str>, expression: &str) -> String {
    let assumptions = assumption
        .map(|a| format!(r#"["{a}"]"#))
        .unwrap_or_else(|| "[]".to_string());
    format!(
        r#"{{"id":"{id}","kind":"formal","statement":"S of {id}.","expression":{expression},"scope":{{"domain":"finite"}},"assumptions":{assumptions}}}"#
    )
}

fn atom(id: &str) -> String {
    format!(r#"{{"op":"atom","id":"{id}"}}"#)
}

fn implies(antecedent: &str, consequent: &str) -> String {
    format!(r#"{{"op":"implies","antecedent":{antecedent},"consequent":{consequent}}}"#)
}

fn and(items: &[&str]) -> String {
    let inner = items.join(",");
    format!(r#"{{"op":"and","items":[{inner}]}}"#)
}

fn mp_argument(id: &str, conclusion: &str, premises: &str) -> String {
    format!(
        r#"{{"id":"{id}","conclusion":"{conclusion}","premises":[{premises}],"rule":"MODUS_PONENS","evidence_specs":[]}}"#
    )
}

#[test]
fn a_two_claim_assumption_cycle_is_rejected_and_marks_both_claims_invalid() {
    let claims = [
        formal_claim("C.a", Some("C.b"), &atom("A")),
        formal_claim("C.b", Some("C.a"), &atom("B")),
    ]
    .join(",");
    let report = check(&Kernel::load_str(&doc(&claims, "", "")).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    for claim in ["C.a", "C.b"] {
        let finding = report
            .claims
            .iter()
            .find(|item| item.id == claim)
            .expect("claim");
        assert_eq!(finding.structure, StatusAxis::Invalid, "{claim}");
    }
    let cycle_codes = report
        .diagnostics
        .iter()
        .filter(|item| item.code == "cycle")
        .count();
    assert!(cycle_codes >= 2, "{report:?}");
    assert!(!report.claim_supported);
}

#[test]
fn a_three_claim_assumption_cycle_flags_every_member() {
    let claims = [
        formal_claim("C.a", Some("C.c"), &atom("A")),
        formal_claim("C.b", Some("C.a"), &atom("B")),
        formal_claim("C.c", Some("C.b"), &atom("C")),
    ]
    .join(",");
    let report = check(&Kernel::load_str(&doc(&claims, "", "")).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    for claim in ["C.a", "C.b", "C.c"] {
        let finding = report
            .claims
            .iter()
            .find(|item| item.id == claim)
            .expect("claim");
        assert_eq!(finding.structure, StatusAxis::Invalid, "{claim}");
    }
}

#[test]
fn a_derivation_cycle_through_a_distant_assumption_is_rejected() {
    // C.p assumes C.r; C.r assumes C.q; an argument concludes C.q from C.p.
    // The assumption relation alone finds no cycle; the derivation does.
    let claims = [
        formal_claim("C.p", Some("C.r"), &atom("P")),
        formal_claim("C.r", Some("C.q"), &atom("R")),
        formal_claim("C.pq", None, &implies(&atom("P"), &atom("Q"))),
        formal_claim("C.q", None, &atom("Q")),
    ]
    .join(",");
    let arguments = mp_argument("A.q", "C.q", r#""C.p","C.pq""#);
    let report = check(&Kernel::load_str(&doc(&claims, &arguments, "")).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    let finding = report
        .arguments
        .iter()
        .find(|item| item.id == "A.q")
        .expect("argument");
    assert!(
        finding.diagnostic_codes.iter().any(|code| code == "cycle"),
        "{finding:?}"
    );
    assert!(!report.claim_supported);
}

#[test]
fn an_unknown_rule_is_rejected_rather_than_left_pending() {
    let claims = formal_claim("C.a", None, &atom("A"));
    let argument = r#"{"id":"A.x","conclusion":"C.a","premises":[],"rule":"FANTASY_RULE","evidence_specs":[]}"#;
    let report = check(&Kernel::load_str(&doc(&claims, argument, "")).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    let finding = report
        .arguments
        .iter()
        .find(|item| item.id == "A.x")
        .expect("argument");
    assert_eq!(finding.structure, StatusAxis::Invalid);
    assert!(finding
        .diagnostic_codes
        .iter()
        .any(|code| code == "unsupported_rule"));
}

#[test]
fn modus_ponens_accepts_either_premise_order() {
    let claims = [
        formal_claim("C.p", None, &atom("P")),
        formal_claim("C.pq", None, &implies(&atom("P"), &atom("Q"))),
        formal_claim("C.q", None, &atom("Q")),
    ]
    .join(",");
    for premises in [r#""C.p","C.pq""#, r#""C.pq","C.p""#] {
        let arguments = mp_argument("A.q", "C.q", premises);
        let report = check(&Kernel::load_str(&doc(&claims, &arguments, "")).expect("load"));
        assert_eq!(
            report.decision,
            Decision::StructurallyValid,
            "{premises}: {report:?}"
        );
    }
}

#[test]
fn modus_ponens_rejects_a_backwards_implication() {
    // Implies(Q, P) with premise P does not license Q.
    let claims = [
        formal_claim("C.p", None, &atom("P")),
        formal_claim("C.qp", None, &implies(&atom("Q"), &atom("P"))),
        formal_claim("C.q", None, &atom("Q")),
    ]
    .join(",");
    let arguments = mp_argument("A.q", "C.q", r#""C.p","C.qp""#);
    let report = check(&Kernel::load_str(&doc(&claims, &arguments, "")).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "mp_conclusion"));
}

#[test]
fn and_intro_records_mixed_kinds_as_an_obligation_not_a_verdict() {
    let claims = [
        formal_claim("C.f", None, &atom("F")),
        format!(
            r#"{{"id":"C.g","kind":"factual","statement":"S of C.g.","expression":{},"scope":{{"domain":"finite"}},"assumptions":[]}}"#,
            atom("G")
        ),
        format!(
            r#"{{"id":"C.both","kind":"formal","statement":"S of C.both.","expression":{},"scope":{{"domain":"finite"}},"assumptions":[]}}"#,
            and(&[&atom("F"), &atom("G")])
        ),
    ]
    .join(",");
    let argument = r#"{"id":"A.both","conclusion":"C.both","premises":["C.f","C.g"],"rule":"AND_INTRO","evidence_specs":[]}"#;
    let report = check(&Kernel::load_str(&doc(&claims, argument, "")).expect("load"));
    assert_eq!(report.decision, Decision::StructurallyValid, "{report:?}");
    let finding = report
        .arguments
        .iter()
        .find(|item| item.id == "A.both")
        .expect("argument");
    assert!(finding.mixed_dossier);
    assert!(finding
        .obligations
        .iter()
        .any(|item| item.starts_with("MIXED_DOSSIER")));
    assert!(!report.claim_supported);
}

#[test]
fn and_intro_rejects_the_conclusion_in_the_wrong_order() {
    let claims = [
        formal_claim("C.p", None, &atom("P")),
        formal_claim("C.q", None, &atom("Q")),
        formal_claim("C.qp", None, &and(&[&atom("Q"), &atom("P")])),
    ]
    .join(",");
    let argument = r#"{"id":"A.qp","conclusion":"C.qp","premises":["C.p","C.q"],"rule":"AND_INTRO","evidence_specs":[]}"#;
    let report = check(&Kernel::load_str(&doc(&claims, argument, "")).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "and_conclusion"));
}

#[test]
fn conditional_application_must_retain_every_premise_and_assumption() {
    let claims = [
        formal_claim("C.t", None, &atom("T")),
        format!(
            r#"{{"id":"C.h","kind":"conditional","statement":"H given T.","expression":{},"scope":{{"domain":"finite"}},"assumptions":["C.t"]}}"#,
            atom("H")
        ),
        format!(
            r#"{{"id":"C.s","kind":"conditional","statement":"S keeps T.","expression":{},"scope":{{"domain":"finite"}},"assumptions":["C.h"]}}"#,
            atom("S")
        ),
    ]
    .join(",");
    let argument = r#"{"id":"A.s","conclusion":"C.s","premises":["C.h"],"rule":"CONDITIONAL_APPLICATION","evidence_specs":[]}"#;
    let report = check(&Kernel::load_str(&doc(&claims, argument, "")).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "obligation_dropped"));

    // Keeping both obligations passes.
    let claims = [
        formal_claim("C.t", None, &atom("T")),
        format!(
            r#"{{"id":"C.h","kind":"conditional","statement":"H given T.","expression":{},"scope":{{"domain":"finite"}},"assumptions":["C.t"]}}"#,
            atom("H")
        ),
        format!(
            r#"{{"id":"C.s","kind":"conditional","statement":"S keeps both.","expression":{},"scope":{{"domain":"finite"}},"assumptions":["C.h","C.t"]}}"#,
            atom("S")
        ),
    ]
    .join(",");
    let report = check(&Kernel::load_str(&doc(&claims, argument, "")).expect("load"));
    assert_eq!(report.decision, Decision::StructurallyValid, "{report:?}");
}

#[test]
fn conditional_application_rejects_dropping_a_scope_key_and_finite_to_countable() {
    let premise = format!(
        r#"{{"id":"C.h","kind":"conditional","statement":"H.","expression":{},"scope":{{"domain":"finite","observations":"finite"}},"assumptions":[]}}"#,
        atom("H")
    );
    let conclusion = format!(
        r#"{{"id":"C.s","kind":"conditional","statement":"S.","expression":{},"scope":{{"domain":"countable"}},"assumptions":["C.h"]}}"#,
        atom("S")
    );
    let argument = r#"{"id":"A.s","conclusion":"C.s","premises":["C.h"],"rule":"CONDITIONAL_APPLICATION","evidence_specs":[]}"#;
    let report = check(
        &Kernel::load_str(&doc(&[premise, conclusion].join(","), argument, "")).expect("load"),
    );
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_widened"));
}

#[test]
fn an_empirical_record_does_not_accept_lean_evidence() {
    let claim = r#"{"id":"C.run","kind":"empirical","statement":"S of C.run.","expression":{"op":"atom","id":"RUN"},"scope":{"experiment":"batch-7"},"assumptions":[]}"#;
    let evidence = r#"{"id":"E.lean","kind":"lean","claim_id":"C.run","runner_id":"runner.one","target":"proofs/one.lean","scope":{"experiment":"batch-7"},"availability":"candidate"}"#;
    let argument = r#"{"id":"A.run","conclusion":"C.run","premises":[],"rule":"EMPIRICAL_RECORD","evidence_specs":["E.lean"]}"#;
    let report = check(&Kernel::load_str(&doc(claim, argument, evidence)).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "python_missing"));
}

#[test]
fn a_lean_anchor_does_not_accept_a_registered_runner() {
    let claim = formal_claim("C.one", None, &atom("ONE"));
    let evidence = r#"{"id":"E.reg","kind":"registered","claim_id":"C.one","runner_id":"runner.reg","target":"ok","scope":{"domain":"finite"},"availability":"candidate"}"#;
    let argument = r#"{"id":"A.one","conclusion":"C.one","premises":[],"rule":"LEAN_ANCHOR","evidence_specs":["E.reg"]}"#;
    let report = check(&Kernel::load_str(&doc(&claim, argument, evidence)).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "lean_missing"));
}

#[test]
fn evidence_for_a_different_claim_is_a_link_error_not_silence() {
    let claims = [
        formal_claim("C.one", None, &atom("ONE")),
        formal_claim("C.two", None, &atom("TWO")),
    ]
    .join(",");
    let evidence = r#"{"id":"E.two","kind":"lean","claim_id":"C.two","runner_id":"runner.one","target":"proofs/two.lean","scope":{"domain":"finite"},"availability":"pending"}"#;
    let argument = r#"{"id":"A.one","conclusion":"C.one","premises":[],"rule":"LEAN_ANCHOR","evidence_specs":["E.two"]}"#;
    let report = check(&Kernel::load_str(&doc(&claims, argument, evidence)).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "evidence_link"));
}

#[test]
fn evidence_scope_differing_from_claim_scope_is_a_contract_error() {
    let claim = r#"{"id":"C.one","kind":"formal","statement":"S of C.one.","expression":{"op":"atom","id":"ONE"},"scope":{"domain":"finite"},"assumptions":[]}"#;
    let evidence = r#"{"id":"E.one","kind":"lean","claim_id":"C.one","runner_id":"runner.one","target":"proofs/one.lean","scope":{"domain":"countable"},"availability":"pending"}"#;
    let report = check(&Kernel::load_str(&doc(claim, "", evidence)).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "evidence_scope"));
}

#[test]
fn a_claim_with_no_arguments_stays_pending_and_an_empty_document_is_pending() {
    let claim = formal_claim("C.quiet", None, &atom("QUIET"));
    let report = check(&Kernel::load_str(&doc(&claim, "", "")).expect("load"));
    assert_eq!(report.decision, Decision::Pending);
    assert_eq!(report.claims[0].structure, StatusAxis::Pending);

    let report = check(&Kernel::load_str(&doc("", "", "")).expect("load"));
    assert_eq!(report.decision, Decision::Pending);
    assert!(!report.claim_supported);
}

#[test]
fn alias_exact_requires_the_same_expression_and_scope() {
    let claims = [
        formal_claim("C.from", None, &atom("SAME")),
        formal_claim("C.to", None, &atom("SAME")),
        format!(
            r#"{{"id":"C.wide","kind":"formal","statement":"S of C.wide.","expression":{},"scope":{{"domain":"countable"}},"assumptions":[]}}"#,
            atom("SAME")
        ),
    ]
    .join(",");
    // Scope differences are reported before the rule runs (scope_mismatch).
    let argument = r#"{"id":"A.to","conclusion":"C.wide","premises":["C.from"],"rule":"ALIAS_EXACT","evidence_specs":[]}"#;
    let report = check(&Kernel::load_str(&doc(&claims, argument, "")).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "scope_mismatch"));

    // An expression difference with the same scope reaches alias_mismatch.
    let differing = [
        formal_claim("C.f", None, &atom("FIRST")),
        format!(
            r#"{{"id":"C.g","kind":"formal","statement":"S of C.g.","expression":{},"scope":{{"domain":"finite"}},"assumptions":[]}}"#,
            atom("SECOND")
        ),
    ]
    .join(",");
    let argument = r#"{"id":"A.g","conclusion":"C.g","premises":["C.f"],"rule":"ALIAS_EXACT","evidence_specs":[]}"#;
    let report = check(&Kernel::load_str(&doc(&differing, argument, "")).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "alias_mismatch"));

    let argument = r#"{"id":"A.to","conclusion":"C.to","premises":["C.from"],"rule":"ALIAS_EXACT","evidence_specs":[]}"#;
    let report = check(&Kernel::load_str(&doc(&claims, argument, "")).expect("load"));
    assert_eq!(report.decision, Decision::StructurallyValid, "{report:?}");
    let finding = report
        .arguments
        .iter()
        .find(|item| item.id == "A.to")
        .expect("argument");
    assert!(finding
        .obligations
        .iter()
        .any(|item| item.starts_with("SEMANTIC_MAPPING_UNRESOLVED")));
}

#[test]
fn conditional_claims_report_conditional_axes() {
    let claims = format!(
        r#"{{"id":"C.cond","kind":"conditional","statement":"S of C.cond.","expression":{},"scope":{{"domain":"finite"}},"assumptions":[]}}"#,
        atom("COND")
    );
    let report = check(&Kernel::load_str(&doc(&claims, "", "")).expect("load"));
    assert_eq!(report.claims[0].formal, StatusAxis::Conditional);
    assert_eq!(report.claims[0].empirical, StatusAxis::Conditional);
}

#[test]
fn evidence_target_that_is_not_a_claim_is_a_contract_error() {
    let claim = formal_claim("C.one", None, &atom("ONE"));
    let evidence = r#"{"id":"E.ghost","kind":"lean","claim_id":"C.ghost","runner_id":"runner.one","target":"proofs/ghost.lean","scope":{"domain":"finite"},"availability":"pending"}"#;
    let report = check(&Kernel::load_str(&doc(&claim, "", evidence)).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    assert!(report
        .diagnostics
        .iter()
        .any(|item| item.code == "evidence_target"));
}

#[test]
fn ratio_handles_zero_and_extreme_values_without_panicking() {
    let zero = Ratio::new(0, 7).expect("zero ratio");
    assert_eq!(zero.numer(), 0);
    assert_eq!(zero.denom(), 1);

    let negative_den = Ratio::new(3, -4).expect("normalized");
    assert_eq!(negative_den.numer(), -3);
    assert_eq!(negative_den.denom(), 4);

    let min = Ratio::new(i64::MIN, 1).expect("i64::MIN over one is representable");
    assert_eq!(min.numer(), i64::MIN);
    assert_eq!(min.denom(), 1);

    // 1/i64::MIN cannot be made positive in i64; it must not panic.
    assert_eq!(Ratio::new(1, i64::MIN), None);
    // i64::MIN / i64::MIN reduces to 1/1.
    let one = Ratio::new(i64::MIN, i64::MIN).expect("self ratio");
    assert_eq!((one.numer(), one.denom()), (1, 1));
    assert_eq!(Ratio::new(1, 0), None);
    assert_eq!(format!("{}", Ratio::new(2, 4).expect("half")), "1/2");
}

#[test]
fn a_deep_assumption_chain_does_not_overflow_the_stack() {
    // Keep the chain and its two extra claims below the loader's collection cap;
    // the argument at the end still walks every link in the chain.
    const N: usize = MAX_COLLECTION - 3;
    let mut claims = Vec::with_capacity(N);
    claims.push(formal_claim("C.n000000", None, &atom("A")));
    for index in 1..N {
        let id = format!("C.n{index:06}");
        let prev = format!("C.n{:06}", index - 1);
        claims.push(formal_claim(&id, Some(&prev), &atom("A")));
    }
    let last = format!("C.n{:06}", N - 1);
    let implied = formal_claim("C.pq", None, &implies(&atom("A"), &atom("B")));
    claims.push(implied);
    let conclusion = formal_claim("C.end", None, &atom("B"));
    claims.push(conclusion);
    let argument = mp_argument("A.end", "C.end", &format!(r#""{last}","C.pq""#));
    let report = check(&Kernel::load_str(&doc(&claims.join(","), &argument, "")).expect("load"));
    assert_eq!(report.decision, Decision::StructurallyValid, "{report:?}");
}

#[test]
fn a_deep_assumption_cycle_flags_every_member_without_recursion_overflow() {
    const N: usize = 5_000;
    let mut claims = Vec::with_capacity(N);
    for index in 0..N {
        let id = format!("C.m{index:06}");
        let next = format!("C.m{:06}", (index + 1) % N);
        claims.push(formal_claim(&id, Some(&next), &atom("A")));
    }
    let report = check(&Kernel::load_str(&doc(&claims.join(","), "", "")).expect("load"));
    assert_eq!(report.decision, Decision::Rejected);
    let cycle_claims = report
        .diagnostics
        .iter()
        .filter(|item| item.code == "cycle")
        .count();
    assert_eq!(cycle_claims, N, "every member of the ring must be flagged");
}

#[test]
fn audited_diagnostics_name_entities_and_next_steps() {
    // d1.2-ultra audit (see progress/d1-ultra-audit-2026-11-23.md): diagnostics
    // must name the offending entity and the next step, not just the mismatch.
    let kernel = Kernel::load_str(&doc(
        &formal_claim("C.a", None, &atom("A")),
        r#"{"id":"A.a","conclusion":"C.a","premises":["C.missing"],"rule":"ALIAS_EXACT","evidence_specs":[]}"#,
        "",
    ))
    .expect("load");
    let report = check(&kernel);
    let diagnostic = report
        .diagnostics
        .iter()
        .find(|item| item.code == "missing_premise")
        .expect("missing_premise diagnostic");
    assert!(
        diagnostic.detail.contains("C.missing"),
        "{}",
        diagnostic.detail
    );
    assert!(
        diagnostic.detail.contains("fix") || diagnostic.detail.contains("add"),
        "{}",
        diagnostic.detail
    );

    let evidence_doc = doc(
        &formal_claim("C.a", None, &atom("A")),
        "",
        r#"{"id":"E.x","kind":"lean","claim_id":"C.ghost","runner_id":"runner.one","target":"proofs/x.lean","scope":{"domain":"finite"},"availability":"pending"}"#,
    );
    let report = check(&Kernel::load_str(&evidence_doc).expect("load"));
    let diagnostic = report
        .diagnostics
        .iter()
        .find(|item| item.code == "evidence_target")
        .expect("evidence_target diagnostic");
    assert!(
        diagnostic.detail.contains("C.ghost"),
        "{}",
        diagnostic.detail
    );
    assert!(diagnostic.detail.contains("E.x"), "{}", diagnostic.detail);
}

#[test]
fn the_exact_synthetic_instance_remains_exact() {
    let instance = argument_audit::ssch_one_decision_exact_v1().expect("finite instance");
    assert_eq!(instance.risk0, Ratio::new(1, 5).expect("risk0"));
    assert_eq!(instance.risk1, Ratio::new(4, 5).expect("risk1"));
    assert_eq!(instance.bayes_risk, Ratio::new(19, 50).expect("bayes"));
    assert_eq!(instance.return0.numer(), -1);
    assert_eq!(instance.return1.numer(), -4);
}
