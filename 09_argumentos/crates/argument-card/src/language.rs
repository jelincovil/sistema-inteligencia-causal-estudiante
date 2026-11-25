use crate::error::SpeakError;

/// Fixed labels for the human paragraph. The formal keys stay in English
/// so a card parses in either language.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Language {
    En,
    Es,
}

impl Language {
    pub fn parse(value: &str) -> Result<Self, SpeakError> {
        match value {
            "en" => Ok(Self::En),
            "es" => Ok(Self::Es),
            other => Err(SpeakError::Language(other.to_string())),
        }
    }

    pub const fn as_str(self) -> &'static str {
        match self {
            Self::En => "en",
            Self::Es => "es",
        }
    }

    pub fn rule_gloss(self, rule: &str) -> &'static str {
        match (self, rule) {
            (Self::En, "MODUS_PONENS") => "exact modus ponens on the expressions, not on the wording",
            (Self::Es, "MODUS_PONENS") => "modus ponens exacto sobre las expresiones, no sobre la redacción",
            (Self::En, "AND_INTRO") => "and-introduction; the conclusion is exactly the conjunction, in order",
            (Self::Es, "AND_INTRO") => "introducción de la conjunción; la conclusión es exactamente esa conjunción, en orden",
            (Self::En, "ALIAS_EXACT") => "same expression and same scope; a paraphrase is not this rule",
            (Self::Es, "ALIAS_EXACT") => "misma expresión y mismo alcance; una paráfrasis no es esta regla",
            (Self::En, "LEAN_ANCHOR") => "a named Lean declaration is the intended anchor; no export was checked here",
            (Self::Es, "LEAN_ANCHOR") => "una declaración Lean nombrada es el ancla prevista; aquí no se revisó ninguna exportación",
            (Self::En, "LEAN_APPLY") => "premises would have to be instantiated by a Lean wrapper; compiling another theorem does not count",
            (Self::Es, "LEAN_APPLY") => "las premisas tendrían que instanciarse con un wrapper Lean; que compile otro teorema no cuenta",
            (Self::En, "EMPIRICAL_RECORD") => "a record of one specified run, not a universal or clinical claim",
            (Self::Es, "EMPIRICAL_RECORD") => "registro de una corrida especificada, no una afirmación universal ni clínica",
            (Self::En, "CONDITIONAL_APPLICATION") => "the conclusion stays conditional on every retained obligation",
            (Self::Es, "CONDITIONAL_APPLICATION") => "la conclusión sigue condicionada a cada obligación conservada",
            (Self::En, _) => "a rule name with no fixed gloss in this reading",
            (Self::Es, _) => "un nombre de regla sin glosa fija en esta lectura",
        }
    }
}
