# Documentary corpus report: causal-ai-production-technical-mcp-v1

This is deterministic documentary ingestion, not scientific or semantic certification. Candidates are unreviewed, whitespace-normalized verbatim source assertions; exact raw units are authoritative. No Python, Typst, shell, or other imported source was executed. No legacy kernel claims were exported.

## Counts by collection

| Collection | Discovered files | Included | Excluded | Parsed | Metadata only | Units | Candidates present | Occurrences | Pruned directories |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 02_production_monograph | 166 | 157 | 9 | 126 | 31 | 5325 | 2144 | 2273 | 1 |
| 05_technical_snapshot | 115 | 107 | 8 | 97 | 10 | 4565 | 1698 | 1809 | 0 |
| 08_mcp_operations | 106 | 106 | 0 | 67 | 39 | 243 | 106 | 107 | 13 |

**Unique candidates:** 2252  
**Candidate occurrences:** 4189  
**Byte-identical monograph relations:** 102  
**Content-variant monograph relations:** 5

Exact normalized duplicate statements share one content-derived candidate ID and retain all occurrences, paths, source revisions, spans, and headings. `byte_identical` relations describe file bytes; `content_variant` lists same-relative-path monograph files whose hashes differ. Neither relation suppresses sources or units. Candidate deduplication is separate from byte-level file relations.

## Required groups

| Group | Collection | Expected | Matched | Status |
|---|---|---:|---:|---|
| mcp-configuration | 08_mcp_operations | 1 | 1 | pass |
| mcp-current-contract-documentation | 08_mcp_operations | 1 | 1 | pass |
| mcp-current-contract-json | 08_mcp_operations | 16 | 16 | pass |
| mcp-evaluation-criteria | 08_mcp_operations | 1 | 1 | pass |
| mcp-evaluation-specifications | 08_mcp_operations | 7 | 7 | pass |
| mcp-knowledge-records | 08_mcp_operations | 25 | 25 | pass |
| mcp-local-contract | 08_mcp_operations | 1 | 1 | pass |
| mcp-root-readme | 08_mcp_operations | 1 | 1 | pass |
| mcp-workflows | 08_mcp_operations | 8 | 8 | pass |
| production-data-engineering-chapters | 02_production_monograph | 15 | 15 | pass |
| production-data-engineering-main | 02_production_monograph | 1 | 1 | pass |
| production-main | 02_production_monograph | 1 | 1 | pass |
| production-method-chapters | 02_production_monograph | 33 | 33 | pass |
| technical-main | 05_technical_snapshot | 1 | 1 | pass |
| technical-method-chapters | 05_technical_snapshot | 33 | 33 | pass |

## Exclusions

| Reason | Entries |
|---|---:|
| `binary_or_generated_asset_excluded_but_inventoried` | 15 |
| `explicit_empty_root_placeholder` | 1 |
| `pruned_by_declared_policy_no_descendants_read` | 14 |
| `unknown_non_utf8_or_unsupported_asset_excluded_but_inventoried` | 1 |

Pruned directories are recorded once and their descendants were not read. Excluded regular files remain inventoried. Included metadata-only files are SHA-256 hashed. Empty root placeholders are explicit exclusions.

## Coverage and limitations

- `documentary_coverage_complete=true` is relative only to declared roots, required groups, and these policies.
- `semantically_curated_corpus_complete=false`.
- `scientific_validity_certified=false` and `execution_replayed=false`.
- `legacy_kernel_claims_exported=0`.
- Candidate IDs are unreviewed content-derived `cand.<hash>` values, not durable curated semantic IDs.
- Candidates do not assert atomicity, causal identification, scientific verification, or tested status.
- Automatic topics are multi-label and unreviewed, with `uncategorized` fallback.
- JSON document units have JSON pointer `/`; review JSONL is validated one exact line at a time; bibliography YAML is lexical only.

## Commands

From `argumentos copy/`, using this checked-in configuration and its parent repository:

```sh
cargo run --locked -p arg-ingest -- build --config config/corpus-ingest.json --repository-root .. --output artifacts/documentary-corpus
cargo run --locked -p arg-ingest -- verify --config config/corpus-ingest.json --repository-root .. --output artifacts/documentary-corpus
cargo run --locked -p arg-ingest -- query --candidates artifacts/documentary-corpus/argument_candidates.jsonl --collection 02_production_monograph --topic monitoring --contains "causal" --limit 20
```
