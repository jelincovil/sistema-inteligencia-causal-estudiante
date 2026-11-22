mod corpus;

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use anyhow::{Context, Result};
use arg_check::{
    admit_receipt, check, ssch_one_decision_exact_v1, ByteVerification, CheckReport, Decision,
    LIMITS,
};
use arg_model::{evidence_spec_sha256, Kernel, Receipt};
use clap::{Parser, Subcommand};

#[derive(Debug, Parser)]
#[command(
    name = "argumentos",
    version,
    about = "Check an argument kernel. A passing check is not a certified corpus."
)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Debug, Subcommand)]
enum Command {
    /// Show profiles, limits, and the synthetic exact instance. Prints no credentials.
    Doctor,
    /// Check one kernel document. Exit 0 is structural only.
    Check {
        #[arg(long)]
        kernel: PathBuf,
        #[arg(long)]
        json: Option<PathBuf>,
        /// Exit 3 when any obligation remains. Does not create evidence.
        #[arg(long)]
        require_verified: bool,
        /// Verify receipt targets and artifacts against current local bytes.
        #[arg(long)]
        receipts: Option<PathBuf>,
        /// Write target-check lines and admission records to PATH as NDJSON:
        /// one JSON object per line, with kinds `receipt_input`,
        /// `receipt_artifact`, `admission`, and `spec_not_in_kernel`.
        /// PATH is created or truncated even when no lines are produced,
        /// yielding an empty file. Without this flag those lines are
        /// written to stderr. stdout carries the report (nothing when
        /// --json is set). Requires --receipts.
        #[arg(long, value_name = "PATH")]
        receipts_json: Option<PathBuf>,
        /// Project root used to verify the current bytes of receipt targets
        /// and artifacts. Defaults to `.`.
        #[arg(long, default_value = ".")]
        root: PathBuf,
    },
    /// Run the self-contained local fixture set. Rejects `invalid_*`.
    Fixtures {
        #[arg(long)]
        dir: PathBuf,
    },
    /// Audit local corpus structure and byte references; never certify claims.
    Corpus {
        #[arg(long)]
        dir: PathBuf,
        /// Project root for `local` source keys and registered artifact targets.
        /// Defaults to the parent of `--dir`.
        #[arg(long)]
        root: Option<PathBuf>,
        /// Write the deterministic JSON audit instead of printing it.
        #[arg(long)]
        json: Option<PathBuf>,
    },
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => code,
        Err(err) => {
            // Typed contract failures keep their message and the exit-2
            // contract channel; anything else is an environment/usage error.
            if let Some(contract) = err.downcast_ref::<arg_model::ContractError>() {
                eprintln!("contract: {contract}");
            } else {
                eprintln!("error: {err:#}");
            }
            ExitCode::from(2)
        }
    }
}

fn run() -> Result<ExitCode> {
    let cli = Cli::parse();
    match cli.command {
        Command::Doctor => {
            doctor();
            Ok(ExitCode::SUCCESS)
        }
        Command::Check {
            kernel,
            json,
            require_verified,
            receipts,
            receipts_json,
            root,
        } => check_path(
            &kernel,
            json.as_ref(),
            require_verified,
            receipts.as_ref(),
            receipts_json.as_ref(),
            &root,
        ),
        Command::Fixtures { dir } => fixtures(&dir),
        Command::Corpus { dir, root, json } => {
            corpus::audit(&dir, root.as_deref(), json.as_deref())
        }
    }
}

fn doctor() {
    println!("argumentos {}", env!("CARGO_PKG_VERSION"));
    println!("checker: {}", arg_check::CHECKER_VERSION);
    println!("profiles: scientific_audit (schema 1.0 default), structural (schema 1.1 default)");
    println!("evidence classes: lean, python, registered");
    println!("registered is trackable only; it is not a proof and not a reproduction");
    println!("limits: {LIMITS}");
    println!(
        "input limits: document {} bytes, JSON depth {}, JSON nodes {}, claims/arguments/specs {}, receipts {}, local file hash cap {} bytes",
        arg_model::MAX_DOCUMENT_BYTES,
        arg_model::MAX_JSON_DEPTH,
        arg_model::MAX_JSON_NODES,
        arg_model::MAX_COLLECTION,
        arg_model::MAX_RECEIPTS,
        arg_model::MAX_LOCAL_FILE_BYTES,
    );
    match ssch_one_decision_exact_v1() {
        Some(instance) => println!(
            "synthetic fixture {}: risk0={}, risk1={}, bayes={}, scope={}",
            instance.experiment,
            instance.risk0,
            instance.risk1,
            instance.bayes_risk,
            instance.scope
        ),
        None => println!("synthetic fixture ssch_one_decision_exact_v1: arithmetic error"),
    }
}

fn check_path(
    path: &Path,
    json: Option<&PathBuf>,
    require_verified: bool,
    receipts: Option<&PathBuf>,
    receipts_json: Option<&PathBuf>,
    root: &Path,
) -> Result<ExitCode> {
    if receipts.is_none() && receipts_json.is_some() {
        anyhow::bail!("--receipts-json requires --receipts");
    }
    let bytes = corpus::read_document_capped(path)?;
    let kernel = match Kernel::load(&bytes) {
        Ok(kernel) => kernel,
        Err(err) => {
            eprintln!("contract: {err}");
            return Ok(ExitCode::from(2));
        }
    };
    let report = check(&kernel);
    if let Some(receipts) = receipts {
        admit_file(&kernel, receipts, root, receipts_json)?;
    }
    let rendered = serde_json::to_string_pretty(&report)?;
    if let Some(out) = json {
        fs::write(out, format!("{rendered}\n"))
            .with_context(|| format!("writing {}", out.display()))?;
    } else {
        println!("{rendered}");
    }
    Ok(exit_for(&report, require_verified))
}

/// NDJSON destination for target-check lines and admission records.
///
/// The NDJSON stream is deterministic: receipts in file order, each
/// receipt's `input_hashes` in sorted-locator order, then artifacts in
/// array order, then the admission record. stdout never carries these
/// lines; it is reserved for the report.
enum AdmissionSink {
    Stderr(std::io::Stderr),
    File {
        writer: std::io::BufWriter<fs::File>,
        path: PathBuf,
    },
}

impl AdmissionSink {
    /// `--receipts-json PATH` creates or truncates PATH even when no lines
    /// are produced; without it the lines go to stderr.
    fn create(receipts_json: Option<&PathBuf>) -> Result<Self> {
        match receipts_json {
            Some(path) => {
                let file = fs::File::create(path)
                    .with_context(|| format!("creating receipts file {}", path.display()))?;
                Ok(Self::File {
                    writer: std::io::BufWriter::new(file),
                    path: path.clone(),
                })
            }
            None => Ok(Self::Stderr(std::io::stderr())),
        }
    }

    fn write_line(&mut self, value: &serde_json::Value) -> Result<()> {
        let text = serde_json::to_string(value).context("serializing receipt line")?;
        match self {
            Self::Stderr(stderr) => {
                writeln!(stderr, "{text}").context("writing receipt line to stderr")?;
            }
            Self::File { writer, path } => {
                writeln!(writer, "{text}")
                    .with_context(|| format!("writing receipt line to {}", path.display()))?;
            }
        }
        Ok(())
    }

    fn finish(mut self) -> Result<()> {
        match &mut self {
            Self::Stderr(stderr) => stderr.flush().context("flushing stderr")?,
            Self::File { writer, path } => writer
                .flush()
                .with_context(|| format!("flushing receipts file {}", path.display()))?,
        }
        Ok(())
    }
}

fn admit_file(
    kernel: &Kernel,
    path: &Path,
    root: &Path,
    receipts_json: Option<&PathBuf>,
) -> Result<()> {
    let canonical_root = corpus::canonical_root(root)?;
    let bytes = corpus::read_document_capped(path)?;
    let receipts = Receipt::load_all(&bytes)?;
    let mut sink = AdmissionSink::create(receipts_json)?;
    for receipt in &receipts {
        let Some(spec) = kernel
            .evidence_specs
            .iter()
            .find(|spec| spec.id == receipt.spec_id)
        else {
            sink.write_line(&serde_json::json!({
                "kind": "spec_not_in_kernel",
                "receipt_id": receipt.id,
                "spec_id": receipt.spec_id,
                "claim_supported": false,
            }))?;
            continue;
        };
        let hash = evidence_spec_sha256(spec)?;

        let mut input_hashes = ByteVerification::default();
        for (locator, expected) in &receipt.input_hashes {
            let target = corpus::verify_registered(&canonical_root, locator, expected);
            sink.write_line(&target_line(
                "receipt_input",
                &receipt.id,
                locator,
                expected,
                &target,
            ))?;
            input_hashes.absorb(target.outcome);
        }
        let mut artifacts = ByteVerification::default();
        for artifact in &receipt.artifacts {
            let target =
                corpus::verify_registered(&canonical_root, &artifact.path, &artifact.sha256);
            sink.write_line(&target_line(
                "receipt_artifact",
                &receipt.id,
                &artifact.path,
                &artifact.sha256,
                &target,
            ))?;
            artifacts.absorb(target.outcome);
        }

        let admission = admit_receipt(receipt, spec, &hash, &input_hashes, &artifacts);
        sink.write_line(&admission_line(&admission)?)?;
        if admission.claim_supported {
            anyhow::bail!("internal error: admission set claim_supported");
        }
    }
    sink.finish()
}

fn admission_line(admission: &arg_check::Admission) -> Result<serde_json::Value> {
    let mut value = serde_json::to_value(admission).context("serializing admission")?;
    if let Some(object) = value.as_object_mut() {
        object.insert("kind".to_string(), serde_json::json!("admission"));
    }
    Ok(value)
}

fn target_line(
    kind: &str,
    receipt_id: &str,
    locator: &str,
    expected: &str,
    target: &corpus::TargetCheck,
) -> serde_json::Value {
    let status = match target.outcome {
        arg_check::TargetOutcome::Matched => "matched",
        arg_check::TargetOutcome::Mismatched => "changed",
        arg_check::TargetOutcome::Missing => "missing",
        arg_check::TargetOutcome::Rejected => "rejected",
    };
    serde_json::json!({
        "kind": kind,
        "receipt_id": receipt_id,
        "locator": locator,
        "expected_sha256": expected,
        "actual_sha256": target.actual_sha256,
        "status": status,
        "reason": target.reason,
    })
}

fn fixtures(dir: &PathBuf) -> Result<ExitCode> {
    let mut entries = fs::read_dir(dir)
        .with_context(|| format!("reading {}", dir.display()))?
        .collect::<std::io::Result<Vec<_>>>()?;
    entries.sort_by_key(|entry| entry.file_name());
    let mut checks = Vec::new();
    let mut failed = false;
    for entry in entries {
        let path = entry.path();
        if path.extension().and_then(|ext| ext.to_str()) != Some("json") {
            continue;
        }
        let name = entry.file_name().to_string_lossy().to_string();
        let expected = !name.starts_with("invalid_");
        // An unreadable fixture aborts the run; an oversized one rejects
        // like any other contract failure.
        let bytes = match corpus::read_document_capped(&path) {
            Ok(bytes) => bytes,
            Err(error) => {
                if error.downcast_ref::<arg_model::ContractError>().is_some() {
                    Vec::new()
                } else {
                    return Err(error);
                }
            }
        };
        let accepted = match Kernel::load(&bytes) {
            Ok(kernel) => check(&kernel).decision == Decision::StructurallyValid,
            Err(_) => false,
        };
        if accepted != expected {
            failed = true;
        }
        checks.push(serde_json::json!({
            "file": name,
            "expected_accept": expected,
            "accepted": accepted,
        }));
    }
    if checks.is_empty() {
        failed = true;
    }
    let summary = serde_json::json!({
        "package_validation": if failed { "FAIL" } else { "PASS" },
        "self_contained": true,
        "fixture_count": checks.len(),
        "checks": checks,
        "corpus_closed": false,
        "scientific_validity_certified": false,
        "limit": LIMITS,
    });
    println!("{}", serde_json::to_string_pretty(&summary)?);
    if failed {
        Ok(ExitCode::from(1))
    } else {
        Ok(ExitCode::SUCCESS)
    }
}

fn exit_for(report: &CheckReport, require_verified: bool) -> ExitCode {
    if report.decision == Decision::Rejected {
        return ExitCode::from(3);
    }
    if require_verified
        && (report.pending_count > 0 || report.decision != Decision::StructurallyValid)
    {
        return ExitCode::from(3);
    }
    ExitCode::SUCCESS
}
