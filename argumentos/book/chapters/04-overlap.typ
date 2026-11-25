= Positivity, Overlap, and Estimand Support

== Positivity is an assumption about target support <positivity>

For a binary treatment and covariates $X$, define the propensity score

$ e(x) = P(T=1 mid X=x). $ <eq:propensity>

ATE positivity requires

$ 0 < e(x) < 1 quad "for almost every" x "in the target population support". $ <eq:positivity>

The support qualifier is essential. ATT identification needs control outcomes for covariate patterns represented among treated units; it does not require every population stratum to contain treated units. An ATE analysis over a restricted population can narrow the support requirement only by also narrowing the estimand.

*Structural nonpositivity* occurs when treatment is impossible or mandatory at a relevant stratum. *Practical nonpositivity* concerns sparse but theoretically possible treatment variation, producing extreme inverse weights and high variance. A sample containing only $T=1$ at one $X=x$ does not prove structural nonpositivity at $x$, but it signals that the observed-data functional is poorly supported there.

== Why overlap tails dominate adjusted estimates

Let $c in (0,1/2)$ and define a clipped score

$ e_c(x) = min(max(hat(e)(x),c),1-c). $ <eq:clipped-propensity>

Inverse-probability contributions then use denominators bounded by $c$ and $1-c$. That protects computations from arbitrarily large nominal weights, but it also changes the estimator from the unclipped AIPW functional. Clipping can hide weak overlap and induce bias; it does not create additional treated or control information. The smaller the effective denominators, the more a few observations can dominate both the estimate and its apparent stability.

A useful overlap review therefore includes more than the minimum and maximum of $hat(e)(X)$:

+ quantiles within treatment groups and split roles;
+ counts or shares below and above prespecified thresholds;
+ maximum implied inverse-probability weights and their concentration;
+ covariate distributions before and after clipping, trimming, or weighting;
+ convergence and separation diagnostics for fitted propensity models; and
+ explicit identification of any estimand that changes when records are removed or weights are modified.

The executable report implements raw-propensity summaries, threshold counts, fold diagnostics, and fixed clipping sensitivity calculations. It does not interpret those diagnostics as a hypothesis test proving @eq:positivity.

== The propensity score as a balancing score

The propensity score has two distinct roles. As a treatment probability it justifies inverse-probability weights under exchangeability. As a *balancing score*, it satisfies

$ T perp X mid e(X). $ <eq:balancing>

To see why, use iterated expectations:

$ P(T=1 mid X,e(X)) = e(X), quad P(T=1 mid e(X)) = E[e(X) mid e(X)] = e(X). $

Thus treatment is independent of $X$ conditional on $e(X)$. If potential outcomes are independent of $T$ given $X$, they are also independent of $T$ given $e(X)$ @rosenbaum1983. This does not imply that conditioning only on an *estimated* propensity score is automatically sufficient; model error, unmeasured confounding, and support problems remain @imbensrubin2015.

The same balancing logic encourages diagnostic comparisons across quantiles or matched sets. A low-dimensional propensity summary is useful, but adjustment need not use it exclusively: AIPW combines it with outcome regressions. Whatever route is chosen, measured balance is necessary for some diagnostics, not sufficient for exchangeability.

== Standardized differences and weight diagnostics

For a covariate coordinate $X_j$, a common unweighted standardized mean difference is

$ "SMD"_j = (overline(X)_(j,1)-overline(X)_(j,0)) / sqrt((s_(j,1)^2+s_(j,0)^2)/2). $ <eq:smd>

Weighted versions replace means and variances by their weighted counterparts. Threshold conventions can focus attention, but an SMD is not a p-value and its meaning depends on the target sample, weight definition, and interactions/nonlinearities. A small SMD for each main effect may coexist with poor joint overlap.

Weight summaries should accompany them. With treatment indicator $T_i$ and general analysis weights $w_i$, effective sample size is often summarized as

$ n_"ESS" = (sum_i w_i)^2 / (sum_i w_i^2). $ <eq:ess>

A small ESS relative to $n$ warns that a few rows dominate. The current Rust artifact exposes the more direct propensity-tail summaries instead of claiming a complete weight-diagnostics suite. Its clipping variants are execution checks, not evidence that the target population remains unchanged.

== Trimming, overlap weights, and changed questions

Trimming drops observations outside a propensity interval or outside common empirical support. This defines a data-dependent subpopulation unless the trimming rule itself is reframed prospectively. Reporting only the original ATE label after trimming would be misleading.

Alternative *overlap weights* upweight clinically or scientifically comparable regions:

$ w_i = T_i(1-e(X_i)) + (1-T_i)e(X_i). $ <eq:overlap-weights>

These weights target the average treatment effect in the overlap-weighted population, not the original ATE. Their stability is attractive precisely because they alter the target population toward equipoise. Any such switch must be justified before seeing results and must change the estimand statement.

The implemented case retains the frozen clipped AIPW scores and reports fixed alternative clips. It does not silently relabel its results as an overlap-weighted or trimmed treatment effect, and it does not select whichever clip gives a desired sign.

== Separation, finite samples, and numerical health

Logistic regression can approach infinite coefficients when a linear predictor nearly separates treatment classes. Small samples, sparse categorical combinations, and deterministic covariates make this more likely. Numerical convergence to finite values is therefore only one check: fitted probabilities at machine boundaries, coefficient magnitudes, rank deficiency, iteration counts, and stability across folds are also relevant.

The Rust pipeline standardizes features within each nuisance fit, excludes the intercept from ridge penalization, records propensity convergence and a separation heuristic, and preserves these diagnostics in JSON. Ridge stabilization can improve numerical behavior but introduces its own bias and does not solve a nonidentified parameter.

== Diagnostics cannot prove assumptions

#figure(
  table(
    columns: (1.25fr, 1.6fr, 1.5fr),
    table.header([Observed diagnostic], [What it can reveal], [What it cannot establish]),
    [Extreme $hat(e)(X)$], [Sparse estimated support or unstable weights], [Whether true positivity fails or omitted confounding exists],
    [Measured imbalance], [Residual differences in chosen summaries], [Exchangeability of unobserved potential outcomes],
    [Non-significant balance test], [Low evidence against a particular observed difference], [Equivalence, adequate power, or correctness of the adjustment set],
    [Good treatment prediction], [Treatment assignment is predictable from features], [Better causal identification; highly deterministic treatment can worsen overlap],
    [Numerical convergence], [An optimizer stopped under its recorded criteria], [Model correctness, positivity, or unbiased estimation],
    [Fold-to-fold stability], [Some computational robustness under the same sample], [New external populations or protection against shared structural bias],
  ),
  caption: [A diagnostic is local evidence about computation or observed data, not a proof of identification.],
) <tab:diagnostic-boundary>

This diagnostic–assumption distinction governs interpretation of the case output. Weak overlap lowers confidence in reliable ATE estimation and broadens uncertainty; it does not become a new randomized design. Conversely, a green computational gate must never be rendered as “causal validity passed.”
