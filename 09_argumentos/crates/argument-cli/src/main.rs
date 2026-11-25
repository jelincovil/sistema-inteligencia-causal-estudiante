mod corpus;

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::ExitCode;

use anyhow::{Context, Result};
use argument_audit::{
    admit_receipt, check, explain, ssch_one_decision_exact_v1, AuditGraph, ByteVerification,
    CheckReport, Decision, LIMITS,
};
use argument_card::{
    parse_card, project, render, review_card, review_prose, Language, Lexicon, Outcome,
    SPEAK_LIMITS,
};
use argument_document::{evidence_spec_sha256, Kernel, Receipt};
use clap::{Parser, Subcommand};

#[derive(Debug, Parser)]
#[command(
    name = "argument-audit",
    version,
    about = "Audit typed argument documents (claims, rules, evidence). A passing audit is not a certified corpus."
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
        /// Write a typed dependency graph for deterministic agent queries.
        #[arg(long)]
        emit_graph: Option<PathBuf>,
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
    /// Explain one node or finding without changing the audit verdict.
    Explain {
        /// Recompute the graph from a kernel.
        #[arg(long, required_unless_present = "graph", conflicts_with = "graph")]
        kernel: Option<PathBuf>,
        /// Read a graph previously written by `check --emit-graph`.
        #[arg(long, required_unless_present = "kernel", conflicts_with = "kernel")]
        graph: Option<PathBuf>,
        /// Typed node/finding id, or a unique bare claim/argument/evidence id.
        id: String,
    },
    /// Run the self-contained local fixture set. Rejects `invalid_*`.
    Fixtures {
        #[arg(long)]
        dir: PathBuf,
    },
    /// Render a controlled human card from a kernel. Not a certificate.
    Render {
        #[arg(long)]
        kernel: PathBuf,
        #[arg(long, default_value = "en")]
        language: String,
        #[arg(long)]
        lexicon: Option<PathBuf>,
        #[arg(long)]
        out: Option<PathBuf>,
    },
    /// Compare a card or free prose with the kernel. Exit 0 is not an endorsement.
    Align {
        #[arg(long)]
        kernel: PathBuf,
        #[arg(long)]
        text: PathBuf,
        #[arg(long, default_value = "en")]
        language: String,
        #[arg(long)]
        lexicon: Option<PathBuf>,
        /// Treat the text as free prose even if it has no argument keys.
        #[arg(long)]
        prose: bool,
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
            if let Some(contract) = err.downcast_ref::<argument_document::ContractError>() {
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
            emit_graph,
            require_verified,
            receipts,
            receipts_json,
            root,
        } => check_path(
            &kernel,
            json.as_ref(),
            emit_graph.as_ref(),
            require_verified,
            receipts.as_ref(),
            receipts_json.as_ref(),
            &root,
        ),
        Command::Explain { kernel, graph, id } => {
            explain_path(kernel.as_ref(), graph.as_ref(), &id)
        }
        Command::Fixtures { dir } => fixtures(&dir),
        Command::Render {
            kernel,
            language,
            lexicon,
            out,
        } => render_path(&kernel, &language, lexicon.as_ref(), out.as_ref()),
        Command::Align {
            kernel,
            text,
            language,
            lexicon,
            prose,
        } => align_path(&kernel, &text, &language, lexicon.as_ref(), prose),
        Command::Corpus { dir, root, json } => {
            corpus::audit(&dir, root.as_deref(), json.as_deref())
        }
    }
}

fn doctor() {
    println!("argument-audit {}", env!("CARGO_PKG_VERSION"));
    println!("checker: {}", argument_audit::CHECKER_VERSION);
    println!("profiles: scientific_audit (schema 1.0 default), structural (schema 1.1 default)");
    println!("evidence classes: lean, python, registered");
    println!("registered is trackable only; it is not a proof and not a reproduction");
    println!("limits: {LIMITS}");
    println!("reading: {SPEAK_LIMITS}");
    println!(
        "input limits: document {} bytes, JSON depth {}, JSON nodes {}, claims/arguments/specs {}, receipts {}, local file hash cap {} bytes",
        argument_document::MAX_DOCUMENT_BYTES,
        argument_document::MAX_JSON_DEPTH,
        argument_document::MAX_JSON_NODES,
        argument_document::MAX_COLLECTION,
        argument_document::MAX_RECEIPTS,
        argument_document::MAX_LOCAL_FILE_BYTES,
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
    emit_graph: Option<&PathBuf>,
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
    if let Some(out) = emit_graph {
        let graph = AuditGraph::from_report(&kernel, &report)
            .map_err(|err| anyhow::anyhow!(err.to_string()))?;
        let rendered = serde_json::to_string_pretty(&graph)?;
        fs::write(out, format!("{rendered}\n"))
            .with_context(|| format!("writing {}", out.display()))?;
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

fn explain_path(kernel: Option<&PathBuf>, graph: Option<&PathBuf>, id: &str) -> Result<ExitCode> {
    let graph = match (kernel, graph) {
        (Some(path), None) => {
            let kernel = load_kernel(path)?;
            let report = check(&kernel);
            AuditGraph::from_report(&kernel, &report)
                .map_err(|err| anyhow::anyhow!(err.to_string()))?
        }
        (None, Some(path)) => {
            let bytes = corpus::read_document_capped(path)?;
            AuditGraph::from_json_slice(&bytes).map_err(|err| anyhow::anyhow!(err.to_string()))?
        }
        _ => anyhow::bail!("provide exactly one of --kernel or --graph"),
    };
    let explanation = explain(&graph, id).map_err(|err| anyhow::anyhow!(err.to_string()))?;
    if explanation.claim_supported {
        anyhow::bail!("internal error: an explanation certified a claim");
    }
    println!("{}", serde_json::to_string_pretty(&explanation)?);
    Ok(ExitCode::SUCCESS)
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

fn admission_line(admission: &argument_audit::Admission) -> Result<serde_json::Value> {
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
        argument_audit::TargetOutcome::Matched => "matched",
        argument_audit::TargetOutcome::Mismatched => "changed",
        argument_audit::TargetOutcome::Missing => "missing",
        argument_audit::TargetOutcome::Rejected => "rejected",
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
                if error
                    .downcast_ref::<argument_document::ContractError>()
                    .is_some()
                {
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

fn render_path(
    path: &Path,
    language: &str,
    lexicon: Option<&PathBuf>,
    out: Option<&PathBuf>,
) -> Result<ExitCode> {
    let kernel = load_kernel(path)?;
    let language = Language::parse(language).map_err(|err| anyhow::anyhow!(err.to_string()))?;
    let lexicon = load_lexicon(lexicon, language)?;
    let reading =
        render(&kernel, &lexicon, language).map_err(|err| anyhow::anyhow!(err.to_string()))?;
    if let Some(path) = out {
        fs::write(path, &reading.card).with_context(|| format!("writing {}", path.display()))?;
    } else {
        print!("{}", reading.card);
    }
    eprintln!(
        "reading: claim_supported=false alignment_guaranteed=false glosses_pending={}",
        reading.glosses_pending.len()
    );
    Ok(ExitCode::SUCCESS)
}

fn align_path(
    kernel_path: &Path,
    text_path: &Path,
    language: &str,
    lexicon: Option<&PathBuf>,
    prose: bool,
) -> Result<ExitCode> {
    let kernel = load_kernel(kernel_path)?;
    let language = Language::parse(language).map_err(|err| anyhow::anyhow!(err.to_string()))?;
    let lexicon = load_lexicon(lexicon, language)?;
    let bytes = corpus::read_document_capped(text_path)?;
    let text = String::from_utf8(bytes)
        .with_context(|| format!("reading {} as UTF-8", text_path.display()))?;
    let looks_like_card = text.lines().any(|line| line.starts_with("argument: "))
        || text.starts_with("argument-card ");
    let report = if prose || !looks_like_card {
        review_prose(&kernel, &text, &lexicon).map_err(|err| anyhow::anyhow!(err.to_string()))?
    } else {
        review_card(&kernel, &text, &lexicon, language)
            .map_err(|err| anyhow::anyhow!(err.to_string()))?
    };
    let parsed_matches = match (parse_card(&text), project(&kernel)) {
        (Ok(parsed), Ok(formal)) => parsed == formal,
        _ => false,
    };
    println!("{}", serde_json::to_string_pretty(&report)?);
    eprintln!(
        "align: outcome={} endorsement={} formal_round_trip={parsed_matches}",
        outcome_label(report.outcome),
        report.endorsement
    );
    if report.claim_supported || report.alignment_guaranteed {
        anyhow::bail!("internal error: a reading review certified alignment");
    }
    Ok(exit_for_review(report.outcome))
}

fn load_kernel(path: &Path) -> Result<Kernel> {
    let bytes = corpus::read_document_capped(path)?;
    Ok(Kernel::load(&bytes)?)
}

fn load_lexicon(path: Option<&PathBuf>, language: Language) -> Result<Lexicon> {
    let Some(path) = path else {
        return Ok(Lexicon::empty(language));
    };
    let bytes = corpus::read_document_capped(path)?;
    Lexicon::load(&bytes).map_err(|err| anyhow::anyhow!(err.to_string()))
}

fn outcome_label(outcome: Outcome) -> &'static str {
    match outcome {
        Outcome::NoBlockingProblem => "no_blocking_problem",
        Outcome::BlockingProblem => "blocking_problem",
        Outcome::Unresolved => "unresolved",
    }
}

fn exit_for_review(outcome: Outcome) -> ExitCode {
    match outcome {
        Outcome::NoBlockingProblem | Outcome::Unresolved => ExitCode::SUCCESS,
        Outcome::BlockingProblem => ExitCode::from(3),
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
