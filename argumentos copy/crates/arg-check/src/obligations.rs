//! The closed vocabulary of obligation codes emitted by the checker.
//!
//! An obligation is a typed sentence `"CODE: detail"` carried by a
//! structurally valid argument. It is not a diagnostic and it is never an
//! approval; it records what still has to happen before a claim could be
//! admitted. This module is the single place that names the prefixes;
//! classification (for example `mixed_dossier`) goes through
//! [`obligation_code`] instead of ad hoc `starts_with` checks.

/// Availability (pending or candidate) was recorded; nothing was replayed.
pub const NO_REPLAY: &str = "NO_REPLAY";
/// A Lean-facing obligation remains; no Lean export was admitted.
pub const NO_FORMAL_PROOF: &str = "NO_FORMAL_PROOF";
/// Premises or evidence mix claim kinds; a mixed dossier is not a theorem.
pub const MIXED_DOSSIER: &str = "MIXED_DOSSIER";
/// Natural-language sameness was not established by `ALIAS_EXACT`.
pub const SEMANTIC_MAPPING_UNRESOLVED: &str = "SEMANTIC_MAPPING_UNRESOLVED";
/// A registered runner is tracked, not an experimental reproduction.
pub const REGISTERED_RUNNER: &str = "REGISTERED_RUNNER";
/// A recorded plan is not a reproduced result.
pub const EMPIRICAL_NOT_REPRODUCED: &str = "EMPIRICAL_NOT_REPRODUCED";
/// Identification or population independence was not discharged.
pub const SCOPE_NOT_JUSTIFIED: &str = "SCOPE_NOT_JUSTIFIED";

/// Every obligation prefix this checker emits, sorted for determinism.
pub const ALL: &[&str] = &[
    EMPIRICAL_NOT_REPRODUCED,
    MIXED_DOSSIER,
    NO_FORMAL_PROOF,
    NO_REPLAY,
    REGISTERED_RUNNER,
    SCOPE_NOT_JUSTIFIED,
    SEMANTIC_MAPPING_UNRESOLVED,
];

/// Render one obligation from its code and detail.
pub fn render(code: &str, detail: &str) -> String {
    format!("{code}: {detail}")
}

/// Extract the obligation code from an obligation sentence.
///
/// Accepts `"CODE"` and `"CODE: detail"`. Returns `None` for anything
/// else, including empty details attached to unknown codes, so a typo in
/// a hand-written obligation can never be misclassified as a known code.
pub fn obligation_code(obligation: &str) -> Option<&'static str> {
    ALL.iter().copied().find(|code| {
        obligation
            .strip_prefix(code)
            .is_some_and(|rest| rest.is_empty() || rest.starts_with(':'))
    })
}

/// True when the obligation carries the [`MIXED_DOSSIER`] code.
pub fn is_mixed_dossier(obligation: &str) -> bool {
    obligation_code(obligation) == Some(MIXED_DOSSIER)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn all_emitted_prefixes_roundtrip_through_the_classifier() {
        for code in ALL {
            assert_eq!(
                obligation_code(&format!("{code}: detail text")),
                Some(*code),
                "{code} with detail must classify"
            );
            assert_eq!(
                obligation_code(code),
                Some(*code),
                "{code} alone must classify"
            );
            assert_eq!(
                obligation_code(&render(code, "detail")),
                Some(*code),
                "rendered {code} must classify"
            );
        }
    }

    #[test]
    fn unknown_or_malformed_codes_classify_as_none() {
        assert_eq!(obligation_code("APPROVED: looks good"), None);
        assert_eq!(obligation_code("NO_REPLAYX: extension is not a code"), None);
        assert_eq!(obligation_code("no_replay: lower case is not a code"), None);
        assert_eq!(obligation_code(""), None);
        assert_eq!(obligation_code("NO REPLAY: spaces are not colons"), None);
    }

    #[test]
    fn mixed_dossier_classification_is_exact() {
        assert!(is_mixed_dossier(
            "MIXED_DOSSIER: premises carry mixed claim kinds (empirical, formal)"
        ));
        assert!(!is_mixed_dossier(
            "NO_REPLAY: availability pending or candidate is not admitted evidence"
        ));
        assert!(!is_mixed_dossier("MIXED_DOSSIERX: impostor"));
    }

    #[test]
    fn all_is_sorted_and_closed() {
        let mut sorted = ALL.to_vec();
        sorted.sort_unstable();
        assert_eq!(ALL, sorted.as_slice(), "ALL stays sorted for determinism");
        assert_eq!(
            ALL.len(),
            7,
            "the obligation vocabulary is closed; additions are a software change"
        );
    }
}
