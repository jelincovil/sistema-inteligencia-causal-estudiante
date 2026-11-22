# Implementation report

**Project:** Causal ML/AI: identification, implementation, and evidence  
**Final validation date:** 2026-11-22 UTC  
**Scope:** `argumentos copy/`, plus declared read-only documentary ingestion from `02_causal AI en produccion/`, `05_contenido_tecnico/`, and `08_mcp-agentes-causales/` in the parent repository

## 1. Delivered system and evidence boundary

This directory is a Rust workspace with local typed-kernel, fixture, book, and bundled-data workflows, plus explicit read-only documentary ingestion from three parent-repository collections. It combines:

- a hardened, 1.1, atom-aware typed argument kernel with its two scientific profiles;
- a nine-chapter, cited Typst book with mathematical derivations;
- a byte-pinned public observational LaLonde/NSW–PSID CSV and provenance record;
- deterministic CSV/data-contract auditing, transformations, split allocation, and holdout bookkeeping;
- an executable five-fold cross-fitted AIPW analysis with declared nuisance learners; and
- a claim/evidence corpus that links theory, provenance, identification, estimation, diagnostics, and limitations without treating pending evidence as verified; and
- a deterministic documentary build/verify/query workflow that inventories the complete declared source scope, preserves exact source spans and hashes, and extracts explicitly unreviewed argument candidates.

The software checks below passed. **No causal claim, evidence corpus, data-value license, or production deployment is certified by those checks.** In particular, `scientific_causal_claim_verified`, `claim_supported`, `corpus_closed`, `semantically_curated_corpus_complete`, and `scientific_validity_certified` remain false where applicable.

No files outside this directory were edited. The three imported source collections were read but never modified or executed. No Git staging, commits, branch operations, deletion, or reversion of user work was performed. All computational project tooling is Rust. The preserved `python` evidence class in the legacy kernel is an enum value only; no Python runner or auxiliary Python script was added. Build and replay outputs are under ignored `/build/`; Cargo output is under ignored `/target/`.

## 2. Preserved kernel semantics

The implementation retains the existing typed model and checker while deeply hardening them. `README.md` documents the contracts and their limits. The preserved and extended behavior includes:

1. kernel schema 1.0 defaults to `scientific_audit`, while schema 1.1 defaults to `structural` unless a compiled profile is declared;
2. strict typed claims, expressions, dependencies, sources, evidence specifications, and scientific profiles;
3. rejection of duplicate keys and self-authored privileged statuses;
4. canonical content hashes and both derivation-local and cross-argument cycle handling;
5. candidate receipts bound to an evidence-specification hash and current in-root bytes where available;
6. no promotion of a receipt, structural result, or registered target into `claim_supported`;
7. bounded input parsing, strict root/symlink containment, and closed-world atom registry enforcement; and
8. fail-closed scope equality except explicitly declared aggregation keys and the narrow domain lattice.

`crates/arg-cli` adds the project-facing `doctor`, `check`, `fixtures`, and recursive `corpus` workflows. The corpus inventory binds claims to current local file bytes, finds cross-file ID collisions and missing sources/artifacts, and reports pending obligations. It deliberately does not replay external processes, run Lean, verify prose anchors, or infer scientific validity. `doctor` also reports these limitations directly.

The fixture and hardening suites remain self-contained under `examples/fixtures/` and integration tests; no workflow depends on a sealed sibling repository or an assertion about an earlier external repository state.

## 3. Theory/book implementation

`book/main.typ` assembles nine substantive chapters and `book/references.bib` supplies 20 scholarly entries. `book/LITERATURE_MATRIX.md` maps those sources to evidentiary roles without treating literature lookup as replay. The content covers:

- explicit association, prediction, counterfactual, and operational claim taxonomy;
- structural causal models, DAGs, potential outcomes, estimands, and randomization;
- observational identification, backdoor adjustment, and the distinction among confounders, colliders, and mediators;
- consistency, interference, positivity/overlap, and correct-temporal-order requirements;
- IPW/AIPW derivations, influence-function reasoning, cross-fitting, and DML;
- CATE/meta-learners and policy learning as theory rather than fabricated executable results;
- diagnostics versus untestable assumptions;
- sampling uncertainty, sensitivity, and transportability;
- feature availability, entity/epoch split governance, monitoring/deployment, and evidence limits; and
- the implementation-level argument/evidence kernel.

The generated empirical fragment in `book/generated/lalonde.typ` comes from the saved Rust artifact; it is not a hand-invented result table. The detailed limitations explain why an executable adjusted contrast is not automatic causal identification.

### Compilation result

```sh
mkdir -p build/book
typst compile book/main.typ build/book/causal-ml-book.pdf --root .
pdfinfo build/book/causal-ml-book.pdf
shasum -a 256 build/book/causal-ml-book.pdf
```

- Typst: **0.15.1**; compilation **succeeded**.
- PDF: **33 pages**, A4, tagged, PDF 1.7; 616,719 bytes at this final bibliographically normalized compilation.
- PDF SHA-256 at this compilation: `c1f5e48f34351e3392116189b229726bf39a9b4ed948693c8f44e8c5dbb4a895`.
- Output location: `build/book/causal-ml-book.pdf` (ignored, not a checked-in evidentiary artifact).

PDF metadata and hashes are observations about this local compilation, not claims of byte-stable output across different Typst versions or build timestamps.

## 4. Genuine real-data provenance and verification

### Included object

The genuine public input is `data/real/lalonde.csv`, the MatchIt `lalonde` sample mirrored by Rdatasets. It contains NSW treated observations and a nonexperimental PSID comparison sample. It is **not** relabelled randomized NSW data, Jobs/IHDP data, or synthetic data.

| Field | Recorded value |
|---|---|
| Stable raw URL | `https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/1dcc2bf5f955cc1224a3e1307256e1fe86b68dae/csv/MatchIt/lalonde.csv` |
| Pinned documentation | `https://raw.githubusercontent.com/vincentarelbundock/Rdatasets/1dcc2bf5f955cc1224a3e1307256e1fe86b68dae/doc/MatchIt/lalonde.html` |
| Repository commit pinned at retrieval | `1dcc2bf5f955cc1224a3e1307256e1fe86b68dae` |
| Retrieval record | `data/real/PROVENANCE.md` |
| Raw size | 27,509 bytes |
| Raw SHA-256 | `a49703ca0233ba0a27fa9cda959a38a07f6825def0f7743cf2380ce4e57dd3ef` |
| Rows | 614 source observations plus CSV header |
| Treatment/control | 185 treated / 429 comparison observations |
| Unit ID | `rownames`, treated as a source-row identifier |
| Treatment | `treat` |
| Outcome | `re78`, nominal 1978 earnings |
| Baseline covariates | `age`, `educ`, `race`, `married`, `nodegree`, `re74`, `re75` |

The raw artifact is retained without editing values, labels, or row order to make exact reproduction possible. Its inclusion is not a new license grant.

### Direct upstream checks

Direct `curl`/file-read checks were used; no Firecrawl source was used. Retrieved reference files and response headers were placed in ignored `build/reverification/upstream/`. The later byte comparison used:

```sh
cmp data/real/lalonde.csv build/reverification/upstream/lalonde.csv
wc -c data/real/lalonde.csv build/reverification/upstream/lalonde.csv
shasum -a 256 data/real/lalonde.csv build/reverification/upstream/lalonde.csv
```

All passed: both files were 27,509 bytes and had the SHA-256 above. The direct response was HTTP 200 with `content-length: 27509` and response date `Sun, 22 Nov 2026 02:51:45 GMT`. These network observations are not trusted publication timestamps.

The upstream `lalonde.html` documentation reports 614 observations, the NSW-treated/PSID-comparison construction, treatment/outcome meanings, and baseline covariates. The MatchIt package `DESCRIPTION` inspected during the check reports MatchIt 4.8.2 and package GPL (>=2). The Rdatasets README licenses its code under GPL-3 but explicitly describes the difficulty of determining a definitive license for actual copied rows/columns.

**License/status remains `unresolved_upstream` for data values.** Neither the MatchIt package statement nor the Rdatasets code statement was converted into an asserted dataset-value license. Before redistribution outside this reproducibility context, the rights question needs independent review.

### Data audit

The source byte count/hash matched the strict contract. The audit found:

- zero missing required cells;
- zero duplicate unit IDs;
- zero exact duplicate records;
- five repeated measurement vectors after excluding the row ID, retained as warnings rather than inferred repeated people;
- declared ranges/types respected; and
- no supplied epoch, so temporal separation is unavailable rather than fabricated.

`README.md`, `data/real/PROVENANCE.md`, and `book/chapters/06-lalonde-case.typ` document the observational identification boundary. Synthetic numerical tests live separately in generated test output and never constitute provenance for these empirical numbers.

## 5. Frozen analytical protocol and estimator

`config/lalonde.contract.json` binds the expected raw bytes/hash and declares roles, feature availability, ranges/categories, split rules, transformations, and the estimator. Its SHA-256 is `f66da858ea890ec4b89eb0fd2e4e4a167dd4a7815e450cd64acdcea8c23e5f86`.

The protocol is deliberately simple:

1. salted entity-hash assignment into 60% train, 20% calibration, and 20% holdout;
2. identity transforms for ordinary covariates and `log1p` for `re74`/`re75`;
3. five deterministic folds within train;
4. fold-local standardization;
5. main-effects logistic IRLS for propensity, unpenalized intercept, fixed ridge for other coefficients;
6. separate treatment-level ridge-linear outcome regressions;
7. clipping of propensity at the fixed primary value 0.05, with predeclared calculations at 0.01 and 0.10;
8. a calibration gate restricted to computational/treatment-propensity diagnostics using features and treatment only, followed by descriptive calibration `re78` outcome means reported as associations and never used for selection or revision; and
9. one final holdout evaluation with train-only nuisance fits, recorded in a local append-only ledger.

For held-out fold observations, the implemented AIPW score is

\[
\widehat\psi_i = \widehat\mu_1(X_i)-\widehat\mu_0(X_i)
+ \frac{T_i\{Y_i-\widehat\mu_1(X_i)\}}{\widetilde e(X_i)}
- \frac{(1-T_i)\{Y_i-\widehat\mu_0(X_i)\}}{1-\widetilde e(X_i)},
\qquad \widehat\tau = n^{-1}\sum_i \widehat\psi_i .
\]

The nuisance fits for a cross-fitted score exclude that observation’s training fold. Final holdout scores use train-only fits. Reported intervals use the empirical influence-function standard error and a normal reference. Clipping is explicit: it changes the weights/numerical target and does not repair nonpositivity.

The estimand has a split-specific ATE interpretation only under consistency, noninterference, conditional mean exchangeability given the declared measured covariates, positivity, and a well-defined treatment/target population. Those substantive assumptions are not verified. The descriptive mean-difference outputs are labelled `association_only`; the adjusted results are labelled conditional, not proven causal effects.

No model, features, transform, split, clipping rule, or threshold was selected or revised from final holdout outcomes. The checked-in output is an already-consumed final protocol record. Repeating estimation in its directory is refused. A fresh output directory allows byte-reproducibility testing, not a new opportunity to tune against holdout results.

## 6. Actual empirical outputs

The values below were read from `artifacts/lalonde/report.md` and `artifacts/lalonde/causal_report.json`; the localized-review replay reproduced the current deterministic files byte-for-byte. A separate comparison against the preserved pre-review report confirmed all 421 pre-existing numeric leaves unchanged, with 19 numeric additions from confidence metadata and no missing or changed baseline values. Dollar values are nominal and are not inflation-adjusted here.

| Quantity | Artifact result | Interpretation |
|---|---:|---|
| Observations | 614 | NSW treated + nonexperimental PSID comparison |
| Train/calibration/holdout | 366 / 114 / 134 | deterministic source-ID allocation |
| Raw all-row treated-minus-control difference | −635.0 nominal dollars | associational, not causal |
| Train cross-fitted AIPW, clip 0.05 | −269.3 | conditional adjusted contrast |
| Train IF standard error | 1023.1 | approximate sampling uncertainty only |
| Train normal 95% interval | [−2274.4, 1735.9] | excludes hidden-confounding/transport uncertainty |
| Final holdout AIPW, clip 0.05 | 426.3 | one final evaluation, not model selection |
| Holdout IF standard error | 1821.9 | wide interval; not causal certainty |
| Holdout normal 95% interval | [−3144.6, 3997.3] | compatible with a broad range of contrasts |
| Raw propensity outside [0.05, 0.95], calibration | 44 / 114 (38.6%) | visible warning beside the computational gate |
| Raw propensity outside [0.05, 0.95], train | 138 / 366 | serious support warning |
| Raw propensity outside [0.05, 0.95], holdout | 41 / 134 | serious support warning |

All recorded nuisance optimizations converged and none was flagged for suspected separation. That computational status does not resolve overlap, identification, model misspecification, or influential-tail concerns. In particular, 44 of 114 calibration observations (38.6%) have raw propensities outside [0.05, 0.95]; the report places this quantitative weak-overlap warning beside the gate status, and a passing gate is computational rather than scientific approval. Linear outcome predictions are not truncated to nonnegative earnings. Calibration records `outcome_used_in_gate: false` and `outcomes_reported_descriptively: true`; the legacy `outcome_used` field is explicitly a gate-only alias, not a claim that calibration outcomes are never read. The final ledger records one `H001-final-only` event and `model_changes_permitted: false`.

The full-precision source of truth is `artifacts/lalonde/causal_report.json`. The registered sensitivity clipping calculations are reported in the artifact, but are **not** hidden-confounding bounds or an invitation to select a preferred answer. No CATE, treatment policy, deployed threshold, automated decision, or production monitoring result is claimed.

## 7. Executed real-data clean replay

A new ignored output directory was used so the checked-in consumed holdout was not reopened:

`build/review-fixes-20261122/lalonde/`

The following commands were actually executed once, in order:

```sh
cargo run --locked -p causal-ml -- prepare \
  --input data/real/lalonde.csv \
  --contract config/lalonde.contract.json \
  --output build/review-fixes-20261122/lalonde

cargo run --locked -p causal-ml -- estimate \
  --input data/real/lalonde.csv \
  --contract config/lalonde.contract.json \
  --output build/review-fixes-20261122/lalonde

cargo run --locked -p causal-ml -- report \
  --contract config/lalonde.contract.json \
  --output build/review-fixes-20261122/lalonde \
  --markdown build/review-fixes-20261122/lalonde/report.md \
  --typst build/review-fixes-20261122/lalonde/lalonde.typ
```

- `prepare`: passed; 614 observations validated, status `pass`, scientific causal claim verification false.
- `estimate`: passed; one holdout event added in this clean replay, no holdout-based model selection, scientific causal claim verification false.
- `report`: passed; report SHA-256 `9193ea4574ab202e0b771cc0b5db7f4f74c6ddd6f24c676dd0850dfb7beba70b`.
- Estimation was not rerun into this directory or into `artifacts/lalonde/` after that single replay.

After promotion of the deterministic outputs, the following six `cmp` commands all exited successfully:

```sh
cmp artifacts/lalonde/audit.json build/review-fixes-20261122/lalonde/audit.json
cmp artifacts/lalonde/splits.csv build/review-fixes-20261122/lalonde/splits.csv
cmp artifacts/lalonde/causal_report.json build/review-fixes-20261122/lalonde/causal_report.json
cmp artifacts/lalonde/report.md build/review-fixes-20261122/lalonde/report.md
cmp book/generated/lalonde.typ build/review-fixes-20261122/lalonde/lalonde.typ
cmp artifacts/lalonde/holdout_ledger.json build/review-fixes-20261122/lalonde/holdout_ledger.json
```

| Deterministic artifact | SHA-256 |
|---|---|
| `audit.json` | `6756aa706657f74b16abeae26b54df28281555bfac2de13470e3e4d1da19520c` |
| `splits.csv` | `d50097fadd29eca6e39dbd9aee8410a65e6f34233e6a057b975ba7f54b70c17f` |
| `causal_report.json` | `9193ea4574ab202e0b771cc0b5db7f4f74c6ddd6f24c676dd0850dfb7beba70b` |
| `report.md` | `8cefa37e8dc5b5b84437fa8b7b3a764964c79ab6e3652aafe488ccc72fcf3b2b` |
| `lalonde.typ` | `0104dea8aaef7a312b7d72d4f727adf1c239a8c8f4b5b8c566836a536a427acc` |

The current checked-in ledger and clean-replay ledger are byte-identical. Relative to the preserved pre-review ledger, the sole event retains its ID, purpose, source/contract/audit/split hashes, and `model_changes_permitted: false`; its local access timestamp changed from 1795314949 to 1795317536, and its report hash correctly changed to the regenerated report SHA above. The estimator, split assignment, and numerical estimates did not change. The local timestamp is not a trusted external timestamp, and the ledger is not tamper-proof or globally witnessed.

## 8. Localized review fixes (2026-11-22)

Four reporting/protocol ambiguities were corrected without changing the frozen estimator, contract, fold assignments, split roles, thresholds, or any numerical estimate:

1. Calibration documentation and JSON now distinguish the X/T-only computational and propensity gate (`outcome_used_in_gate`) from subsequently reported descriptive outcome means (`outcomes_reported_descriptively`). The legacy `outcome_used` field remains as an explicitly documented gate-only alias to avoid unnecessary schema breakage.
2. Failed-gate reports now say “before holdout outcomes were evaluated or reported,” not “accessed.” They acknowledge raw CSV parsing and all-record preparation summaries while distinguishing those operations from holdout evaluation and model selection. A deterministic failed-gate integration test covers both the empty holdout ledger/results and the required wording.
3. The book and README now state precisely that train-fold membership depends only on stable entity IDs; the protocol salt governs split-role assignment. A regression test changes the salt and verifies unchanged train-fold IDs while role assignments still change. No salt or fold output was changed.
4. Confidence reporting now declares `confidence_level`, a percentage, and dynamically labeled generic interval fields. Legacy `normal_95_*` fields are emitted as compatibility mirrors only at the checked-in 0.95 level. Unit tests exercise 0.90 labels/bounds and legacy-field omission; the 0.95 artifact bounds remain unchanged.

The report also surfaces calibration weak overlap directly beside gate status and explicitly says a passing gate is computational, not scientific approval, positivity, exchangeability, or identification. The existing holdout was not used to select or revise any model or reporting threshold.

## 9. Software, fixture, and corpus validation

All required locked commands were executed from this directory with Rust/Cargo 1.99.1:

| Command | Observed result |
|---|---|
| `cargo fmt --all -- --check` | Passed; no formatting differences |
| `cargo check --workspace --all-targets --locked` | Passed |
| `cargo clippy --workspace --all-targets --locked -- -D warnings` | Passed with warnings denied |
| `cargo test --workspace --locked` | Passed; 107 tests, 0 failures; no doc tests |
| `cargo run --locked -p arg-cli -- doctor` | Passed; self-contained profiles and explicit evidence limits displayed |
| `cargo run --locked -p arg-cli -- fixtures --dir examples/fixtures` | Passed; 11 fixture outcomes matched, self-contained true, certification/closure false |
| `cargo run --locked -p arg-cli -- check --kernel corpus/causal_ml.json --json build/reverification/corpus_check.json` | Structurally valid; 0 diagnostics; 7 argument obligations plus 52 claim-axis counters; `claim_supported: false` |
| `cargo run --locked -p arg-cli -- corpus --dir corpus --root . --json artifacts/corpus_audit.json` | Passed current-byte/structural audit; details below |
| `argumentos-corpus build`, `verify`, and filtered `query` via `cargo run --locked -p arg-ingest` | Passed; ten deterministic artifacts verified, 19,558,019 bytes, five MCP contract candidates returned |
| `typst compile book/main.typ build/book/causal-ml-book.pdf --root .` | Passed; 33-page PDF |

The 107 tests pass across the workspace. They exercise valid kernel behavior plus malformed/missing CSV fields, bad types/categories/ranges, duplicate IDs and exact rows, source-hash mismatch, deterministic entity/epoch split behavior, salt-independent train-fold membership, leakage failures, numerical diagnostics as implemented, dynamic confidence labels/bounds, artifact tampering, repeated-holdout refusal, and failed-gate reporting with no holdout evaluation. Kernel-hardening tests add bounded hostile JSON inputs, root/symlink escape rejection, receipt consistency and byte verification, atom registry closure/use, scope aggregation and rejection cases, cross-argument support cycles, self-approval mapping, and current-registry corpus checks. Documentary tests add required-group prefix/suffix matching, exact unit-to-source byte/hash round trips (including UTF-8 and CRLF), explicit exclusion records, deterministic builds and queries, path safety, tamper detection, and occurrence preservation. These are deterministic tests, not Monte Carlo claims about estimator performance or evidence of scientific validity.

The corpus audit inventories one kernel file with 52 atomicized claims, four arguments, and 30 registered evidence specs. Every evidence spec remains candidate/unverified. It reports 59 checker counters—7 argument obligations and 52 claim-axis counters—zero rejected files, zero cycle diagnostics, zero cross-file duplicate IDs, zero missing local sources, and zero missing registered artifacts. `evidence_replayed`, `claim_supported`, `corpus_closed`, and `scientific_validity_certified` remain false.

The source audit records the current LaLonde file, contract, splits, report, ledger, ten book source files, and prose source locations. Hashes show which current bytes were seen; they are not proof of the prose anchor, a trusted timestamp, independent execution replay, or scientific correctness.

## 10. Complete documentary corpus expansion

### 10.1 Delivered scope and evidence layers

`crates/arg-ingest` provides the `argumentos-corpus` binary with `build`, `verify`, and `query` commands. `config/corpus-ingest.json` declares read-only ingestion from:

- `02_causal AI en produccion/` as `02_production_monograph`;
- `05_contenido_tecnico/` as `05_technical_snapshot`; and
- `08_mcp-agentes-causales/` as `08_mcp_operations`.

The three evidence layers remain distinct:

| Layer | Delivered contents | Status |
|---|---|---|
| Hardened typed kernel | 52 atomicized claims, four arguments, 30 evidence specifications, 49-atom closed registry | Structurally audited; 59 checker counters pending; no scientific evidence promoted |
| Exact documentary corpus | 388 discovered regular files, 370 included files, 10,130 exact source units | Complete relative to declared roots, required groups, parsing roles, and exclusions |
| Extracted candidates | 2,252 unique candidates and 4,189 occurrences | `source_assertion_unverified`, `unreviewed`, and `atomicity_status=not_assessed` |

The complete observed coverage is:

| Collection | Discovered | Included | Excluded | Parsed | Metadata only | Units | Candidates present | Occurrences | Pruned dirs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `02_production_monograph` | 167 | 157 | 10 | 126 | 31 | 5,322 | 2,144 | 2,273 | 1 |
| `05_technical_snapshot` | 115 | 107 | 8 | 97 | 10 | 4,565 | 1,698 | 1,809 | 0 |
| `08_mcp_operations` | 106 | 106 | 0 | 67 | 39 | 243 | 106 | 107 | 13 |
| **Total** | **388** | **370** | **18** | **290** | **80** | **10,130** | **2,252 unique overall** | **4,189** | **14** |

Per-collection candidate counts overlap; occurrence counts, not candidate counts, sum to 4,189. All 15 required groups pass, including both monograph chapter families and entry points and the MCP knowledge, workflow, contract, criteria, evaluation, configuration, and root-documentation groups. `capitulos_de/` denotes data engineering, not German.

### 10.2 Executed build, verification, and query

The final workflow was executed from `argumentos copy/`:

```sh
cargo run --locked -p arg-ingest -- build \
  --config config/corpus-ingest.json \
  --repository-root .. \
  --output artifacts/documentary-corpus

cargo run --locked -p arg-ingest -- verify \
  --config config/corpus-ingest.json \
  --repository-root .. \
  --output artifacts/documentary-corpus

cargo run --locked -p arg-ingest -- query \
  --candidates artifacts/documentary-corpus/argument_candidates.jsonl \
  --collection 08_mcp_operations \
  --topic contracts \
  --limit 5
```

Observed build result: **ten artifacts; documentary coverage verified for 388 regular files**. Observed verification result: **ten artifacts and 19,558,019 bytes verified byte-for-byte; scientific validity remains uncertified**. The query returned five deterministically ordered MCP candidates with exact occurrence paths, source revisions, byte/line spans, and unreviewed status.

Configuration SHA-256: `b94389546b5706b4a5b293336f206290d6b53ab4f71f0d8cd9b553f79a9e3480`.

| Generated artifact | SHA-256 |
|---|---|
| `source_inventory.jsonl` | `1545ee520bcedecfbd7e9767753ef20eaae6196cf3bea83b76b9a24d4f1dec7a` |
| `sources.jsonl` | `69cfef24555ea23a7fe2e108fb6b658d2cdd7fbcd1e0bb75fea1f2a3be3baef7` |
| `source_units.jsonl` | `c526b8924d84a1d70fe5435ea5b1471a48006ef29d603dcffea3e859cd447c7d` |
| `argument_candidates.jsonl` | `540a64d4b72253fe0b189627d14c59bd9fb0906878fc62437a1d0bf2d39e1c96` |
| `relations.jsonl` | `209d7c669c7c5bd3b3cb41e0f4ed2fc627ab1f152d9fa0564547c314002500cd` |
| `exclusions.jsonl` | `b890bd5d6ae38d3fed4ca648490a38739bdec84fb15220f42f0cb6b955d2f804` |
| `coverage.json` | `c1336704eb8c482363b269a890a1026ad9028895893adde51ed671fdebe450ff` |
| `REPORT.md` | `f14f6ed0b8a6d3df3f9cc62b010845e3a2516c9788af4420da31f32f0fe1b82c` |
| `manifest.json` | `78f92be4af1503737cf64f5ac7566064b7b95b2c04e412522f5af31d36375036` |
| `checksums.json` (independent digest; excluded from itself) | `3e8ad4106f3b82c275bdb9adb76813e125e0923634b0ff2d9d557ed61e715ed4` |

`verify` regenerates all expected artifacts in memory, compares bytes, and rejects missing or unexpected files. Its success establishes deterministic regeneration under the declared configuration, not semantic correctness. Detailed artifact roles and operating instructions are in `corpus/DOCUMENTARY_WORKFLOW.md`.

### 10.3 Accounting, regression coverage, and imported limitations

- Eighteen regular files are explicitly excluded and inventoried: 15 binary/generated assets, two empty root placeholders, and one unknown non-UTF-8 `.DS_Store`. Fourteen pruned directories are separately recorded once; unread descendants are not included in regular-file totals.
- Eighty metadata-only files are hashed without being treated as candidate prose. Imported Python, Typst, shell, MCP, and other source code was not executed.
- The relationship stream records 102 byte-identical monograph-file pairs and five content variants. Candidate deduplication, byte identity, and semantic equivalence remain separate operations; all source occurrences are retained.
- The ingestion crate has 21 passing tests: seven unit tests and 14 integration tests. Every real source unit independently round-trips to original bytes and hashes in the integration suite.
- No documentary candidate was automatically promoted into the typed kernel. Candidate IDs and automatic topics are unreviewed extraction metadata, not durable curated identities or scientific classifications.
- Documentary ingestion did not run estimation, create a holdout event, change the frozen LaLonde protocol, or validate production deployment.

The imported source state retains known limitations rather than silently repairing it: the MCP chapter plan is stale about data-engineering chapters; the contract README lists C-01–C-12 despite C-13–C-15 and references nonexistent paths; evaluation Markdown files are designs rather than executed experiments; MCP acceptance evidence is 13 PASS, 3 NOT_IMPLEMENTED, and `BLOCKED_LOCAL_V1`; the MCP reference estimator supports ATE/AIPW rather than every method named in knowledge records; and monograph theorem/reference verification issues remain unresolved or non-verifiable.

`documentary_coverage_complete=true` is therefore policy-relative structural completeness. `semantically_curated_corpus_complete=false`, `scientific_validity_certified=false`, and `execution_replayed=false` remain explicit.

## 11. Kernel hardening and corpus repair (2026-11-22)

### 11.1 Engineering hardening

The audit found several classes of defects that tests could not detect because the happy path passed. They are now repaired:

1. Input loaders now enforce documented byte, depth, node, collection, statement, and scope limits. Duplicate-key pre-parsing and assumption traversal are iterative or budgeted and return typed contract errors rather than crashing or hanging.
2. Local source/artifact resolution canonicalizes the project root and target, rejects parent escapes and every symlink component, rejects directories/non-regular files deliberately, and streams hash checks with a cap.
3. Receipt admission rejects duplicate receipt IDs, validates strict UTC timestamps and ordering, rejects `execution_passed=true` with any failed or pending observed check, and uses a closed set of stable reasons.
4. CLI receipt handling resolves a project root (default `.`) and verifies current bytes for `input_hashes` targets and all declared artifact paths. Target-check lines and admission records are emitted as deterministic NDJSON through `--receipts-json`, or to stderr by default, never interleaved with the report on stdout. `execution_admitted` has been replaced with byte-verification-oriented, non-witness semantics. `claim_supported` and `replay_witnessed` remain constants `false`.
5. The scope checker fails closed in both directions. Only explicitly declared aggregation keys (`role`, `clip`, `diagnostic`, `claim_class`, `limitation`) may be omitted from a conclusion; `domain`/`observations` retain only the finite→countable→infinite lattice. Scenario/population changes such as lab→field are rejected. Instrumented conclusion additions no longer appear invisibly.
6. Argument support graphs now detect global cross-argument cycles with SCC analysis in addition to per-derivation and assumption cycles. Acyclic alternatives of an invalidated derivation remain separately adjudicable.
7. Factual claims now accumulate a pending axis. The CLI distinguishes the seven argument obligations from the 52 claim-axis counters while preserving the compatibility sum `pending_count`.
8. `MIXED_DOSSIER` describes mixed premise kinds accurately; self-approval mapping now handles unknown serde variants and forbidden scope map keys/values case-insensitively; obligations use a closed code vocabulary and exact classifier instead of repeated ad hoc `starts_with`; unused helpers were removed.
9. The audit distinguishes locally byte-verified sources from all other source systems in `source_system_counts` and `unchecked_sources`; symlinked JSON corpus entries are reported in `skipped_entries` instead of disappearing silently. Both never count as checked.
10. Present non-string `schema_version` values now produce a distinct typed error instead of `missing`; exact-rational arithmetic uses checked `i128` intermediates; schema/loader divergence is pinned by regression tests rather than papered over.
11. A top-level `atoms` registry documents a closed atom namespace: every expression atom must resolve to one owned definition claim, registered-unused atoms are rejected, and registry bytes participate in canonical kernel hashing.

The current kernel hashes are `corpus/causal_ml.json` SHA-256 `880789de76c3beef5176f7e79ad7f602426f8e089240b91110382602877f71b1` and canonical SHA-256 `e17bfc7667cfe5a43a39e9222475379c9b96551628aa0489d5157bf75e97bb8e`.

### 11.2 Argument and evidence graph repair

The rewritten corpus keeps the identity `causal-ml-lalonde-executable-book-v1` and `scientific_audit`, but its contents are materially stronger:

- **52 claims**: 3 formal, 16 conditional, 21 factual, and 12 empirical.
- **4 arguments**: the assumptions conjunction, revised conditional backdoor modus ponens, atomic protocol dossier conjunction, and counterfactual conditional dossier.
- **30 candidate evidence specs**: all `registered`, all unverified; registered targets are inventoried but not replay witnesses.
- **49 atoms**: a closed registry with an owning claim for every atom. `corpus/ATOM_REGISTRY.md` documents the policy and the atomic decomposition.

Key repairs include demoting substantive causal premises from `formal` to `conditional`; adding the declared adjustment-set atom to the identification conjunction and backdoor implication; splitting provenance, licensing, schema, feature, split, cross-fit, holdout-ledger, convergence, and overlap claims into one fact per claim; replacing nonexistent anchors with actual audit/contract/report locators; adding a new epoch-disjoint claim; encoding the clip 0.01/0.10 holdout sensitivity claims; and routing the final conditional dossier through identifier, protocol, provenance, license, overlap, convergence, unadjusted, AIPW, sensitivity, and explicit limit claims.

The adjusted locators were cross-checked against local files and JSON top-level/dot paths. Semantic prose verification still does not exist. The final structure checks return `structurally_valid`; diagnostics are empty; argument verdicts are valid structurally; `A.protocol.conjunction` honestly records `MIXED_DOSSIER`; and `claim_supported` remains `false`.

`artifacts/corpus_audit.json` now records 52 claims, 30 evidence specs, zero missing sources/artifacts, zero cycles, zero rejected files, and SHA-256 `c5f1e868132806bbbcaab3c22151c2bfccc9d0088fa58f91e5c2498acc2f91ee`.

### 11.3 Literature curation with OpenAlex and Semantic Scholar

This pass deliberately separated bibliographic lookup from evidentiary validation. It consulted Semantic Scholar and OpenAlex and normalized the bibliography and case provenance without changing generated results or the consumed holdout.

- **Semantic Scholar matches:** LaLonde (`61572150188f35378fa208a158d2dbe0817647b8`) and Chernozhukov et al. DML (`f75b70c9d7078724b592ec3e21de705e7b6ff73f`).
- **Dehejia & Wahba index normalization:** OpenAlex exposes the JASA record (`W3122948292`, alternate records include `W2891753394`) and the NBER working-paper record `W2171442673` (`10.3386/w6586`). The bibliography uses JASA DOI `10.1080/01621459.1999.10473858`.
- **Heckman, LaLonde & Smith (1999):** added as methodological context with DOI `10.1016/S1573-4463(99)03012-6` (OpenAlex `W1530306231`).
- **Imbens & Rubin (2015):** added with DOI `10.1017/CBO9781139025751` (OpenAlex `W2263423262`).
- **Cinelli & Hazlett (2020):** added as omitted-variable-bias sensitivity context with DOI `10.1111/rssb.12348` (OpenAlex `W2996483157`).
- **Chernozhukov et al. (2018):** already in bibliography; Semantic Scholar and OpenAlex identifiers are recorded in `book/LITERATURE_MATRIX.md`.
- LaLonde's 1986 AER article has no stable DOI in the consulted records. The project deliberately does not invent one and instead records OpenAlex `W2150118316` as the nearest exact-title/publication record while retaining `repec:aea:aecrev:v:76:y:1986:i:4:p:604-20` and the journal citation.

`book/LITERATURE_MATRIX.md` now maps kernel families to source roles, identifiers, supported warrants, and unsupported inferences. `data/real/PROVENANCE.md` also records the bibliographic records consulted. The pass improved citation metadata and fine-grained review documentation; it did not turn literature into replay, certify identification, promote candidate evidence, or alter any empirical claim.

### 11.4 What remains impossible to fix locally

This repair does **not** certify identification, support, exchangeability, measurement validity, licensing, external replication, holdout preregistration, or production deployment. Atom registry closure is a namespace property, not epistemic validation. Atomic claims are clearer, not automatically true. Candidate registered evidence remains candidate evidence. Independent scientific review, hidden-confounding analysis, license review, external replication, and real acceptance evidence remain separate human/operational work.

Consequently, the repaired corpus is a materially safer auditable dossier, not a scientifically closed corpus.

## 12. Reproduction and release hygiene

- `Cargo.lock` is used by every Cargo execution above.
- Runtime dependencies are limited to established CLI/serialization/error/CSV/hash crates; there is no dataframe/server/ML framework dependency.
- `/target/` and `/build/` are ignored in `.gitignore`; generated PDFs and clean-room replays stay local.
- `artifacts/lalonde/` is an inspectable consumed-output record, not a location for further estimation.
- `artifacts/corpus_audit.json` is a current-byte/structure snapshot, not a corpus closure statement.
- `artifacts/documentary-corpus/` contains ten deterministic generated artifacts with exact provenance; its strict verifier rejects extra local notes or drift.
- `corpus/DOCUMENTARY_WORKFLOW.md` documents the parent-source dependency, operation, accounting, and semantic-curation boundary.
- `config/test.contract.json` supports generated-synthetic tests and is not real-data provenance.
- `README.md` provides safe quickstart commands and identifies the correct Cargo package names (`arg-cli`, not `argumentos`; `causal-ml`; `arg-ingest` with binary `argumentos-corpus`).
- `reviews/lalonde_internal_audit.md` is an explicitly internal, non-certifying protocol audit; it verifies declaration-level local evidence and records blocking causal-review gaps, but is not an independent referee.
- `reviews/external_review_packet.md` is handoff-ready material defining the external deliverables and veto boundaries needed before any stronger interpretation.
- `progress/STATE.json` describes this actual project rather than referring to a missing destination repository.
- No release approval, cryptographic timestamp service, externally signed preregistration, or independently reproduced evidence receipt is asserted.

## 13. Unresolved limitations and appropriate next work

1. **Observational identification:** NSW/PSID assignment is nonexperimental. Conditional exchangeability is unverified and cannot be manufactured by AIPW.
2. **Support:** propensity tails are substantial. Clipping does not create positivity, and extreme influence contributions remain a concern.
3. **Model specification:** simple main-effects logistic/linear models may be misspecified; double robustness does not protect against joint misspecification or unmeasured confounding.
4. **Estimand/population:** split-specific adjusted contrasts do not automatically identify a national or program-wide effect. Treatment versions, consistency, interference, measurement, and transport assumptions need domain support.
5. **Uncertainty:** normal-reference IF intervals are approximate, not cluster-robust here, and omit identification, dataset-construction, model-selection, sensitivity, and transport uncertainty.
6. **Sensitivity:** clip 0.01/0.10 comparisons are now encoded as candidate registered-evidence claims, but clipping is still not a hidden-confounding sensitivity analysis. No validated quantitative confounding bound is supplied.
7. **Temporal/entity design:** the CSV has source row IDs but no epoch or independently verified longitudinal person key. Epoch-aware splitting is tested on synthetic schemas, unavailable on this real artifact.
8. **Holdout governance:** the local ledger is advisory and editable at the filesystem level. The ledger claims are now anchor-correct and split, but fresh directories still do not make repeatedly consulted holdout outcomes independent again.
9. **Data rights:** upstream data-value redistribution status is unresolved. The CSV checksum proves bytes, not permission.
10. **Evidence replay:** registered artifacts have current-byte validation and corrected locators, but they have not been independently executed by the argument checker; JSON paths and Markdown/Typst prose anchors remain non-replayed and uncertified. Structural green is not corpus closure.
11. **Advanced methods:** CATE/meta-learners, policy learning, online monitoring, rollback, and deployment are covered theoretically but not implemented or validated in this case.
12. **External reproducibility:** all deterministic outputs matched on this machine/toolchain. Cross-platform numerical bit-for-bit identity and independent scientific replication remain unverified.
13. **Semantic curation:** the typed kernel is atomic and registry-closed, while the 2,252 documentary candidates are still unreviewed source assertions. Atomicity, durable IDs, claim scope, contradictions, authority, and evidence obligations still require explicit review before any candidate is promoted.
14. **Imported operational evidence:** documentary coverage includes MCP designs, contracts, and acceptance records, but does not make the blocked local acceptance state production-ready or turn estimators discussed in knowledge resources into implemented capabilities.

`reviews/lalonde_internal_audit.md` is a useful internal stress-test, not the missing independent review. The next documentary stage is semantic curation with contradiction/duplicate review and evidence-specific replay, while preserving the exact raw spans as provenance. Any subsequent feature, learner, target, splitting, clipping, or inferential change after seeing the existing holdout result must be openly treated as a new analysis protocol. The correct next scientific step is not in-place model tuning; it is independent design review, justified identification/sensitivity analysis, and genuinely new outcome-independent validation data where feasible.
