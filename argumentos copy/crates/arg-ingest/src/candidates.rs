use std::collections::{BTreeMap, BTreeSet};

use crate::{
    sha256, ArgumentCandidate, CandidateOccurrence, SourceScope, SourceUnit, OUTPUT_SCHEMA_VERSION,
};

pub(crate) fn link_candidates(units: &mut [SourceUnit]) -> Vec<ArgumentCandidate> {
    let mut grouped: BTreeMap<String, Vec<usize>> = BTreeMap::new();
    for (index, unit) in units.iter().enumerate() {
        if unit.coverage_status != "pending_candidate_link" {
            continue;
        }
        let statement = normalize_whitespace(&unit.raw_text);
        if statement.is_empty() {
            continue;
        }
        grouped.entry(statement).or_default().push(index);
    }

    let mut candidates = Vec::new();
    for (statement, indices) in grouped {
        let statement_sha256 = sha256(statement.as_bytes());
        let id = format!("cand.{statement_sha256}");
        let first = &units[indices[0]];
        let argument_kind = argument_kind(first, &statement);
        let topics = topics(first, &statement);
        let mut occurrences = indices
            .iter()
            .map(|index| {
                let unit = &units[*index];
                CandidateOccurrence {
                    unit_id: unit.id.clone(),
                    collection: unit.collection.clone(),
                    edition: unit.edition.clone(),
                    path: unit.path.clone(),
                    collection_path: unit.collection_path.clone(),
                    source_revision: unit.source_revision.clone(),
                    span: unit.span.clone(),
                    heading_trail: unit.heading_trail.clone(),
                }
            })
            .collect::<Vec<_>>();
        occurrences.sort_by(|left, right| {
            (
                &left.collection,
                &left.path,
                left.span.byte_start,
                &left.unit_id,
            )
                .cmp(&(
                    &right.collection,
                    &right.path,
                    right.span.byte_start,
                    &right.unit_id,
                ))
        });
        let source_scopes = make_scopes(&occurrences, units);
        for index in indices {
            units[index].coverage_status = "candidate_linked".to_owned();
            units[index].candidate_id = Some(id.clone());
        }
        candidates.push(ArgumentCandidate {
            schema_version: OUTPUT_SCHEMA_VERSION.to_owned(),
            id,
            statement,
            statement_sha256,
            argument_kind,
            epistemic_status: "source_assertion_unverified".to_owned(),
            review_status: "unreviewed".to_owned(),
            source_status: "current".to_owned(),
            candidate_origin: "automatic_verbatim_extraction".to_owned(),
            topics,
            topic_review_status: "automatic_unreviewed".to_owned(),
            occurrences,
            source_scopes,
            atomicity_status: "not_assessed".to_owned(),
        });
    }
    candidates.sort_by(|left, right| left.id.cmp(&right.id));
    candidates
}

fn make_scopes(occurrences: &[CandidateOccurrence], units: &[SourceUnit]) -> Vec<SourceScope> {
    let units_by_id = units
        .iter()
        .map(|unit| (unit.id.as_str(), unit))
        .collect::<BTreeMap<_, _>>();
    let mut grouped: BTreeMap<(String, String, String), BTreeSet<String>> = BTreeMap::new();
    for occurrence in occurrences {
        let Some(unit) = units_by_id.get(occurrence.unit_id.as_str()) else {
            continue;
        };
        grouped
            .entry((
                occurrence.collection.clone(),
                occurrence.edition.clone(),
                unit.source_status.clone(),
            ))
            .or_default()
            .insert(occurrence.path.clone());
    }
    grouped
        .into_iter()
        .map(
            |((collection, edition, source_status), paths)| SourceScope {
                collection,
                edition,
                source_status,
                paths: paths.into_iter().collect(),
            },
        )
        .collect()
}

pub(crate) fn normalize_whitespace(raw: &str) -> String {
    raw.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn argument_kind(unit: &SourceUnit, statement: &str) -> String {
    let role_kind = match unit.role.as_str() {
        "workflow" => Some("workflow"),
        "contract" => Some("contract"),
        "knowledge_resource" => Some("resource"),
        "criterion" => Some("requirement"),
        "evaluation" => Some("evaluation"),
        "mcp_configuration" => Some("contract"),
        "deployment_documentation" => Some("workflow"),
        _ => None,
    };
    if let Some(kind) = role_kind {
        return kind.to_owned();
    }
    if unit.structural_kind == "theorem" {
        return "theorem".to_owned();
    }
    if unit.structural_kind == "definition" {
        return "definition".to_owned();
    }
    if unit.format == "json" {
        return "resource".to_owned();
    }
    let lowercase = statement.to_lowercase();
    if contains_any(
        &lowercase,
        &[
            "limitation",
            "limitación",
            "limitacion",
            "caveat",
            "no certifica",
        ],
    ) {
        "limitation".to_owned()
    } else if contains_any(
        &lowercase,
        &["assumption", "supuesto", "assume ", "asumimos"],
    ) {
        "assumption".to_owned()
    } else if contains_any(
        &lowercase,
        &["must ", "shall ", "debe ", "deben ", "requiere", "required"],
    ) {
        "requirement".to_owned()
    } else {
        "source_assertion".to_owned()
    }
}

fn topics(unit: &SourceUnit, statement: &str) -> Vec<String> {
    let text = format!("{} {} {}", unit.path, unit.role, statement).to_lowercase();
    let controls: [(&str, &[&str]); 12] = [
        (
            "causal_identification",
            &["causal", "backdoor", "identific", "contrafactual"],
        ),
        (
            "estimation",
            &["aipw", "dml", "estim", "meta-learn", "metalearn"],
        ),
        (
            "data_engineering",
            &["datos", "data", "linaje", "pipeline", "ingest"],
        ),
        (
            "validation",
            &["valid", "eval", "placebo", "diagnóst", "diagnost"],
        ),
        (
            "uncertainty",
            &["uncertainty", "incertidumbre", "interval", "sensibilidad"],
        ),
        (
            "deployment",
            &["deploy", "desplieg", "servicio", "nube", "cloud"],
        ),
        ("monitoring", &["monitor", "drift", "alerta", "incidente"]),
        (
            "governance",
            &["gobierno", "governance", "seguridad", "security", "policy"],
        ),
        ("contracts", &["contrato", "contract", "schema"]),
        ("workflows", &["workflow", "flujo", "paso", "step"]),
        (
            "machine_learning",
            &[
                "machine learning",
                "aprendizaje",
                "modelo",
                "prediction",
                "predicción",
            ],
        ),
        ("mcp", &["mcp", "model context protocol", "herramienta"]),
    ];
    let mut topics = controls
        .iter()
        .filter(|(_, needles)| contains_any(&text, needles))
        .map(|(topic, _)| (*topic).to_owned())
        .collect::<Vec<_>>();
    if topics.is_empty() {
        topics.push("uncategorized".to_owned());
    }
    topics
}

fn contains_any(text: &str, needles: &[&str]) -> bool {
    needles.iter().any(|needle| text.contains(needle))
}
