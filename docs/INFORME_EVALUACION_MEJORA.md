# Repository evaluation and improvement report

**Repository:** `sistema-inteligencia-causal-estudiante-main`  
**Branch:** `semana4/proyecto`  
**Baseline HEAD:** `737e166`  
**Evaluation date:** 2026-11-22  
**Scope:** the existing teaching, notebook, production, monograph, and MCP components, plus the conversion of `argumentos copy/` into a self-contained Causal ML/AI theory and real-data engineering project.

## 1. Executive conclusion

The repository is substantially stronger after this intervention. The main improvements are fail-closed serving and promotion, explicit policy-estimation semantics, stronger data/split and path integrity checks, working MCP stdio packaging, reproducible book editions, a manifest that is actually verified, and a self-contained Rust causal-analysis project with genuine observational data.

The final scoped software checks pass:

- **46** notebook policy tests;
- **54** production tests plus `compileall`;
- **94** canonical and **14** legacy MCP tests;
- Week 4 IHDP/Jobs data-contract checks, estimation assertions, service smoke tests, and **5** DML-IV tests;
- **107** Rust argument/Causal ML tests, formatting, checking, and Clippy;
- **11/11** argument fixtures and a structurally valid but explicitly open claim corpus;
- all three monograph editions and the nine-chapter Causal ML book compiled with Typst;
- **125/125** declared public-distribution files passed existence, byte-count, and SHA-256 verification.

**These results do not certify causal identification, scientific validity, legal redistribution rights, production readiness, or deployment safety.** The MCP local V1 acceptance runner remains intentionally blocked, the A4 historical holdout is no longer independent confirmatory evidence, LaLonde data-value redistribution rights remain unresolved upstream, and several security and operational boundaries still require trusted inputs or further engineering.

The detailed argument-project deliverable and artifact evidence are in [`argumentos copy/IMPLEMENTATION_REPORT.md`](../argumentos%20copy/IMPLEMENTATION_REPORT.md). This root report does not duplicate all of its formulas and generated digests.

## 2. Preservation and attribution boundaries

The starting worktree was **not clean**. Before this audit it already contained staged changes to `.gitignore` and `README.md`, extensive Week 4 edits and deletions, modified monograph and license files, numerous untracked teaching materials, and the pre-existing `argumentos copy/` argument kernel.

Accordingly:

- no reset, clean, checkout-based restoration, staging, commit, branch operation, or deletion of user work was performed;
- pre-existing modifications and deletions remain in the worktree;
- no Week 4 training/demo/monitor CLI, bundle promotion, stored-evidence regeneration, or notebook retraining was run;
- the Week 4 champion still reads `v0009`; the historical evidence discussed in the project concerns `v0008`;
- local generated directories such as MCP `.tmp/`, argument-project `build/`, and `target/` were not treated as source or removed;
- manifest hashes were refreshed to describe the **current** declared bytes, including some pre-existing user edits. This records integrity; it does not attribute or endorse every pre-existing change.

For mixed files such as root `README.md`, the Week 4 implementation, and the monograph, the dirty starting tree prevents a clean line-by-line separation from Git alone. The groups below identify this intervention's work, not every pre-existing difference from `737e166`.

### Files and areas authored or corrected by this intervention

| Area | Work owned by this intervention |
|---|---|
| Root governance | `MANIFEST_ESTUDIANTE.json`, `scripts/validate_student_repo.py`, the validation-scope text in `README.md`, `.github/workflows/semana4-proyecto.yml`, and this report. |
| Main monograph | Edition documentation in `02_causal AI en produccion/Causal_AI/main.typ`, strict edition validation in `template/template.typ`, and new `Causal_AI/README.md`. Existing user edits in those Typst files were preserved. |
| Serie A | `03_notebooks_caso_estudio/lib/policy_utils.py`, `notebooks/A4_policy_uplift_ihdp.ipynb`, and new focused tests under `tests/`. |
| Production | The modified B1/B3/B4 runtimes and documentation, `src/causalops/`, `04_produccion_causal/Makefile`, its README, and the newly added test directories. |
| MCP | The canonical/legacy packaging corrections, declaration/path/lineage validation, CLI and Docker entrypoint changes, associated docs, and new regression/acceptance tests under `08_mcp-agentes-causales/`. |
| Week 4 | Focused current-tree corrections concentrated in data/split verification, registration/promotion, service gating, window selection, and smoke/regression checks. These changes sit within a much larger pre-existing Week 4 rewrite. |
| `argumentos copy/` | The self-contained Causal ML crate, data/provenance/protocol, argument corpus, nine-chapter book, tests, generated case-study artifacts, reports, and project documentation, while preserving the original typed argument-kernel semantics. |

The large number of other modified/deleted/untracked paths shown by `git status` must **not** be interpreted as wholly authored by this intervention.

## 3. Repository architecture reviewed

| Path | Role and audit focus |
|---|---|
| `01_silabo/` | Course syllabus, calendar, and reading sequence; treated as teaching context rather than executable causal evidence. |
| `02_causal AI en produccion/Causal_AI/` | Long-form monograph with `curso`, `comercial`, and `principios` editions; focused on edition selection, exclusions, and reproducible compilation. |
| `03_notebooks_caso_estudio/` | Four Serie A notebooks and estimation helpers; focused on policy value definitions, calibration/evaluation separation, and holdout interpretation. |
| `04_produccion_causal/` | DML and policy serving, gates, cards, local registry, and drift monitoring; focused on fail-closed behavior and artifact/metric integrity. |
| `05_contenido_tecnico/` | Book snapshot and reference material; not confused with the current monograph edition. |
| `06_proyecto_final/` | Final-project instructions and assessment context. |
| `07_docencia/semana_4_proyecto/` | Teaching prototype, synthetic benchmark datasets, DML-IV extension, registry and service; focused on current-tree correctness without regenerating evidence. |
| `08_mcp-agentes-causales/` | Canonical MCP 2.0.0 server and renamed legacy package; focused on declaration enforcement, path containment, lineage, packaging, and acceptance status. |
| `argumentos copy/` | New self-contained Rust/Type/Typst project linking claims, theory, observational data, estimation, and evidence limits. |
| `MANIFEST_ESTUDIANTE.json`, `scripts/` | Public-distribution declaration and root environment/integrity checks. |

This was a systems and methodology audit with focused repairs, not an independent line-by-line peer review of every page, citation, pedagogical claim, and legacy artifact in the repository.

## 4. How Mem0 was used—and its limits

Mem0 was queried for causal ML/AI repository, governance, traceability, leakage, holdout, and reproducibility practices. The relevant results were **general LFD140 governance conventions**, not repository-specific causal methodology:

- lifecycle traceability and signaling;
- role accountability and review enforcement;
- normative clarity and metadata presence;
- branching/tagging and contributor workflow transparency;
- governance files, status, changelog, release, and ADR conventions.

Representative memory IDs were `b1583f37-c0a4-48f1-b2e8-a89b1db1f683` and `e955e277-c3b3-440d-8402-7e68065bfd49`. Their transferable ideas were applied conservatively through explicit contracts, provenance, hashes, pending-versus-verified states, scoped reports, and transparent validation. The separate project's branch-protection and release conventions were **not** imposed on this repository, and no Git history was changed.

No Mem0 result supplied a causal identification, estimator-selection, or statistical-validation recipe for this codebase. Those decisions came from the observed code, tests, data contracts, and causal-inference methodology. A separate memory recommended `causal_env` at `/opt/homebrew/Caskroom/miniforge/base/envs/causal_env`; that path is stale/nonexistent here and was not followed. Existing environments under Week 4, its DML-IV extension, and MCP were used instead. No Conda environment was installed.

## 5. Principal findings and implemented improvements

### 5.1 Policy estimation and notebook protocol

**Findings.** The legacy policy IPW name obscured the estimand, factual and alignment-weighted quantities were conflated, and calibration/evaluation responsibilities were not sufficiently explicit. The revised A4 historical holdout had already been inspected, so it cannot become independent confirmation by rerunning it.

**Corrections.** `policy_utils.py` now provides a correctly defined `target_policy_value_ipw`, separates factual observed-policy value from the legacy alignment-weighted diagnostic, retains deprecated `policy_value_ipw` with a warning, and enforces train → validation calibration → frozen test evaluation in policy helpers. A4 now calibrates on validation and labels historical holdout evidence exploratory/contaminated.

**Boundary.** No estimator or threshold was tuned against the inspected holdout to improve results. Notebook/export execution was not run end-to-end. Fresh confirmatory claims require a genuinely new, uninspected holdout and a frozen protocol.

### 5.2 Production serving, gates, and monitoring

**Findings.** Batch support/abstention parity was incomplete; nonfinite and undeclared-support values could evade boundaries; required artifacts were not consistently hash-covered; gate/card/monitor states could contradict one another; missing, malformed, nonfinite, or domain-invalid metrics could be treated as healthy; and KS/PSI semantics were not reliably independent.

**Corrections.** B1 and B3 now fail closed on support, nonfinite values, artifact coverage, gate/card incoherence, and any state other than explicit `pasa`. Promotion requires coherent, fresh, finite evidence and bundle integrity. KS and PSI are separate statistics with separate thresholds; constant-reference PSI is handled explicitly; the monitor rejects absent or malformed evidence instead of raising or continuing silently.

**Boundary.** Passing a computational gate is not proof of exchangeability, positivity, causal identification, or deployment readiness. No live-service demonstration, container run, or full production demo was executed.

### 5.3 MCP server and agent boundary

**Findings.** Declaration enforcement could occur too late; malformed states and stale revisions were insufficiently closed; filesystem paths needed containment before creation/opening; C-09 lineage needed an actual contained data path and recomputed digest; package identity, extras, and Docker startup were inconsistent.

**Corrections.** Declarations now precede dependent operations, malformed/unknown states fail closed, empty/stale revisions are blocked, containment precedes filesystem operations, and lineage requires a 64-hex SHA-256 recomputed before every PASS. The canonical package is `mcp-causal` 2.0.0, the legacy distribution is `mcp-causal-legacy`, test/full extras include the real dependencies, and the Docker entrypoint starts the stdio server.

**Boundary.** Static path containment does not remove persistent-filesystem TOCTOU races. The acceptance runner is not green: **13 PASS, 0 FAIL, 3 NOT_IMPLEMENTED** (`V1-02`, `V1-03`, `V1-09`), final `BLOCKED_LOCAL_V1`. This is deliberately reported as incomplete, not converted into a passing gate.

### 5.4 Week 4 data, service, and registry

**Findings.** Promotion needed integrity/gate-card verification before pointer writes; newly registered versions must not assert `pasa` before monitoring; service health and numerical answers depended too loosely on gate state; data verification needed independent counts, unique/disjoint IDs, and truth-wall checks; an unknown `SIC_VENTANA` must not silently select a healthy window.

**Corrections.** These behaviors now fail closed or default to unknown/pending as appropriate. Data checks compare actual and declared counts and enforce unique, disjoint IDs across partitions and the absence of truth files/columns. Unknown window identifiers are errors. Smoke/regression coverage includes malformed states and integrity failures.

**Boundary.** The `test` partition remains diagnostic, not an automatically untouched holdout. The champion/alias pointer pair is still not transactional. Neither model regeneration nor a current-version release was performed.

### 5.5 Root distribution, CI, and monograph

**Findings.** The distribution validator claimed “no secrets” without scanning contents and did not validate manifest hashes. The manifest no longer matched current declared files. Root CI invoked deleted `real/ihdp` paths. An unknown Typst `modo` silently selected `curso`, weakening edition reproducibility.

**Corrections.**

- `scripts/validate_student_repo.py` now checks all declared paths, duplicate/unsafe entries, byte counts, and SHA-256 values while retaining forbidden path/name checks.
- Its output and root README now describe only the checks actually performed; neither claims a content-level secrets scanner.
- All **20** mismatched declared-file records exposed by the first new integrity run were refreshed. The other **105** matching entries were left unchanged; all **125** now pass.
- Root Week 4 CI now uses `synthetic/ihdp` and names that scenario accurately.
- The monograph rejects an unknown edition with an explicit Typst panic; non-course editions exclude E/J, and `principios` also excludes B/L3. Build commands and expectations are documented in `02_causal AI en produccion/Causal_AI/README.md`.

**Boundary.** Manifest integrity covers only the files declared for public distribution, not the entire worktree. No GitHub Actions run was triggered, and there is still no root CI matrix covering notebooks, production, MCP, Rust, and every Typst edition.

## 6. `argumentos copy/`: delivered theory and real-data engineering project

The directory is now a self-contained Rust workspace rather than only an argument-kernel sketch. It includes:

1. preserved typed claims, expressions, assumptions, canonical hashes, profiles, derivation-local cycle handling, pending obligations, and candidate receipts;
2. strict JSON contracts and CSV parsing, schema/range/missing-value/duplicate checks, deterministic preprocessing, entity/epoch split governance, artifact hashes, and a holdout-use ledger;
3. an implemented five-fold cross-fitted AIPW estimator with logistic IRLS propensity, ridge outcome models, fold-local transforms, declared clipping, influence-function intervals, and saved Markdown/Typst reports;
4. nine substantive cited chapters spanning claim taxonomy, potential outcomes/SCMs, identification, positivity, IPW/AIPW/DML, CATE/meta-learners and policies, uncertainty/transport, governance/monitoring, and argument reconstruction;
5. a typed corpus connecting the book and empirical artifacts without treating structural validity as scientific proof.

### Genuine observational input

`data/real/lalonde.csv` is the MatchIt LaLonde sample mirrored at a pinned Rdatasets commit: **614** observations, **185** NSW treated and **429** nonexperimental PSID comparisons, **27,509 bytes**, SHA-256 `a49703ca0233ba0a27fa9cda959a38a07f6825def0f7743cf2380ce4e57dd3ef`. Provenance and direct-source links are recorded in `data/real/PROVENANCE.md`.

This is a genuinely observational NSW–PSID comparison, not the randomized NSW benchmark and not a synthetic relabeling. Nevertheless, the parameter is only conditionally interpretable: exchangeability, consistency, interference, treatment versions, sampling, measurement, and transport are not established by the CSV. Estimated overlap is weak (**138/366** training and **41/134** holdout observations outside raw-propensity [0.05, 0.95]). The reported train cross-fitted AIPW contrast is −269.3 nominal dollars with normal 95% interval [−2274.4, 1735.9], and the consumed holdout contrast is 426.3 [−3144.6, 3997.3]. These wide intervals and the nonzero estimates are **not evidence of a beneficial or harmful population effect** and omit hidden-confounding and other important uncertainty.

The data-value redistribution license is unresolved upstream. Rdatasets' uncertainty and MatchIt's package GPL text are not conflated; the bundled pin is not presented as a new license grant.

An independent numerical review within the audit reconstructed the AIPW/ridge/logistic calculations and found only floating-point-scale differences. That supports implementation fidelity, not causal identification or evidence closure.

### Explicit non-claims

- CATE, treatment-policy learning, hidden-confounding bounds, live monitoring, and deployment are covered theoretically but are not empirically implemented in this executable case.
- The saved final holdout has already been consumed; it was not rerun during final validation.
- `scientific_causal_claim_verified`, `claim_supported`, `corpus_closed`, and `scientific_validity_certified` remain false where applicable.
- The corpus currently has **52 claims, 4 arguments, 30 candidate evidence specifications, and 59 pending obligation-and-axis counters**. Structural checks do not replay receipts, verify prose anchors, or close those obligations.
- Local ledgers and hashes aid reproducibility but are not tamper-proof, externally witnessed preregistration or authentication.

## 7. PASA — checks that actually passed

“Pass” below means only that the named local check exited successfully on 2026-11-22.

| Component | Verified result |
|---|---|
| Root doctor | Python 3.13.14 and imports of `numpy`, `pandas`, and `sklearn` passed under the Week 4 `.venv_ci`. Standalone `/usr/bin/python3` 3.9.6 is below course requirements, and standalone Python 3.13 lacks those packages. |
| Public-distribution validator | Four Serie A notebooks; no detected forbidden names/paths in its enumerated scope; **125** declared files passed existence, size, and SHA-256 checks. |
| Policy helpers | **46 passed** in 0.26 s. The existing Week 4 scientific stack was combined through `PYTHONPATH` with `pytest` from the existing MCP environment; no packages were installed. |
| Production | **54 passed**: 20 core, 8 B1, 11 B3, and 15 B4 tests; `compileall` succeeded. |
| MCP | **94 canonical passed** and **14 legacy passed** on the final run. Earlier in the same intervention, installed-wheel tests had **91 passed** and offline build/dependency checks passed; those specific checks were not necessary to repeat after root-only edits. |
| Week 4 data | Synthetic IHDP: 747 rows split 448/149/150. Synthetic Jobs: 1,722 rows split 1,033/344/345. Hashes, declared/actual counts, unique/disjoint IDs, schema, and truth wall passed. |
| Week 4 assertions/service | `pruebas_estimacion.py` printed `PRUEBAS: OK`; `humo.py` printed `HUMO: OK`, including non-pass gates, malformed artifacts, abstention, determinism, and service routes. Champion remained `v0009`. |
| DML-IV | **5/5 passed** with its own `.venv`; DoubleML emitted nonfatal pandas deprecation warnings. |
| Rust argument workspace | `cargo fmt --check`, `cargo check`, Clippy with warnings denied, and **107 tests passed**. |
| Argument fixtures/corpus | **11/11** expected accept/reject fixtures passed; corpus structural checks succeeded with 29 obligations still pending. No holdout estimation was replayed. |
| Argument book | Typst 0.15.1 compiled a tagged **33-page** A4 PDF successfully. |
| Main monograph | `curso`: **459 pages**; `comercial`: **449 pages**; `principios`: **365 pages**. All compiled successfully to `/tmp`. Unknown `modo=invalido` failed with exit code 1 and the intended message. |
| Patch whitespace | `git diff --check` passed before report creation and is rerun as a final hygiene check. It does not inspect or validate untracked content semantically. |

## 8. FALLA — unresolved failures and release blockers

1. **MCP local V1 is incomplete.** `V1-02`, `V1-03`, and `V1-09` are `NOT_IMPLEMENTED`; the acceptance runner intentionally exits 1 with `BLOCKED_LOCAL_V1`. A unit-test green badge must not be presented as full acceptance.
2. **Confirmatory A4 evidence is unavailable.** The historical holdout was inspected. Current outputs can be exploratory, but only a new uninspected holdout under a newly frozen protocol can restore independent confirmation.
3. **LaLonde redistribution permission is unresolved.** The data-value license must be established before treating the self-contained bundle as legally cleared for redistribution.
4. **Untrusted artifact loading is not safe.** Some joblib/pickle paths may deserialize before hash verification. Hashes detect particular byte changes but do not authenticate provenance or make deserialization safe. Only trusted local artifacts belong in the current boundary; authenticated/signed bundles and safe loading are future work.
5. **Filesystem races remain.** MCP path containment is checked before operations, but does not eliminate symlink/replacement TOCTOU on a persistent writable filesystem. It is a trusted-filesystem boundary, not a sandbox.
6. **Week 4 pointer updates are not transactional as a pair.** Alias/champion updates need crash-safe transactional design before strong release claims.
7. **Root CI coverage is incomplete.** The corrected workflow exercises Week 4 only; there is no comprehensive root CI pass for the notebook, production, MCP, Rust, and Typst components.
8. **Current champion readiness is not established by historical evidence.** Evidence associated with `v0008` cannot silently certify `v0009`; current-version evaluation remains necessary.

Items 4–6 are documented residual boundaries as well as failed properties for hostile or crash-prone environments; they were not hidden behind successful unit tests.

## 9. NO VERIFICABLE — claims not established by this audit

- **Causal identification and population effects:** no computational gate or test establishes exchangeability, positivity in the population, consistency, noninterference, treatment-version validity, or transportability.
- **Full notebook execution:** A1–A4 were not retrained/exported end-to-end; only focused helper tests were run.
- **Docker and deployment:** the Docker daemon was unavailable. MCP Docker behavior was reviewed statically but not executed. No cloud, production, or live deployment was validated.
- **Current Week 4 artifact reproduction:** no training, estimation, monitor CLI, demo, registration, or promotion was run into stored artifacts. The service smoke checks do not constitute fresh model evidence.
- **Production end-to-end behavior:** the full production demo/monitor/live service was not run.
- **Comprehensive CI:** local checks do not prove GitHub Actions or other clean-environment builds pass.
- **Corpus/evidence closure:** 29 obligations remain pending, and registered/candidate evidence is not independently replayed by the structural checker.
- **Secrets and whole-tree integrity:** the root validator is deliberately not a content-level secret scanner and does not certify files outside the 125-entry public manifest.
- **Legal compliance and complete editorial correctness:** no legal opinion or exhaustive scientific/editorial peer review was produced.
- **Clean global holdout governance:** local ledgers and already-consumed holdouts are reproducibility aids, not proof that no human inspected or reused outcomes elsewhere.

### Synthetic versus observational benchmark terminology

The current Week 4 numeric IHDP/Jobs files are under `synthetic/`. Their numeric values must not be described as direct empirical observations from the original studies. Reserved `real/` labels in older benchmark metadata or other namespaces are not, by themselves, evidence of empirical provenance. The deleted `real/ihdp` CI path was corrected to `synthetic/ihdp` for this reason and because the current files live there.

By contrast, the LaLonde/NSW–PSID CSV in `argumentos copy/data/real/` is a pinned observational data artifact. Its genuine observational provenance still does not make treatment randomized or its adjusted contrasts automatically causal.

## 10. Executed commands and reproducibility notes

Commands below use the same relative working directories as the final checks; environment-specific absolute paths are shown where needed.

### Root

```sh
cd <repo>

07_docencia/semana_4_proyecto/.venv_ci/bin/python scripts/doctor_minimo.py
python3 scripts/validate_student_repo.py
PYTHONPATH=03_notebooks_caso_estudio:08_mcp-agentes-causales/.venv/lib/python3.13/site-packages \
  07_docencia/semana_4_proyecto/.venv_ci/bin/python -m pytest -q \
  03_notebooks_caso_estudio/tests/test_policy_utils.py
git --no-pager diff --check
```

The first validator run correctly failed and listed every stale size/hash. After only the affected manifest records were refreshed, it printed:

```text
student repo: OK (4 notebooks Serie A; sin nombres/rutas prohibidos; 125 archivos del manifiesto con tamaño y SHA-256 verificados)
```

### Production

```sh
cd 04_produccion_causal
make validate PY=.venv_ci/bin/python
```

The four `unittest discover` stages ran 20, 8, 11, and 15 tests, all OK; `compileall` then succeeded. No `demo` or `monitor` target was invoked.

### MCP

```sh
cd 08_mcp-agentes-causales
.venv/bin/python -m pytest -q tests
.venv/bin/python -m pytest -q server/tests
```

Results: `94 passed` and `14 passed`. The previously executed acceptance runner remained `13 PASS / 0 FAIL / 3 NOT_IMPLEMENTED / BLOCKED_LOCAL_V1`; it was not relabeled or bypassed.

### Week 4 safe suite

```sh
cd 07_docencia/semana_4_proyecto
SIC_ESCENARIO=synthetic/ihdp .venv_ci/bin/python datos.py
SIC_ESCENARIO=synthetic/jobs .venv_ci/bin/python datos.py
SIC_ESCENARIO=synthetic/ihdp .venv_ci/bin/python pruebas_estimacion.py
SIC_ESCENARIO=synthetic/ihdp .venv_ci/bin/python humo.py
cd extension_dml_iv
.venv/bin/python pruebas_iv.py
```

No `make demo`, `make estimar`, `make registrar`, or `make monitor` was run.

### Rust argument/Causal ML project

```sh
cd argumentos\ copy
cargo fmt --all -- --check
cargo check --workspace
cargo clippy --workspace --all-targets -- -D warnings
cargo test --workspace
mkdir -p build/audits
cargo run --locked -p arg-cli -- doctor
cargo run --locked -p arg-cli -- fixtures --dir examples/fixtures
cargo run --locked -p arg-cli -- check --kernel corpus/causal_ml.json
cargo run --locked -p arg-cli -- corpus --dir corpus --root . --json build/audits/corpus_audit.json
typst compile --root . book/main.typ /tmp/causal-ml-book.pdf
pdfinfo /tmp/causal-ml-book.pdf
```

The non-estimating checks were run fresh. The consumed LaLonde holdout pipeline was not rerun. The project's README also documents locked Cargo variants and a separate clean-replay protocol for future work.

### Main monograph

```sh
cd 02_causal\ AI\ en\ produccion/Causal_AI
typst compile --root . main.typ /tmp/Causal_AI-curso.pdf
typst compile --root . --input modo=comercial main.typ /tmp/Causal_AI-comercial.pdf
typst compile --root . --input modo=principios main.typ /tmp/Causal_AI-principios.pdf
typst compile --root . --input modo=invalido main.typ /tmp/Causal_AI-invalido.pdf
```

The first three exited 0; the last exited 1 with `modo de edición desconocido: invalido; use curso, comercial o principios`. `pdfinfo` reported 459, 449, and 365 pages respectively.

## 11. Recommended next work, in priority order

1. **Resolve legal and scientific release blockers:** establish LaLonde data-value redistribution permission and freeze a new protocol with a genuinely uninspected A4 holdout before any confirmatory reporting.
2. **Complete or rescope MCP V1:** implement and independently verify `V1-02`, `V1-03`, and `V1-09`; keep the acceptance badge blocked until then.
3. **Re-establish current-version evidence:** evaluate the actual champion (`v0009`) under a clean protocol rather than relying on historical `v0008` evidence.
4. **Add a root CI matrix:** run policy tests, production validation, canonical/legacy/package MCP tests, locked Rust checks, argument fixtures/corpus, and all Typst editions on clean workers.
5. **Harden the trust boundary:** replace unsafe pre-verification deserialization, authenticate bundles, define filesystem ownership/permissions, and address TOCTOU with an appropriate sandbox or OS-level design.
6. **Make registry transitions crash-safe:** design an atomic generation/pointer protocol and recovery behavior rather than treating independent writes as one transaction.
7. **Perform independent substantive review:** replay registered evidence, inspect claims/citations and model assumptions, and run clean notebook/container/deployment checks where those claims are needed.

## 12. Final assessment

The repository now has materially better engineering controls and a much stronger educational bridge from causal theory to executable evidence accounting. The most valuable change is not merely the number of passing tests: ambiguous states now more often remain pending, malformed evidence fails closed, and previously implicit scientific assumptions are labeled as assumptions.

At the same time, the correct release posture is **qualified**, not green across every dimension. Software checks pass in the executed scopes; full MCP acceptance fails, several security boundaries remain explicit, the data license needs resolution, and independent causal/confirmatory conclusions remain unverified. That distinction should be preserved in future READMEs, CI badges, teaching materials, and public claims.
