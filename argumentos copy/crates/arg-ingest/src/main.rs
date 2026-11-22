use std::io::{self, Write};
use std::path::PathBuf;
use std::process::ExitCode;

use anyhow::{Context, Result};
use clap::{Parser, Subcommand};

#[derive(Debug, Parser)]
#[command(
    name = "argumentos-corpus",
    version,
    about = "Deterministic documentary ingestion; candidates remain unreviewed."
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Rebuild all deterministic artifacts after documentary coverage passes.
    Build {
        #[arg(long)]
        config: PathBuf,
        #[arg(long)]
        repository_root: PathBuf,
        #[arg(long)]
        output: PathBuf,
    },
    /// Regenerate in memory and compare every expected artifact byte-for-byte.
    Verify {
        #[arg(long)]
        config: PathBuf,
        #[arg(long)]
        repository_root: PathBuf,
        #[arg(long)]
        output: PathBuf,
    },
    /// Print deterministically ordered matching candidates as JSONL.
    Query {
        #[arg(long)]
        candidates: PathBuf,
        #[arg(long)]
        collection: Option<String>,
        #[arg(long)]
        topic: Option<String>,
        #[arg(long)]
        contains: Option<String>,
        #[arg(long)]
        limit: Option<usize>,
    },
}

fn main() -> ExitCode {
    match run() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("error: {error:#}");
            ExitCode::from(1)
        }
    }
}

fn run() -> Result<()> {
    match Cli::parse().command {
        Command::Build {
            config,
            repository_root,
            output,
        } => {
            let config = arg_ingest::load_config(&config)?;
            let coverage = arg_ingest::build(&config, &repository_root, &output)?;
            println!(
                "built {} artifacts; verified documentary coverage for {} regular files",
                arg_ingest::ARTIFACT_NAMES.len(),
                coverage.discovered_regular_files
            );
        }
        Command::Verify {
            config,
            repository_root,
            output,
        } => {
            let config = arg_ingest::load_config(&config)?;
            let report = arg_ingest::verify(&config, &repository_root, &output)?;
            println!(
                "verified {} artifacts and {} bytes; scientific validity remains uncertified",
                report.artifacts_compared, report.bytes_compared
            );
        }
        Command::Query {
            candidates,
            collection,
            topic,
            contains,
            limit,
        } => {
            let candidates = arg_ingest::load_candidates(&candidates)?;
            let filter = arg_ingest::QueryFilter {
                collection,
                topic,
                contains,
                limit,
            };
            let selected = arg_ingest::query_candidates(&candidates, &filter);
            let stdout = io::stdout();
            let mut writer = stdout.lock();
            for candidate in selected {
                serde_json::to_writer(&mut writer, &candidate)
                    .context("serializing query candidate")?;
                writer.write_all(b"\n").context("writing query JSONL")?;
            }
        }
    }
    Ok(())
}
