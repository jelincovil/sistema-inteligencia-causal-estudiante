use std::collections::BTreeMap;

use argument_document::Expression;

use crate::error::SpeakError;
use crate::render::{OpenClaim, ProjectedArgument, Projection};

/// Recover the formal projection from a controlled card.
///
/// The `reading:` paragraph is ignored. Free prose, with no `argument:`
/// keys, is not a card and returns [`SpeakError::Card`].
pub fn parse_card(text: &str) -> Result<Projection, SpeakError> {
    let lines: Vec<&str> = text.lines().collect();
    let kernel_sha256 = field(&lines, "kernel_sha256")?;
    let mut arguments = Vec::new();
    let mut index = 0;
    while index < lines.len() {
        if lines[index].starts_with("argument: ") {
            let (argument, next) = parse_argument(&lines, index)?;
            arguments.push(argument);
            index = next;
            continue;
        }
        index += 1;
    }
    arguments.sort_by(|left, right| left.id.cmp(&right.id));
    let open_claims = parse_open(&lines)?;
    if arguments.is_empty() && open_claims.is_empty() && !text.contains("argument:") {
        return Err(SpeakError::Card(
            "no argument keys; free prose is not a formal card".to_string(),
        ));
    }
    Ok(Projection {
        kernel_sha256,
        arguments,
        open_claims,
    })
}

fn parse_argument(lines: &[&str], start: usize) -> Result<(ProjectedArgument, usize), SpeakError> {
    let id = value_at(lines[start], "argument")?;
    let mut cursor = start + 1;
    let mut fields = BTreeMap::new();
    while cursor < lines.len()
        && !lines[cursor].starts_with("argument: ")
        && lines[cursor] != "open:"
        && lines[cursor] != "reading:"
    {
        if let Some((key, value)) = split_field(lines[cursor]) {
            fields.insert(key, value);
        }
        cursor += 1;
    }
    if cursor < lines.len() && lines[cursor] == "reading:" {
        cursor += 1;
        if cursor >= lines.len() || lines[cursor] != "<<<" {
            return Err(SpeakError::Card(format!(
                "argument `{id}` is missing the reading fence"
            )));
        }
        cursor += 1;
        while cursor < lines.len() && lines[cursor] != ">>>" {
            cursor += 1;
        }
        if cursor >= lines.len() {
            return Err(SpeakError::Card(format!(
                "argument `{id}` has an unclosed reading"
            )));
        }
        cursor += 1;
    }
    let conclusion = required(&fields, "conclusion", &id)?;
    let expression = required(&fields, "expression", &id)?;
    parse_expression(&expression)?;
    Ok((
        ProjectedArgument {
            id,
            conclusion,
            kind: required(&fields, "kind", "")?,
            rule: required(&fields, "rule", "")?,
            premises: split_ids(&required(&fields, "premises", "")?),
            evidence: split_ids(&required(&fields, "evidence", "")?),
            scope: parse_scope(&required(&fields, "scope", "")?)?,
            assumptions: split_ids(&required(&fields, "assumptions", "")?),
            expression,
        },
        cursor,
    ))
}

fn parse_open(lines: &[&str]) -> Result<Vec<OpenClaim>, SpeakError> {
    let Some(start) = lines.iter().position(|line| *line == "open:") else {
        return Ok(Vec::new());
    };
    let mut claims = Vec::new();
    for line in lines.iter().skip(start + 1) {
        if line.is_empty() || line.starts_with("argument: ") {
            break;
        }
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        // Layout: `{id} kind={kind} assumptions={list}`. The assumption list
        // runs to the end of the line and is comma-space joined, so it cannot
        // be split on whitespace.
        let (id, rest) = line
            .split_once(" kind=")
            .ok_or_else(|| SpeakError::Card(format!("open claim `{line}` has no `kind=` field")))?;
        if !argument_document::is_id(id) {
            return Err(SpeakError::Card(format!(
                "open claim id `{id}` does not match the kernel id contract"
            )));
        }
        let (kind, assumptions_text) = rest.split_once(" assumptions=").ok_or_else(|| {
            SpeakError::Card(format!("open claim `{id}` has no `assumptions=` field"))
        })?;
        if kind.trim().is_empty() {
            return Err(SpeakError::Card(format!("open claim `{id}` has no kind")));
        }
        let assumptions = split_ids(assumptions_text);
        for assumption in &assumptions {
            if !argument_document::is_id(assumption) {
                return Err(SpeakError::Card(format!(
                    "open assumption `{assumption}` does not match the kernel id contract"
                )));
            }
        }
        claims.push(OpenClaim {
            id: id.to_string(),
            kind: kind.to_string(),
            assumptions,
        });
    }
    claims.sort_by(|left, right| left.id.cmp(&right.id));
    Ok(claims)
}

/// Depth cap for nested expressions, matching the JSON parser's implicit
/// recursion bound. A card must not overflow the stack before it errors.
const MAX_EXPRESSION_DEPTH: usize = 128;

pub fn parse_expression(text: &str) -> Result<Expression, SpeakError> {
    let (expression, rest) = parse_expression_at(text, 0)?;
    if !rest.is_empty() {
        return Err(SpeakError::Card(format!(
            "trailing data in expression `{text}`"
        )));
    }
    Ok(expression)
}

fn parse_expression_at(text: &str, depth: usize) -> Result<(Expression, &str), SpeakError> {
    if depth > MAX_EXPRESSION_DEPTH {
        return Err(SpeakError::Card(format!(
            "expression nested deeper than {MAX_EXPRESSION_DEPTH} levels"
        )));
    }
    if let Some(rest) = text.strip_prefix("atom:") {
        let (id, rest) = take_id(rest)?;
        return Ok((Expression::Atom { id }, rest));
    }
    if let Some(rest) = text.strip_prefix("implies(") {
        let (antecedent, rest) = parse_expression_at(rest, depth + 1)?;
        let rest = rest
            .strip_prefix(", ")
            .ok_or_else(|| SpeakError::Card("implies is missing a consequent".to_string()))?;
        let (consequent, rest) = parse_expression_at(rest, depth + 1)?;
        let rest = rest
            .strip_prefix(')')
            .ok_or_else(|| SpeakError::Card("implies is missing ')'".to_string()))?;
        return Ok((
            Expression::Implies {
                antecedent: Box::new(antecedent),
                consequent: Box::new(consequent),
            },
            rest,
        ));
    }
    if let Some(rest) = text.strip_prefix("and(") {
        let mut items = Vec::new();
        let mut rest = rest;
        loop {
            let (item, next) = parse_expression_at(rest, depth + 1)?;
            items.push(item);
            if let Some(next) = next.strip_prefix(", ") {
                rest = next;
                continue;
            }
            let next = next
                .strip_prefix(')')
                .ok_or_else(|| SpeakError::Card("and is missing ')'".to_string()))?;
            if items.len() < 2 {
                return Err(SpeakError::Card(
                    "and-expression needs two items".to_string(),
                ));
            }
            return Ok((Expression::And { items }, next));
        }
    }
    Err(SpeakError::Card(format!(
        "expression `{text}` is not a controlled form"
    )))
}

fn take_id(text: &str) -> Result<(String, &str), SpeakError> {
    let end = text.find([',', ')', ' ']).unwrap_or(text.len());
    let id = &text[..end];
    if id.is_empty() {
        return Err(SpeakError::Card("empty expression id".to_string()));
    }
    if !argument_document::is_id(id) {
        return Err(SpeakError::Card(format!(
            "expression id `{id}` does not match the kernel id contract"
        )));
    }
    Ok((id.to_string(), &text[end..]))
}

/// Exact quote check. Offsets are UTF-8 bytes, not Unicode scalar indexes.
pub fn check_quote(source: &str, start: usize, end: usize, quote: &str) -> Result<(), SpeakError> {
    let bytes = source.as_bytes();
    if end < start || end > bytes.len() {
        return Err(SpeakError::Quote { start, end });
    }
    if !source.is_char_boundary(start) || !source.is_char_boundary(end) {
        return Err(SpeakError::Quote { start, end });
    }
    if &source[start..end] == quote {
        Ok(())
    } else {
        Err(SpeakError::Quote { start, end })
    }
}

fn field(lines: &[&str], name: &str) -> Result<String, SpeakError> {
    let prefix = format!("{name}: ");
    lines
        .iter()
        .find_map(|line| line.strip_prefix(&prefix).map(str::to_string))
        .ok_or_else(|| SpeakError::Card(format!("missing `{name}`")))
}

fn value_at(line: &str, name: &str) -> Result<String, SpeakError> {
    line.strip_prefix(&format!("{name}: "))
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .map(str::to_string)
        .ok_or_else(|| SpeakError::Card(format!("missing `{name}`")))
}

fn split_field(line: &str) -> Option<(String, String)> {
    let (key, value) = line.split_once(": ")?;
    if key.contains(' ') {
        return None;
    }
    Some((key.to_string(), value.to_string()))
}

fn required(fields: &BTreeMap<String, String>, key: &str, id: &str) -> Result<String, SpeakError> {
    fields
        .get(key)
        .cloned()
        .ok_or_else(|| SpeakError::Card(format!("argument `{id}` is missing `{key}`")))
}

fn split_ids(value: &str) -> Vec<String> {
    if value == "-" {
        return Vec::new();
    }
    let mut ids: Vec<String> = value
        .split(',')
        .map(str::trim)
        .filter(|item| !item.is_empty())
        .map(str::to_string)
        .collect();
    ids.sort();
    ids.dedup();
    ids
}

fn parse_scope(value: &str) -> Result<BTreeMap<String, String>, SpeakError> {
    let mut scope = BTreeMap::new();
    if value == "-" {
        return Ok(scope);
    }
    for part in value.split(',') {
        let part = part.trim();
        let Some((key, raw)) = part.split_once('=') else {
            return Err(SpeakError::Card(format!("scope entry `{part}` has no '='")));
        };
        if scope.insert(key.to_string(), raw.to_string()).is_some() {
            return Err(SpeakError::Card(format!("duplicate scope key `{key}`")));
        }
    }
    Ok(scope)
}
