# Choosing an inference model for experiment results

## Recommendation

For ExAbby's stated feature—showing p-values on an admin page people can inspect before an experiment is formally complete—use **anytime-valid sequential inference versus control as the target design**. Keep the current treatment-versus-control structure and multiplicity protection, but replace the fixed-horizon z-test with a sequential method whose p-values or confidence sequences remain valid across repeated looks.

A Bayesian Beta-Binomial view is viable if ExAbby deliberately changes the product question to “how large might the lift be, how likely is it to be practically useful, and what is the cost of choosing this arm?” It requires an exposed, defensible prior and a calibrated stopping rule or explicit decision-loss threshold. It should not relabel a posterior probability as “significance,” nor claim to preserve a 5% frequentist false-positive rate. A naïve `P(treatment > control) > 95%` rule is not the safest replacement for a continuously viewed p-value.

## Implemented design

ExAbby now uses a two-sided beta-binomial mixture confidence sequence from Howard et al. for each arm's Bernoulli conversion mean. Combining the treatment and control sequences with an equal error split yields an anytime-valid confidence sequence for absolute lift. Inverting that sequence produces the raw treatment-versus-control p-value, and Holm's procedure adjusts the family across treatment arms. This remains dependency-free and computable from the summary counts ExAbby already exposes while adapting to the Bernoulli mean more tightly than the generic Hoeffding normal-mixture boundary.

The guarantee covers continuous monitoring and data-dependent stopping for a fixed start date, metric, and eligibility rule. Selecting date ranges, metrics, or exclusions after inspecting results is a separate selection problem and is not made valid merely by using a confidence sequence.

## The three options

### 1. Prior pooled two-proportion z-test plus Holm

The replaced design was a reasonable, small implementation of a conventional fixed-horizon analysis:

- Each treatment is compared with the configured control, which matches the product question.
- A two-sided pooled two-proportion test asks whether the treatment and control conversion probabilities differ. R's official `prop.test` similarly tests whether proportions in several groups are equal, with a two-sided alternative by default ([R documentation](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/prop.test.html)).
- Holm adjustment is an appropriate family-wise error correction across the treatment arms for a metric. R's official documentation describes Holm as strongly controlling family-wise error under arbitrary assumptions and as dominating unmodified Bonferroni ([R documentation](https://stat.ethz.ch/R-manual/R-devel/library/stats/html/p.adjust.html)); this comes from Holm's original sequentially rejective procedure ([Holm, 1979](https://www.ime.usp.br/~abe/lista/pdf4R8xPVzCnX.pdf)).
- Suppressing the approximation when an expected cell is below five follows the standard warning for chi-square/z approximations ([SciPy statistical documentation](https://docs.scipy.org/doc/scipy/reference/generated/scipy.stats.contingency.chi2_contingency.html)).

Its main limitation is not the control comparison or Holm correction. It is **when the result is read and acted upon**. Fixed-horizon p-values assume that the sample size or analysis time was chosen independently of the accumulating result. Johari et al. show that ordinary p-values and confidence intervals become unreliable when people continuously monitor a test and choose when to stop; their always-valid methods are designed for exactly that workflow ([Johari et al., 2021](https://pubsonline.informs.org/doi/10.1287/opre.2021.2135)). A continuously updating admin screen makes that misuse likely even if the calculation itself is correct.

The current sparse-cell guard is honest but produces no inferential result on many low-traffic experiments. It also does not solve low power: a non-significant p-value is not evidence that the treatment and control are equivalent. Finally, “Holm per metric” controls the family across arms for that metric, not across every metric, time window, segment, or exploratory analysis a user might inspect.

**Use this option when:** the experiment has one declared primary metric, a planned end/sample size, and the decision is made once at that endpoint.

### 2. Independent Beta-Binomial posteriors versus control

For a binary conversion metric, a lightweight model is:

```text
theta_arm ~ Beta(alpha, beta)
conversions_arm ~ Binomial(trials_arm, theta_arm)

theta_arm | data ~ Beta(
  alpha + conversions_arm,
  beta + trials_arm - conversions_arm
)
```

The Beta prior is conjugate to the Binomial likelihood, so the posterior update is closed-form and cheap; the Stan User's Guide gives the same posterior update ([Stan documentation](https://mc-stan.org/docs/2_23/stan-users-guide/exploiting-conjugacy.html)). Unlike the normal approximation, a proper Beta prior yields a posterior even with zero or very few conversions. That does **not** create information: sparse-data intervals should remain wide, and results can be strongly prior-sensitive. Stan's example shows that even a seemingly weak `Beta(0.5, 0.5)` prior can produce boundary-heavy posteriors with little data ([Stan documentation](https://mc-stan.org/docs/2_27/stan-users-guide/posteriors-with-unbounded-densities.html)).

Bayesian output maps more directly to a product decision. Published A/B work reports probability to beat the baseline, probability to be best, credible intervals, expected improvement, and expected loss ([Kamalbasha and Eugster, 2020](https://arxiv.org/abs/2003.02769)). Expected loss is especially useful because it distinguishes a tiny, harmless miss from a large, costly one; the multi-arm version compares each candidate with the best alternative, not only with control ([Stucchio, 2015](https://www.chrisstucchio.com/pubs/VWO_SmartStats_technical_whitepaper.pdf)).

Continuous monitoring needs a precise claim. Deng et al. prove that Bayes factors/posterior odds retain their Bayesian interpretation under proper stopping rules when all observations are used, but also document bad practices and increased frequentist Type-I error under monitoring ([Deng et al., 2016](https://arxiv.org/abs/1602.05549)). Deng's earlier objective-Bayes paper is more pointed: optional-stopping and multiplicity advantages depend on a genuine or well-learned prior; a generic uniform prior can be too aggressive ([Deng, 2015](https://gwern.net/doc/statistics/decision/2015-deng.pdf)). Therefore a simple `P(treatment > control) > 95%` rule must not be presented as equivalent to `p < .05`.

For multiple arms, independent posteriors make `P(arm > control)` and `P(arm is best)` computable, but they do not make winner selection consequence-free. If ExAbby later supports many arms routinely, a hierarchical Bayesian model can partially pool arm effects; Gelman, Hill, and Yajima show how multilevel models address multiplicity through partial pooling rather than wider intervals or adjusted p-values ([Gelman et al., 2012](https://arxiv.org/abs/0907.2478)). That is a later extension, not necessary for the first useful Bayesian version.

**Use this option when:** the primary goal is an understandable decision view, continuous inspection is normal, and ExAbby can expose the prior and a predeclared decision rule rather than promise fixed-alpha significance.

### 3. Always-valid sequential frequentist inference

Always-valid p-values or confidence sequences preserve frequentist validity across repeated looks. Johari et al. develop always-valid p-values and confidence intervals for continuously monitored A/B tests, including multiple-hypothesis control in the sequential setting ([Johari et al., 2021](https://pubsonline.informs.org/doi/10.1287/opre.2021.2135)). Howard et al. define confidence sequences whose coverage is uniform over an unbounded time horizon ([Howard et al., 2021](https://arxiv.org/abs/1810.08240)).

This is the best match if “p-value” and controlled Type-I error are non-negotiable product promises. It is also materially more complex to implement, explain, and validate than a conjugate Beta-Binomial view, especially when adding multiple arms, practical-effect thresholds, and power behavior.

**Use this option when:** users must stop at arbitrary times while retaining a frequentist error guarantee.

## Recommended product contract

For the p-value feature, the default results table should show, for every treatment relative to control:

1. Observed conversion rate and observed absolute lift.
2. An anytime-valid p-value versus control.
3. A confidence sequence for absolute lift, so effect magnitude is visible alongside significance.
4. Multiplicity-adjusted status across all treatment arms for the declared primary metric, using a sequentially valid multiple-testing procedure rather than assuming the fixed-horizon composition remains valid.
5. A neutral state such as “collect more data” until a configured minimum exposure/duration floor and decision threshold are both met.

If ExAbby also offers a Bayesian decision panel, it should show posterior lift with a credible interval, `P(lift > minimum practical lift)`, expected loss/regret, and—when there are three or more arms—probability each arm is best. Its prior must be visible and configurable. A generic proper prior can be offered as a transparent library default, but it should be called “weak default,” not “uninformative.” If adopters have comparable historical experiments, ExAbby can later support a baseline-and-strength prior or empirical-Bayes calibration. A simple sensitivity check using more than one plausible prior is valuable when data are sparse.

The implementation replaces the adjusted z-test instead of retaining a second statistical mode. If a fixed-horizon analysis is added later, keep it in an explicit advanced section with its planned-end warning; do not show a green/red winner badge from it while the test is still accumulating data.

## Bottom line

The current control-relative test is statistically sound for a planned, single endpoint. It is not the best default for a continuously viewed p-value dashboard. The strongest match to the requested feature is control-relative, anytime-valid sequential inference with sequential multiplicity control and confidence sequences. Bayesian inference is a good separate decision-oriented mode when ExAbby is explicit about priors, uncertainty, practical lift, and loss-based stopping, but it does not automatically solve optional stopping, inadequate data, or multi-arm selection.
