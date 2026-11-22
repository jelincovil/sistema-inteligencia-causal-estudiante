use thiserror::Error;

/// A document failed before any rule ran.
///
/// These are input-contract failures (exit 2). They are not mathematical
/// verdicts and they are not evidence failures.
#[derive(Debug, Error, PartialEq, Eq)]
pub enum ContractError {
    #[error("document is not valid UTF-8")]
    Utf8,
    #[error("JSON is not an object")]
    NotObject,
    #[error("JSON parse failed: {0}")]
    Json(String),
    #[error("duplicate JSON key `{key}` at {path}")]
    DuplicateKey { path: String, key: String },
    #[error("document exceeds the {limit}-byte limit (got {actual})")]
    InputTooLarge { limit: u64, actual: u64 },
    #[error("JSON exceeds the maximum depth of {limit}")]
    JsonTooDeep { limit: usize },
    #[error("JSON exceeds the maximum node count of {limit}")]
    JsonTooManyNodes { limit: usize },
    #[error("{what} exceeds the maximum of {limit} (got {actual})")]
    CollectionTooLarge {
        what: &'static str,
        limit: usize,
        actual: usize,
    },
    #[error("timestamp `{0}` is not an RFC3339 UTC second/fraction timestamp (YYYY-MM-DDTHH:MM:SS[.fraction]Z)")]
    BadTimestamp(String),
    #[error("started_at is after finished_at")]
    TimestampOrder,
    #[error("unsupported schema_version `{0}` (accepted: 1.0, 1.1)")]
    SchemaVersion(String),
    #[error("schema_version must be a string (`1.0` or `1.1`); got {0}")]
    SchemaVersionNonString(String),
    #[error("unknown profile `{0}` (known: scientific_audit, structural)")]
    Profile(String),
    #[error("duplicate identifier `{0}` across claims, arguments, evidence, and receipts")]
    DuplicateId(String),
    #[error(
        "identifier `{0}` does not match ^[A-Za-z][A-Za-z0-9_.:-]*$ or exceeds the length limit"
    )]
    BadId(String),
    #[error("claim `{0}` has an empty statement")]
    EmptyStatement(String),
    #[error("claim `{0}` uses `and` with fewer than two items")]
    AndArity(String),
    #[error("self-approval rejected: {0}")]
    SelfApproval(String),
    #[error("atom `{atom}` is not in the atom registry")]
    AtomNotRegistered { atom: String },
    #[error("atom `{atom}` is registered but never used by any claim expression")]
    UnusedAtom { atom: String },
    #[error(
        "atom registry entry `{atom}` names definition claim `{claim}`, which does not resolve"
    )]
    AtomDefinitionClaim { atom: String, claim: String },
    #[error("contract rejected: {0}")]
    Invalid(String),
}

impl ContractError {
    pub(crate) fn from_serde(err: serde_json::Error) -> Self {
        let message = err.to_string();
        if is_self_approval(&message) {
            return Self::SelfApproval(message);
        }
        Self::Json(message)
    }
}

/// Field or variant names that certify, close, or vouch for a claim.
///
/// A document that tries to write any of these as a key, a value, or a
/// variant is self-approving itself, and the loader fails closed. The list
/// is matched case-insensitively. Extending it is the safe direction:
/// an entry that never appears costs nothing.
pub(crate) const DENIED_CERTIFIERS: &[&str] = &[
    "approved",
    "admitted",
    "argumentation",
    "certified",
    "claim_supported",
    "corpus_closed",
    "decision",
    "editorial",
    "empirical",
    "evidence_replayed",
    "formal",
    "lean_checked",
    "reproduced",
    "scientific_validity_certified",
    "status",
    "structure",
    "trusted",
    "verified",
];

/// True when `name` certifies, closes, or vouches for a claim.
pub(crate) fn certifying_field(name: &str) -> bool {
    let normalized = name.trim().to_ascii_lowercase();
    DENIED_CERTIFIERS.contains(&normalized.as_str())
}

fn is_self_approval(message: &str) -> bool {
    let field = unknown_field(message).or_else(|| unknown_variant(message));
    let Some(field) = field else {
        return false;
    };
    certifying_field(field)
}

fn unknown_field(message: &str) -> Option<&str> {
    quoted_after(message, "unknown field `")
}

fn unknown_variant(message: &str) -> Option<&str> {
    quoted_after(message, "unknown variant `")
}

fn quoted_after<'a>(message: &'a str, marker: &str) -> Option<&'a str> {
    let start = message.find(marker)? + marker.len();
    let rest = &message[start..];
    let end = rest.find('`')?;
    Some(&rest[..end])
}
