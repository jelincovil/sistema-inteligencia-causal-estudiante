use std::collections::BTreeMap;
use std::fmt::Write as _;

use argument_document::{sha256_hex, Claim, ClaimKind, Expression, Kernel, LoadedArgument};

use crate::error::SpeakError;
use crate::language::Language;
use crate::lexicon::Lexicon;

/// Formal projection of a kernel. This is the object a card must recover.
/// It is not a release and it carries no status.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Projection {
    pub kernel_sha256: String,
    pub arguments: Vec<ProjectedArgument>,
    pub open_claims: Vec<OpenClaim>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct ProjectedArgument {
    pub id: String,
    pub conclusion: String,
    pub kind: String,
    pub rule: String,
    pub premises: Vec<String>,
    pub evidence: Vec<String>,
    pub scope: BTreeMap<String, String>,
    pub assumptions: Vec<String>,
    pub expression: String,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct OpenClaim {
    pub id: String,
    pub kind: String,
    pub assumptions: Vec<String>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Reading {
    pub language: Language,
    pub projection: Projection,
    pub card: String,
    pub card_sha256: String,
    /// Atom ids with no authored gloss. The card leaves them as ids.
    pub glosses_pending: Vec<String>,
    pub claim_supported: bool,
    pub alignment_guaranteed: bool,
}

pub fn project(kernel: &Kernel) -> Result<Projection, SpeakError> {
    let kernel_sha256 = kernel
        .content_sha256()
        .map_err(|err| SpeakError::Contract(err.to_string()))?;
    let mut arguments = kernel
        .arguments
        .iter()
        .map(|argument| project_argument(kernel, argument))
        .collect::<Result<Vec<_>, _>>()?;
    arguments.sort_by(|left, right| left.id.cmp(&right.id));
    let concluded: std::collections::BTreeSet<&str> = arguments
        .iter()
        .map(|argument| argument.conclusion.as_str())
        .collect();
    let mut open_claims = kernel
        .claims
        .iter()
        .filter(|claim| !concluded.contains(claim.id.as_str()))
        .map(|claim| OpenClaim {
            id: claim.id.clone(),
            kind: kind_str(claim.kind).to_string(),
            assumptions: sorted(claim.assumptions.clone()),
        })
        .collect::<Vec<_>>();
    open_claims.sort_by(|left, right| left.id.cmp(&right.id));
    Ok(Projection {
        kernel_sha256,
        arguments,
        open_claims,
    })
}

pub fn render(
    kernel: &Kernel,
    lexicon: &Lexicon,
    language: Language,
) -> Result<Reading, SpeakError> {
    if lexicon.language != language && !lexicon.is_empty() {
        return Err(SpeakError::Lexicon(format!(
            "lexicon language `{}` does not match reading language `{}`",
            lexicon.language.as_str(),
            language.as_str()
        )));
    }
    let projection = project(kernel)?;
    let mut glosses_pending = Vec::new();
    let card = write_card(kernel, &projection, lexicon, language, &mut glosses_pending)?;
    glosses_pending.sort();
    glosses_pending.dedup();
    let card_sha256 = sha256_hex(card.as_bytes());
    Ok(Reading {
        language,
        projection,
        card,
        card_sha256,
        glosses_pending,
        claim_supported: false,
        alignment_guaranteed: false,
    })
}

fn project_argument(
    kernel: &Kernel,
    argument: &LoadedArgument,
) -> Result<ProjectedArgument, SpeakError> {
    let conclusion = kernel
        .claims
        .iter()
        .find(|claim| claim.id == argument.conclusion)
        .ok_or_else(|| SpeakError::Card(format!("missing conclusion `{}`", argument.conclusion)))?;
    reject_scope_encoding(&conclusion.scope)?;
    Ok(ProjectedArgument {
        id: argument.id.clone(),
        conclusion: conclusion.id.clone(),
        kind: kind_str(conclusion.kind).to_string(),
        rule: argument.rule.canonical(),
        premises: sorted(argument.premises.clone()),
        evidence: sorted(argument.evidence_specs.clone()),
        scope: conclusion.scope.clone(),
        assumptions: sorted(conclusion.assumptions.clone()),
        expression: render_expression(&conclusion.expression),
    })
}

fn write_card(
    kernel: &Kernel,
    projection: &Projection,
    lexicon: &Lexicon,
    language: Language,
    pending: &mut Vec<String>,
) -> Result<String, SpeakError> {
    let mut out = String::new();
    writeln!(out, "argument-card {}", crate_version()).map_err(write_err)?;
    writeln!(out, "language: {}", language.as_str()).map_err(write_err)?;
    writeln!(out, "kernel_sha256: {}", projection.kernel_sha256).map_err(write_err)?;
    writeln!(out, "claim_supported: false").map_err(write_err)?;
    writeln!(out, "alignment_guaranteed: false").map_err(write_err)?;
    writeln!(out, "limits: this card is a reading of the formal projection; it does not certify the wording or the conclusion").map_err(write_err)?;
    writeln!(out).map_err(write_err)?;
    for argument in &projection.arguments {
        write_argument(&mut out, kernel, argument, lexicon, language, pending)?;
    }
    if !projection.open_claims.is_empty() {
        writeln!(out, "open:").map_err(write_err)?;
        for claim in &projection.open_claims {
            writeln!(
                out,
                "  {} kind={} assumptions={}",
                claim.id,
                claim.kind,
                join_or_dash(&claim.assumptions)
            )
            .map_err(write_err)?;
        }
        writeln!(out).map_err(write_err)?;
    }
    Ok(out)
}

fn write_argument(
    out: &mut String,
    kernel: &Kernel,
    argument: &ProjectedArgument,
    lexicon: &Lexicon,
    language: Language,
    pending: &mut Vec<String>,
) -> Result<(), SpeakError> {
    writeln!(out, "argument: {}", argument.id).map_err(write_err)?;
    writeln!(out, "conclusion: {}", argument.conclusion).map_err(write_err)?;
    writeln!(out, "kind: {}", argument.kind).map_err(write_err)?;
    writeln!(out, "rule: {}", argument.rule).map_err(write_err)?;
    writeln!(out, "expression: {}", argument.expression).map_err(write_err)?;
    writeln!(out, "premises: {}", join_or_dash(&argument.premises)).map_err(write_err)?;
    writeln!(out, "evidence: {}", join_or_dash(&argument.evidence)).map_err(write_err)?;
    writeln!(out, "scope: {}", scope_text(&argument.scope)).map_err(write_err)?;
    writeln!(out, "assumptions: {}", join_or_dash(&argument.assumptions)).map_err(write_err)?;
    writeln!(out, "reading:").map_err(write_err)?;
    writeln!(out, "<<<").map_err(write_err)?;
    writeln!(
        out,
        "{}",
        paragraph(kernel, argument, lexicon, language, pending)?
    )
    .map_err(write_err)?;
    writeln!(out, ">>>").map_err(write_err)?;
    writeln!(out).map_err(write_err)?;
    Ok(())
}

fn paragraph(
    kernel: &Kernel,
    argument: &ProjectedArgument,
    lexicon: &Lexicon,
    language: Language,
    pending: &mut Vec<String>,
) -> Result<String, SpeakError> {
    let conclusion = claim(kernel, &argument.conclusion)?;
    let premise_bits = argument
        .premises
        .iter()
        .map(|id| named(kernel, lexicon, id, pending))
        .collect::<Result<Vec<_>, _>>()?;
    let assumption_bits = argument
        .assumptions
        .iter()
        .map(|id| named(kernel, lexicon, id, pending))
        .collect::<Result<Vec<_>, _>>()?;
    let conclusion_name = named(kernel, lexicon, &argument.conclusion, pending)?;
    let rule_gloss = language.rule_gloss(&argument.rule);
    let text = match language {
        Language::En => format!(
            "Argument {id} concludes {conclusion} by {rule} ({rule_gloss}). Premises: {premises}. Open assumptions on the conclusion: {assumptions}. Scope: {scope}. The author's statement is not logic: {statement} This paragraph does not assert the conclusion.",
            id = argument.id,
            conclusion = conclusion_name,
            rule = argument.rule,
            premises = join_human(&premise_bits),
            assumptions = join_human(&assumption_bits),
            scope = scope_text(&argument.scope),
            statement = quote_statement(&conclusion.statement),
        ),
        Language::Es => format!(
            "El argumento {id} concluye {conclusion} por {rule} ({rule_gloss}). Premisas: {premises}. Supuestos abiertos de la conclusión: {assumptions}. Alcance: {scope}. El enunciado del autor no es lógica: {statement} Este párrafo no afirma la conclusión.",
            id = argument.id,
            conclusion = conclusion_name,
            rule = argument.rule,
            premises = join_human(&premise_bits),
            assumptions = join_human(&assumption_bits),
            scope = scope_text(&argument.scope),
            statement = quote_statement(&conclusion.statement),
        ),
    };
    if text.lines().any(|line| line == "<<<" || line == ">>>") {
        return Err(SpeakError::Card(
            "a statement contains a reading delimiter on its own line".to_string(),
        ));
    }
    Ok(text)
}

fn named(
    kernel: &Kernel,
    lexicon: &Lexicon,
    id: &str,
    pending: &mut Vec<String>,
) -> Result<String, SpeakError> {
    let claim = claim(kernel, id)?;
    let mut glosses = Vec::new();
    for atom in atoms(&claim.expression) {
        match lexicon.gloss(&atom) {
            Some(gloss) => glosses.push(gloss.to_string()),
            None => pending.push(atom),
        }
    }
    glosses.sort();
    glosses.dedup();
    if glosses.is_empty() {
        Ok(id.to_string())
    } else {
        Ok(format!("{id} ({})", glosses.join("; ")))
    }
}

pub(crate) fn atoms(expression: &Expression) -> Vec<String> {
    match expression {
        Expression::Atom { id } => vec![id.clone()],
        Expression::Implies {
            antecedent,
            consequent,
        } => {
            let mut ids = atoms(antecedent);
            ids.extend(atoms(consequent));
            ids
        }
        Expression::And { items } => items.iter().flat_map(atoms).collect(),
    }
}

fn claim<'a>(kernel: &'a Kernel, id: &str) -> Result<&'a Claim, SpeakError> {
    kernel
        .claims
        .iter()
        .find(|claim| claim.id == id)
        .ok_or_else(|| SpeakError::Card(format!("missing claim `{id}`")))
}

pub fn render_expression(expression: &Expression) -> String {
    match expression {
        Expression::Atom { id } => format!("atom:{id}"),
        Expression::Implies {
            antecedent,
            consequent,
        } => format!(
            "implies({}, {})",
            render_expression(antecedent),
            render_expression(consequent)
        ),
        Expression::And { items } => {
            let inner = items
                .iter()
                .map(render_expression)
                .collect::<Vec<_>>()
                .join(", ");
            format!("and({inner})")
        }
    }
}

pub fn kind_str(kind: ClaimKind) -> &'static str {
    match kind {
        ClaimKind::Formal => "formal",
        ClaimKind::Empirical => "empirical",
        ClaimKind::Conditional => "conditional",
        ClaimKind::Factual => "factual",
    }
}

fn scope_text(scope: &BTreeMap<String, String>) -> String {
    if scope.is_empty() {
        return "-".to_string();
    }
    scope
        .iter()
        .map(|(key, value)| format!("{key}={value}"))
        .collect::<Vec<_>>()
        .join(", ")
}

fn join_or_dash(ids: &[String]) -> String {
    if ids.is_empty() {
        "-".to_string()
    } else {
        ids.join(", ")
    }
}

fn join_human(parts: &[String]) -> String {
    if parts.is_empty() {
        "-".to_string()
    } else {
        parts.join("; ")
    }
}

fn quote_statement(statement: &str) -> String {
    format!("\"{}\".", statement.replace('"', "'"))
}

fn reject_scope_encoding(scope: &BTreeMap<String, String>) -> Result<(), SpeakError> {
    for (key, value) in scope {
        if key.is_empty() {
            return Err(SpeakError::Card("a scope key cannot be empty".to_string()));
        }
        if key.contains('=') || key.contains(',') || value.contains('=') || value.contains(',') {
            return Err(SpeakError::Card(format!(
                "scope key `{key}` cannot be rendered: comma or equals is reserved"
            )));
        }
        if key.chars().any(|c| c.is_control()) || value.chars().any(|c| c.is_control()) {
            return Err(SpeakError::Card(format!(
                "scope key `{key}` cannot be rendered: control characters are reserved"
            )));
        }
    }
    Ok(())
}

fn sorted(mut ids: Vec<String>) -> Vec<String> {
    ids.sort();
    ids.dedup();
    ids
}

fn crate_version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

fn write_err(err: std::fmt::Error) -> SpeakError {
    SpeakError::Card(err.to_string())
}
