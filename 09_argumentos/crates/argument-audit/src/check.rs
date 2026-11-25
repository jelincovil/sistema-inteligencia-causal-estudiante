use std::collections::{BTreeMap, BTreeSet, HashSet};

use argument_document::{
    Availability, Claim, ClaimKind, EvidenceKind, EvidenceSpec, Expression, Kernel, LoadedArgument,
    ProfileId, Rule,
};

use crate::obligations;
use crate::profile::{allows, evidence_is_computational, evidence_is_formal_anchor};
use crate::report::{
    ArgumentFinding, CheckReport, ClaimFinding, Decision, Diagnostic, Severity, StatusAxis,
};
use crate::scope::scope_differences;
use crate::support::support_cycles;
use crate::{CHECKER_VERSION, LIMITS};

pub fn check(kernel: &Kernel) -> CheckReport {
    let claims = index_claims(kernel);
    let evidence = index_evidence(kernel);
    let mut diagnostics = Vec::new();

    let assumption_cycles = assumption_cycle_claims(kernel);
    for claim_id in &assumption_cycles {
        diagnostics.push(error(
            "cycle",
            claim_id,
            &format!(
                "assumption obligations form a cycle through `{claim_id}`; break the mutual assumption or discharge it by derivation"
            ),
        ));
    }

    let support_cycles = support_cycles(&kernel.arguments);

    for spec in &kernel.evidence_specs {
        match claims.get(&spec.claim_id) {
            None => diagnostics.push(error(
                "evidence_target",
                &spec.id,
                &format!(
                    "evidence target `{}` is not a claim in this document; point spec `{}` at an existing claim id",
                    spec.claim_id, spec.id
                ),
            )),
            Some(claim) if claim.scope != spec.scope => diagnostics.push(error(
                "evidence_scope",
                &spec.id,
                &format!(
                    "evidence `{}` scope differs from claim `{}` scope; align the evidence scope or the claim's scope",
                    spec.id, spec.claim_id
                ),
            )),
            Some(_) => {}
        }
        if matches!(
            spec.availability,
            Availability::Pending | Availability::Candidate
        ) {
            // Availability is a request, not a verdict. Recorded so it cannot
            // be reread later as support.
        }
    }

    for claim in &kernel.claims {
        for assumption in &claim.assumptions {
            if !claims.contains_key(assumption) {
                diagnostics.push(error(
                    "missing_assumption",
                    &claim.id,
                    &format!("assumption `{assumption}` does not resolve to a claim in this document; add the claim or fix the assumption id"),
                ));
            }
        }
    }

    let mut findings = Vec::new();
    for argument in &kernel.arguments {
        findings.push(judge_argument(
            kernel.profile,
            argument,
            &claims,
            &evidence,
            &assumption_cycles,
            &support_cycles,
            &mut diagnostics,
        ));
    }

    let claim_findings = claim_statuses(kernel, &findings, &assumption_cycles);
    sort_diagnostics(&mut diagnostics);
    findings.sort_by(|left, right| left.id.cmp(&right.id));

    let decision = if diagnostics
        .iter()
        .any(|item| item.severity == Severity::Error)
    {
        Decision::Rejected
    } else if findings
        .iter()
        .any(|item| item.structure == StatusAxis::Valid)
    {
        Decision::StructurallyValid
    } else {
        Decision::Pending
    };
    let claim_pending_axes = claim_pending_axes(&claim_findings);
    let argument_obligations = argument_obligations(&findings);
    let pending_count =
        u32::try_from(u64::from(argument_obligations) + u64::from(claim_pending_axes))
            .unwrap_or(u32::MAX);

    CheckReport {
        checker_version: CHECKER_VERSION.to_string(),
        profile: kernel.profile.as_str().to_string(),
        decision,
        claim_supported: false,
        argument_obligations,
        claim_pending_axes,
        pending_count,
        diagnostics,
        arguments: findings,
        claims: claim_findings,
        limits: LIMITS.to_string(),
    }
}

fn judge_argument(
    profile: ProfileId,
    argument: &LoadedArgument,
    claims: &BTreeMap<String, &Claim>,
    evidence: &BTreeMap<String, &EvidenceSpec>,
    assumption_cycles: &BTreeSet<String>,
    support_cycles: &BTreeMap<String, Vec<String>>,
    diagnostics: &mut Vec<Diagnostic>,
) -> ArgumentFinding {
    let mut codes = Vec::new();
    let mut obligations = Vec::new();
    let push =
        |diagnostics: &mut Vec<Diagnostic>, codes: &mut Vec<String>, code: &str, detail: &str| {
            diagnostics.push(error(code, &argument.id, detail));
            codes.push(code.to_string());
        };

    if !allows(profile, &argument.rule) {
        push(
            diagnostics,
            &mut codes,
            "unsupported_rule",
            &format!(
                "rule `{}` is not in profile `{}`; it stays unsupported and is not pending approval",
                argument.rule.canonical(),
                profile.as_str()
            ),
        );
    }

    let conclusion = match claims.get(&argument.conclusion) {
        Some(claim) => Some(*claim),
        None => {
            push(
                diagnostics,
                &mut codes,
                "missing_conclusion",
                &format!(
                    "conclusion `{}` does not resolve to a claim in this document; add the claim or fix the conclusion reference",
                    argument.conclusion
                ),
            );
            None
        }
    };

    let mut premises = Vec::new();
    for premise_id in &argument.premises {
        match claims.get(premise_id) {
            Some(claim) => premises.push(*claim),
            None => push(
                diagnostics,
                &mut codes,
                "missing_premise",
                &format!("premise `{premise_id}` does not resolve to a claim in this document; add the claim or fix the premise id"),
            ),
        }
    }

    let mut linked = Vec::new();
    for spec_id in &argument.evidence_specs {
        match evidence.get(spec_id) {
            Some(spec) if spec.claim_id == argument.conclusion => linked.push(*spec),
            Some(spec) => push(
                diagnostics,
                &mut codes,
                "evidence_link",
                &format!("evidence `{spec_id}` supports claim `{}`, not conclusion `{}`; link evidence only to its own conclusion", spec.claim_id, argument.conclusion),
            ),
            None => push(
                diagnostics,
                &mut codes,
                "evidence_link",
                &format!("evidence `{spec_id}` does not resolve to an evidence spec in this document; add the spec or fix the reference"),
            ),
        }
    }

    if let Some(conclusion) = conclusion {
        if premises.len() == argument.premises.len() {
            for premise in &premises {
                for finding in scope_differences(&premise.scope, &conclusion.scope) {
                    if matches!(argument.rule, Rule::ConditionalApplication)
                        && finding.lattice_widening
                    {
                        push(
                            diagnostics,
                            &mut codes,
                            "scope_widened",
                            "a scenario change cannot widen finite to countable or drop a scope key",
                        );
                    } else {
                        push(
                            diagnostics,
                            &mut codes,
                            "scope_mismatch",
                            &format!(
                                "premise scope does not match the conclusion: {}",
                                finding.detail
                            ),
                        );
                    }
                }
            }
        }
        if derivation_cycles(argument, conclusion, claims)
            || assumption_cycles.contains(&conclusion.id)
        {
            push(
                diagnostics,
                &mut codes,
                "cycle",
                &format!(
                    "derivation cycle: the premise chain reaches conclusion `{}`; break the loop or rely on an acyclic alternative argument for this claim",
                    conclusion.id
                ),
            );
        }
        if let Some(members) = support_cycles.get(&argument.id) {
            push(
                diagnostics,
                &mut codes,
                "support_cycle",
                &format!(
                    "this argument sits on a cross-argument support cycle covering {}; mutual derivation is not independent support",
                    members.join(", ")
                ),
            );
        }
        if codes.is_empty() {
            apply_rule(
                argument,
                conclusion,
                &premises,
                &linked,
                diagnostics,
                &mut codes,
                &mut obligations,
            );
        }
    }

    if codes.is_empty() {
        obligations.push(obligations::render(
            obligations::NO_REPLAY,
            "availability pending or candidate is not admitted evidence",
        ));
    }

    let structure = if codes.is_empty() {
        StatusAxis::Valid
    } else {
        StatusAxis::Invalid
    };
    codes.sort();
    codes.dedup();
    obligations.sort();
    obligations.dedup();
    let mixed_dossier = obligations
        .iter()
        .any(|item| obligations::is_mixed_dossier(item));
    ArgumentFinding {
        id: argument.id.clone(),
        rule: argument.rule.canonical(),
        structure,
        obligations,
        mixed_dossier,
        diagnostic_codes: codes,
    }
}

fn apply_rule(
    argument: &LoadedArgument,
    conclusion: &Claim,
    premises: &[&Claim],
    linked: &[&EvidenceSpec],
    diagnostics: &mut Vec<Diagnostic>,
    codes: &mut Vec<String>,
    obligations: &mut Vec<String>,
) {
    match &argument.rule {
        Rule::ModusPonens => {
            if premises.len() != 2 {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "mp_arity",
                    "modus ponens requires exactly two premises",
                );
                return;
            }
            let expressions = [
                premises[0].expression.clone(),
                premises[1].expression.clone(),
            ];
            let matches = (0..2).any(|index| {
                implication_matches(
                    &expressions[index],
                    &expressions[1 - index],
                    &conclusion.expression,
                )
            });
            if !matches {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "mp_conclusion",
                    "modus ponens requires exact AST: P and Implies(P, Q) yield Q",
                );
            } else {
                obligations.push(obligations::render(
                    obligations::NO_FORMAL_PROOF,
                    "exact AST is not a Lean proof",
                ));
            }
        }
        Rule::AndIntro => {
            if premises.len() < 2 {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "and_arity",
                    "and-introduction requires at least two premises",
                );
                return;
            }
            let expected = Expression::And {
                items: premises
                    .iter()
                    .map(|premise| premise.expression.clone())
                    .collect(),
            };
            if conclusion.expression != expected {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "and_conclusion",
                    "conclusion expression is not exactly And of the premise expressions, in order",
                );
            }
            let kinds: BTreeSet<&str> = premises
                .iter()
                .map(|premise| premise.kind.as_str())
                .collect();
            if kinds.len() > 1 {
                obligations.push(obligations::render(
                    obligations::MIXED_DOSSIER,
                    &format!(
                        "premises carry mixed claim kinds ({}); a dossier mixing kinds does not become a Lean theorem or an admitted claim",
                        kinds.into_iter().collect::<Vec<_>>().join(", ")
                    ),
                ));
            }
        }
        Rule::AliasExact => {
            if premises.len() != 1 {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "alias_arity",
                    "alias-exact requires one premise",
                );
                return;
            }
            if premises[0].expression != conclusion.expression
                || premises[0].scope != conclusion.scope
            {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "alias_mismatch",
                    "alias-exact requires the same expression and the same scope; prose paraphrase is editorial",
                );
            } else {
                obligations.push(obligations::render(
                    obligations::SEMANTIC_MAPPING_UNRESOLVED,
                    "natural-language sameness is not this rule",
                ));
            }
        }
        Rule::LeanAnchor => {
            if conclusion.kind != ClaimKind::Formal {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "lean_kind",
                    "a Lean anchor requires a formal claim",
                );
            }
            if !linked
                .iter()
                .any(|spec| evidence_is_formal_anchor(spec.kind))
            {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "lean_missing",
                    "a Lean anchor requires a lean evidence spec",
                );
            }
            obligations.push(obligations::render(
                obligations::NO_FORMAL_PROOF,
                "no Lean export was admitted",
            ));
        }
        Rule::LeanApply => {
            if conclusion.kind != ClaimKind::Formal {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "lean_kind",
                    "Lean apply requires a formal claim",
                );
            }
            if premises.is_empty() {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "lean_apply_premises",
                    "Lean apply needs the instantiated premises",
                );
            }
            if !linked
                .iter()
                .any(|spec| evidence_is_formal_anchor(spec.kind))
            {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "lean_missing",
                    "Lean apply requires a lean evidence spec for this conclusion",
                );
            }
            obligations.push(obligations::render(
                obligations::NO_FORMAL_PROOF,
                "a linked spec is not a wrapper result; compiling another theorem does not count",
            ));
        }
        Rule::EmpiricalRecord => {
            if conclusion.kind != ClaimKind::Empirical {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "empirical_promotion",
                    "an empirical record cannot promote a non-empirical claim",
                );
            }
            if !linked
                .iter()
                .any(|spec| evidence_is_computational(spec.kind))
            {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "python_missing",
                    "an empirical record requires a computational evidence spec",
                );
            }
            if linked
                .iter()
                .any(|spec| spec.kind == EvidenceKind::Registered)
            {
                obligations.push(obligations::render(
                    obligations::REGISTERED_RUNNER,
                    "a registered runner is not an experimental reproduction",
                ));
            }
            obligations.push(obligations::render(
                obligations::EMPIRICAL_NOT_REPRODUCED,
                "the spec records a planned run, not a result",
            ));
        }
        Rule::ConditionalApplication => {
            if conclusion.kind != ClaimKind::Conditional {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "conditional_kind",
                    "conditional application must conclude a conditional claim",
                );
            }
            if premises.is_empty() {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "conditional_premises",
                    "conditional application needs the theorem and the scenario",
                );
            }
            let mut required = BTreeSet::new();
            for premise in premises {
                required.insert(premise.id.clone());
                required.extend(premise.assumptions.iter().cloned());
            }
            let have: BTreeSet<String> = conclusion.assumptions.iter().cloned().collect();
            if !required.is_subset(&have) {
                fail(
                    diagnostics,
                    codes,
                    &argument.id,
                    "obligation_dropped",
                    "conditional application must retain every premise and assumption as an obligation",
                );
            }
            obligations.push(obligations::render(
                obligations::SCOPE_NOT_JUSTIFIED,
                "a simulation does not by itself discharge identification or population independence",
            ));
        }
        Rule::Unsupported(_) => {}
    }
}

fn implication_matches(
    candidate: &Expression,
    other: &Expression,
    conclusion: &Expression,
) -> bool {
    match candidate {
        Expression::Implies {
            antecedent,
            consequent,
        } => antecedent.as_ref() == other && consequent.as_ref() == conclusion,
        _ => false,
    }
}

fn derivation_cycles(
    argument: &LoadedArgument,
    conclusion: &Claim,
    claims: &BTreeMap<String, &Claim>,
) -> bool {
    let mut visiting = HashSet::new();
    visiting.insert(conclusion.id.clone());
    let mut done = HashSet::new();
    argument
        .premises
        .iter()
        .chain(conclusion.assumptions.iter())
        .any(|next| walk_assumptions(next, &mut visiting, &mut done, claims))
}

fn walk_assumptions(
    root: &str,
    visiting: &mut HashSet<String>,
    done: &mut HashSet<String>,
    claims: &BTreeMap<String, &Claim>,
) -> bool {
    if visiting.contains(root) {
        return true;
    }
    if done.contains(root) {
        return false;
    }
    let mut cyclic = false;
    let mut stack: Vec<(String, usize)> = Vec::new();
    visiting.insert(root.to_string());
    stack.push((root.to_string(), 0));
    while let Some((id, index)) = stack.last_mut() {
        let assumptions = claims
            .get(id.as_str())
            .map(|claim| claim.assumptions.as_slice())
            .unwrap_or(&[]);
        if *index >= assumptions.len() {
            let (finished, _) = stack.pop().expect("frame exists");
            visiting.remove(&finished);
            done.insert(finished);
            continue;
        }
        let next = assumptions[*index].clone();
        *index += 1;
        if visiting.contains(&next) {
            cyclic = true;
            continue;
        }
        if done.contains(&next) {
            continue;
        }
        visiting.insert(next.clone());
        stack.push((next, 0));
    }
    cyclic
}

fn assumption_cycle_claims(kernel: &Kernel) -> BTreeSet<String> {
    let claims = index_claims(kernel);
    let mut cyclic = BTreeSet::new();
    let mut visited = HashSet::new();
    for claim in &kernel.claims {
        if visited.contains(&claim.id) {
            continue;
        }
        let mut path: Vec<String> = Vec::new();
        let mut in_path: HashSet<String> = HashSet::new();
        let mut stack: Vec<(String, usize)> = Vec::new();
        path.push(claim.id.clone());
        in_path.insert(claim.id.clone());
        stack.push((claim.id.clone(), 0));
        while let Some((id, index)) = stack.last_mut() {
            let assumptions = claims
                .get(id.as_str())
                .map(|claim| claim.assumptions.as_slice())
                .unwrap_or(&[]);
            if *index >= assumptions.len() {
                let popped = stack.pop().expect("frame exists").0;
                path.pop();
                in_path.remove(&popped);
                visited.insert(popped);
                continue;
            }
            let next = assumptions[*index].clone();
            *index += 1;
            if in_path.contains(&next) {
                if let Some(start) = path.iter().position(|item| item == &next) {
                    cyclic.extend(path[start..].iter().cloned());
                }
                continue;
            }
            if visited.contains(&next) || !claims.contains_key(&next) {
                continue;
            }
            path.push(next.clone());
            in_path.insert(next.clone());
            stack.push((next, 0));
        }
    }
    cyclic
}

fn claim_statuses(
    kernel: &Kernel,
    findings: &[ArgumentFinding],
    assumption_cycles: &BTreeSet<String>,
) -> Vec<ClaimFinding> {
    // Index findings by argument id once, then bucket them by conclusion.
    // This replaces the old claims x arguments^2 double lookup.
    let finding_by_id: BTreeMap<&str, &ArgumentFinding> = findings
        .iter()
        .map(|finding| (finding.id.as_str(), finding))
        .collect();
    let mut findings_by_conclusion: BTreeMap<&str, Vec<&ArgumentFinding>> = BTreeMap::new();
    for argument in &kernel.arguments {
        if let Some(finding) = finding_by_id.get(argument.id.as_str()) {
            findings_by_conclusion
                .entry(argument.conclusion.as_str())
                .or_default()
                .push(*finding);
        }
    }
    let mut statuses = Vec::new();
    for claim in &kernel.claims {
        let concluding: &[&ArgumentFinding] = findings_by_conclusion
            .get(claim.id.as_str())
            .map(Vec::as_slice)
            .unwrap_or(&[]);
        let structure = if assumption_cycles.contains(&claim.id) {
            StatusAxis::Invalid
        } else if concluding
            .iter()
            .any(|finding| finding.structure == StatusAxis::Valid)
        {
            StatusAxis::Valid
        } else if !concluding.is_empty() {
            StatusAxis::Invalid
        } else {
            StatusAxis::Pending
        };
        let (formal, empirical) = axes_for(claim);
        statuses.push(ClaimFinding {
            id: claim.id.clone(),
            structure,
            formal,
            empirical,
            editorial: StatusAxis::Pending,
            argumentation: StatusAxis::NotRun,
        });
    }
    statuses.sort_by(|left, right| left.id.cmp(&right.id));
    statuses
}

fn axes_for(claim: &Claim) -> (StatusAxis, StatusAxis) {
    // A valid structure does not discharge either axis. Backing stays pending
    // until a future replay witness, which this function does not accept.
    // A factual claim asserts something about the world; without replay it
    // accumulates a pending axis too, instead of counting as clear.
    match claim.kind {
        ClaimKind::Formal => (StatusAxis::Pending, StatusAxis::NotApplicable),
        ClaimKind::Empirical => (StatusAxis::NotApplicable, StatusAxis::Pending),
        ClaimKind::Conditional => (StatusAxis::Conditional, StatusAxis::Conditional),
        ClaimKind::Factual => (StatusAxis::NotApplicable, StatusAxis::Pending),
    }
}

fn axis_open(axis: StatusAxis) -> bool {
    matches!(
        axis,
        StatusAxis::Pending | StatusAxis::Conditional | StatusAxis::Stale | StatusAxis::Failed
    )
}

fn argument_obligations(findings: &[ArgumentFinding]) -> u32 {
    let obligations = findings
        .iter()
        .filter(|finding| finding.structure == StatusAxis::Valid)
        .map(|finding| finding.obligations.len())
        .sum::<usize>();
    u32::try_from(obligations).unwrap_or(u32::MAX)
}

fn claim_pending_axes(claims: &[ClaimFinding]) -> u32 {
    let axes = claims
        .iter()
        .filter(|claim| axis_open(claim.formal) || axis_open(claim.empirical))
        .count();
    u32::try_from(axes).unwrap_or(u32::MAX)
}

fn index_claims(kernel: &Kernel) -> BTreeMap<String, &Claim> {
    kernel
        .claims
        .iter()
        .map(|claim| (claim.id.clone(), claim))
        .collect()
}

fn index_evidence(kernel: &Kernel) -> BTreeMap<String, &EvidenceSpec> {
    kernel
        .evidence_specs
        .iter()
        .map(|spec| (spec.id.clone(), spec))
        .collect()
}

fn fail(
    diagnostics: &mut Vec<Diagnostic>,
    codes: &mut Vec<String>,
    subject: &str,
    code: &str,
    detail: &str,
) {
    diagnostics.push(error(code, subject, detail));
    codes.push(code.to_string());
}

fn error(code: &str, subject: &str, detail: &str) -> Diagnostic {
    Diagnostic {
        code: code.to_string(),
        severity: Severity::Error,
        subject: subject.to_string(),
        detail: detail.to_string(),
    }
}

fn sort_diagnostics(diagnostics: &mut [Diagnostic]) {
    diagnostics.sort_by(|left, right| {
        (&left.code, &left.subject, &left.detail).cmp(&(&right.code, &right.subject, &right.detail))
    });
}
