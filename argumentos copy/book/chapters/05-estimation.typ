= Estimation, Cross-Fitting, Heterogeneity, and Policy Learning

== Notation and three estimation routes

For observation $W=(X,T,Y)$, define outcome regressions and propensity as

$ mu_t(x) = E[Y mid T=t,X=x], quad e(x)=P(T=1 mid X=x), t in {0,1}. $

Let $eta=(mu_0,mu_1,e)$ denote the nuisance functions. Once @eq:identified-ate identifies $psi(1)-psi(0)$, estimation still requires choices about models, support, regularization, sample reuse, and uncertainty. Three canonical routes clarify the tradeoffs:

+ *Outcome standardization:* estimate $mu_0,mu_1$ and average $hat(mu)_1(X_i)-hat(mu)_0(X_i)$ over the target sample.
+ *Inverse-probability weighting (IPW):* estimate $e$ and weight observed outcomes by estimated treatment probabilities.
+ *Augmented IPW (AIPW):* combine outcome prediction with inverse-propensity residual corrections.

All three still need correct identification. Flexible regression or “AI” changes nuisance estimation, not the definition of the causal estimand.

== IPW identification and its variance problem

Under consistency, exchangeability, and positivity,

$ E[T Y/e(X)] &= E( E[T Y(1)/e(X) mid X,T] ) \
  &= E( (e(X)/e(X)) E[Y(1) mid X] ) = E[Y(1)], $ <eq:ipw-derivation>

and similarly $E[(1-T)Y/(1-e(X))]=E[Y(0)]$. The moment conditions motivate IPW estimation, but @eq:propensity near zero or one makes the corresponding terms unstable. A correct propensity model can therefore coexist with a practically unusable estimator.

Empirical inverse weights also require the correct target normalization and careful handling of finite-sample correction terms. Their high variance is not repaired by a statistically significant fitted propensity coefficient.

== The AIPW score and a double-robustness derivation <aipw>

For treatment level $t$, write $a_t(T)$ for the indicator that $T=t$, and $p_t(x)=P(T=t mid X=x)$. Define

$ phi_t(W;eta) = mu_t(X) + (a_t(T)(Y-mu_t(X))) / p_t(X). $ <eq:aipw-one-arm>

The implemented binary score contrast is

$ phi_1-phi_0 = mu_1(X)-mu_0(X) + (T(Y-mu_1(X)))/e(X) - ((1-T)(Y-mu_0(X)))/(1-e(X)). $ <eq:aipw-score>

Under true nuisances and the identification assumptions, $E[phi_1-phi_0]=tau_"ATE"$. The connection to semiparametric efficiency and influence functions comes from the missing-data and efficient-estimation literature @robins1994 @hahn1998.

Double robustness can be shown directly rather than invoked as a slogan. For one arm, let $mu_t^*,p_t^*$ be candidate nuisance functions. If $p_t^*$ is the true treatment probability but $mu_t^*$ is arbitrary, conditioning on $X$ gives

$ E[(a_t(T)(Y-mu_t^*(X)))/p_t^*(X) mid X] = (p_t(X)/p_t^*(X))(mu_t(X)-mu_t^*(X)) = mu_t(X)-mu_t^*(X), $ <eq:dr-propensity>

so $E[phi_t(W;mu_t^*,p_t^*)]=E[mu_t(X)]=E[Y(t)]$ under identification. If instead $mu_t^*=mu_t$ is correct, the residual factor has conditional mean

$ E[a_t(T)(Y-mu_t(X)) mid X] = p_t(X)(mu_t(X)-mu_t(X))=0, $ <eq:dr-outcome>

so the augmentation vanishes even when $p_t^*$ is misspecified, provided denominators are finite. Thus consistency for the one-arm functional holds if *either* nuisance is correct under the remaining assumptions. Double robustness is not immunity when both are wrong, positivity fails, or the causal premises fail.

The AIPW score can also be viewed as a plug-in outcome contrast plus a first-order correction for outcome-model error. This correction explains both its centering and its sensitivity to extreme propensity estimates.

== Cross-fitted sample protocol

Naively fitting $hat(eta)$ and evaluating its score on the same observations can introduce own-observation bias, especially with adaptive machine learners. Cross-fitting separates these roles while retaining all training observations for estimation:

+ deterministically partition the training entities into $K$ folds $I_1,dots,I_K$;
+ for fold $k$, fit preprocessing and all nuisances on $I_(-k)$;
+ evaluate $phi_1-phi_0$ for $i in I_k$ using only $hat(eta)^((-k))$;
+ average all out-of-fold scores; and
+ refit preprocessing and nuisances on all training rows for a later external evaluation on data not used in those fits.

The cross-fitted estimate is

$ hat(tau)_"CF" = 1/n sum_(k=1)^K sum_(i in I_k) [phi_1(W_i;hat(eta)^((-k)))-phi_0(W_i;hat(eta)^((-k)))]. $ <eq:cross-fitted-aipw>

This is the train estimator implemented in Rust. Fold assignment depends only on stable entity IDs, not on the protocol salt or outcomes; split role assignment separately uses the protocol salt. The final holdout estimator uses nuisances trained on train only; its role is not another model-selection sweep.

== Neyman orthogonality and double/debiased ML

Let $psi(W;theta,eta)$ be a score with $E[psi(W;theta_0,eta_0)]=0$. Neyman orthogonality requires its Gateaux derivative in nuisance directions to vanish at the truth:

$ D_r E[psi(W;theta_0,eta_0+r Delta)]_(r=0)=0. $ <eq:orthogonality>

The AIPW score has this local orthogonality property under regularity conditions. Intuitively, first-order nuisance-estimation errors do not translate into first-order changes in the target score. With sample splitting or cross-fitting and suitable product-of-error rate conditions, double/debiased machine learning supports root-$n$ inference in settings where naive plug-in ML would be biased @chernozhukov2018.

Orthogonality does not mean that arbitrary poor nuisance estimates are harmless in a sample of 614 rows. Product-of-error behavior is asymptotic, clipping changes the score, and weak overlap can dominate finite samples. The implemented elementary learners make the mechanics auditable; they do not claim the full flexible-learning DML research program.

== Exact nuisance formulas used in this project

All declared feature transformations occur before nuisance fitting. The 1974/1975 earnings fields use $log(1+x)$ per the frozen contract, categorical race is encoded deterministically, and continuous design columns are standardized with means and scales from the nuisance-fit rows only.

For standardized design matrix $Z$ including an intercept, logistic propensity fitting minimizes

$ ell(beta) = sum_i [-T_i log p_i-(1-T_i)log(1-p_i)] + lambda/2 sum_(j>0) beta_j^2, quad p_i="sigmoid"(Z_i beta). $ <eq:logistic-objective>

The implementation records Newton/IRLS convergence and separation diagnostics. In each update, weights and working residuals produce a linearized system whose intercept is unpenalized. Ridge is fixed by the contract, not selected against holdout outcomes.

For each $t in {0,1}$, outcome fitting solves

$ hat(beta)_t = "argmin"_beta sum_(i:T_i=t)(Y_i-Z_i beta)^2 + lambda sum_(j>0) beta_j^2 $ <eq:ridge-outcome>

on the nuisance-fit subset. The resulting $hat(mu)_t(x)=Z(x)hat(beta)_t$ can predict negative earnings. That is a visible limitation of a ridge-linear model for nonnegative, skewed 1978 earnings—not a hidden transformation into a more favorable model.

== Influence-function intervals

For score values $D_i=phi_1(W_i)-phi_0(W_i)$ with average $hat(tau)$, the report uses

$ hat("se") = sqrt((1/(n(n-1))) sum_(i=1)^n (D_i-hat(tau))^2), quad hat(tau) plus.minus z_(0.975) hat("se"). $ <eq:if-interval>

This is a normal-reference influence-function approximation. It treats units as independent under the sampling model, and the cross-fitting/estimation details must satisfy their own asymptotic conditions. It does not include uncertainty about unmeasured confounding, measurement validity, target-population shift, researcher model selection, or interference. No cluster-robust or bootstrap interval is implemented.

== CATE and meta-learners: methods map, not executed results <sec:heterogeneity>

The CATE $tau(x)$ asks how effects vary with baseline features. It is a more ambitious and usually less stable target than ATE. The commonly named meta-learners organize nuisance fitting differently @kunzel2019:

#figure(
  table(
    columns: (0.65fr, 2.4fr, 1.45fr),
    table.header([Learner], [Construction], [Principal caution]),
    [S], [Fit one outcome model with treatment as a feature; contrast predictions at $T=1$ and $T=0$], [Regularization can shrink treatment-effect heterogeneity toward zero],
    [T], [Fit separate models $hat(mu)_1(x)$ and $hat(mu)_0(x)$; subtract], [Different regularization and unequal arm sizes can induce noisy contrasts],
    [X], [Impute arm-specific effects using opposite-arm predictions, combine with propensity weighting], [Multiple learned components and smoothing choices complicate validation],
    [DR/R], [Construct orthogonal or residualized pseudo-outcomes, then regress them on $X$], [Pseudo-outcomes can have extreme variance under weak overlap],
  ),
  caption: [CATE strategies described for theory-practice mapping; none is fitted in the executable case.],
) <tab:metalearners>

A cross-fitted DR learner might use $D_i$ from @eq:aipw-score as a pseudo-outcome and fit $E[D_i mid X_i=x]$. That requires separate validation of conditional-effect calibration and support, not just aggregate AIPW accuracy. Individual predictions $hat(tau)(x)$ are not guaranteed approximate realizations of an individual's counterfactual pair; the estimand remains a conditional mean.

== Policy learning and decision thresholds

A deterministic policy $pi:X -> {0,1}$ assigns treatment from baseline information. Its value is $V(pi)=E[Y(pi(X))]$. Under identification, an IPW representation is

$ V(pi) = E[(1{T=pi(X)}Y) / P(T=pi(X) mid X)]. $ <eq:policy-value>

AIPW supplies an augmented value score for policy learning. A restricted policy class $Pi$ can be selected by maximizing its estimated value, subject to budget, fairness, safety, and implementability constraints. Empirical welfare maximization and doubly robust policy learning develop this program and its regret properties @kitagawa2018 @athey2021.

A reliable protocol distinguishes *policy selection* from *policy evaluation*: thresholds and calibration are learned from train/calibration, while final evaluation is untouched by selection. Treatment costs and capacity constraints must be part of the decision rule rather than retrofitted to a treatment coefficient. This project implements no policy class, policy learner, treatment threshold, fairness criterion, or policy-value evaluation. The calibration set's X/T-only computational gate is not a policy-learning procedure.
