use argument_document::{EvidenceKind, ProfileId, Rule};

// No `Profile` handle type: the compiled-in rule set is selected by
// `ProfileId` from the document, and callers use `allows` directly. A
// wrapper struct was removed as dead code.
pub fn allows(profile: ProfileId, rule: &Rule) -> bool {
    match profile {
        ProfileId::ScientificAudit => matches!(
            rule,
            Rule::LeanAnchor
                | Rule::LeanApply
                | Rule::AndIntro
                | Rule::ModusPonens
                | Rule::EmpiricalRecord
                | Rule::ConditionalApplication
                | Rule::AliasExact
        ),
        ProfileId::Structural => {
            matches!(rule, Rule::ModusPonens | Rule::AndIntro | Rule::AliasExact)
        }
    }
}

pub fn evidence_is_formal_anchor(kind: EvidenceKind) -> bool {
    matches!(kind, EvidenceKind::Lean)
}

pub fn evidence_is_computational(kind: EvidenceKind) -> bool {
    matches!(kind, EvidenceKind::Python)
}
