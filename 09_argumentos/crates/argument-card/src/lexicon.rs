use std::collections::BTreeMap;

use serde::Deserialize;

use crate::error::SpeakError;
use crate::language::Language;

/// Authored hover glosses, one phrase per atom id.
///
/// A gloss explains an id the way a Verso hover explains a Lean name. It is
/// written by a person. It is not inferred, and it does not prove the id
/// means that phrase.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Lexicon {
    pub language: Language,
    entries: BTreeMap<String, String>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct RawLexicon {
    schema_version: String,
    language: String,
    entries: Vec<RawEntry>,
}

#[derive(Debug, Deserialize)]
#[serde(deny_unknown_fields)]
struct RawEntry {
    id: String,
    gloss: String,
}

impl Lexicon {
    pub fn empty(language: Language) -> Self {
        Self {
            language,
            entries: BTreeMap::new(),
        }
    }

    pub fn load(bytes: &[u8]) -> Result<Self, SpeakError> {
        let text = std::str::from_utf8(bytes)
            .map_err(|_| SpeakError::Lexicon("document is not valid UTF-8".to_string()))?;
        argument_document::reject_duplicate_keys(text)
            .map_err(|err| SpeakError::Lexicon(err.to_string()))?;
        let value: serde_json::Value = serde_json::from_str(text)
            .map_err(|err| SpeakError::Lexicon(approval_or_json(&err.to_string())))?;
        let raw: RawLexicon = serde_json::from_value(value)
            .map_err(|err| SpeakError::Lexicon(approval_or_json(&err.to_string())))?;
        if raw.schema_version != "1.0" {
            return Err(SpeakError::Lexicon(format!(
                "unsupported lexicon schema_version `{}`",
                raw.schema_version
            )));
        }
        let language = Language::parse(&raw.language)?;
        let mut entries = BTreeMap::new();
        for entry in raw.entries {
            if entry.gloss.trim().is_empty() {
                return Err(SpeakError::Lexicon(format!(
                    "gloss for `{}` is empty",
                    entry.id
                )));
            }
            if entries.insert(entry.id.clone(), entry.gloss).is_some() {
                return Err(SpeakError::Lexicon(format!(
                    "duplicate gloss for `{}`",
                    entry.id
                )));
            }
        }
        Ok(Self { language, entries })
    }

    pub fn gloss(&self, id: &str) -> Option<&str> {
        self.entries.get(id).map(String::as_str)
    }

    pub fn is_empty(&self) -> bool {
        self.entries.is_empty()
    }
}

fn approval_or_json(message: &str) -> String {
    const DENIED: &[&str] = &[
        "approved",
        "status",
        "claim_supported",
        "exact_generated",
        "agent_reviewed",
        "score",
    ];
    if DENIED.iter().any(|field| message.contains(field)) {
        format!("self-approval rejected: {message}")
    } else {
        message.to_string()
    }
}
