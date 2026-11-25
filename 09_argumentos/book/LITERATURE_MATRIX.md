# Literature and kernel evidence matrix

**Purpose.** This matrix records how scholarly literature aligns with the finely-grained argument kernel. It is a curation aid, not an evidence receipt and not a claim that bibliographic lookup verifies any input to this project.

## How to read the matrix

- `Literature role` is the strongest function a source can play here: conceptual source, methodological warrant, design warning, or theoretical anchor.
- `Kernel status` means literature-aligned and unreviewed, never verified, approved, reproduced, or claim-supported.
- Semantic Scholar and OpenAlex identifiers identify metadata records consulted during curation. They do not encode full-text replay, citation-context checking, production validation, or scientific approval.
- Empirical claims still require the pinned generated artifacts in `artifacts/lalonde/`. A literature record cannot replace that evidence, and this project does not use literature to reinterpret the consumed holdout.

## Evidence roles, literature, and limits

| Kernel family | Literature anchor | Index records consulted | What it gives this project | What it does not give this project |
|---|---|---|---|---|
| Potential outcomes and intervention claims (`C.taxonomy.*`) | Neyman (1990), Rubin (1974, 1978), Imbens & Rubin (2015) | OpenAlex: [`W2263423262`](https://openalex.org/works/W2263423262) | Vocabulary for potential outcomes, interventions, estimation, and finite-population contrasts | Evidence that the NSW/PSID dataset identifies this case's estimand |
| Observational identification and backdoor adjustment (`C.assumptions.*`, `C.identification.adjustment_set`, `C.backdoor.theorem`) | Pearl (1995), Pearl (2009), Hernán & Robins (2020), Imbens & Rubin (2015) | OpenAlex: [`W2263423262`](https://openalex.org/works/W2263423262) | Formal distinction between backdoor-adjustment requirements and untestable exchangeability | A proof that this CSV has a valid adjustment set; that premise remains substantive and unverified |
| Propensity score as a balancing score (`C.assumption.positivity`, `C.empirical.overlap.*`) | Rosenbaum & Rubin (1983), Imbens & Rubin (2015) | OpenAlex: [`W2263423262`](https://openalex.org/works/W2263423262); DOI record `10.1093/biomet/70.1.41` retained in `references.bib` | Defines propensity scores and clarifies that overlap remains an estimable design/diagnostic issue | Evidence of actual exchangeability, positive target support, or correct estimated propensity model |
| LaLonde/NSW case provenance (`C.data.*`, `C.empirical.*`) | LaLonde (1986), Dehejia & Wahba (1999), Heckman, LaLonde & Smith (1999) | Semantic Scholar: [`61572150188f35378fa208a158d2dbe0817647b8`](https://www.semanticscholar.org/paper/61572150188f35378fa208a158d2dbe0817647b8); OpenAlex: [`W2150118316`](https://openalex.org/works/W2150118316), [`W3122948292`](https://openalex.org/works/W3122948292) (JASA DOI `10.1080/01621459.1999.10473858`; alternate OpenAlex records `W2891753394` and NBER `W2171442673` retain `10.3386/w6586`), [`W1530306231`](https://openalex.org/works/W1530306231) / DOI `10.1016/S1573-4463(99)03012-6` | Establishes the NSW/PSID design and the central warning that nonexperimental comparisons may fail to recover the experimental benchmark | Conditional exchangeability, valid PSID construction, license clearance, temporal separation, or a population effect for this exact match |
| AIPW and influence-function reasoning (`C.estimator.aipw`, `C.empirical.aipw_*`) | Robins, Rotnitzky & Zhao (1994), Hahn (1998), Imbens & Rubin (2015) | OpenAlex: [`W2263423262`](https://openalex.org/works/W2263423262); DOIs `10.1080/01621459.1994.10476818` and `10.2307/2998560` retained in `references.bib` | Grounds double robustness and efficient estimation under explicit regularity conditions | Validation of this project's logistic/linear nuisance learners, finite-sample diagnostics, overlap, estimand, or identification |
| Cross-fitting and DML (`C.protocol.cross_fitting`, `C.estimator.aipw`) | Chernozhukov et al. (2018) | Semantic Scholar: [`f75b70c9d7078724b592ec3e21de705e7b6ff73f`](https://www.semanticscholar.org/paper/f75b70c9d7078724b592ec3e21de705e7b6ff73f); OpenAlex: [`W2890118063`](https://openalex.org/works/W2890118063), DOI `10.1111/ectj.12097` | Explains Neyman orthogonality, splitting/cross-fitting, and product-of-error conditions | Proof of those conditions for the implemented eight-year earnings model in 614 rows |
| Clipping and hidden-bias limits (`C.empirical.aipw_holdout_clip_001`, `C.empirical.aipw_holdout_clip_010`, `C.limit.uncertainty`) | Cinelli & Hazlett (2020), Rosenbaum (2002) | OpenAlex: [`W2996483157`](https://openalex.org/works/W2996483157), DOI `10.1111/rssb.12348`; DOI `10.1007/978-1-4757-3692-2` retained for Rosenbaum | Distinguishes clipping sensitivity from hidden omitted-variable-confounding bounds | An omitted-variable-bias bound for the AIPW run, robustness certification, or license to reselect clips after viewing holdout outcomes |
| Claim taxonomy and argument boundary | Neyman (1990), Rubin (1974, 1978), Hernán & Robins (2020) | OpenAlex: [`W2263423262`](https://openalex.org/works/W2263423262); DOI `10.1017/CBO9781139025751` | Grounds the association/prediction/counterfactual/operational taxonomy used by the kernel | Proof that the kernel's AST represents causal logic |
| Transportability limits (`C.limit.transportability`) | Pearl & Bareinboim (2014), Imbens & Rubin (2015) | OpenAlex: [`W2263423262`](https://openalex.org/works/W2263423262) | Supports population-selection diagrams and explicit target-distribution assumptions | Permission to extrapolate from this sample to other populations or periods |
| Evidence obligations and replay governance | No bibliographic article substitutes for replay, hashes, or attestation | Not applicable | Local provenance, hashes, ledgers, and artifacts remain the operative evidence channel | External witness, publication approval, `claim_supported`, or production readiness |

## Fine-grained kernel curation resulting from this pass

1. The case-lineage triangle remains explicitly **LaLonde → Dehejia & Wahba → this pinned MatchIt/Rdatasets artifact**. It is not represented as the NSW randomized benchmark.
2. The backdoor implication remains an argument representation, not a proof: adjustment-set validity is an explicit unverified premise.
3. Weak overlap remains an empirical risk claim: `138/366` training rows (`37.70%`) and `41/134` holdout rows (`30.60%`) fall outside the primary raw-propensity interval.
4. Clip `0.01` and `0.10` are sensitivity checks, not a positivity repair or a robustness certification.
5. Literature curation does not change `anchor_verified:false`, candidate evidence status, or any holdout-based numerical result.

## Bibliographic status normalized in this pass

- `references.bib` retains the original entries and adds `heckman1999`, `imbensrubin2015`, and `cinellihazlett2020`.
- LaLonde's 1986 AER article has no stable DOI in the consulted records. OpenAlex's nearest exact-title record is `W2150118316`, but OpenAlex dates it as the 1984 NBER-aligned/preprint record rather than the 1986 journal page. The bibliography therefore records the journal citation without inventing a DOI.
- Dehejia & Wahba exists as a working-paper record (OpenAlex `W2171442673`, NBER DOI `10.3386/w6586`) and as a JASA record (OpenAlex `W3122948292`; alternate `W2891753394`) with DOI `10.1080/01621459.1999.10473858`. The bibliography uses the JASA version.
- Heckman, LaLonde & Smith (1999) was added as methodological context, not as de novo evidence for this CSV.
- Cinelli & Hazlett (2020) was added as a reference for omitted-variable-bias bounds, not as evidence that the frozen AIPW run satisfies such a bound.

## Remaining boundaries

- OpenAlex and Semantic Scholar metadata can disagree, change, or contain duplicate/preprint links. Treat identifiers as lookup metadata, not evidentiary warrants.
- This matrix does not assert full-text verification of every cited source, citation-context validity, or independent replay.
- Literature support for methodology improves the corpus's citations and semantic review trail; it does not change the consumed holdout or certify the LaLonde result.
