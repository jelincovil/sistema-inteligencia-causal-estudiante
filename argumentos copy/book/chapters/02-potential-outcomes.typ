= Potential Outcomes, Structural Models, and Randomization

== Units, interventions, and potential outcomes

Fix a population of units $i=1,dots,n$ and a binary treatment $T_i in {0,1}$. Let $Y_i(t)$ denote the outcome unit $i$ would realize under a precisely specified intervention that sets treatment to $t$. The pair $(Y_i(1),Y_i(0))$ is more informative than the observed pair $(T_i,Y_i)$; for each unit only the potential outcome compatible with received treatment is observed. Neyman's 1923 formulation, available in English translation with commentary, introduced this experimental missing-data perspective @neyman1990, and Rubin extended it to randomized and nonrandomized studies @rubin1974.

The *fundamental problem of causal inference* is therefore not merely that treatment groups differ. It is that the joint distribution of potential outcomes is not observed directly. All identification arguments explain how design and assumptions recover a chosen functional of that distribution.

A *well-defined intervention* matters. If “receive NSW training” conceals different eligibility rules, program versions, durations, or co-interventions, the symbol $Y(1)$ may bundle substantively different counterfactual worlds. Estimation precision cannot resolve that ambiguity.

== Consistency and treatment versions <consistency>

*Consistency* connects the counterfactual notation to an observable value:

$ Y_i = T_i Y_i(1) + (1-T_i)Y_i(0), $ <eq:consistency>

or equivalently $Y_i=Y_i(T_i)$ for the treatment actually received. Consistency includes a composition requirement: there are no concealed versions of treatment with materially different outcomes within the analysis definition, and measurement corresponds to that same intervention. It is not a claim that treated and control units are exchangeable @imbensrubin2015.

Treatment-version ambiguity is especially dangerous in administrative data. A binary flag for enrollment may represent different services. If versions $v$ matter, one remedy is to index potential outcomes as $Y(t,v)$ and define the strategy or version distribution explicitly. Collapsing them into $Y(t)$ tacitly imposes a restriction; it is not just an encoding convenience.

== Noninterference and exposure mapping <interference>

The ordinary two-potential-outcomes notation also assumes *noninterference*: unit $i$'s outcome does not depend on other units' treatment assignments. More generally, with assignment vector $bold(T)$, the full object is $Y_i(bold(T))$. Noninterference reduces this to $Y_i(T_i)$. Together with consistency and well-defined treatment versions, this is commonly called the stable-unit-treatment-value assumption (SUTVA) @rubin1978.

Noninterference can fail through displacement, spillovers, contagion, shared instructors, market equilibrium, or household effects. Replacing the assumption with “the data are independent rows” is a category mistake: row independence is statistical; interference is structural.

For a known network, one may instead posit an exposure mapping such as

$ Y_i(bold(T)) = Y_i(T_i, G_i(bold(T))), quad G_i(bold(T)) = sum_(j in N_i) T_j, $

and define separate direct and spillover estimands. The exposure mapping is itself a major assumption. The executable LaLonde protocol retains noninterference as an explicit untested premise; it does not estimate network exposures.

== Estimands: total, treated, conditional, and policy contrasts

The binary-treatment average treatment effect (ATE) is

$ tau_"ATE" = E[Y(1)-Y(0)] = E[Y(1)]-E[Y(0)]. $ <eq:ate>

The average treatment effect on the treated (ATT) changes the target distribution:

$ tau_"ATT" = E[Y(1)-Y(0) mid T=1]. $ <eq:att>

The ATE and ATT need not coincide. The conditional average treatment effect (CATE) is

$ tau(x) = E[Y(1)-Y(0) mid X=x], $ <eq:cate>

and requires its own identification and support conditions for each target covariate region. Averaging $tau(X)$ over the full population gives @eq:ate only when $X$ contains the relevant conditioning variables and the integration measure is the same population.

Other scientifically meaningful contrasts include the effect on the untreated, quantile contrasts, survival probabilities at a fixed horizon, and the value of a treatment policy. Mean additivity does not extend to every functional: generally $E[F_(Y(1))^(-1)(q)-F_(Y(0))^(-1)(q)]$ is not the quantile of $Y(1)-Y(0)$. Estimand definitions must respect this distinction.

== Structural causal models and interventions

A structural causal model (SCM) supplies mechanisms rather than only conditional independence statements. For three observed nodes, one simple system is

$ X := f_X(U_X), quad T := f_T(X,U_T), quad Y := f_Y(T,X,U_Y). $ <eq:scm>

$U_X,U_T,U_Y$ are exogenous variables with a specified joint distribution, and each equation defines how the left-hand variable responds when its inputs are set. The graph $X -> T$, $X -> Y$, $T -> Y$ displays the parent relationships in @eq:scm. Independent observed arrows do not by themselves prove that $U_T$ and $U_Y$ are independent @pearl2009[Chapter 1].

An intervention $"do"(T=t)$ replaces the treatment equation with $T:=t$ while leaving other mechanisms intact. It is not generally the same operation as conditioning on the event $T=t$. In the system above, the post-intervention joint law is

$ p(x,y mid "do"(T=t)) = p(x) p(y mid t,x), $ <eq:truncated>

where the treatment-assignment factor is removed. This truncated-factorization expression assumes the modeled graph, mechanisms, and exogenous dependence structure. The potential outcome $Y(t)$ is the solution for $Y$ after this replacement.

For a DAG whose observed distribution factorizes as $p(v)=product_j p(v_j mid "pa"_j)$, the same intervention logic gives

$ p(v_(-T) mid "do"(T=t)) = product_(j: V_j != T) p(v_j mid "pa"_j) quad "with" T "fixed to" t, $ <eq:truncated-general>

subject to the usual Markov and consistency conditions. This is the do-calculus starting point, not a license to interpret every conditional association causally.

== D-separation: when paths transmit dependence

In a DAG, a *path* may follow arrows in either direction. Relative to a conditioning set $Z$, the path is blocked when:

+ it contains a chain $A -> B -> C$ or fork $A <- B -> C$ with $B in Z$; or
+ it contains a collider $A -> B <- C$ such that neither $B$ nor any descendant of $B$ is in $Z$.

If every path between two nodes is blocked by $Z$, they are *d-separated*. Under the global Markov condition, d-separation implies conditional independence; faithfulness adds the converse implication from every conditional independence to d-separation. Faithfulness can fail through exact parameter cancellation, so empirical independence is not universal proof of a missing arrow @pearl1995.

The collider rule explains why “adjust for more pre-treatment variables” is unsafe. Conditioning on an ordinary fork blocks that path; conditioning on a collider can open it. Conditioning on a descendant of a collider can also open the path partially.

== Randomization identifies by design—not by regression

Suppose the complete potential outcomes are fixed attributes for the target experiment and treatment is assigned independently of them:

$ T perp (Y(1),Y(0)), quad 0 < P(T=1) < 1. $ <eq:randomized>

Random assignment provides the design basis for @eq:randomized, subject to the actual allocation mechanism and concealment. With consistency and noninterference,

$ E[Y mid T=1] &= E[Y(1) mid T=1] = E[Y(1)], \
 E[Y mid T=0] &= E[Y(0) mid T=0] = E[Y(0)]. $

Consequently $Delta_"assoc"=tau_"ATE"$ in @eq:assoc under those design conditions. The argument does not depend on covariate balance happening to be perfect in a realized sample, nor on fitting a linear model. Covariate adjustment can improve precision or address chance imbalance, but the randomization mechanism supplies the core warrant @rubin1978.

Observational treatment assignment lacks that design guarantee. The analyst instead defends conditional exchangeability given measured covariates and a valid observation process. That is the central problem of the next chapter.

== The running case at the design boundary

The pinned LaLonde/MatchIt artifact combines treated NSW observations with PSID comparisons, following the nonexperimental analysis tradition of LaLonde and Dehejia–Wahba @lalonde1986 @dehejia1999. It is not the NSW randomized experimental benchmark. Calling `treat` a treatment column does not reproduce the assignment mechanism. The case therefore asks a deliberately narrower question: what does a frozen adjusted estimator compute, and which additional premises would be necessary before its output could be interpreted causally?
