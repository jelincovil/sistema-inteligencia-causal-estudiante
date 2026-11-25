= Observational Identification and Adjustment

== Conditional exchangeability <exchangeability>

Let $X$ be measured before treatment assignment. Conditional mean exchangeability for treatment level $t$ states

$ E[Y(t) mid T=1,X=x] = E[Y(t) mid T=0,X=x] = E[Y(t) mid X=x] $ <eq:mean-exchange>

on the target support. The stronger joint-independence statement is $(Y(1),Y(0)) perp T mid X$. Either formulation must be tied to the estimand; a mean restriction can identify mean effects without identifying distributional effects.

Exchangeability asserts that, within the specified covariate strata, treatment carries no additional information about potential outcomes. It is not established by equal observed outcomes, covariate balance, a large model $R^2$, or non-significant tests for observed differences. Unmeasured determinants of assignment and outcome remain possible. Balance diagnostics address measured features under a particular metric; they cannot observe the omitted variables that the assumption excludes.

A baseline covariate is not automatically an appropriate adjustment variable. Its causal location and the observation/selection process matter. The identification task is to justify a sufficient set, not to maximize the number of columns in a design matrix.

== Standardization and the backdoor derivation <backdoor>

For discrete $X$, define the adjustment functional

$ psi(t) = sum_x E[Y mid T=t,X=x] P(X=x). $ <eq:standardization>

The following derivation exposes exactly where assumptions enter. Starting from the law of total expectation,

$ E[Y(t)] &= sum_x E[Y(t) mid X=x] P(X=x) \
  &= sum_x E[Y(t) mid T=t,X=x] P(X=x) \
  &= sum_x E[Y mid T=t,X=x] P(X=x) = psi(t). $ <eq:identification-derivation>

The second equality uses mean exchangeability $Y(t) perp T mid X$; the third uses consistency on the $T=t$ stratum. Each conditional expectation in the first line must be defined. Positivity guarantees that the required treatment stratum exists wherever $P(X=x)$ places target mass, and noninterference ensures that $Y(t)$ describes the declared unit-level intervention. Continuous versions replace the sum by an integral and require a density/support formulation.

Under these premises,

$ tau_"ATE" = psi(1)-psi(0). $ <eq:identified-ate>

For the ATT, the outer distribution is that of the treated:

$ tau_"ATT" = sum_x [E(Y mid T=1,X=x)-E(Y mid T=0,X=x)] P(X=x mid T=1), $ <eq:identified-att>

again under the relevant conditional unconfoundedness, consistency, and positivity for the treated support. Substituting ATE weights into an ATT calculation changes the estimand.

== The graphical backdoor criterion

A set $Z$ satisfies the backdoor criterion relative to $(T,Y)$ in a causal DAG if no node in $Z$ is a descendant of $T$ and $Z$ blocks every path between $T$ and $Y$ that has an arrow into $T$. Conditioning on such a set identifies the interventional distribution by the backdoor adjustment formula @pearl1995 @pearl2009[Chapter 3]:

$ p(y mid "do"(T=t)) = sum_z p(y mid t,z) p(z). $ <eq:backdoor-formula>

The criterion is sufficient, not a statement that every non-descendant adjustment set is harmless or necessary. It encodes a particular graphical route to identification. Front-door adjustment, instrumental variables, and other strategies can identify effects when no observed backdoor set exists, but they introduce different assumptions and are not used here.

The identification conjunction used in `corpus/causal_ml.json` contains consistency, noninterference, conditional exchangeability, and positivity; the prose and DAG additionally require a valid baseline adjustment set and observation model. The kernel can represent the corresponding implication and modus-ponens dependency. It cannot examine a DAG, verify a target population, or decide whether the substantive premises hold.

== Confounder, mediator, collider: different adjustment consequences <roles>

The word “confounder” is sometimes used for any correlate of treatment and outcome. That heuristic is inadequate. Structural role and target estimand determine whether adjustment helps.

#figure(
  table(
    columns: (0.8fr, 1.35fr, 2.15fr),
    table.header([Structure], [Minimal pattern], [Adjustment implication]),
    [Common cause], [$X -> T$, $X -> Y$], [A measured sufficient common-cause set can block an open noncausal backdoor path. Whether a variable belongs depends on the entire graph.],
    [Mediator], [$T -> M -> Y$], [Adjusting for $M$ changes the total-effect estimand by blocking a causal path. Direct and indirect effects need separate definitions and stronger assumptions.],
    [Collider], [$T -> C <- Y$], [Conditioning on the collider can open a noncausal path. A pre-treatment collider on other ancestral paths can also create bias.],
    [Descendant of outcome], [$Y -> D$ or $T,Y -> D$], [Adjustment may condition on treatment consequences and distort identification; temporal priority alone does not make it a covariate.],
    [Instrument], [$Z -> T -> Y$ plus unmeasured $T <-> Y$], [Ordinary control for $Z$ does not remove unmeasured confounding and can amplify some biases; instrumental-variable identification requires separate exclusion and independence conditions.],
  ),
  caption: [Variable roles are graph- and estimand-specific; “more covariates” is not a theorem.],
) <tab:adjustment-roles>

Consider $T -> M -> Y$, where $M$ is a post-treatment mediator. The regression $E[Y mid T,M]$ does not generally recover the total effect of $T$. Conversely, a baseline common cause not included in $X$ leaves the corresponding backdoor path uncontrolled. A collider example $A -> C <- B$, with $A -> T$ and $B -> Y$, shows why a measured pre-treatment variable can still be harmful to condition on. In M-bias structures, blindly adjusting for the collider may introduce association where marginal confounding through that path was absent.

== Selection, measurement, and graph validity

Selection can itself be conditioning. If only records with $S=1$ enter the dataset, the analysis uses the distribution conditional on $S=1$. When treatment and outcome (or their causes) influence selection, collider stratification can generate associations. Complete-case analysis is similarly a modeling assumption, not a neutral preprocessing step. The data audit can count missing cells; it cannot certify that missingness is harmless.

Measurement error adds variables between the latent construct and the recorded field. If baseline confounders are measured with error, conditioning on their proxies need not block the original backdoor path. Outcome errors shared across treatment groups may have different consequences from differential errors. These mechanisms belong in the causal model and sensitivity plan, not in a footnote after model fitting.

Graph identification also requires causal sufficiency or an explicitly represented latent structure, a correct graph, and a suitable intervention semantics. d-separation is a calculus on the supplied graph. If the graph is wrong, an efficient algorithm will answer the wrong formal question correctly.

== Identification review before estimation

Before any outcome-driven modeling, the review should answer:

+ Which causal arrow does treatment represent, and what are its versions?
+ Which open noncausal paths remain after conditioning on the proposed set?
+ Is any proposed covariate a mediator, collider, descendant of treatment, or product of selection?
+ On which support does the estimand require both treatment levels?
+ Which selection, measurement, and interference assumptions are implicit?
+ If a premise fails, is the association still useful descriptively, and what sensitivity quantity would remain meaningful?

This review is also the point to stop. If identification is indefensible, the project may report descriptive contrasts and protocol quality without presenting an “adjusted causal effect.” The remaining estimation chapters assume the identification conjunction only conditionally; their mathematics does not promote it to a verified fact.
