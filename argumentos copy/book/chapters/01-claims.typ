#import "../common.typ": boundary

= Claims, Questions, and the Causal Workflow

== Four claims that must not be conflated <taxonomy>

A model can be useful for one kind of claim while providing no warrant for another. This project therefore labels every material statement as *association*, *prediction*, *counterfactual*, or *operational*. These labels describe the proposition being defended, not the sophistication of the software.

#figure(
  table(
    columns: (0.85fr, 1.45fr, 1.5fr, 1.2fr),
    table.header([Claim class], [Object of the claim], [What would support it], [What does not suffice]),
    [Association], [A functional of an observed joint or conditional distribution], [A measurement definition, traceable data, and a reproducible calculation], [High predictive accuracy or a statistically small p-value alone],
    [Prediction], [Out-of-sample outcome or decision loss under a declared deployment distribution], [A prediction target, leakage-safe validation, calibration where needed, and uncertainty], [A causal graph or a treatment coefficient alone],
    [Counterfactual], [A contrast between outcomes under specified interventions], [A well-defined intervention, estimand, observation model, identification assumptions, and estimation protocol], [Feature importance, SHAP values, or an observational coefficient without identification],
    [Operational], [Behavior of a versioned data and software system], [Execution records, access governance, monitoring, failure handling, and rollback], [A scientifically elegant estimand or a green unit-test suite],
  ),
  caption: [Claim taxonomy used throughout the project. Support remains class-specific.],
) <tab:claim-taxonomy>

An associational binary-treatment contrast is

$ Delta_"assoc" = E[Y mid T=1] - E[Y mid T=0]. $ <eq:assoc>

@eq:assoc is defined without potential outcomes. It may describe selection, treatment, measurement differences, or a combination of them. A prediction claim instead evaluates, for example, $E[(Y-hat(Y))^2]$ on observations not used to fit $hat(Y)$, with the prediction time and distribution stated. Neither expression says what would happen if the same units' treatments were changed.

A counterfactual claim concerns an expression such as $E[Y(1)-Y(0)]$, but writing potential outcomes does not solve identification. It creates obligations: what treatment versions exist, which population is targeted, whether units affect each other, and how observed data reveal the relevant potential-outcome distribution. An operational claim concerns a different object again: whether a particular contract, executable, split ledger, and monitoring process behaved as recorded. Its verification cannot fill gaps in the counterfactual argument.

== From a decision to an estimand

An *estimand* is the population quantity the analysis seeks, before finite-sample estimation choices. A precise estimand statement includes the unit, eligibility criteria, treatment strategies, outcome and horizon, handling of competing events and missingness, treatment-effect scale, and target population. Hernán and Robins organize this discipline through the target-trial analogy @hernan2020[Chapter 1]. A target trial need not be literally feasible or ethical; it makes ambiguities visible.

#figure(
  table(
    columns: (1fr, 2.8fr),
    table.header([Design element], [Question that must be answered]),
    [Unit], [Person, household, school, cluster, or another entity? Are repeated records separate units?],
    [Time zero], [When are eligibility, treatment assignment, covariates, and follow-up anchored?],
    [Intervention], [Which treatment version, duration, adherence rule, and co-interventions define each arm?],
    [Outcome], [What is measured, by whom, at what horizon, and in which units?],
    [Population], [To which source or target population does the estimand refer?],
    [Contrast], [ATE, ATT, a covariate-conditional effect, a risk ratio, a restricted time horizon, or policy value?],
    [Observation process], [How do sampling, treatment measurement, censoring, and missingness alter what is observed?],
  ),
  caption: [Minimum estimand and observation-model checklist.],
) <tab:estimand-checklist>

For example, “the effect of job training” is not yet a scientific estimand. A more defensible starting point would name the training program and eligibility period, define receipt relative to assignment, specify 1978 earnings and its nominal-dollar scale, identify the eligible target population, and explain the comparison-group construction. Even that statement leaves exchangeability and missing-data questions unresolved.

== The identification–estimation–computation sequence

The project uses the following ordering:

+ *Scientific question.* Name the intervention, outcome, time horizon, and target population.
+ *Causal model.* State structural equations or equivalent potential-outcome restrictions, including interference and measurement mechanisms.
+ *Estimand.* Write the functional that would answer the question under complete potential-outcome information.
+ *Identification.* Derive an observed-data functional under explicit assumptions. If this fails, a flexible learner cannot repair it.
+ *Data contract.* Establish unit IDs, timestamps, feature availability, types, missingness, duplicates, source bytes, and permissible role usage.
+ *Estimation protocol.* Freeze learners, folds, nuisance separation, clipping, diagnostics, calibration rules, and holdout policy before final evaluation.
+ *Computation and diagnostics.* Execute deterministic code; distinguish numerical failure, weak support, sampling uncertainty, and structural assumption failure.
+ *Evidence record.* Bind artifacts and arguments to exact bytes while keeping unknown assumptions unknown.
+ *Decision and monitoring.* If a decision follows, prespecify its loss, implementation constraints, drift checks, and rollback policy.

This order prevents a common inversion: using a promising holdout result to invent an estimand or assumption story afterward. It also separates *identification failure* from *estimation error*. A precisely estimated associational quantity can be a poor answer to a causal question; an imprecise adjusted estimate can still have a coherent conditional interpretation.

== What this executable project does—and does not do

#figure(
  table(
    columns: (1.25fr, 1.55fr, 1.35fr),
    table.header([Layer], [Implemented here], [Not established by implementation]),
    [Source], [Pinned public LaLonde/MatchIt CSV, exact bytes, source documentation, unresolved data-value license status], [A new redistribution license or proof of upstream legal completeness],
    [Data], [Typed audit, duplicate and range checks, entity-hash roles, feature-availability contract], [A temporal design, error-free measurement, or verified entity history],
    [Estimation], [Cross-fitted AIPW with deterministic logistic and ridge-linear learners], [Automatic elimination of confounding or model misspecification],
    [Governance], [One recorded final holdout event and read-only report regeneration], [A tamper-proof ledger or permission for renewed tuning],
    [Argument], [Typed claims, dependencies, canonical hashes, cycle handling, candidate receipts], [Formal proof replay, semantic anchor validation, or scientific claim certification],
  ),
  caption: [Artifact capability is deliberately narrower than scientific validity.],
) <tab:project-boundaries>

CATE meta-learners and policy learning are derived in @sec:heterogeneity as methodological context, but they are not executed in the LaLonde case. Flexible nuisance libraries, cluster-robust inference, repeated epochs, production monitoring, independent runner replay, and Lean proof checking are likewise outside the current implementation. Those absences are contract boundaries, not unfinished claims to be silently marked complete.

#boundary[
  The project’s success criterion is not a favorable treatment coefficient. It is a reproducible chain in which associations are labeled as associations, adjusted estimates receive only their earned conditional interpretation, and missing identification or evidence remains visibly unresolved.
]
