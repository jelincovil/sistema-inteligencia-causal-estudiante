= Uncertainty, Sensitivity, and Transportability

== A single interval is not the full uncertainty budget <uncertainty>

Statistical reports often display one confidence interval as if it summarized all reasons an estimate could be wrong. A more honest uncertainty budget separates at least six sources.

#figure(
  table(
    columns: (1.05fr, 2.2fr, 1.55fr),
    table.header([Source], [Question], [Treatment in this project]),
    [Sampling], [How variable is the score under its stated unit-level sampling approximation?], [Normal-reference influence-function interval],
    [Nuisance estimation], [How do model form, regularization, cross-fitting, and convergence affect the estimate?], [Fixed elementary learners, fold diagnostics, no model search],
    [Support], [Which regions have sparse treatment/control information?], [Raw propensity tails and fixed clipping variants],
    [Unmeasured confounding], [How large a departure from exchangeability remains plausible?], [Unresolved; no numeric hidden-bias bound],
    [Measurement and selection], [Do source rows represent well-defined units, interventions, outcomes, and inclusion mechanisms?], [Source documentation and limitations; not externally validated],
    [Transport], [Does the target differ in effect modifiers, versions, interference, or follow-up?], [No target-population identification claim],
  ),
  caption: [Uncertainty is multidimensional; a sampling interval covers only one row and only under its assumptions.],
) <tab:uncertainty-budget>

The normal-reference interval is conditional on the implementation and its asymptotic approximation. It is not a Bayesian posterior probability that the effect lies in an interval, and it does not randomize over analyst assumptions. A wide interval can reveal limited information; a narrow interval can coexist with large structural bias.

Cross-fitting variability adds another practical issue. One deterministic split makes computation reproducible but does not display all possible fold assignments. Repeated cross-fitting, bootstrap procedures, or learner-uncertainty analyses would require their own frozen protocol and cannot be improvised from the consumed holdout.

== Clipping sensitivity is not hidden-confounding sensitivity <sensitivity>

The executable case computes a small, predeclared set of clipped AIPW scores. Changes across clips demonstrate that stabilized inverse weights can alter the adjusted contrast. They do not represent a range of unmeasured-confounding scenarios, and one must not choose the “preferred” coefficient after comparing them. Omitted-variable-bias bounds require their own explicit sensitivity parameters @cinellihazlett2020.

A formal sensitivity analysis needs a parameterization of an identification departure. For example, without exchangeability but retaining consistency and support for the observed strata, define a mean-selection discrepancy

$ b_t(x) = E[Y(t) mid T=t,X=x] - E[Y(t) mid X=x]. $ <eq:selection-bias>

The standardization functional then satisfies

$ psi(t) = E[Y(t)] + E[b_t(X)], $ <eq:bias-decomposition>

so the adjusted observed-data contrast differs from the ATE by $E[b_1(X)-b_0(X)]$. Conditional exchangeability asserts these discrepancies are zero. @eq:bias-decomposition is an explanatory decomposition, not an estimator of hidden bias: the potential-outcome terms needed to learn $b_t$ remain unobserved. A useful sensitivity analysis would impose externally defended bounds or models on them and propagate those choices.

Rosenbaum's $Gamma$ framework offers another approach in matched observational studies. Under a particular logistic hidden-bias model, two otherwise matched units' treatment odds can differ by at most $Gamma$, and inference examines worst-case assignments over that bound @rosenbaum2002. That model targets specific matching designs and statistics. The current AIPW pipeline neither implements matching nor computes Rosenbaum bounds, so it would be incorrect to paste a $Gamma$ interpretation onto its clipping variants.

Other departures include differential outcome measurement, treatment misclassification, unobserved selection, interference, and treatment-version heterogeneity. Each needs a different sensitivity mechanism. A generic “robustness check” cannot cover all of them.

== Model and analyst uncertainty

Researcher degrees of freedom include the estimand, adjustment set, transforms, learners, regularization, folds, overlap handling, diagnostics, exclusion rules, and interval method. This project reduces some flexibility by freezing them before final holdout evaluation, but a frozen arbitrary specification is not thereby correct. The calibration gate uses only features and treatment for computational criteria; descriptive calibration outcome means are subsequently reported as associations, never used to rank or revise scientific explanations or models.

Predeclared sensitivity analyses should be read as a *set of analyses under named alternative assumptions*, not a menu from which to select a result. Reports should preserve all outputs, including nonconvergence, a changed sign, or disagreement between train and holdout. If a scientifically new specification is later required, it needs a new protocol identity and governance plan rather than silent reuse of the same holdout.

Multiplicity also applies across projects and repeated dataset uses. A local ledger cannot discover every analysis ever performed elsewhere on LaLonde variants. Its narrow meaning is one recorded event within this directory.

== Transportability and external validity <transportability>

An internally valid source-population effect need not identify an effect in another population. Let $S=1$ denote membership in the source sample and $S=s^*$ denote a target population. Let $X^*$ contain treatment-effect modifiers needed for exchangeability across populations. A simple transport assumption is

$ Y(t) perp S mid X^*, $ <eq:transport-exchange>

together with support $P(S=1 mid X^*=x)>0$ wherever the target has mass. Then

$ E[Y(t) mid S=s^*] = sum_x E[Y(t) mid X^*=x,S=1] P(X^*=x mid S=s^*). $ <eq:transport-formula>

This standardization expresses exactly what is required: a defensible selection diagram or exchangeability argument, measured effect modifiers, overlapping source/target support, compatible treatment versions and outcome measurement, and a target covariate distribution. Transportability and selection diagrams extend this logic to explicit differences between populations @pearl2014.

The pinned case has no separate target-population sampling indicator, target covariate census, or validated effect-modifier set. Consequently @eq:transport-formula cannot be computed for a claimed external workforce or time period. Repeating the source estimate with new confidence language would not identify transport.

Temporal transport adds treatment-version drift, labor-market changes, inflation and measurement differences, policy environments, and changes in interference. Since the artifact supplies no repeated epoch, even temporal leakage validation is unavailable. Entity-disjoint sample splitting is not a solution to these scientific shifts.

== Decisions under unresolved uncertainty

An honest decision record asks whether uncertainty is decision-relevant. A broad interval may have the same sign conclusion as a point estimate in an informal narrative but imply a different optimal action under asymmetric costs. Weak support may call for narrower eligibility, additional design work, or no deployment rather than a more aggressive algorithm.

Before acting, a review should therefore specify:

+ which conclusions are associational, predictive, counterfactual, or operational;
+ which structural departures would reverse a decision;
+ which additional data could identify them;
+ whether an intervention would be implemented under the same treatment versions and support; and
+ which monitoring signal triggers suspension or rollback.

The present artifact supports the limited operational conclusion that a fixed computation ran and was documented. It does not establish that training assignment is beneficial, harmful, or ready for policy use.
