use serde::Serialize;
use serde_json::{Map, Value};
use sha2::{Digest, Sha256};

use crate::error::ContractError;
use crate::limits::HASH_BUFFER_BYTES;
use crate::model::{AtomEntry, Claim, EvidenceSpec, Expression, Kernel, LoadedArgument};

/// Canonical UTF-8 JSON for hashes.
///
/// Object keys are sorted. Set-like arrays (assumptions, premises, evidence
/// spec ids, and the three top-level collections) are sorted by id. `and`
/// items keep their order: that order is part of the expression. Timestamps
/// are not part of a kernel hash. This is a project canonical form, not an
/// RFC 8785 claim.
pub fn canonical_kernel(kernel: &Kernel) -> Result<Vec<u8>, ContractError> {
    let value = kernel_value(kernel)?;
    let mut bytes =
        serde_json::to_vec(&value).map_err(|err| ContractError::Json(err.to_string()))?;
    bytes.push(b'\n');
    Ok(bytes)
}

pub fn sha256_hex(bytes: &[u8]) -> String {
    let digest = Sha256::digest(bytes);
    digest.iter().map(|byte| format!("{byte:02x}")).collect()
}

/// Stream a file through the hasher in fixed-size chunks.
///
/// Returns `Ok(None)` when the file exceeds `max_bytes`; nothing is
/// truncated silently. I/O failures are returned to the caller.
pub fn sha256_file_capped(
    path: &std::path::Path,
    max_bytes: u64,
) -> std::io::Result<Option<(String, u64)>> {
    use std::io::Read;
    let mut file = std::fs::File::open(path)?;
    let mut hasher = Sha256::new();
    let mut buffer = vec![0_u8; HASH_BUFFER_BYTES];
    let mut total = 0_u64;
    loop {
        let read = file.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        total += read as u64;
        if total > max_bytes {
            return Ok(None);
        }
        hasher.update(&buffer[..read]);
    }
    let digest = hasher.finalize();
    Ok(Some((
        digest.iter().map(|byte| format!("{byte:02x}")).collect(),
        total,
    )))
}

pub fn kernel_sha256(kernel: &Kernel) -> Result<String, ContractError> {
    Ok(sha256_hex(&canonical_kernel(kernel)?))
}

/// Hash of one evidence spec. A receipt's `spec_hash` is compared to this,
/// not to a hash of the whole kernel and not to a hash the caller writes as proof.
pub fn evidence_spec_sha256(spec: &EvidenceSpec) -> Result<String, ContractError> {
    let value = evidence_value(spec)?;
    let mut bytes =
        serde_json::to_vec(&value).map_err(|err| ContractError::Json(err.to_string()))?;
    bytes.push(b'\n');
    Ok(sha256_hex(&bytes))
}

fn kernel_value(kernel: &Kernel) -> Result<Value, ContractError> {
    let mut claims = kernel.claims.clone();
    claims.sort_by(|left, right| left.id.cmp(&right.id));
    let mut arguments = kernel.arguments.clone();
    arguments.sort_by(|left, right| left.id.cmp(&right.id));
    let mut evidence = kernel.evidence_specs.clone();
    evidence.sort_by(|left, right| left.id.cmp(&right.id));

    let mut object = Map::new();
    object.insert(
        "schema_version".to_string(),
        Value::String(kernel.schema_version.as_str().to_string()),
    );
    object.insert(
        "profile".to_string(),
        Value::String(kernel.profile.as_str().to_string()),
    );
    if let Some(corpus) = &kernel.corpus {
        object.insert("corpus".to_string(), to_value(corpus)?);
    }
    if let Some(registry) = &kernel.atoms {
        object.insert("atoms".to_string(), Value::Array(registry_value(registry)));
    }
    object.insert(
        "claims".to_string(),
        Value::Array(claims.iter().map(claim_value).collect::<Result<_, _>>()?),
    );
    object.insert(
        "arguments".to_string(),
        Value::Array(
            arguments
                .iter()
                .map(argument_value)
                .collect::<Result<_, _>>()?,
        ),
    );
    object.insert(
        "evidence_specs".to_string(),
        Value::Array(
            evidence
                .iter()
                .map(evidence_value)
                .collect::<Result<_, _>>()?,
        ),
    );
    Ok(Value::Object(object))
}

fn registry_value(registry: &std::collections::BTreeMap<String, AtomEntry>) -> Vec<Value> {
    registry
        .iter()
        .map(|(atom, entry)| {
            let mut object = Map::new();
            object.insert("id".to_string(), Value::String(atom.clone()));
            object.insert(
                "definition_claim".to_string(),
                Value::String(entry.definition_claim.clone()),
            );
            if let Some(description) = &entry.description {
                object.insert(
                    "description".to_string(),
                    Value::String(description.clone()),
                );
            }
            Value::Object(object)
        })
        .collect()
}

fn claim_value(claim: &Claim) -> Result<Value, ContractError> {
    let mut assumptions = claim.assumptions.clone();
    assumptions.sort();
    let mut object = Map::new();
    object.insert("id".to_string(), Value::String(claim.id.clone()));
    object.insert(
        "book_key".to_string(),
        match &claim.book_key {
            Some(key) => Value::String(key.clone()),
            None => Value::Null,
        },
    );
    object.insert("source".to_string(), to_value(&claim.source)?);
    object.insert("kind".to_string(), to_value(&claim.kind)?);
    object.insert(
        "statement".to_string(),
        Value::String(claim.statement.clone()),
    );
    object.insert(
        "expression".to_string(),
        expression_value(&claim.expression),
    );
    object.insert("scope".to_string(), scope_value(&claim.scope));
    object.insert(
        "assumptions".to_string(),
        Value::Array(assumptions.into_iter().map(Value::String).collect()),
    );
    Ok(Value::Object(object))
}

fn argument_value(argument: &LoadedArgument) -> Result<Value, ContractError> {
    let mut premises = argument.premises.clone();
    premises.sort();
    let mut evidence = argument.evidence_specs.clone();
    evidence.sort();
    let mut object = Map::new();
    object.insert("id".to_string(), Value::String(argument.id.clone()));
    object.insert(
        "conclusion".to_string(),
        Value::String(argument.conclusion.clone()),
    );
    object.insert(
        "premises".to_string(),
        Value::Array(premises.into_iter().map(Value::String).collect()),
    );
    object.insert("rule".to_string(), Value::String(argument.rule.canonical()));
    object.insert(
        "evidence_specs".to_string(),
        Value::Array(evidence.into_iter().map(Value::String).collect()),
    );
    Ok(Value::Object(object))
}

fn evidence_value(spec: &EvidenceSpec) -> Result<Value, ContractError> {
    let mut object = Map::new();
    object.insert("id".to_string(), Value::String(spec.id.clone()));
    object.insert(
        "kind".to_string(),
        Value::String(spec.kind.as_str().to_string()),
    );
    object.insert("claim_id".to_string(), Value::String(spec.claim_id.clone()));
    object.insert(
        "runner_id".to_string(),
        Value::String(spec.runner_id.clone()),
    );
    object.insert("target".to_string(), Value::String(spec.target.clone()));
    object.insert("scope".to_string(), scope_value(&spec.scope));
    object.insert("availability".to_string(), to_value(&spec.availability)?);
    Ok(Value::Object(object))
}

fn expression_value(expression: &Expression) -> Value {
    match expression {
        Expression::Atom { id } => {
            let mut object = Map::new();
            object.insert("op".to_string(), Value::String("atom".to_string()));
            object.insert("id".to_string(), Value::String(id.clone()));
            Value::Object(object)
        }
        Expression::Implies {
            antecedent,
            consequent,
        } => {
            let mut object = Map::new();
            object.insert("op".to_string(), Value::String("implies".to_string()));
            object.insert("antecedent".to_string(), expression_value(antecedent));
            object.insert("consequent".to_string(), expression_value(consequent));
            Value::Object(object)
        }
        Expression::And { items } => {
            let mut object = Map::new();
            object.insert("op".to_string(), Value::String("and".to_string()));
            object.insert(
                "items".to_string(),
                Value::Array(items.iter().map(expression_value).collect()),
            );
            Value::Object(object)
        }
    }
}

fn scope_value(scope: &std::collections::BTreeMap<String, String>) -> Value {
    let mut object = Map::new();
    for (key, value) in scope {
        object.insert(key.clone(), Value::String(value.clone()));
    }
    Value::Object(object)
}

fn to_value<T: Serialize>(value: &T) -> Result<Value, ContractError> {
    serde_json::to_value(value).map_err(|err| ContractError::Json(err.to_string()))
}
