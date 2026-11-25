use thiserror::Error;

#[derive(Debug, Error, PartialEq, Eq)]
pub enum SpeakError {
    #[error("unknown language `{0}` (accepted: en, es)")]
    Language(String),
    #[error("card is missing `{0}`")]
    Card(String),
    #[error("quote bytes [{start}, {end}) do not match the source")]
    Quote { start: usize, end: usize },
    #[error("{0}")]
    Lexicon(String),
    #[error("{0}")]
    Contract(String),
}
