# Complete documentary corpus workflow

## Purpose and evidence boundary

This workflow inventories and indexes the complete declared documentary scope from the parent repository. It does **not** convert every source block into a reviewed scientific claim.

Three layers must remain distinct:

| Layer | Current contents | Meaning |
|---|---|---|
| Typed argument kernel | 52 claims, 4 arguments, 30 evidence specifications, 49-atom closed registry | Hardened, atomic, and registry-enforced LaLonde/theory kernel in `corpus/causal_ml.json`; 59 checker counters remain pending |
| Exact documentary sources | 387 discovered regular files, 370 included files, 10,133 source units | Source-complete ingestion relative to the declared roots and exclusions, with exact paths, byte spans, line spans, and hashes |
| Extracted candidates | 2,252 unique candidates and 4,189 occurrences | Unreviewed, whitespace-normalized source assertions; not 2,252 manually curated or scientifically verified arguments |

Every extracted candidate has `epistemic_status=source_assertion_unverified`, `review_status=unreviewed`, and `atomicity_status=not_assessed`. A `cand.<hash>` identifier is a content-derived extraction key, not a durable curated identity. Automatic topics and argument kinds are also unreviewed.

`documentary_coverage_complete=true` means only that the declared roots were walked, required groups matched, regular files were accounted for, and links and hashes passed. It does not mean semantic completion, execution replay, causal identification, or scientific certification.

## Required repository layout

Run all commands from `09_argumentos/`. The typed kernel and LaLonde workflow are local to this directory, while documentary ingestion explicitly depends on these siblings in the parent repository:

```text
../02_causal AI en produccion/
../05_contenido_tecnico/
../08_mcp-agentes-causales/
```

The paths are declared in `config/corpus-ingest.json`. The workflow reads these collections but never edits them, executes imported Python/Typst/shell code, starts an MCP server, or reruns the LaLonde estimator. If this directory is moved without those siblings, rebuild and verification correctly fail.

## End-to-end operation

### 1. Rebuild all deterministic artifacts

```sh
cargo run --locked -p arg-ingest -- build \
  --config config/corpus-ingest.json \
  --repository-root .. \
  --output artifacts/documentary-corpus
```

The build walks sources in deterministic order, rejects unsafe roots and source symlinks, accounts for every discovered regular file, extracts exact source units, links candidates, checks the required groups, and only then writes the complete artifact set.

The output directory is deliberately strict: missing expected outputs, unexpected extra files, or drift cause verification to fail. Put local notes elsewhere, not inside `artifacts/documentary-corpus/`.

### 2. Verify a byte-identical regeneration

```sh
cargo run --locked -p arg-ingest -- verify \
  --config config/corpus-ingest.json \
  --repository-root .. \
  --output artifacts/documentary-corpus
```

`verify` regenerates every artifact in memory and compares all expected files byte-for-byte. It also rejects missing and extra artifacts. It does not certify the semantic or scientific content of matching bytes.

### 3. Query without changing the corpus

```sh
cargo run --locked -p arg-ingest -- query \
  --candidates artifacts/documentary-corpus/argument_candidates.jsonl \
  --collection 02_production_monograph \
  --topic monitoring \
  --contains "causal" \
  --limit 20
```

Filters select candidates with at least one matching occurrence. `collection` and `topic` use substring matching; `contains` is case-insensitive. Results are ordered by candidate ID, not ranked by scientific importance, and `--limit` truncates that deterministic order. Use the returned occurrence paths, revisions, and spans to inspect the exact raw unit before citing a candidate.

Omit filters for a broader query. For example, this reads MCP candidates only:

```sh
cargo run --locked -p arg-ingest -- query \
  --candidates artifacts/documentary-corpus/argument_candidates.jsonl \
  --collection 08_mcp_operations \
  --topic contracts \
  --limit 5
```

### 4. Run software regression checks

```sh
cargo fmt --all -- --check
cargo check --workspace --all-targets --locked
cargo clippy --workspace --all-targets --locked -- -D warnings
cargo test --workspace --locked
cargo run --locked -p argument-cli -- fixtures --dir examples/fixtures
```

The statistical holdout is not reopened by documentary ingestion. Changing source ingestion or documentary formatting is not permission to revise the frozen LaLonde protocol against its consumed holdout.

## Artifact guide

`artifacts/documentary-corpus/` intentionally retains ten inspectable artifacts:

| File | Role |
|---|---|
| `source_inventory.jsonl` | One record per discovered regular file and one per explicitly pruned directory |
| `sources.jsonl` | Every included source, including metadata-only files, with its SHA-256 and parsing role |
| `source_units.jsonl` | Exact raw source slices with authoritative byte/line spans and raw hashes |
| `argument_candidates.jsonl` | Deduplicated unreviewed candidates with all occurrences and source scopes |
| `relations.jsonl` | Byte-identical and content-variant relations between the two monographs |
| `exclusions.jsonl` | Explicit excluded-file and pruned-directory records |
| `coverage.json` | Collection totals, required-group paths, consistency checks, and evidence boundaries |
| `REPORT.md` | Generated human-readable counts and operational summary |
| `manifest.json` | Configuration hash, output contract, processing flags, and explicit non-certification flags |
| `checksums.json` | SHA-256 for each other generated artifact; it excludes itself |

The retained artifacts make the documentary result inspectable and independently verifiable. They are generated outputs, not handwritten curated claims; `verify` must pass after any intentional rebuild.

## Observed complete-documentary coverage

| Collection | Discovered | Included | Excluded | Parsed | Metadata only | Units | Candidates present | Occurrences | Pruned dirs |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `02_production_monograph` | 166 | 157 | 9 | 126 | 31 | 5,325 | 2,144 | 2,273 | 1 |
| `05_technical_snapshot` | 115 | 107 | 8 | 97 | 10 | 4,565 | 1,698 | 1,809 | 0 |
| `08_mcp_operations` | 106 | 106 | 0 | 67 | 39 | 243 | 106 | 107 | 13 |
| **Total** | **387** | **370** | **17** | **290** | **80** | **10,133** | **2,252 unique overall** | **4,189** | **14** |

Per-collection candidate counts overlap because the same normalized statement can occur in several collections. Occurrences, not per-collection candidate counts, sum to 4,189. Discovered regular files satisfy `370 + 17 = 387`; the 14 pruned directories are recorded separately and their descendants were not read.

All 15 required groups pass: two production chapter families and entry points, technical chapters and entry point, 25 MCP knowledge resources, 8 workflows, 16 current contract JSON files plus contract documentation, the local contract, evaluation criteria, seven evaluation specifications, MCP configuration, and the MCP root README. `capitulos_de/` and `main_de.typ` denote **data engineering**, not German-language material.

## Roles, exclusions, duplicates, and variants

- Current manuscript prose, knowledge resources, workflows, contracts, criteria, and evaluation Markdown can produce candidates according to their declared roles.
- Bibliographies, review ledgers, historical text, layouts, and other support material are retained as source units but do not automatically become current candidates.
- Source code, tests, configuration outside candidate-approved roles, and generated reports remain metadata-only and hashed; imported code is not executed.
- Fifteen binary/generated assets and one empty root placeholder are excluded but inventoried. One unknown non-UTF-8 source, `02_causal AI en produccion/.DS_Store`, is also excluded and inventoried.
- Pruned dependency/build/VCS directories are recorded once. Their unread descendants cannot be represented in regular-file totals.

The relationship stream preserves 102 byte-identical monograph-file pairs. Five same-relative-path files differ and are marked `content_variant`:

1. `capitulos/cap09_features_sin_fuga.typ`
2. `apendices/apJ_guia_instructores.typ`
3. `main.typ`
4. `template/template.typ`
5. `bibliografia/refs.yml`

Byte-level identity, normalized-candidate identity, and semantic equivalence are different operations. Neither relationship nor candidate deduplication deletes source records, units, or occurrences.

## Source limitations retained as limitations

- `plan-capitulos/PLAN_MCP_CAPITULOS.md` is stale where it says data-engineering chapters are missing; all 15 are present.
- `contratos/README.md` lists C-01–C-12 although C-13–C-15 exist and some referenced paths do not exist.
- Evaluation Markdown files are evaluation designs, not executed experiments or datasets.
- The latest inspected MCP acceptance evidence is 13 PASS, 3 NOT_IMPLEMENTED, with `BLOCKED_LOCAL_V1`; it is not complete production success.
- The MCP reference estimation path supports ATE/AIPW only. ATT, CATE, IV, DiD, and RD knowledge records do not imply corresponding production estimators.
- Monograph verification records retain unresolved or non-verifiable theorem/reference issues.

These observations describe the imported source state. This workflow does not silently repair the source collections or promote their statements into verified claims.

## Required next stage: semantic curation

A candidate becomes a curated argument only through a separate review that establishes atomicity, a durable identifier, claim type and scope, assumptions, contradictions or duplicates, source authority, and evidence obligations. Causal assertions additionally require estimand and identification review; empirical assertions require executable provenance and independent replay; production assertions require observed acceptance evidence.

No automatic extractor can responsibly perform those promotions. Keep the existing typed kernel unchanged until that review is explicitly performed and recorded. Structural completeness, query availability, and deterministic regeneration are the delivered workflow—not scientific closure.
