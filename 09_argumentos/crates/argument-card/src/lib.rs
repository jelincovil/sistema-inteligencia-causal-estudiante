//! Reading layer between a kernel argument and human language.
//!
//! Palomar keeps the formal statement apart from the informal account.
//! Comparator checks the formal side. A language-model review may report
//! that the informal wording looks fair, and that report is not an
//! endorsement. This crate is the same split for kernel arguments:
//!
//! - `render` writes a controlled card from the kernel. The card is a
//!   reading of the formal object, not a new argument.
//! - `parse_card` recovers that formal projection. Free prose does not.
//! - `review` compares a card, or an informal account, with the kernel
//!   and records findings. It never sets `claim_supported`.
//!
//! `argument-audit` does not depend on this crate. A reading cannot discharge
//! an obligation, widen a scope, or add a rule.

mod error;
mod fidelity;
mod language;
mod lexicon;
mod parse;
mod render;

pub use error::SpeakError;
pub use fidelity::{review_card, review_prose, FidelityReport, Finding, Outcome};
pub use language::Language;
pub use lexicon::Lexicon;
pub use parse::{check_quote, parse_card};
pub use render::{project, render, Projection, Reading};

pub const SPEAK_VERSION: &str = "0.1.0";

pub const SPEAK_LIMITS: &str = "Controlled card renders and parses the formal projection only. A glossary is an authored hover gloss, not a proof of meaning. Free prose is an informal account: the review may report a finding and cannot endorse alignment. No score is emitted. No language-model call is made. claim_supported stays false.";
