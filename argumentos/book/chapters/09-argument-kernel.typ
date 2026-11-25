#import "../common.typ": boundary

= Argument Graphs, Evidence Candidates, and Audit Limits

== Why a separate argument kernel

Statistical artifacts can be reproducible while their interpretation becomes detached from its premises. The argument kernel is a small administrative layer for typed claims, exact expression trees, dependency rules, evidence specifications, canonical content hashes, and cycle diagnostics. It is intentionally conservative: structural validity records whether a formal dependency follows a compiled rule, not whether the underlying science is true.

The four workspace crates have distinct responsibilities:

- `arg-model` strictly loads schema documents, rejects duplicate fields and self-authored status claims, preserves claim/evidence types, and computes canonical hashes;
- `arg-check` implements profile rules, derivation-local cycle handling, candidate receipt admission, and explicit pending obligations;
- `arg-cli` exposes kernel checks, local fixtures, doctor information, receipt admission, and recursive corpus byte inventories; and
- `causal-ml` handles the real-data audit, splits, nuisance estimation, AIPW, holdout ledger, and artifact-derived reports.

The kernel neither replaces the estimator nor embeds statistical authority in JSON. It makes the provenance and reasoning dependencies inspectable.

== Claims, scopes, expressions, and canonical identity

A claim has an identifier, source locator, kind, statement, exact expression, scope, and explicit assumptions. Claim kinds are formal, empirical, conditional, and factual. An expression can be exactly one of three shapes: an atom, a conjunction (`and`), or an implication (`implies`). There is no negation, universal, existential, or any other shape in the strict schema. Scope fields constrain such things as estimand, dataset, role, clip, setting, diagnostic, or claim class.

The corpus carries an explicit top-level `atoms` registry. Every atom an expression can name must appear there; the registry maps each atom to the single claim that defines it (`definition_claim`) and to a short plain-language description. An atom used by an expression but absent from the registry is rejected by the loader, and so is a registered atom no claim defines or uses. The registry is explicit identity bookkeeping, not an approval ledger: it has no status, review, or support fields, and it cannot make a premise true. Claims whose expressions are conjunctions or implications own no atoms of their own; ownership belongs to the atom-typed leaves.

Canonical serialization removes presentation whitespace and orders structure deterministically so the content digest refers to semantic kernel content rather than accidental formatting. Raw-file SHA-256 and canonical SHA-256 are both useful: the former identifies exact document bytes; the latter identifies the normalized representation accepted by the loader.

A hash is not a trusted timestamp, authorship proof, digital signature, or semantic correctness judgment. If a file changes, its inventory digest changes; this says nothing by itself about whether the old or new proposition is scientifically justified.

The loader rejects attempts to write fields such as `approved`, `lean_checked`, `reproduced`, or `claim_supported` into a claim document. Status must be computed by the checker. Unknown statuses remain unknown rather than defaulting to valid.

== Profiles and rule obligations

The `structural` profile supports exact alias, conjunction introduction, and modus ponens. The `scientific_audit` profile preserves the legacy evidence-aware rules: formal anchor/application obligations, conjunction introduction, modus ponens, empirical records, conditional application, and exact aliases. Rules are compiled in Rust; a corpus cannot invent a new rule simply by writing its name.

For an AND-introduction argument, the conclusion expression must be the conjunction of the premise expressions in the same order. For modus ponens, the implication antecedent and premise must match exactly, with the conclusion matching the consequent. Conditional application checks two requirements on the conclusion: its scope must not widen any premise scope, and every premise together with the assumptions it carries must be retained as an obligation in the conclusion's assumptions. Obligation retention is the mechanism that stops a proof-shaped argument from quietly laundering premises into unstated context: if a premise is used, the obligations it names survive into whatever conclusion is drawn from it. These restrictions prevent a broad causal statement from being derived from a narrower one by changing only its prose.

A structurally valid derivation can still carry obligations such as:

- `NO_FORMAL_PROOF` when an exact expression tree has no checked formal proof;
- `NO_REPLAY` when evidence is pending or merely a candidate;
- `MIXED_DOSSIER` when premises of different claim kinds are combined without becoming a formal theorem; and
- `SCOPE_NOT_JUSTIFIED` when a computation does not discharge identification or population independence.

This separation is visible in the LaLonde corpus. Syntactic backdoor implication and modus ponens may be structurally valid while all identification premises remain pending. The conditional causal claim retains its assumptions instead of shedding them after an AIPW computation.

== Cycles are assessed per derivation, and across arguments

A dependency graph can contain an invalid cyclic alternative and a separate acyclic derivation for the same conclusion. Rejecting the entire claim merely because one alternative is cyclic would erase that distinction. The checker therefore diagnoses cycles within each derivation: the edges from a conclusion's premises and assumptions are walked for the argument being judged, and an independent alternative derivation is judged on its own edges.

A second layer closes the loop across arguments. Assumption obligations are also walked globally for cycles among claims, so an assumption that is — directly or through a chain — its own obligation is flagged. Both layers are administrative dependency checks, and neither substitutes for the other.

Cycle handling is still administrative. It does not infer causal cycles from SCMs, solve feedback systems, or decide whether reciprocal treatment mechanisms are identifiable. Causal DAG acyclicity and derivation-graph cycle detection are different topics.

== Evidence kinds preserve legacy semantics

Kernel evidence kinds remain `lean`, `python`, and `registered` for compatibility with existing fixtures. These names are schema vocabulary, not instructions to execute those ecosystems. No Python tooling is added or called by this project.

A `registered` specification tracks a runner identifier, target path, scope, and availability. Its presence does not replay a process, validate a claim's values, or produce computational proof. Under the preserved rule contracts, registered evidence alone does not satisfy an empirical-record derivation, just as it does not satisfy a formal anchor.

Receipt admission accepts incoming receipts only as candidates. Even fields such as `execution_passed` or `scientific_criterion_met` cannot cause the base checker to set `claim_supported = true`. This candidate-only boundary protects the project from self-authored success receipts. Independent runners, signature verification, semantic target parsing, and proof replay would require separate implementations and trust decisions.

== The LaLonde argument corpus

`corpus/causal_ml.json` links the following objects directly to local sources and candidate artifacts:

+ claim taxonomy and the difference between associational, predictive, counterfactual, and operational statements;
+ consistency, noninterference, exchangeability, positivity, and a declared adjustment-set premise, combined into a five-atom conditional identification conjunction and a conditional backdoor implication;
+ exact AIPW/cross-fitting definitions and the frozen estimator contract;
+ real-data lineage split into independently falsifiable facts (pinned bytes and hash, commit-bound URL); unresolved data-value licensing; schema audits split into observation count, declared columns, exact duplicates, duplicate unit ids, and repeated measurement vectors;
+ feature availability split into baseline availability, outcome exclusion, and frozen transforms; split governance split into entity-hash strategy, declared fractions, and entity-disjoint verification;
+ estimator and protocol facts split into folds and cross-fitting, propensity-fit numerics, frozen primary clip, frozen sensitivity clips, and outcome models;
+ descriptive and adjusted empirical statements tied to generated report paths; overlap diagnostics split by train and holdout slices; numerical-convergence diagnostics split by fold-level and deployed fits;
+ the local holdout-use record split into the ledger event, the report-side access sequence, and the tuning-reuse flag;
+ two predeclared sensitivity records for the holdout path at clips 0.01 and 0.10, alongside the primary clip 0.05 train and holdout records, because clip choice materially moves the holdout readout;
+ hidden-confounding, interval, transportability, monitoring, and reconstruction limits; and
+ a final conditional claim that does not discard those premises.

The architecture is deliberately split: one atomic, independently falsifiable fact per claim, and one evidence specification per atomic claim where a registered artifact target exists. Each specification carries exactly the claim's scope — never a wider or narrower one — and remains a candidate request, not admitted evidence. Compound statements such as the protocol dossier are explicit derived conjunctions, introduced by AND-introduction from their atomic premises, and a mixed factual/empirical dossier records a `MIXED_DOSSIER` obligation instead of laundering its inputs into a single kind. Theory-only limitation claims carry no registered evidence specification, because there is no runner that can execute them.

This linkage is intentionally not a green scientific dashboard. Factual claims about source bytes or contracts lack replay-promoting receipts; empirical outputs remain pending; and conceptual statements still need substantive peer review. Unknown evidence stays unknown.

== Corpus inventory and its precise limits <reconstruction>

The `argumentos corpus` command recursively discovers JSON kernels, performs strict loading and structural checks, and emits a deterministic JSON catalog. It inventories raw and canonical file hashes, claim/source/evidence records, availability and pending counts, duplicate cross-file IDs, local source paths, and current registered artifact paths and digests. Missing files, invalid kernels, duplicate identifiers, rejected derivations, or path-escaping locators cause a nonzero audit result.

A passing corpus inventory means that the local structural and existence checks succeeded. It specifically does *not* mean that:

- a Markdown heading, Typst label, or JSON path after `#` was parsed and verified—the current audit reports `anchor_verified = false`;
- numerical statements in prose were compared semantically with JSON values;
- empirical or formal claims were independently replayed;
- reference bytes have trusted timestamps or immutable backups;
- scientific identification, target-population definitions, or legal rights were approved; or
- the corpus is closed (`corpus_closed` remains false).

The fixture command supplies a separate small contract suite: valid pending documents must parse and invalid shapes, cycles, rules, missing premises, evidence mismatches, self-authored status, and scope widening must fail their expected paths. These deterministic negative tests protect the administrative checker, not the scientific assumptions.

== From administrative reconstruction to genuine verification

A credible extension path would add independently maintained runners, signed and timestamped manifests, semantic JSON-path and document-anchor replay, artifact-environment capture, registered seeds and executable identities, and—where warranted—formal proof checking of the mathematical layer. Every addition would need adversarial tests and a clear trust model.

Even then, executable verification would remain subordinate to design. A formally verified backdoor derivation proves the implication from its encoded premises; it does not prove that NSW and PSID participants are exchangeable, that earnings are measured correctly, that interference is absent, or that an external population has the same effect. The argument kernel is most useful when it keeps that boundary impossible to overlook.

#boundary[
  No output of this workspace should be redescribed as `CORPUS_CLOSED`, `SOFTWARE_READY`, or scientifically certified without evidence and review outside the current implementation. Structural green is not scientific green.
]
