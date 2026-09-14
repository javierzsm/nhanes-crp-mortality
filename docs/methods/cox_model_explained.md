# Understanding the Cox model used in this study

**Document status:** Version 0.2, 14 September 2026. Educational methods guide. This document explains the model but does not replace the protocol or statistical analysis plan. All unresolved specifications must be frozen in those documents before mortality outcome analysis.

## Purpose

This guide explains the statistical model proposed for the NHANES CRP and mortality study. It progresses from the structure of one participant's record to survey-weighted Cox regression with a restricted cubic spline. The objective is to preserve the full statistical complexity while making every component traceable to an epidemiological question.

The analysis has three defining features. The outcome is time to death rather than mortality status alone; C-reactive protein is continuous and may have a nonlinear association with mortality; NHANES is a complex probability sample. A valid model must address these features together.

## 1. What one participant contributes

For participant $i$, the analysis requires:

$$
(T_i,\delta_i,X_i,\mathbf Z_i,w_i,s_i,c_i)
$$

where:

- $T_i$ is time from the NHANES examination to death or censoring;
- $\delta_i$ is 1 for an observed death and 0 for censoring;
- $X_i$ is baseline CRP;
- $\mathbf Z_i$ contains adjustment variables;
- $w_i$ is the survey weight;
- $s_i$ identifies the sampling stratum;
- $c_i$ identifies the primary sampling unit.

The public mortality file supplies `PERMTH_EXM`, the number of months from the mobile examination center examination to death or the end of follow-up, and `MORTSTAT`, the mortality indicator. Together they define:

```r
Surv(time = PERMTH_EXM, event = MORTSTAT)
```

## 2. Why mortality status is insufficient

Consider four participants:

| Person | Follow-up | Result |
|---|---:|---|
| A | 3 years | Death |
| B | 15 years | Alive at study end |
| C | 11 years | Death |
| D | 6 years | Alive at study end |

A binary model records two deaths and two non-deaths. It ignores when the deaths occurred and treats 6 years of observed survival as equivalent to 15 years. Survival analysis uses both the event indicator and the observed time.

## 3. Censoring

A participant is right-censored when death has not been observed by the last available follow-up time. Censoring does not mean that the participant will never die. It means only that the event was not observed during the analytic window.

For someone censored after 120 months, we know:

$$
T_i>120
$$

The participant contributes information to every risk set during those 120 months. The Cox model assumes conditionally non-informative censoring: after accounting for modeled variables, censoring should not contain additional information about the unobserved event time.

## 4. Survival, hazard and cumulative hazard

Let $T$ be time to death. The survival function is:

$$
S(t)=P(T>t)
$$

It is the probability of remaining alive beyond time $t$.

The hazard is:

```math
h(t)
=
\lim_{\Delta t \to 0}
\frac{
  \Pr\left(t \leq T < t+\Delta t \mid T \geq t\right)
}{
  \Delta t
}
```

The conditioning is essential. The hazard is the instantaneous death rate among people alive immediately before $t$. It is a rate, not a probability.

The cumulative hazard is:

$$
H(t)=\int_0^t h(u)\,du
$$

and:

$$
S(t)=\exp\left(-H(t)\right)
$$

A hazard ratio is therefore not interchangeable with a risk ratio, risk difference or ratio of survival probabilities.

## 5. Risk sets

At each observed death time $t_k$, the risk set $R(t_k)$ contains participants who remain under observation and alive immediately before that time.

| Person | Time | Event | CRP (mg/L) |
|---|---:|---:|---:|
| A | 4 | 1 | 8 |
| B | 7 | 0 | 2 |
| C | 9 | 1 | 1 |
| D | 3 | 0 | 5 |

At time 4, A, B and C are in the risk set. D is absent because D was censored at time 3. The model compares A, the observed death, with the people who could have died at that time. This comparison is repeated at every death, with a changing risk set.

## 6. Cox proportional hazards regression

The model specifies:

$$
h_i(t)=h_0(t)\exp(\eta_i)
$$

where $h_0(t)$ is an unspecified baseline hazard and $\eta_i$ is the participant's linear predictor. In an adjusted model:

$$
\eta_i=\beta X_i+\gamma_1Z_{i1}+\cdots+\gamma_pZ_{ip}
$$

The model is semiparametric. Covariate coefficients are estimated parametrically, while the baseline hazard is not assigned a particular distribution.

## 7. Partial likelihood

If participant $i$ dies at $t_i$, without tied event times, the participant contributes:

$$
\frac{\exp(\eta_i)}
{\sum_{j\in R(t_i)}\exp(\eta_j)}
$$

The numerator is the relative hazard score of the person who died. The denominator sums the scores of everyone who could have died then. Multiplying across deaths gives the partial likelihood:

$$
L(\boldsymbol\beta)=
\prod_{i:\delta_i=1}
\frac{\exp(\eta_i)}
{\sum_{j\in R(t_i)}\exp(\eta_j)}
$$

The baseline hazard cancels within each risk-set comparison, allowing the regression coefficients to be estimated without specifying $h_0(t)$.

### Numerical example

Assume $\beta=0.20$ and one risk set:

| Person | $X$ | $\exp(0.20X)$ |
|---|---:|---:|
| A, observed death | 3 | 1.822 |
| B | 1 | 1.221 |
| C | 0 | 1.000 |

The contribution is:

$$
\frac{1.822}{1.822+1.221+1.000}=0.451
$$

Candidate coefficients generate different contributions over all event times. The fitted coefficients maximize their product, or equivalently the sum of their logarithms.

## 8. Numerical optimization

There is no closed-form solution for all coefficients. Software iteratively:

1. selects starting values;
2. calculates the log partial likelihood;
3. calculates its gradient and curvature;
4. updates the coefficients;
5. repeats until changes fall below convergence tolerances.

Convergence means that a numerical solution was found. It does not demonstrate correct model specification, absence of bias or scientific validity.

## 9. From log-hazard contrast to hazard ratio

Taking logarithms gives:

$$
\log h_i(t)=\log h_0(t)+\eta_i
$$

For two covariate patterns $a$ and $b$:

$$
HR(a,b)=\frac{h(t\mid a)}{h(t\mid b)}
=\exp\left(\eta(a)-\eta(b)\right)
$$

The difference $\eta(a)-\eta(b)$ is a contrast on the log-hazard scale. Exponentiating it produces the hazard ratio. If the contrast equals 0.182:

$$
HR=\exp(0.182)\approx1.20
$$

This is a 20% higher hazard, not a 20 percentage-point increase in mortality probability.

## 10. Base-2 logarithm of CRP

CRP typically has a long right tail. Modeling each additional mg/L as equivalent can give extreme observations excessive influence and imposes a questionable absolute scale.

We define:

$$
X_i=\log_2(CRP_i)
$$

A one-unit increase is a doubling:

$$
\log_2(2x)-\log_2(x)=1
$$

Under a linear effect:

$$
h_i(t)=h_0(t)\exp\left(\beta\log_2(CRP_i)+\boldsymbol\gamma^T\mathbf Z_i\right)
$$

the hazard ratio per doubling is:

$$
HR_{doubling}=\exp(\beta)
$$

If $\exp(\beta)=1.20$, each doubling is associated with a 20% higher hazard, conditional on the model and its assumptions.

## 11. Why a spline is still needed

The logarithmic transformation changes the exposure scale but still assumes a straight-line relationship between `log2(CRP)` and log hazard. It requires every doubling to have the same hazard ratio. A restricted cubic spline evaluates whether the association instead contains curvature.

## 12. Restricted cubic spline

A spline constructs a smooth function from connected polynomial pieces. Their meeting locations are knots. Knots are mathematical devices, not clinical thresholds or exposure categories.

Using basis functions $B_m(X)$:

$$
f(X)=\beta_1B_1(X)+\cdots+\beta_qB_q(X)
$$

The Cox model becomes:

$$
h_i(t)=h_0(t)\exp\left[f\left\{\log_2(CRP_i)\right\}+\boldsymbol\gamma^T\mathbf Z_i\right]
$$

The cubic pieces have matching value, slope and curvature at every knot. The restriction forces the function to be linear beyond the outer knots, where sparse data would otherwise permit unstable cubic behavior.

The current SAP specification uses four knots at the weighted 5th, 35th, 65th and 95th percentiles of `log2(CRP)`. Their numerical locations will be calculated and frozen before outcome modeling.

## 13. Interpreting a spline

Individual spline coefficients are not epidemiological effects. They multiply artificial basis functions and must be combined. For concentrations $x$ and $x_{ref}$:

$$
HR(x,x_{ref})=
\exp\left[f\{\log_2(x)\}-f\{\log_2(x_{ref})\}\right]
$$

If 2 mg/L is the reference and the estimated HR at 8 mg/L is 1.45, the estimated hazard at 8 mg/L is 45% higher than at 2 mg/L, conditional on adjustment variables. It is not a cumulative mortality-risk difference.

The result should show the curve, its 95% confidence band, the reference concentration and the range supported by sufficient observations.

## 14. Tests derived from the spline

The global association test evaluates whether all CRP spline coefficients are jointly zero. The nonlinearity test evaluates whether the nonlinear components are jointly zero after retaining the linear component.

| Global association | Nonlinearity | Interpretation |
|---|---|---|
| Not supported | Not supported | Insufficient evidence of association |
| Supported | Not supported | Association compatible with a constant HR per doubling |
| Supported | Supported | Association not adequately summarized by one HR |
| Not supported | Supported | Unusual result requiring examination of uncertainty and specification |

Model interpretation must also consider the curve, confidence band, tail information and scientific plausibility.

## 15. Proportional hazards assumption

For fixed covariate patterns $a$ and $b$:

$$
\frac{h(t\mid a)}{h(t\mid b)}
=\exp\left(\eta(a)-\eta(b)\right)
$$

The right-hand side contains no time. The model assumes that the hazard ratio remains constant over follow-up, although absolute hazards may change substantially.

Proportionality will be evaluated using scaled Schoenfeld residuals, formal tests, graphical assessment and survey-weighted exposure-by-log-time interactions. If the CRP interaction p-value is below 0.05 or the residual plot shows a sustained pattern, CRP contrasts will be estimated at 5, 10 and 15 years. A constant HR will remain the primary summary only when those contrasts retain the same direction and do not materially change interpretation.

Meaningful non-proportionality may be handled by time interactions, pre-specified follow-up intervals, stratification on adjustment variables or standardized survival summaries.

## 16. Tied death times

Follow-up is recorded in months, so several deaths may share the same observed time. The planned model will use Efron's approximation to handle these tied event times. This choice will be frozen in the statistical analysis plan.

## 17. Why NHANES requires survey-weighted Cox regression

NHANES uses unequal selection probabilities, stratification and clustered sampling. A conventional Cox model assumes a simple random sample and can misrepresent population estimates and their uncertainty.

The survey design will be specified as:

```r
design <- survey::svydesign(
  ids = ~SDMVPSU,
  strata = ~SDMVSTRA,
  weights = ~combined_mec_weight,
  nest = TRUE,
  data = analytic_data
)
```

The model will use:

```r
fit <- survey::svycoxph(
  Surv(PERMTH_EXM, MORTSTAT) ~ exposure + covariates,
  design = design,
  ties = "efron"
)
```

Coefficients are estimated using survey-weighted pseudo-partial likelihood. Design-based robust standard errors incorporate strata and primary sampling units. The term *pseudo* indicates that survey weights modify the estimation equations; it does not imply an approximate or inferior analysis.

## 18. Pooling cycles

The cycle audit confirmed six comparable cycles spanning 12 years. NHANES supplies special four-year MEC weights for 1999–2002, so a single `WTMEC2YR/6` rule is not correct for every cycle. The combined examination weight is:

$$
w_{12-year}=
\begin{cases}
WTMEC4YR\times\frac{4}{12}, & 1999\text{--}2002\\
WTMEC2YR\times\frac{2}{12}, & 2003\text{--}2010
\end{cases}
$$

Cycle will be included to account for baseline-period differences. These weights target the civilian, noninstitutionalized US adult population represented across the pooled survey period.

The pre-outcome audit found 34 linkage-ineligible participants among 28,924 adults with CRP and a positive MEC weight. They will be excluded and counted in the participant flow. No additional eligibility weight will be estimated.

## 19. Statistical inference

For a linear CRP term:

```math
H_0:\beta=0
```

and:

```math
CI_{95\%}
=
\exp\left[
\hat{\beta}\pm 1.96\,SE_{\mathrm{design}}(\hat{\beta})
\right]
```

Multi-parameter spline terms will be evaluated with design-based joint Wald tests. Ordinary likelihood-ratio tests are not automatically appropriate for a survey-weighted pseudolikelihood fit.

Inference will emphasize estimates and confidence intervals. A p-value is not the probability that the null hypothesis is true, and statistical significance is not evidence of causation.

## 20. Confounding and causal restraint

Adjustment variables will be selected before outcome analysis using substantive knowledge and a causal diagram. They will not be chosen through univariable screening, stepwise regression or attempts to optimize statistical significance.

Adjustment can reduce confounding but does not guarantee causal identification. Controlling for a mediator can remove part of the association, while controlling for a collider can introduce bias. The primary adjustment set must therefore be justified and pre-specified.

The planned estimand is an adjusted prognostic association. Results should use language such as “was associated with,” unless a stronger causal estimand and its assumptions are explicitly justified.

## 21. Diagnostics and sensitivity analyses

The analysis will examine:

1. participant flow and exclusions;
2. numbers of deaths and censored observations;
3. follow-up distribution;
4. CRP distribution and detection-limit handling;
5. convergence;
6. proportional hazards;
7. functional form of CRP and age;
8. influential observations;
9. missing-data patterns;
10. mortality-linkage eligibility;
11. early deaths;
12. concentrations compatible with acute inflammation.

Sensitivity analyses will exclude deaths within 12 or 24 months and repeat the analysis after excluding CRP greater than 10 mg/L. The final exclusion is not a cleaning rule; high CRP can contain genuine prognostic information. NHANES below-detection fill values will be retained in the primary analysis, then replaced by the nominal detection limit and excluded in separate sensitivity analyses.

Sex and age group, 20–64 versus 65 years or older, are pre-specified secondary effect modifiers. Their interaction estimates will be interpreted as secondary evidence rather than replacements for the overall association.

## 22. Correct and incorrect interpretations

Suppose the adjusted HR is 1.18 per doubling, with a 95% confidence interval of 1.10 to 1.27.

Appropriate:

> Each doubling of baseline CRP was associated with an 18% higher hazard of all-cause mortality during follow-up, after adjustment for the pre-specified covariates.

Inappropriate:

- “CRP increased mortality by 18%,” because it asserts causation;
- “the probability of death increased by 18%,” because hazard is not cumulative risk;
- “18% more participants died,” because this is not a risk difference;
- “CRP predicted death with 82% accuracy,” because no accuracy measure was estimated.

## 23. Concept-to-code map

| Scientific element | R representation |
|---|---|
| Follow-up and death | `Surv(PERMTH_EXM, MORTSTAT)` |
| Base-2 exposure | `log2(crp_mg_l)` |
| Natural/restricted spline basis | `splines::ns(log2_crp, ...)` |
| Sampling strata | `SDMVSTRA` |
| Primary sampling unit | `SDMVPSU` |
| Examination weight | `WTMEC2YR`, transformed for pooled cycles |
| Survey design | `survey::svydesign()` |
| Survey-weighted Cox model | `survey::svycoxph()` |
| Conventional PH diagnostic | `survival::cox.zph()` |
| Hazard-ratio contrast | `exp(eta_a - eta_b)` |

Software syntax does not define the estimand. Every model term must trace back to the protocol, and every reported contrast must identify the two compared exposure values.

## 24. Exercises

1. A participant is alive when follow-up ends after 132 months. What are the observed time and event indicator?
2. If $\hat\beta=0.15$ for `log2(CRP)`, calculate the HR for 4 versus 2 mg/L and 8 versus 2 mg/L.
3. Why is someone censored before a death time absent from that death's risk set?
4. Why are individual spline coefficients not separately interpretable?
5. Distinguish the global spline association test from the nonlinearity test.

## 25. Solutions

1. Time is 132 months and the event indicator is 0.
2. For 4 versus 2 mg/L, $HR=\exp(0.15)=1.162$. For 8 versus 2 mg/L, $HR=\exp(0.30)=1.350$.
3. After censoring, continued survival is unknown, so the person cannot be confirmed as available to experience the later event.
4. The coefficients multiply artificial basis functions; interpretation requires their joint value and a contrast between exposure values.
5. The global test asks whether all CRP terms are jointly zero; the nonlinearity test asks whether nonlinear terms are zero after retaining the linear component.

## Recommended reading

- Nahhas RW. *Introduction to Regression Methods for Public Health Using R*. Chapters 7 and 8, Survival Analysis and Analyzing Complex Survey Data. https://www.bookdown.org/rwnahhas/RMPH/
- Harrell FE Jr. *Regression Modeling Strategies*. 2nd ed. Springer; 2015. https://doi.org/10.1007/978-3-319-19425-7
- Kleinbaum DG, Klein M. *Survival Analysis: A Self-Learning Text*. 3rd ed. Springer; 2012. https://doi.org/10.1007/978-1-4419-6646-9
- Therneau TM, Grambsch PM. *Modeling Survival Data: Extending the Cox Model*. Springer; 2000. https://doi.org/10.1007/978-1-4757-3294-8
- Johnson CL, Paulose-Ram R, Ogden CL, et al. National Health and Nutrition Examination Survey: Analytic Guidelines, 1999–2010. *Vital Health Stat 2*. 2013;(161):1–24. PMID: 25090154.
