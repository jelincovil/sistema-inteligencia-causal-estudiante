use serde::Serialize;

use argument_document::Kernel;

use crate::error::SpeakError;
use crate::language::Language;
use crate::lexicon::Lexicon;
use crate::parse::parse_card;
use crate::render::{atoms, project, render, Projection};

/// What a reader is allowed to take from a wording review.
///
/// Palomar withholds scores because the same commit can score 5 and then 4.
/// This report has no score. `NoBlockingProblem` means the formal keys
/// matched. It does not mean the wording was endorsed.
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Outcome {
    NoBlockingProblem,
    BlockingProblem,
    Unresolved,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct Finding {
    pub code: String,
    pub blocking: bool,
    pub subject: String,
    pub detail: String,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct FidelityReport {
    pub outcome: Outcome,
    pub endorsement: &'static str,
    pub claim_supported: bool,
    pub alignment_guaranteed: bool,
    pub findings: Vec<Finding>,
    pub limits: &'static str,
}

pub fn review_card(
    kernel: &Kernel,
    card: &str,
    lexicon: &Lexicon,
    language: Language,
) -> Result<FidelityReport, SpeakError> {
    let formal = project(kernel)?;
    let parsed = parse_card(card)?;
    let mut findings = Vec::new();
    if parsed.kernel_sha256 != formal.kernel_sha256 {
        findings.push(finding(
            "stale_reading",
            true,
            &formal.kernel_sha256,
            "the card is pinned to a different kernel snapshot",
        ));
    }
    compare_projection(&formal, &parsed, &mut findings);
    compare_reading_coverage(kernel, &formal, card, lexicon, language, &mut findings)?;
    Ok(finish(findings))
}

pub fn review_prose(
    kernel: &Kernel,
    prose: &str,
    lexicon: &Lexicon,
) -> Result<FidelityReport, SpeakError> {
    if prose.trim().is_empty() {
        return Err(SpeakError::Card("informal account is empty".to_string()));
    }
    if prose.lines().any(|line| line.starts_with("argument: ")) {
        return Err(SpeakError::Card(
            "this text has argument keys; review it as a card, not as free prose".to_string(),
        ));
    }
    let mut findings = vec![finding(
        "unresolved_mapping",
        false,
        "prose",
        "free prose is an informal account; this review does not decide that it matches the kernel",
    )];
    let formal = project(kernel)?;
    for argument in &formal.arguments {
        for premise in &argument.premises {
            if !mentioned(prose, premise, kernel, lexicon) {
                findings.push(finding(
                    "id_absent_from_prose",
                    false,
                    premise,
                    "neither the premise id nor an authored gloss for its atom appears in the informal account; absence is not proof of concealment",
                ));
            }
        }
        for assumption in &argument.assumptions {
            if !mentioned(prose, assumption, kernel, lexicon) {
                findings.push(finding(
                    "id_absent_from_prose",
                    false,
                    assumption,
                    "an open assumption is not named in the informal account; absence is not proof it was concealed",
                ));
            }
        }
    }
    Ok(finish(findings))
}

fn compare_projection(formal: &Projection, parsed: &Projection, findings: &mut Vec<Finding>) {
    for argument in &formal.arguments {
        match parsed.arguments.iter().find(|item| item.id == argument.id) {
            None => findings.push(finding(
                "missing_claim",
                true,
                &argument.id,
                "the card omits an argument that is in the kernel",
            )),
            Some(other) => {
                if other.conclusion != argument.conclusion
                    || other.rule != argument.rule
                    || other.premises != argument.premises
                    || other.evidence != argument.evidence
                    || other.scope != argument.scope
                    || other.assumptions != argument.assumptions
                    || other.expression != argument.expression
                    || other.kind != argument.kind
                {
                    findings.push(finding(
                        "changed_argument",
                        true,
                        &argument.id,
                        "the card's formal keys differ from the kernel projection",
                    ));
                }
            }
        }
    }
    for argument in &parsed.arguments {
        if formal.arguments.iter().all(|item| item.id != argument.id) {
            findings.push(finding(
                "unsupported_claim",
                true,
                &argument.id,
                "the card describes an argument that is not in this kernel",
            ));
        }
    }
    for claim in &formal.open_claims {
        if parsed.open_claims.iter().all(|item| item.id != claim.id) {
            findings.push(finding(
                "missing_claim",
                true,
                &claim.id,
                "the card omits an open claim",
            ));
        }
    }
}

fn compare_reading_coverage(
    kernel: &Kernel,
    formal: &Projection,
    card: &str,
    lexicon: &Lexicon,
    language: Language,
    findings: &mut Vec<Finding>,
) -> Result<(), SpeakError> {
    let rendered = render(kernel, lexicon, language)?;
    if reading_body(card) == reading_body(&rendered.card) {
        return Ok(());
    }
    findings.push(finding(
        "harmless_wording",
        false,
        "reading",
        "the human paragraph differs from the regenerated reading; the formal keys are the object under review",
    ));
    for argument in &formal.arguments {
        let Some(body) = argument_reading(card, &argument.id) else {
            continue;
        };
        for premise in &argument.premises {
            if !mentioned(&body, premise, kernel, lexicon) {
                findings.push(finding(
                    "reading_omits_premise",
                    false,
                    &argument.id,
                    "the human paragraph does not name a premise that the formal keys still carry",
                ));
            }
        }
    }
    Ok(())
}

/// A claim counts as mentioned when the text names the claim id, or an
/// authored gloss for one of the claim's atoms. Glosses are keyed by atom,
/// never by claim id.
fn mentioned(text: &str, id: &str, kernel: &Kernel, lexicon: &Lexicon) -> bool {
    if text.contains(id) {
        return true;
    }
    let Some(claim) = kernel.claims.iter().find(|claim| claim.id == id) else {
        return false;
    };
    atoms(&claim.expression).iter().any(|atom| {
        lexicon
            .gloss(atom)
            .is_some_and(|gloss| text.contains(gloss))
    })
}

fn reading_body(card: &str) -> String {
    let mut bodies = Vec::new();
    let mut capture = false;
    for line in card.lines() {
        if line == "<<<" {
            capture = true;
            continue;
        }
        if line == ">>>" {
            capture = false;
            continue;
        }
        if capture {
            bodies.push(line);
        }
    }
    bodies.join("\n")
}

fn argument_reading(card: &str, id: &str) -> Option<String> {
    // Line-based, so a CRLF card behaves exactly like an LF card: the premise
    // coverage check must not silently pass just because of line endings.
    let marker = format!("argument: {id}");
    let mut in_argument = false;
    let mut in_reading = false;
    let mut body = Vec::new();
    for line in card.lines() {
        if line == marker {
            in_argument = true;
            continue;
        }
        if in_argument && line.starts_with("argument: ") {
            return None;
        }
        if in_argument && line == "<<<" {
            in_reading = true;
            continue;
        }
        if in_reading && line == ">>>" {
            return Some(body.join("\n"));
        }
        if in_reading {
            body.push(line);
        }
    }
    None
}

fn finding(code: &str, blocking: bool, subject: &str, detail: &str) -> Finding {
    Finding {
        code: code.to_string(),
        blocking,
        subject: subject.to_string(),
        detail: detail.to_string(),
    }
}

fn finish(mut findings: Vec<Finding>) -> FidelityReport {
    findings.sort_by(|left, right| {
        (&left.code, &left.subject, &left.detail).cmp(&(&right.code, &right.subject, &right.detail))
    });
    let outcome = if findings.iter().any(|item| item.blocking) {
        Outcome::BlockingProblem
    } else if findings
        .iter()
        .any(|item| item.code == "unresolved_mapping")
    {
        Outcome::Unresolved
    } else {
        Outcome::NoBlockingProblem
    };
    FidelityReport {
        outcome,
        endorsement: "not_endorsed",
        claim_supported: false,
        alignment_guaranteed: false,
        findings,
        limits: crate::SPEAK_LIMITS,
    }
}
