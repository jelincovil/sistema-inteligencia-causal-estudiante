# External review packet request

**Purpose.** This packet is ready to hand to an independent reviewer or legal/licensing specialist. It is a request for an external verdict, not a simulated independent verdict.

## Deliverables requested

1. **Identification review.** Decide whether the evaluated claim is identifiable from the supplied NSW–PSID construction, with explicit treatment of consistency, interference, treatment versions, exchangeability, measurement, and support. State whether a valid baseline adjustment set exists and on what population.
2. **Overlap/transportability review.** Quantify the transportable support of the declared target population. State whether the computed contrast has a population interpretation, or is bounded to observed support only.
3. **Replay/replication review.** From the byte pins in the project, re-create the audit, splits, report, ledger-hash binding, and generated artifacts using a cleared computational environment. Report deterministic match/mismatch and any nondeterministic dependencies.
4. **Sensitivity review.** Specify a hidden-confounding analysis appropriate to this analysis (for example, sensitivity parameters, partial-R² bounds, or a prespecified Rosenbaum-style model only where applicable). Do not substitute the existing 0.01/0.05/0.10 clipping checks.
5. **Rights review.** Decide whether the CSV or this repository may redistribute the data values in its current distribution status and what removal/notice obligation would apply otherwise.
6. **Operating-claim review.** State whether any monitoring, rollback, oversight, or deployment-use claim is supportable. If none, keep this repository permanently as a research artifact.

## Evidence to inspect

- `data/real/lalonde.csv` and `data/real/PROVENANCE.md`
- `config/lalonde.contract.json`
- `artifacts/lalonde/audit.json`
- `artifacts/lalonde/splits.csv`
- `artifacts/lalonde/causal_report.json`
- `artifacts/lalonde/holdout_ledger.json`
- `book/main.typ`, `book/LITERATURE_MATRIX.md`, and `corpus/causal_ml.json`
- `reviews/lalonde_internal_audit.md`
- owner, reviewer identity, date, scope, express verdict, required changes, and redistributable review artifact

## Reviewer decision options

- `accepted_for_population_causal_claim`
- `accepted_for_matched_support_only`
- `rejected_for_identification`
- `inconclusive_needs_new_data`
- `redistribution_prohibited`
- `redistribution_permitted_with_notice`
- `not_deployment_ready`

## Repository treatment after review

- No claim, receipt, `anchor_verified`, `claim_supported`, or deployment status may be promoted without the reviewer's written output and project owner approval.
- Any revision to holdout inputs, learners, split fractions, clips, transformations, or estimand after seeing the result must be labeled as a new analysis protocol.
- Absent external review, this remains a traceable, inspected internally replayable dossier, not a scientific or operational certification.
