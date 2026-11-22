use std::path::PathBuf;
use std::process::ExitCode;

use anyhow::Result;
use causal_ml::{estimate_from_paths, prepare, render_from_paths};
use clap::{Parser, Subcommand};

#[derive(Debug, Parser)]
#[command(
    name = "causal-ml",
    version,
    about = "Deterministic data audits and conditional AIPW estimation; no command certifies causal identification."
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Validate a pinned CSV and write a deterministic audit, split manifest, and empty holdout ledger.
    Prepare {
        #[arg(long)]
        input: PathBuf,
        #[arg(long)]
        contract: PathBuf,
        #[arg(long)]
        output: PathBuf,
    },
    /// Run the frozen protocol once. A nonempty holdout ledger prevents reuse.
    Estimate {
        #[arg(long)]
        input: PathBuf,
        #[arg(long)]
        contract: PathBuf,
        #[arg(long)]
        output: PathBuf,
    },
    /// Verify and render existing artifacts as Markdown and Typst without opening raw outcomes.
    Report {
        #[arg(long)]
        contract: PathBuf,
        #[arg(long)]
        output: PathBuf,
        #[arg(long)]
        markdown: PathBuf,
        #[arg(long)]
        typst: PathBuf,
    },
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("error: {error:#}");
            ExitCode::from(2)
        }
    }
}

fn run() -> Result<()> {
    match Cli::parse().command {
        Command::Prepare {
            input,
            contract,
            output,
        } => {
            let preparation = prepare(&input, &contract, &output)?;
            println!(
                "{}",
                serde_json::to_string_pretty(&serde_json::json!({
                    "command": "prepare",
                    "status": preparation.audit.status,
                    "audit": preparation.audit_path,
                    "splits": preparation.splits_path,
                    "observations": preparation.audit.observation_count,
                    "split_manifest_sha256": preparation.audit.split_manifest_sha256,
                    "scientific_causal_claim_verified": false,
                }))?
            );
        }
        Command::Estimate {
            input,
            contract,
            output,
        } => {
            let report = estimate_from_paths(&input, &contract, &output)?;
            println!(
                "{}",
                serde_json::to_string_pretty(&serde_json::json!({
                    "command": "estimate",
                    "status": report.status,
                    "report": output.join("causal_report.json"),
                    "holdout_accessed": report.holdout.is_some(),
                    "holdout_outcomes_used_for_model_selection": report.holdout_outcomes_used_for_model_selection,
                    "scientific_causal_claim_verified": report.scientific_causal_claim_verified,
                }))?
            );
        }
        Command::Report {
            contract,
            output,
            markdown,
            typst,
        } => {
            let rendered = render_from_paths(&output, &contract, &markdown, &typst)?;
            println!(
                "{}",
                serde_json::to_string_pretty(&serde_json::json!({
                    "command": "report",
                    "markdown": rendered.markdown_path,
                    "typst": rendered.typst_path,
                    "report_sha256": rendered.report_sha256,
                    "scientific_causal_claim_verified": rendered.scientific_causal_claim_verified,
                }))?
            );
        }
    }
    Ok(())
}
