---
title: "CRP and mortality in NHANES: a commented methodological manuscript"
subtitle: "What we did, why we did it, the alternatives, and what we cannot conclude"
author: "Working document for review by Javier Zorrilla de San Martin"
date: 2026-10-24
lang: en
format:
  html:
    toc: true
    toc-depth: 2
    number-sections: true
    embed-resources: true
    theme: default
    fontsize: 18px
    linestretch: 1.65
    code-copy: true
    smooth-scroll: true
    html-math-method: mathml
execute:
  enabled: false
---

## Purpose and reading guide {#sec-lectura}

This is an alternative learning manuscript, longer than the scientific draft. Its purpose is to help the investigator reconstruct the study's logic, question its assumptions, and explain its decisions without having to remember R commands. It does not replace the protocol, frozen statistical analysis plan, or amendments, and it does not add models or change estimates. This English revision also incorporates the completed Amendment 001 sensitivity; the original Spanish wording remains available in Git history. The legacy source filename is retained so that existing links continue to work.

The explanation moves from the scientific question through design decisions, survival modeling, extensions, and missing data. Equations first describe the general idea and then its application. Simplifications, such as an unweighted likelihood without ties, are identified explicitly: an educational expression must not be confused with all the details of the software implementation.

Four levels of evidence must remain distinct:

| Level | What it means | What it does not mean |
| --- | --- | --- |
| Prespecified rule | Documented before examining associations | The only defensible choice |
| Verified implementation | Code follows the rules and produces coherent objects | The model perfectly describes reality |
| Favorable diagnostic | A particular concerning pattern was not found in the checks performed | All assumptions have been proved |
| Substantive result | An estimate obtained under explicit decisions | A causal relationship or a model-independent truth |

Numbers come from saved outputs, including documented corrections. Fictional participants and hypothetical probabilities serve only to explain concepts. Markdown provides the source; HTML supplies a navigable contents list and typeset equations.

**Question to answer by the end:** Which aspects of the result depend on the data, the survey design, the model's functional form, and assumptions about missing values?

## Scientific question: prognostic association, causality, and prediction {#sec-pregunta}

The study asks whether higher baseline C-reactive protein, abbreviated CRP to match the code, is associated with higher subsequent mortality among adults represented by NHANES 1999–2010.

**Baseline** matters. We have one initial measurement rather than a complete longitudinal CRP history. The model relates that marker to subsequent outcomes. It does not describe how an individual's hazard changes when that person's CRP rises or falls over time.

**Associated** also matters. An intervention changing CRP was not randomized. A high concentration can reflect multiple measured and unmeasured processes. Covariate adjustment does not automatically turn a coefficient into the effect of intervening on CRP. The adjusted association alone cannot distinguish whether CRP is a cause, marker, consequence of existing disease, or a combination.

A prognostic association study is also different from a **validated clinical prediction study**. The latter would require defined prediction targets, absolute-risk estimates, and suitable calibration and discrimination assessments. We have not shown that adding CRP to a clinical tool improves decisions.

The primary target is therefore an adjusted hazard ratio per doubling of CRP. When the relationship is nonlinear or varies over follow-up, that number is a working-model summary rather than a universal biological constant.

## Why freeze the protocol? {#sec-congelacion}

Protocol and SAP v0.3 were frozen before association analysis. This separates initial scientific decisions from choices potentially influenced by attractive results. Exposure, outcome, covariates, population, time scale, sensitivities, and the two effect-modification hypotheses were specified.

Freezing does not make a failed implementation untouchable or eliminate problems discovered only after opening outcomes. It requires documenting changes and their timing. The project's actual chronology is:

| Decision | Timing and status |
| --- | --- |
| Primary specification and general sensitivities | SAP v0.3 frozen before association analysis |
| Assign 0.5 months to four deaths in the examination month | Amendment 001: after follow-up was opened, before the first association fit |
| Replace continuous log-time interaction with four periods | Amendment 002: after auxiliary diagnostics and computational failure, before estimating the replacement model |
| Test linear age as a sensitivity | Amendment 003: after primary results were known, before fitting that sensitivity |
| Final imputation and parallelization details | Developed after primary analysis; documented and tested before real imputation |
| Sex and age-group interactions | Prespecified hypotheses; implementation details recorded on 23 October before their fits |
| Isolate the same-month-death sensitivity | Promised in Amendment 001; completed on 23 October after the initial reporting review identified the outstanding item |

This chronology prevents retrospectively presenting every decision as preceding all results. Reproducibility requires an honest timeline as well as code.

## Population, eligibility, and cohort construction {#sec-cohorte}

### Target and analyzed populations

NHANES uses a complex probability design to represent the civilian noninstitutionalized US population. We pooled six cycles, from 1999–2000 through 2009–2010. Analysis additionally required adulthood, positive CRP, a positive MEC weight, mortality-linkage eligibility, and the other eligibility conditions.

These restrictions affect generalizability. Original survey weights do not ensure that every subset selected by measurement availability, linkage, and complete covariates is automatically representative without further assumptions. Imputation expands the analysis for missing covariates; it does not recover people lacking exposure measurements or linkage eligibility.

### Observed flow

| Stage | Participants |
| --- | ---: |
| Adults with positive CRP and MEC weight | 28,924 |
| Eligible for mortality linkage | 28,890 |
| Confirmed pregnancies excluded | 1,135 |
| Final eligible cohort | 27,755 |
| Complete cases for primary adjustment | 26,818 |
| At least one missing primary covariate | 937 |
| Complete cases additionally requiring income/poverty | 24,683 |

The 937 incomplete participants are people, not cells: one person can have several missing values. There were 5,886 deaths among complete cases and 6,354 in the eligible cohort. These are observed counts rather than survey-weighted population totals.

### Pregnancy and indeterminate status

Confirmed pregnancy was excluded for measurement comparability and the interpretation of CRP and BMI in this study question. This restricts scope; it does not classify pregnancy as erroneous data.

Indeterminate status was not converted into either confirmed pregnancy or confirmed absence. It was retained primarily and examined in a sensitivity. There were 209 eligible participants in that category, including 180 complete cases. Exclusion therefore reduces the primary sample from 26,818 to 26,638, rather than removing 209 primary participants.

### Identifiers, special codes, and questionnaire skips

Components are joined by `SEQN`, with uniqueness checks to prevent a join from multiplying records. Accidental duplication changes weights, risk sets, and event counts; it is not a formatting detail.

Numeric codes for “do not know” or “refused” are not valid clinical categories. They were recoded to missing before identifying complete cases. Consequently, final counts differ from an early audit that counted only conventional `NA` values.

Not every unasked question is missing information. If someone never smoked and a subsequent question applies only to smokers, that structural skip need not prevent classification as a never smoker. Derivation code distinguishes these cases.

## Adjustment variables and why they were not selected by p-values {#sec-ajuste}

The demographic model includes age, sex, race/Hispanic origin, and cycle. The primary model adds education, smoking, BMI, diabetes, hypertension, and prevalent cardiovascular disease (CVD). Variables were not selected using univariable tests, stepwise procedures, or the smallest p-value.

The rationale is to preserve a previously defined adjusted question rather than let sample noise decide what “adjusted” means. This does not prove that every relevant determinant is included or that each covariate has an identifiable causal interpretation. In a prognostic study, adjusting for prevalent disease can deliberately change the residual association being described without identifying causal direct effects.

| Construct | Implementation and caution |
| --- | --- |
| Age | Baseline years with a spline; no global linearity assumption |
| Sex | `RIAGENDR` categories; not reinterpreted as a comprehensive gender measurement |
| Race/Hispanic origin | Five harmonized categories; coefficients are not assigned biological causality |
| Education | Five categories without equal numeric spacing |
| Smoking | Never, former, current, respecting questionnaire routes |
| BMI | Positive continuous measurement; not categorized for inferential convenience |
| Diabetes | No, borderline, yes; borderline was not merged after reviewing results |
| Hypertension | Reported diagnostic history; not an exhaustive classification based on measured blood pressure |
| Prevalent CVD | Yes if any component is affirmative; no only when all are explicitly negative; otherwise missing |
| Cycle | Factor representing recruitment-period differences |
| Income/poverty | Additional sensitivity adjustment, not a primary covariate |

Greater missingness for income/poverty—2,244 records, 8.09% of eligible participants—motivated treating it separately, alongside more complete education information. These are not interchangeable constructs: including education does not establish sufficient socioeconomic adjustment.

Comparing demographic and primary models is not a causal decomposition of the coefficient change. Noncollapsibility and changes in the conditioning set also affect hazard models. Attenuation cannot automatically be called a “percentage explained.”

## CRP: units, logarithm, and detection limit {#sec-exposicion}

### Convert units before interpretation

The released variable is in mg/dL. We multiply by ten:

$$
\mathrm{CRP}_{\mathrm{mg/L}}=10\,\mathrm{CRP}_{\mathrm{mg/dL}}.
$$

Conversion ensures that thresholds and contrasts use the intended units. Changing only the unit inside a logarithm adds a constant to the predictor; this does not change the slope per doubling in this model. However, labels for 1, 2, 4, or 8 mg/L would be wrong without the correct conversion.

### Why a base-2 logarithm?

Define $X=\log_2(\mathrm{CRP})$. Then:

$$
\log_2(2c)-\log_2(c)=1.
$$

The same predictor increment compares 1 with 2 mg/L, 2 with 4, or 4 with 8. A model linear in log2 assigns every doubling the same HR, $e^\beta$. This is a model restriction subsequently examined using a spline.

CRP need not be normally distributed to enter Cox regression as a logarithmic predictor. The choice affects functional form on the log-hazard scale, interpretation, and tail influence; it does not turn Cox into normal regression of CRP.

For multiplication by a factor $a$:

$$
HR(c\to ac)=\exp\{\beta\log_2(a)\}.
$$

Quadrupling is two doublings, giving $e^{2\beta}$. An absolute 1 mg/L increase has no constant HR on this scale: 1 to 2 and 10 to 11 are different concentration ratios.

### Values below detection

The public file contains a released fill value of 0.01 mg/dL for observations identified as below detection. The documented nominal limit is 0.02 mg/dL. The primary analysis retains the public value; separate sensitivities replace it with 0.02 mg/dL or exclude those observations.

Documentation describes a limit-divided-by-$\sqrt{2}$ rule, but $0.02/\sqrt{2}\simeq0.01414$ is not numerically 0.01. We do not reconstruct precision absent from the released value or treat it as an exact concentration. Reporting must distinguish the documented rule from the available number. The indicator uses the public value and the file audit.

**Implication:** we preserve a reproducible primary rule and assess dependence on it; we do not recover the true concentration below detection.

## Follow-up, censoring, and four zero-month times {#sec-tiempo}

For each person, observed time and event indicator are:

$$
T_i=\min(T_i^{\mathrm{death}},C_i),
\qquad
\delta_i=I(T_i^{\mathrm{death}}\le C_i),
$$

where $C_i$ is the available observation endpoint. Time is elapsed months since the MEC examination, with public mortality linkage through the end of 2019. This is not attained age as the time scale; baseline age enters as a covariate.

A censored person contributes survival up to the observed time and membership in earlier risk sets. That person is not treated as someone who will never die or as a death at study closure.

Inference requires assumptions about observation, censoring, and linkage quality. An administrative closing date alone does not establish independence of every loss of follow-up or outcome classification. Linkage eligibility and public-file limitations must be described.

Four eligible participants have recorded death and zero released months. We interpret the monthly resolution as death within the examination interval and assign 0.5 months analytically, preserving the original. This is a midpoint approximation, not a reconstructed death date.

The pipeline requires positive analysis times. This does not imply that every Cox implementation is mathematically unable to accept a zero-coded event: technical acceptance of a number does not settle its interpretation as grouped time. Amendment 001 chose an explicit convention for this project.

**Completed amendment sensitivity:** only two of the four eligible deaths belong to the complete-case sample; the other two already lack required covariates. Excluding the applicable two gives 26,816 participants and 5,884 deaths, with HR 1.129632 (95% CI 1.108576–1.151088), versus primary HR 1.129854. The relative HR change is −0.01965%. The [dated addendum](../same_month_death_sensitivity_v1/README.md) documents the 23 October execution. This isolates the midpoint issue more narrowly than excluding every death within 12 or 24 months. Similarity is not a formal equivalence test.

## Why survival analysis, and what does hazard mean? {#sec-hazard}

Hazard is an instantaneous rate conditional on remaining alive just before $t$:

$$
h(t\mid\mathbf{x})
=\lim_{\Delta t\to0}
\frac{\Pr(t\le T<t+\Delta t\mid T\ge t,\mathbf{x})}{\Delta t}.
$$

The survival function is $S(t\mid\mathbf{x})=\Pr(T>t\mid\mathbf{x})$. The two are related by:

$$
S(t\mid\mathbf{x})=\exp\{-H(t\mid\mathbf{x})\},
\qquad
H(t\mid\mathbf{x})=\int_0^t h(u\mid\mathbf{x})\,du.
$$

Logistic regression of final mortality status would lose timing information and compare people with different observation windows without modeling those windows in the same way. Cox uses event ordering and each participant's time at risk, retaining censoring under its assumptions.

An HR of 1.13 does not mean that 13% more of all participants die or that ten-year mortality increases by 13 percentage points. It compares model hazards conditional on covariates and the survivors at each instant.

Even under proportional hazards, with reference survival $S_0(t)$ and linear predictor $\eta$:

$$
S(t\mid\mathbf{x})=S_0(t)^{\exp(\eta)}.
$$

Converting a hazard contrast into an absolute-risk contrast also requires baseline hazard or survival and a defined comparison population. This study does not validate an individual risk calculator.

## The Cox model and its estimation {#sec-cox}

### Primary model structure

$$
h_i(t)=h_0(t)\exp\left\{
\beta X_i+f(\mathrm{age}_i)+\boldsymbol{\gamma}^{\top}\mathbf{Z}_i
\right\},
\qquad X_i=\log_2(\mathrm{CRP}_i).
$$

The baseline $h_0(t)$ has no prespecified parametric form. The exponential part describes hazard ratios. “Semiparametric” does not mean “without assumptions”: the predictor, functional forms, and time-constant coefficients are specified.

### Partial likelihood: intuition without weights or ties

If person $i$ dies at $t_i$, with risk set $R(t_i)$ immediately beforehand, the contribution is:

$$
\frac{\exp(\boldsymbol{\theta}^{\top}\mathbf{x}_i)}
{\sum_{j\in R(t_i)}\exp(\boldsymbol{\theta}^{\top}\mathbf{x}_j)}.
$$

The product compares who died with those who could have died at each event. The common baseline hazard cancels. Estimation does not simply divide average CRP among deaths by average CRP among survivors.

The associated score equation is:

$$
U(\boldsymbol{\theta})=
\sum_{i:\delta_i=1}
\{\mathbf{x}_i-\overline{\mathbf{x}}_{R(t_i)}(\boldsymbol{\theta})\}=0,
$$

where risk-set means are weighted by $e^{\boldsymbol{\theta}^{\top}\mathbf{x}_j}$. This introduces the idea; actual execution incorporates weights and ties.

### Survey weighting

A conceptual weighted score without ties is:

$$
U_w(\boldsymbol{\theta})=
\sum_i w_i\delta_i
\left[
\mathbf{x}_i-
\frac{\sum_{j\in R(t_i)}w_j\mathbf{x}_j e^{\boldsymbol{\theta}^{\top}\mathbf{x}_j}}
{\sum_{j\in R(t_i)}w_j e^{\boldsymbol{\theta}^{\top}\mathbf{x}_j}}
\right].
$$

Weights affect both event contributions and weighted risk-set composition. Fitting conventional Cox regression and multiplying its HR by an average weight would not implement this analysis.

### Ties and the Efron approximation

Monthly follow-up creates tied death times. In an unweighted illustration with $d$ tied deaths, Efron approximates the denominator using:

$$
\prod_{\ell=0}^{d-1}
\left[
\sum_{j\in R(t)}e^{\eta_j}
-\frac{\ell}{d}\sum_{j\in D(t)}e^{\eta_j}
\right],
$$

where $D(t)$ is the tied-death set. This represents gradual removal of that set. The teaching formula does not replace the implementation with noninteger weights. The choice is fixed in the SAP and implemented by `method="efron"` [S2](https://www.stat.ethz.ch/R-manual/R-devel/library/survival/html/coxph.html).

We did not choose the exact method after comparing p-values. Efron does not reconstruct within-month death ordering.

## Survey design: weights, strata, PSUs, and variance {#sec-encuesta}

### Three different roles

A weight represents a participant's contribution to the target population under the survey construction. Strata organize sampling, and a PSU identifies a clustered selection unit. Two people in one PSU need not provide independent information as in simple random sampling.

`nest=TRUE` interprets PSU labels within strata. `SDMVPSU=1` does not identify one shared unit across the entire study. Moreover, `strata=~SDMVSTRA` in the **survey design** differs from adding `strata(SDMVSTRA)` to a Cox formula: the latter permits different baseline hazards and defines another model.

### Why not divide every two-year weight by six?

The applied rule is:

$$
w_i^{\mathrm{pool}}=\begin{cases}
\mathrm{WTMEC4YR}_i/3,&1999\text{–}2002,\\
\mathrm{WTMEC2YR}_i/6,&2003\text{–}2010.
\end{cases}
$$

The first block represents four of twelve years; the others represent two each. NCHS guidance requires starting with the four-year weight when combining 1999–2000 and 2001–2002 [S1](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx). The difference is not an ignorable common multiplier: it changes the relative contribution of early cycles.

The initial code filter uses positivity of `WTMEC2YR`; final analytic weights follow the rule above. Reading the original files for this companion found no membership discrepancies between two-year and four-year positivity among adults with positive CRP in those cycles: 4,145 and 4,729 participants. This establishes equivalence of that filter **in these files**, not equality of weight values.

### Sandwich covariance

Design covariance has the general form:

$$
\widehat{\operatorname{Var}}(\widehat{\boldsymbol{\theta}})
=A^{-1}B_{\mathrm{design}}A^{-\top}.
$$

$A$ describes estimating-equation sensitivity; $B_{\mathrm{design}}$ estimates contribution variability while accounting for clustering and stratification. An illustrative expression is:

$$
B_{\mathrm{design}}=\sum_h\frac{n_h}{n_h-1}
\sum_{a=1}^{n_h}(\mathbf{g}_{ha}-\bar{\mathbf{g}}_h)
(\mathbf{g}_{ha}-\bar{\mathbf{g}}_h)^{\top},
$$

using PSU-level linearized contributions. The exact implementation is supplied by `survey`, rather than calculated manually from this simplified expression. Comparing its SE with an ordinary Cox SE is not model validation.

### What do 91 degrees of freedom mean?

The validated cohort has 180 nested PSUs and 89 strata:

$$
\nu_{\mathrm{design}}=180-89=91.
$$

These are neither 91 participants nor 91 events. Nor do **all** study tests use denominator df 91. Spline and interaction Wald tests use their model-residual df; the replicated temporal test uses 91, and Rubin pooling uses its finite convention. Each calculation needs its actual reference distribution.

### Representativeness after complete-case selection

Retaining original weights does not automatically correct additional selection on complete covariates. Primary analysis concerns the observed complete-case cohort under transportability and model assumptions. MI checks this particular loss; it does not resolve prior selection on CRP, linkage, or pregnancy, or prove universal representativeness.

## Age and CRP splines: controlled flexibility {#sec-splines}

### Why avoid one rigid age slope?

If age relates nonlinearly to log hazard, a straight age term may leave residual structure associated with CRP. A spline permits curvature without estimating a separate parameter for every year or selecting categories after seeing results.

Frozen age locations were **22, 38, 52, and 78 years**, the weighted 5th, 35th, 65th, and 95th percentiles. `splines::ns` uses 38 and 52 as interior knots and 22/78 as boundaries, producing three columns. Its natural cubic basis spans the same restricted cubic spline space with these knots, although coefficients from other parameterizations are not interchangeable.

“Linear tails” means linearity of the spline predictor outside the boundaries, not linearity of untransformed hazard or absence of observations outside 22–78. Ages outside those boundaries were retained.

### CRP basis and restrictions

The CRP basis comprises the linear term $x=\log_2(\mathrm{CRP})$ and two nonlinear functions. For knots $\kappa_1<\dots<\kappa_K$, one parameterization is:

$$
\begin{aligned}
d_j(x)={}&\frac{(x-\kappa_j)_+^3}{(\kappa_K-\kappa_1)^2}\\
&-\frac{(\kappa_K-\kappa_j)(x-\kappa_{K-1})_+^3}
{(\kappa_K-\kappa_{K-1})(\kappa_K-\kappa_1)^2}\\
&+\frac{(\kappa_{K-1}-\kappa_j)(x-\kappa_K)_+^3}
{(\kappa_K-\kappa_{K-1})(\kappa_K-\kappa_1)^2},\\
&\qquad j=1,\ldots,K-2.
\end{aligned}
$$

Here $(u)_+=\max(u,0)$ and $K=4$. The function is:

$$
g(x)=\alpha_1x+\alpha_2d_1(x)+\alpha_3d_2(x).
$$

Tail restrictions reduce flexibility in regions that often contain little information. Frozen log2 knots were approximately $-2.32193$, $0.13750$, $1.58496$, and $3.87774$, corresponding to **0.2, 1.1, 3.0, and 14.7 mg/L**. They were not optimized for significance.

### Global test, nonlinearity, and contrasts

The global test evaluates $\alpha_1=\alpha_2=\alpha_3=0$; nonlinearity evaluates only $\alpha_2=\alpha_3=0$. These are different questions. The nonlinearity p-value was approximately 0.000311, with F(2,65) = 9.169.

To compare $c$ mg/L with 1 mg/L, calculate the basis difference:

$$
\mathbf{L}(c)=\mathbf{b}(\log_2 c)-\mathbf{b}(\log_2 1),
$$

$$
\begin{aligned}
\log HR(c:1)&=\mathbf{L}(c)^{\top}\widehat{\boldsymbol{\alpha}},\\
\operatorname{Var}\{\log HR(c:1)\}
&=\mathbf{L}(c)^{\top}\widehat V_\alpha\mathbf{L}(c).
\end{aligned}
$$

Covariance between terms is essential. Adding column-specific standard errors does not produce the contrast interval.

Observed HRs were 1.102 for 2 versus 1 mg/L, 1.275 for 4 versus 1, and 1.507 for 8 versus 1. Their intervals appear in the scientific draft. The figure spans weighted percentiles 1–99 to avoid letting a nearly empty region dominate the visual scale; this plotting restriction does not exclude observations from fitting.

![Saved CRP curve without refitting. The reference point has HR=1 by definition.](../stage6_v1/figures/crp_spline.svg)

## Proportional hazards and variation over follow-up {#sec-ph}

### What is assumed constant?

The primary model assumes that $\beta$ does not depend on $t$. Hazard itself need not be constant: $h_0(t)$ can vary freely. Rather, within the model and holding covariates fixed, $h(t\mid X+1)/h(t\mid X)=e^\beta$ at every time.

Nonlinearity and nonproportionality are different issues. A spline lets the association vary with CRP concentration, but not time if its coefficients remain constant. A temporal interaction permits different coefficients over follow-up while potentially retaining log2 linearity within each period.

### Schoenfeld residuals as an auxiliary diagnostic

A Schoenfeld residual compares the event participant's covariate with its expected risk-set average. A time trend in scaled residuals suggests structure unrepresented by a constant coefficient.

`cox.zph` was applied to an auxiliary weighted model clustered by PSU. That model does not fully reproduce `svycoxph` stratified design variance. Its CRP p-value was approximately $4.63\times10^{-6}$, but this was not the sole basis for population inference. A separate design-based test followed.

### Why change the planned temporal model?

The initial plan interacted CRP with $\log(t)$. The `tt()` implementation expanded risk sets and exhausted memory; no valid result was obtained. Amendment 002 then specified four periods before their estimates were examined.

The replacement has a period-specific coefficient:

$$
h_i(t)=h_0(t)\exp\left\{
\sum_{r=1}^4\beta_rX_iI(t\in I_r)
+f(\mathrm{age}_i)+\boldsymbol{\gamma}^{\top}\mathbf{Z}_i
\right\}.
$$

Cut points are 60, 120, and 180 months. Someone surviving more than fifteen years can contribute four start–stop rows, each describing a risk interval. This remains one person with at most one death. Expansion produced 81,509 rows and retained 5,886 events.

The representation does not make every other coefficient time-varying or establish proportional hazards for the remaining covariates. It is a partial, explicit, computationally feasible approximation.

### JKn replicates and the global contrast

There were 180 design replicates, deleting one PSU per replicate and adjusting weights according to JKn. Covariance has the structure:

$$
\widehat V_{\mathrm{JKn}}
=s\sum_{r=1}^{180}a_r
(\widehat{\boldsymbol{\theta}}^{(r)}-\widehat{\boldsymbol{\theta}})
(\widehat{\boldsymbol{\theta}}^{(r)}-\widehat{\boldsymbol{\theta}})^{\top},
$$

with scale $s$ and factors $a_r$ from `survey`, using MSE centering on the full-sample estimate. Replicate HRs were not naively averaged as if they were imputations. Replicates estimate sampling uncertainty; imputations represent missing-data uncertainty. These are different operations.

The temporal hypothesis is:

$$
H_0:\beta_1=\beta_2=\beta_3=\beta_4.
$$

For a three-row contrast matrix $C$:

$$
F=\frac{(C\widehat{\boldsymbol{\beta}})^{\top}
(C\widehat V C^{\top})^{-1}
(C\widehat{\boldsymbol{\beta}})}{3},
$$

using F(3,91). The result was F = 2.824, p = 0.0431. Period-specific HRs per doubling were 1.180, 1.109, 1.096, and 1.156; corresponding deaths were 1,675, 2,146, 1,468, and 597.

The pattern does not decline monotonically: the last estimate increases and has less precision. Boundaries do not identify exact biological transitions. The overall HR of 1.130 should not be presented as an identical effect at every time.

## Interpreting the primary result {#sec-principal}

The primary coefficient was $\widehat\beta=0.1220883$, with design SE $0.0096146$. Thus:

$$
HR=e^{0.1220883}=1.129854.
$$

The interval uses the primary normal convention:

$$
\mathrm{CI}_{95\%}=\exp\{\widehat\beta\pm1.959964\,SE\}
=[1.108762,\ 1.151347].
$$

This is approximately 13% higher hazard per doubling of CRP **within the adjusted model summary**. It is neither 13 percentage points of risk nor the causal effect of lowering CRP, and it need not apply uniformly over concentration and follow-up.

The primary p-value, approximately $6.05\times10^{-37}$, addresses a particular model-coefficient hypothesis. It does not measure clinical importance, probability of causality, or probability that all assumptions are correct. A small p-value does not correct miscoding, selection bias, or functional-form error.

Given nonlinearity and temporal variation, reporting only this number would be incomplete. We accompanied the primary summary with predefined analyses and limitations rather than searching for another model with a preferred p-value.

## Missing data: the problem being addressed {#sec-faltantes}

There are 937 eligible people with at least one missing primary covariate:

| Variable | Missing values | Percentage of 27,755 |
| --- | ---: | ---: |
| BMI | 575 | 2.072% |
| Education | 48 | 0.173% |
| Smoking | 31 | 0.112% |
| Diabetes | 19 | 0.068% |
| Hypertension | 164 | 0.591% |
| Prevalent CVD | 147 | 0.530% |

The total is 984 cells, exceeding 937 people. Summing variable-specific percentages does not directly yield the percentage of incomplete people.

### Why complete cases as primary?

This was the frozen rule. It gives a transparent analysis without modeling missing values and retains 96.62% of eligible participants. High retention does not establish absence of bias. Incomplete participants need not be a small random subset: for example, those missing BMI were older and had a higher proportion of observed deaths.

Complete-case analysis can be valid under particular selection structures and models, including some that are not MCAR. It does not universally require all missingness to be completely random. Nor is it valid merely because the percentage missing is small. Theoretical conditions must be distinguished from observed patterns.

### MCAR, MAR, and MNAR

Let $R$ indicate observation, $Y_{\mathrm{obs}}$ denote known information, and $Y_{\mathrm{mis}}$ missing information. Conceptually:

$$
\begin{aligned}
\mathrm{MCAR}:&\quad P(R\mid Y_{\mathrm{obs}},Y_{\mathrm{mis}})=P(R),\\
\mathrm{MAR}:&\quad P(R\mid Y_{\mathrm{obs}},Y_{\mathrm{mis}})=P(R\mid Y_{\mathrm{obs}}),\\
\mathrm{MNAR}:&\quad P(R\mid Y_{\mathrm{obs}},Y_{\mathrm{mis}})
\text{ additionally depends on }Y_{\mathrm{mis}}.
\end{aligned}
$$

MAR does not mean that missingness depends on nothing. It permits dependence on appropriately included observed variables. BMI missingness might depend on known age. The stronger claim is that, conditional on the observed context, no additional dependence on unknown BMI needs representation in the model.

We cannot directly compare true missing BMI values with observed ones to verify this condition. Stable traces therefore do not prove MAR. We have not run a formal MNAR sensitivity shifting imputed values under scenarios; MI should not be said to cover that uncertainty automatically.

## What multiple imputation is—and is not {#sec-mi}

MI produces several plausible complete datasets under explicit models. It does not identify the true missing value for an individual. Keeping just one fixed imputed value would hide some uncertainty.

For a fictional person with missing BMI, completed versions might contain 27.4, 28.1, or 26.9. These are different proposals for one unknown baseline value, not observed weight changes over time.

We generated **50 independent chains, each producing one completed dataset**. Each chain made 20 update cycles. We use one final version per chain: 50 datasets, not 1,000 independent samples. All contain the same 27,755 people, and originally observed cells remain fixed.

CRP, death, follow-up, weights, strata, and PSUs were not imputed. These define exposure, observation, or design; changing them would introduce different questions and measurement assumptions.

### Why 50 rather than one or thousands?

Fifty was specified in the SAP. Multiple imputations estimate between-dataset variability and reduce simulation noise. More imputations do not replace an adequate model or solve MNAR. Increasing from 50 to 500 could reduce Monte Carlo error without correcting systematic imputation bias.

We did not choose 50 because it best reproduced the complete-case HR. Neither direction nor proximity to that estimate determined convergence acceptance.

## MICE: six models updated sequentially {#sec-mice}

Let $A_1,\ldots,A_6$ be incomplete covariates and $F$ fixed predictors. Each iteration approximates, for every target:

$$
P(A_j^{\mathrm{mis}}\mid A_j^{\mathrm{obs}},A_{-j},F).
$$

The order was BMI, education, smoking, diabetes, hypertension, and CVD. After updating BMI, the education model can use that update. On the next BMI step, updated values from other targets are available.

A chain begins with initialization and then advances. An iteration is one full pass through the six targets. Initial values are not final results. Twenty passes allow examination of whether behavior has visibly stopped depending on initialization.

MICE, a fully conditional specification approach, adapts models to variable types. This flexibility does not guarantee that all conditional models correspond to one compatible joint distribution or are fully compatible with the final Cox model. That methodological limitation does not disappear through additional iterations.

### Predictor matrix and missingness mask

Each target uses the other five targets and all fixed predictors. Its diagonal is zero: BMI does not predict itself. Fixed-variable rows are zero with empty methods because those variables are not updated.

The `where` matrix is true only for originally missing cells. It prevents MI from becoming general data modification. Methods, predictors, masks, and original data are checked against the saved plan before outcome analysis.

A temporary median/mode-filled copy was used to check matrix rank during preparation. **It was not an analytic dataset or the reported imputation.** Each chain had its own actual initialization and subsequent rank check.

## Imputation methods, variable by variable {#sec-metodos-mi}

### BMI and predictive mean matching

PMM combines prediction and donor selection. It finds observed records whose predicted BMI is close to the incomplete record's prediction and randomly selects an observed donor BMI.

A representation of the continuous fit is:

$$
y_{\mathrm{obs}}=X_{\mathrm{obs}}\beta+\epsilon.
$$

The algorithm obtains an estimate and a parameter draw. Schematically, in its normal component:

$$
\sigma^{*2}=\frac{RSS}{\chi^{2*}_{\nu}},
\qquad
\beta^*=\widehat\beta+\sigma^*Lz,
\quad z\sim N(0,I),
$$

where $LL^{\top}$ relates to the fit's uncertainty matrix. Implementation has its own numerical estimation options; it does not force the final imputed BMI distribution to be normal linear regression.

With `matchtype=1`, observed predictions use estimated coefficients and missing predictions use drawn coefficients. Five nearby donors are identified and one actual BMI is sampled. `donors=5` and `ridge=1e-5` were fixed before execution. Ridge provides small numerical stabilization rather than penalty selection to improve the HR.

The final value is a donor value, not necessarily the regression prediction. This preserves observed support and prevents creation of a BMI outside available donors. It does not guarantee clinical comparability in every respect or calibrated matching models.

Observed support was **12.04–130.21**. Some imputations reused the extreme donor 130.21. Being observed means it is not fabricated, but does not establish clinical validity or remove tail and variance effects. It was not retrospectively trimmed to obtain a more convenient distribution.

### Binary variables: logistic regression with a draw

For hypertension and CVD:

$$
\operatorname{logit}(p_i)=\mathbf{x}_i^{\top}\beta,
\qquad p_i=\frac{1}{1+e^{-\mathbf{x}_i^{\top}\beta}}.
$$

The installed function fits an augmented model to stabilize perfect prediction. It makes an approximate coefficient draw:

$$
\beta^*=\widehat\beta+Lz,
$$

then draws a binary value with probability $p_i^*$. A probability of 0.70 does not mean always imputing “yes” or assigning 0.70 as a category. It gives the probability of a “yes” draw at that step.

Internal augmentation weights are not MEC weights. Conditional fits do not become survey regressions merely by including design predictors.

### Education, smoking, and diabetes: multinomial models

For reference category 0 and categories $c=1,\ldots,C-1$:

$$
P(A=c\mid\mathbf{x})=
\frac{e^{\mathbf{x}^{\top}\beta_c}}
{1+\sum_{d=1}^{C-1}e^{\mathbf{x}^{\top}\beta_d}},
$$

with reference probability equal to the reciprocal of that denominator. A category is sampled from these probabilities.

Education was nominal, avoiding proportional-odds and equally spaced category assumptions, at the cost of more parameters. This does not deny its conceptual order; it avoids imposing an additional ordinal model without justification.

Diabetes retained borderline status. It was not merged when some chains generated no borderline draws among the 19 missing diabetes cells. Zero draws do not mean the level disappeared from the model. Forty of fifty final chains had zero, while others had up to three; mean imputed prevalence was about 1.58% versus 1.64% observed.

### An important distinction about uncertainty and actual code

`polyreg` documentation describes multinomial fitting, prediction, and noise with augmentation for perfect prediction [S3](https://amices.org/mice/reference/mice.impute.polyreg.html). Inspection of **installed MICE 3.19.0** shows `nnet::multinom`, probability calculation, and category sampling. That function contains no explicit multinomial coefficient draw analogous to `logreg`.

It would therefore be incorrect to say that **every** method draws posterior parameters identically. Other targets and sequential updates add variability, but this does not establish an exact joint Bayesian sampler, “proper” imputation, or perfect coverage. This observation documents the algorithm; alone it does not invalidate all MI. Calibration depends on methods, data, and compatibility with analysis.

Rubin's equations incorporate variability actually generated. If a necessary uncertainty source is not represented, increasing $m$ estimates generated variability more precisely without supplying what is missing. A small $B$ is a procedural result, not universal proof that missingness is harmless.

## Survival information in the imputation models {#sec-supervivencia-mi}

### Why including the outcome is appropriate here

The task is retrospective inference about covariate–mortality relationships. Imputing a mortality-associated covariate without outcome information can artificially weaken that association in completed cells. Death and a representation of temporal information were included to preserve analysis-relevant relationships.

Prediction is a different task: a patient's future death is unavailable at prediction time. Our analytical imputation cannot be copied unchanged into preprocessing for a deployed clinical tool or interpreted as out-of-sample prediction validation.

### Nelson–Aalen auxiliary

For distinct time $t_j$, let $d_j$ be deaths and $Y_j$ the risk-set count just beforehand. Define:

$$
\widehat H_{\mathrm{NA}}(t)=\sum_{t_j\le t}\frac{d_j}{Y_j}.
$$

Someone censored at a tied time remains in the risk set just before that time; tied deaths are summed. The auxiliary is calculated once in all 27,755 eligible participants and then fixed.

Teaching example: five records have times 0.25, 0.5, 0.5, 0.5, and 2 months. The first is censored; at 0.5 there are two deaths and one censoring; the last is a death. At 0.5, four people remain at risk and the increment is $2/4=0.5$. At 2, one remains and the increment is 1. Final cumulative hazard is 1.5, not a 150% probability.

The auxiliary is **marginal and unweighted**, neither the adjusted Cox baseline hazard nor a survey population survival curve. It approximates survival information for imputation. Inclusion does not prove exact compatibility with splines, PMM, or time-varying coefficients. These limits were retained in the technical specification.

## Representing sampling within MICE {#sec-diseno-mi}

The final Cox model uses survey design directly. MICE instead uses conditional fits without MEC weighting, with design information as fixed predictors.

The representation avoids redundancy:

| Component | Independent columns |
| --- | ---: |
| Intercept | 1 |
| Six cycles as a factor | 5 |
| Strata within cycle: 89 minus 6 references | 83 |
| PSUs within strata: 180 minus 89 references | 91 |
| Total design-intercept space | 180 |

This spans the same intercept space as a factor of 180 nested PSUs. It does not reduce design complexity to five cycle contrasts; it retains unit effects without redundant factors. Additional covariates bring target-specific matrices to 199–202 columns with full rank.

Centered and scaled $\log(w_i)$ is included as a predictor. It is not a survey likelihood weight multiplying each observation's contribution. Including it does not guarantee consistency under every informative sampling mechanism.

Many fixed unit effects can represent design heterogeneity but become unstable for rare categories. Full rank detects linear dependence; it does not guarantee absence of separation, good conditioning, calibration, or sufficient category counts. Support and multinomial-convergence audits were therefore conducted without opportunistic merging of levels or PSUs.

We did not combine raw PSU IDs as continuous numbers with every equivalent encoding, or make original weights responses. `SEQN` identifies participants but is not a substantively admissible MI predictor.

## Scaling, initialization, and protection of observed values {#sec-integridad-mi}

Continuous predictors and BMI were centered and scaled:

$$
z=\frac{x-\mu}{s},\qquad x=\mu+sz,
$$

using saved input constants; BMI constants use observed values. The aim is numerical stability, not a different estimand. The three age bases are determined by complete age and original knots. They are not independently imputed, and knots are not recalculated per chain.

Although theoretically invertible, floating-point operations might return $28.1000000001$ instead of original $28.1$. For final Cox fitting, observed BMI was preserved **exactly** from original records; only originally missing draws were back-transformed. We did not reconstruct the entire BMI column from transformed data.

Every stage compares counts, IDs, factor levels, fixed data, methods, and matrices. Warnings or unexpected MICE events stop execution for review rather than trigger silent alternatives. These checks establish algorithm fidelity, not the scientific truth of imputed values.

## Convergence: what was reviewed and why we stopped {#sec-convergencia}

### Iteration plan

Twenty initial iterations were planned, with extensions to 40 and 60 if diagnostics warranted, preserving model and random state. Extension until a more favorable HR or p-value was never planned.

At iteration 20, review covered BMI means, variances, quantiles, and category proportions for nominal variables. Mean diabetes codes 1, 2, and 3 do not replace three category proportions: numeric labels do not create clinical distances.

### Classical PSRF

For $m$ chains and a window of $L$ iterations of a summary $z_{k\ell}$:

$$
W=\frac{1}{m}\sum_{k=1}^m s_k^2,
\qquad
B_{\mathrm{trace}}=L\,\operatorname{Var}(\bar z_1,\ldots,\bar z_m),
$$

$$
\widehat R=\sqrt{\frac{(L-1)W/L+B_{\mathrm{trace}}/L}{W}}.
$$

$B_{\mathrm{trace}}$ is a temporal diagnostic for a summary statistic, not Rubin's later $B$. Their algebra resembles each other, but the objects and purposes differ.

Values near one favor overlap for that summary. Classical PSRF can be below one through finite variability; a modern rank-normalized version was not used. Neither establishes MAR or convergence of every distributional feature. If $W=0$, an undefined diagnostic must not be relabeled a pass.

### Autocorrelation, drift, and multiple flags

Lag-1 correlation compares a sequence with itself shifted one iteration. Large positive correlation may suggest persistence; large negative correlation may reflect alternation rather than a stuck chain.

Recorded review criteria were PSRF above 1.05, maximum absolute lag-1 correlation above 0.5, or between-window change above 0.2 within-sequence SD. These are flags, not universal boundaries between valid and invalid science.

Fifty chains and twenty summaries yield 1,000 summary/chain pairs per window. Maximizing over many short sequences makes extreme values likely. This does not justify ignoring flags; it requires examining signs and persistent chains.

In the final ten iterations, maximum PSRF was **1.02453** and maximum normalized mean change **0.15032**. Ten pairs had positive autocorrelation above 0.5 and 71 had negative autocorrelation below −0.5. Across all twenty iterations these counts were 2 and 10, with maximum PSRF **1.00940**.

The two persistent positive pairs were education summaries in chains 4 and 38. The latter had a lower late segment and final recovery. They remain disclosed uncertainties; chains and segments were not discarded. Opposing chain drifts can cancel in averages, so aggregate summaries were accompanied by individual traces.

### Distributions and the actual decision

Imputed BMI means ranged from 28.580 to 29.433 across chains, with reasonable overlap of central curves and observed data. Comparisons were also made by cycle and death. Marginal differences are not inherently errors because incomplete participants have different profiles.

Mean imputed hypertension was about 20.6% versus 34.1% observed, but those missing hypertension were younger on average, 40.7 versus 50.6 years. Imputed CVD was higher and its missing group older. This gives context rather than proof of conditional calibration or MAR.

The decision was to **accept 20 iterations**, based on integrity checks, visual overlap, low aggregate drift, and no persistent global pattern warranting extension. The twenty original flags remain saved. Acceptance did not mean “mathematical convergence proved” or “every indicator passed.” The decision report records this limited conclusion.

## Parallelization and reproducibility {#sec-computo}

Real-sized synthetic versions were tested before MI. Two processes reduced time by about 48% relative to sequential execution. Four completed equivalent work in 99 versus 372 seconds, roughly 3.74 times faster. Ten processes—approximately 60% of sixteen logical CPUs—were not admitted because of memory. The actual run used four.

Chains advance independently, but targets within an iteration use each other's updates. BMI and education were not parallelized within one chain as independent fits.

Each of fifty chains received a fixed L'Ecuyer-CMRG stream from master seed **20261013**. A process seed based on start time would confound randomness and scheduling. Here the stream belongs to the chain rather than its assigned core.

Separate chains have a different draw sequence from a hypothetical sequential multichain object; equality with that unexecuted procedure was not promised. Tests did show equality between sequential and parallel scheduling with the same per-chain states and successful checkpoint recovery.

Compact continuation avoids repeatedly embedding all past states in call histories; releasing temporary objects limits memory. These are implementation changes, not reductions in donors, covariates, or imputation count for speed.

Each chain saves complete state after every iteration through temporary writing, verification readback, and renaming to a new file. Iteration barriers, version/hash checks, and RAM/disk limits protect execution. After interruption, work resumes from the last compatible state without arbitrary reseeding. Hashes are not edited to bypass incompatibility.

The real run completed twenty iterations in about **7 h 27 min**, with peak combined worker memory **3.94 GiB**. All 3,000 multinomial fits recorded optimizer code zero. That means successful optimizer termination, not proof of correct specification or calibrated probabilities.

## Fifty Cox models without replacing the primary analysis {#sec-cincuenta}

After imputation acceptance, each completed dataset was assembled from the immutable eligible cohort. Only originally missing values were inserted. Age was rebuilt using frozen knots, and weights, strata, PSUs, and follow-up were preserved.

Every completed dataset used the same primary formula without income or category changes. Code compares it with the `primary_formula` assignment in Script 06. Models have 25 coefficients, although only CRP is pooled here.

From fit $k$, retain:

$$
Q_k=\widehat\beta_{\mathrm{CRP},k},
\qquad U_k=\widehat{\operatorname{Var}}_{\mathrm{design}}(\widehat\beta_{\mathrm{CRP},k}).
$$

All fifty models retained 27,755 participants, 6,354 deaths, finite coefficients/covariances, positive variance diagonals, and design df 91. This does not establish scientific correctness of every matrix or proportional hazards. Numerical verification is necessary and limited.

Individual log-HRs ranged from 0.125740 to 0.128214. These are imputation results from one sample, not fifty independent studies in new populations.

## Rubin pooling: mathematical development and numerical result {#sec-rubin}

### Why pool log-HRs rather than HRs?

Cox directly estimates the coefficient $\beta$ on the log scale. We pool $Q_k$ and its variance on that scale, then exponentiate. In general:

$$
\exp\left(\frac{1}{m}\sum_k Q_k\right)
\ne\frac{1}{m}\sum_k\exp(Q_k).
$$

The nonlinear transformation causes the inequality. Even if the numerical difference is small here, changing rules because they give similar answers loses the link to specified inference.

### Mean and variance components

With $m=50$:

$$
\bar Q=\frac{1}{m}\sum_{k=1}^m Q_k=0.126956936985662,
$$

$$
\bar U=\frac{1}{m}\sum_{k=1}^m U_k
=8.19973386655202\times10^{-5},
$$

$$
B=\frac{1}{m-1}\sum_{k=1}^m(Q_k-\bar Q)^2
=3.11028579793973\times10^{-7}.
$$

$\bar U$ represents sampling uncertainty within completed analyses; $B$ measures variation among generated missing-value proposals. Under the conditions for MI and its analysis, total variance is estimated by:

$$
T=\bar U+\left(1+\frac{1}{m}\right)B
=8.23145878169100\times10^{-5},
$$

$$
SE_{\mathrm{MI}}=\sqrt T=0.009072738716447.
$$

### Where does the sum come from?

The law of total variance provides intuition. Written across lines for readability:

$$
\begin{aligned}
\operatorname{Var}(\theta\mid Y_{\mathrm{obs}})
={}&E\!\left[\operatorname{Var}(\theta\mid Y_{\mathrm{obs}},Y_{\mathrm{mis}})\mid Y_{\mathrm{obs}}\right]\\
&+\operatorname{Var}\!\left[E(\theta\mid Y_{\mathrm{obs}},Y_{\mathrm{mis}})\mid Y_{\mathrm{obs}}\right].
\end{aligned}
$$

Uncertainty exists even with completed data, and uncertainty also concerns how data should be completed. Rubin's expression approximates their combination and adds a finite-imputation correction. This is not proof that arbitrary completed files meet MI conditions.

### Why not divide everything by 50?

All fifty datasets share the same participants and nearly all observed information. They are not fifty independent samples. Write:

$$
T=\bar U+B+\frac{B}{50}.
$$

Increasing $m$ reduces the last, Monte Carlo-related term. It does not remove original sampling uncertainty or information that was never observed.

If no data were missing, all versions would coincide and $B=0$. Then $T=\bar U$ must remain. Dividing $\bar U$ by 50 would artificially reduce the SE by $\sqrt{50}$ merely by repeating an analysis, without adding anyone.

### Variance fraction, degrees of freedom, and FMI

Define:

$$
\lambda=\frac{(1+1/m)B}{T}=0.003854106,
\qquad
r=\frac{(1+1/m)B}{\bar U}=0.003869018.
$$

Rubin's original df are:

$$
\nu_{\mathrm{old}}=\frac{m-1}{\lambda^2}\approx3{,}298{,}745.
$$

We do not treat that large number as millions of independent survey units. The finite convention uses $\nu_{\mathrm{com}}=91$:

$$
\nu_{\mathrm{obs}}=\frac{\nu_{\mathrm{com}}+1}{\nu_{\mathrm{com}}+3}\nu_{\mathrm{com}}(1-\lambda)
=88.72057,
$$

$$
\nu=\left(\frac{1}{\nu_{\mathrm{old}}}+\frac{1}{\nu_{\mathrm{obs}}}\right)^{-1}
=88.71818.
$$

Finite FMI is:

$$
\mathrm{FMI}=\frac{r+2/(\nu+3)}{r+1}=0.02557599.
$$

This is not 2.56% of participants with missing data. It differs from $\lambda$ because it includes finite-df adjustment. A small FMI also does not measure every possible missing-data bias.

### Interval and test

The coefficient interval is:

$$
\begin{aligned}
\bar Q\pm t_{0.975;\nu}\sqrt T
&=0.12695694\pm1.987066(0.00907274)\\
&=[0.1089288,\ 0.1449851].
\end{aligned}
$$

Exponentiation gives:

$$
HR_{\mathrm{MI}}=1.135368,
\qquad \mathrm{CI}_{95\%}=[1.115083,\ 1.156022].
$$

The t statistic is approximately 13.993 and the two-sided p-value $3.589\times10^{-24}$. This secondary sensitivity uses a finite t interval, while primary inference uses normal Wald intervals. Differences in p-values do not measure how much analysis “improved” after imputation.

### What independent verification actually establishes

Manual equations were compared with `mice::pool.scalar(Q,U,n=92,k=1)` [S4](https://amices.org/mice/reference/pool.scalar.html). Here $92-1=91$ supplies the chosen complete-data df: **92 is not the sample size, and 1 is not the actual number of Cox coefficients**. These are scalar df-calculation parameters.

The two implementations agreed on $\bar Q$, $T$, df, and FMI within numerical tolerance. A $B=0$ control returned $T=\bar U$ and finite df. This compares implementations using the same inputs; it is neither external replication nor MAR validation.

Estimated Monte Carlo SE of $\bar Q$ was:

$$
SE_{\mathrm{MC}}\simeq\sqrt{B/m}=0.00007887,
$$

about 0.87% of the inferential SE. This suggests small simulation noise from fifty imputations for this coefficient under the procedure; it does not measure specification bias.

## Sensitivities: a distinct question for each change {#sec-sensibilidades}

A sensitivity is informative when it changes an interpretable decision while retaining enough continuity to understand the comparison. It is not a competition for a preferred HR. Model changes must also be distinguished from population changes.

| Executed sensitivity | Question | Interpretive limit |
| --- | --- | --- |
| Exclude same-month deaths | Dependence on assigning a midpoint to zero released months | Two additional complete-case exclusions, not all four eligible cases |
| Exclude deaths through 12 months | Dependence on very early events | Does not establish absence of reverse causation |
| Exclude deaths through 24 months | Same concern over a longer window | Changes analyzed people and events |
| Exclude CRP >10 mg/L | Dependence on high concentrations | Threshold neither identifies acute infection with certainty nor proves its cause |
| Change below-detection fill value | Dependence on substitution | Does not reconstruct true unknown CRP |
| Exclude below-detection values | Dependence on those observations | Changes population and exposure range |
| Add income/poverty | Broader socioeconomic adjustment | Changes adjustment and available cases together |
| Linear age | Dependence on flexible age adjustment | Post-primary specification; does not validate linearity |
| Ignore weights, diagnostically | Dependence on weighting/design | Does not replace population inference |
| Exclude indeterminate pregnancy | Dependence on eligibility classification | Does not establish confirmed pregnancy |
| Multiple imputation | Dependence on complete cases | Conditional on models and missingness assumptions |

### Early-death exclusion is not landmark analysis

Code removes participants whose observed death occurs at or before 12 or 24 months. Other records, including shorter censoring times, remain. It does not move time zero to month 12/24 or require everyone to survive and remain observed until then.

A landmark cohort would ask another question among people reaching that point. Calling this analysis landmark would be incorrect. The literal SAP sensitivity informs concern about early events, but selection uses future outcome information and interpretation must be limited.

### Why not impute income in the principal MI sensitivity?

Income is not in the primary adjustment set. MI compares the same adjustment among complete cases and completed eligible participants. Adding income simultaneously would change two decisions and make differences harder to attribute. Income sensitivity remains separate with 24,683 cases.

### Why similar HRs do not prove absence of bias

Sensitivities retained positive associations: for example, 1.108 after excluding deaths through 24 months and 1.101 after excluding CRP >10 mg/L. MI gave 1.135 versus primary 1.130. The same-month sensitivity gave 1.129632 versus 1.129854. These compare correlated estimates descriptively; they are not equivalence tests.

A bias shared across analyses can produce similar answers. A persistently small p-value does not answer what would occur under another MNAR mechanism, measurement error, or unmeasured confounding.

## Effect modification: sex and age group {#sec-interacciones}

Both hypotheses were in the SAP; fits were completed during reconciliation on 23 October. Additional groups were not searched until a significant result appeared.

### Formula and hierarchy

For binary modifier $G$:

$$
\begin{aligned}
\log h(t\mid X,G,\mathbf{Z})
={}&\log h_0(t)+\beta X+\alpha G+\delta XG\\
&+\boldsymbol{\gamma}^{\top}\mathbf{Z}.
\end{aligned}
$$

HR per doubling is $e^\beta$ for $G=0$ and $e^{\beta+\delta}$ for $G=1$, with ratio $e^\delta$. The interaction tests $\delta=0$, not whether each HR separately has p <0.05.

Sex already had a main effect. The age model added a 65+ indicator **without removing the age spline**, plus its interaction. The group main effect preserves hierarchy and permits a discontinuity in that secondary model; the threshold is not treated as a biological transition.

### Contrast covariance

For $G=1$:

$$
\operatorname{Var}(\widehat\beta+\widehat\delta)
=V_{\beta\beta}+V_{\delta\delta}+2V_{\beta\delta}.
$$

SEs are not added, and coefficients from one fit are not assumed independent. Code verifies the result using both a matrix contrast and this identity.

### Results and cautions

| Group | HR per doubling | Normal 95% CI |
| --- | ---: | --- |
| Male | 1.143 | 1.117–1.170 |
| Female | 1.115 | 1.076–1.155 |
| Age 20–64 | 1.164 | 1.126–1.202 |
| Age ≥65 | 1.108 | 1.083–1.134 |

Sex interaction: F(1,66)=1.167, p=0.284. Age interaction: F(1,65)=5.575, p=0.021. Older/younger HR ratio was 0.9523; female/male ratio was 0.9753.

Multiplicative interaction does not establish modification on an absolute-risk scale. Limited sex evidence does not prove equivalence. Age interaction establishes neither causality nor constant differences over all concentrations and times: these models still summarize linear CRP with constant coefficients. Secondary multiplicity and implementation timing are disclosed.

## Influence: local stability without deleting people {#sec-influencia}

DFBETA approximates observations' local coefficient contributions through score and information. Conceptually:

$$
\mathbf{d}_i\simeq A^{-1}\mathbf{s}_i,
$$

subject to the implementation's weighting and sign conventions. This expression is not an exact difference between models with and without a participant. Weighted residuals came from the saved model and were aggregated by PSU; sums were independently checked.

Normalization was $|d_{i,\mathrm{CRP}}|/SE_{\mathrm{design}}(\widehat\beta)$. Maxima were 0.147 design SE per participant and 0.243 per PSU. This describes local estimate concentration. No retrospective exclusion threshold or repeated deletion search was used to stabilize a p-value.

DFBETA uses partial model information, with design SE as a comparison scale. It is not a new survey test or a remedy for erroneous observations, confounding, or bias. Contributions summing near zero are compatible with a solved estimating equation, not proof that every datum is correct.

## Reading results and limitations together {#sec-lectura-conjunta}

Primary and sensitivity estimates are positive, and MI is nearby. This supports a description of adjusted association relatively stable under the examined decisions. It does not establish invariance under every possible decision.

At the same time, the concentration relationship is not strictly log2-linear and the coefficient changes across periods. The correct account retains both: prognostic association is present in the analyses, while one HR has limited representational scope.

Beyond interval-based sampling uncertainty, there is uncertainty about one-time measurement, selection, linkage quality, adjustment models, missingness, and multiple secondary analyses. These are not all quantified by an additional variance already included in a table.

Estimator precision is different from causal accuracy. Reproducible code is different from valid assumptions. Making these distinctions understandable is the purpose of this manuscript.

## Decision matrix for reviewing the rationale {#sec-matriz}

| Decision | Reason in this project | Relevant alternative | Verified / still open |
| --- | --- | --- | --- |
| Adults with CRP and linkage | Available population and baseline exposure | Different population or measurement | Flow and IDs; conditional generalizability |
| Exclude confirmed pregnancy | Question comparability | Include and model separately | Counts; no inference for pregnant people |
| Log2 CRP | Interpretable relative contrasts | Linear mg/L, categories, spline | Spline identifies limits of the summary |
| Efron | Grouped follow-up and fixed rule | Breslow, exact | Valid execution; unknown intramonth ordering |
| Follow-up from examination | Risk window after measurement | Attained age as time | Rule reproduced; alternative not tested here |
| Flexible age | Avoid a rigid global line | Linear age or categories | Fixed knots and linear sensitivity |
| Pooled MEC weights | Match design and cycles | Ignore design | Formula and IDs; no universal selection correction |
| Primary complete cases | Transparent frozen rule | MI as primary | 96.62% retained; bias not excluded |
| MI sensitivity | Examine missing primary covariates | Explicit MNAR or other models | Integrity/mixing; MAR/calibration unproved |
| PMM with five donors | Support plausibility and variation | Continuous normal or other donor count | Actual donors; extremes remain relevant |
| Nominal categories | Avoid extra ordinal restrictions | `polr` with additional assumptions | No opportunistic merging; sparse-level uncertainty |
| Unweighted hazard auxiliary | Approximate survival information | Weighted auxiliary or joint model | Construction verified; approximate compatibility |
| Fixed design effects in MI | Represent clustering without redundancy | Multilevel or other specification | Rank; rare-category stability not guaranteed |
| Fifty chains / twenty iterations | SAP and diagnostic review | More chains or 40/60 iterations | Small Monte Carlo error; no universal convergence proof |
| Four workers | Speed within measured RAM | Sequential or more processes | Equality under fixed streams; ten not admitted |
| Finite Rubin with df 91 | Explicit finite sensitivity convention | Asymptotic df or other inference | Implementations agree; coverage not guaranteed |
| Four temporal periods | Declared feasible replacement | Original log-time interaction | 180 replicates; another approximation to variation |
| Separate interactions | Secondary SAP hypotheses | Other subgroups | Two planned tests; neither causality nor equivalence |
| Same-month-death sensitivity | Amendment 001 commitment | Midpoint alone | Completed: two applicable complete-case deaths removed; HR change −0.01965% |

## Questions to check understanding {#sec-preguntas}

Try answering before reading the next section.

1. Why is HR 1.13 not a 13-percentage-point increase in mortality?
2. How can a model have a highly variable baseline hazard while satisfying proportional hazards?
3. What distinguishes survey strata from `strata()` within Cox?
4. What restrictions follow from one linear log2(CRP) coefficient?
5. Why does a spline alone not solve an association that changes with time?
6. Are fifty imputations with twenty iterations each a thousand independent samples?
7. Why does including death during imputation prevent unchanged reuse for prediction in a new patient?
8. How does a missingness mask differ from predictor selection?
9. How can two groups have individually significant HRs but no significant interaction?
10. What is lost by omitting covariance when adding main and interaction coefficients?
11. Why do we not divide all Rubin variance by fifty?
12. What does comparing manual equations with `pool.scalar` establish, and what does it not?
13. Why need imputed distributions not copy observed marginal distributions?
14. Why do lower RAM usage or additional iterations not verify MAR?
15. Which specific sensitivity is not isolated by excluding all deaths through 12/24 months, and why did it remove only two primary participants?

## Reasoned answers {#sec-respuestas}

**1.** Hazard is an instantaneous rate among people still at risk. Cumulative probability also depends on baseline survival, time, and covariates. A relative rate contrast is not an absolute probability difference.

**2.** Proportional hazards restricts hazard ratios conditional on covariates, not the shape of $h_0(t)$. Baseline hazard can rise or fall while ratios remain constant.

**3.** Survey strata describe sample selection and inform design/variance estimation. Cox strata define separate baseline hazards. They are not interchangeable instructions.

**4.** Every doubling has the same log-hazard change: 1→2 and 4→8 share an HR. A spline lets that change depend on location along the concentration curve.

**5.** Constant-coefficient splines provide concentration flexibility, not time flexibility. The dimensions must be distinguished.

**6.** No. There are fifty completed versions of the same people. Twenty passes per chain construct and diagnose those versions; intermediate steps are not new studies.

**7.** Retrospective inference seeks to preserve relationships with observed outcomes. Future prediction cannot use outcomes not yet known. Available information and the statistical task differ.

**8.** The mask identifies cells allowed to change; the matrix identifies predictors for each target. A fixed predictor can help without being imputed.

**9.** Tests against HR=1 and tests of equality between HRs ask different questions. Interaction evaluates their contrast with the appropriate covariance and inferential reference.

**10.** Coefficients are estimated jointly. Omitting $2V_{\beta\delta}$ can incorrectly increase or decrease variance. It is not universally conservative.

**11.** Repeated proposals for missing values add no new participants. $B/50$ is a finite-simulation correction; $\bar U$ and missing-data uncertainty remain.

**12.** It checks scalar programming agreement with the same inputs. It does not independently establish MAR, the generating algorithm, or causal validity of Cox regression.

**13.** Incomplete people have different known profiles. Enforcing marginal equality may erase structure. Conversely, an explainable difference does not prove conditional calibration.

**14.** Resources and computational mixing concern execution. MAR concerns observation dependence on values we do not see. More CPU or longer traces cannot verify it.

**15.** Excluding only deaths originally coded at zero months before the 0.5-month assignment isolates the midpoint convention. Four occurred among eligible people, but only two were complete cases. That specific analysis is now completed; broad early-death exclusions do not isolate the same perturbation.

## Minimal glossary {#sec-glosario}

| Term | Operational meaning here |
| --- | --- |
| Estimand | Scientific quantity the analysis intends to describe |
| Estimator | Rule mapping data to an estimate |
| Hazard | Instantaneous event rate conditional on remaining at risk |
| HR | Model hazard ratio, not a universal probability ratio |
| Risk set | People still observed and event-free immediately before a time |
| Censoring | Observation ends without a later event observed within the window |
| Residual confounding | Associative structure not completely controlled by adjustment |
| Noncollapsibility | Conditional measure can change after adjustment without every change representing confounding |
| Spline | Flexible function built from bases and knot restrictions |
| PSU | Primary sampling unit within the design |
| Sandwich | Matrix structure for robust/design covariance estimation |
| JKn | Survey jackknife with strata/PSU-adapted replicates |
| MAR | No additional dependence on unknown values conditional on observed information |
| MICE | Sequential updates of conditional missing-data models |
| PMM | Predictive matching and sampling an observed donor value |
| RNG stream | Random sequence reproducibly assigned to a chain |
| Checkpoint | Saved state sufficient for continuation without restarting the random experiment |
| Pooling | Combining estimates and variances, not concatenating rows |
| FMI | Inferential missing-information measure, not percentage of incomplete records |
| DFBETA | Local approximation of coefficient influence |

## Map to sources and code {#sec-fuentes}

### Project documents

- [Protocol v0.3](../../protocol/protocol_v0.3.qmd) and [SAP v0.3](../../protocol/sap_v0.3.qmd).
- [Amendment 001](../../protocol/amendments/001_zero_followup_time.qmd), [Amendment 002](../../protocol/amendments/amendment_002_time_varying_crp.md), and [Amendment 003](../../protocol/amendments/amendment_003_alternative_age_specification.md).
- [CRP audit](../../docs/audits/crp_cycle_audit.md), [eligibility and codes](../../docs/audits/eligibility_category_audit.md), and [MI specification, Sections 7–8](../../docs/methods/multiple_imputation_technical_spec_draft.md).
- [Iteration-20 decision](../../docs/methods/analysis_execution_stage5_real_imputation_review_020.md), [MI completion](../../docs/methods/analysis_execution_stage5_completed.md), and [Stage 6 reconciliation](../../docs/methods/analysis_execution_stage6_sap_reconciliation.md).
- [Current scientific draft](../stage6_v2/manuscript_methods_results.md), [working reporting checklist](../stage6_v1/reporting_checklist_working.md), and [same-month-death sensitivity](../same_month_death_sensitivity_v1/README.md).

### Where to verify a decision

| Topic | Implementation |
| --- | --- |
| Cohort and time | [Script 04](../../src/R/04_build_analysis_cohort.R) |
| Weights, bases, summaries, and Wald tests | [Analysis helpers](../../src/R/00_functions_analysis.R) |
| Primary model | [Script 06](../../src/R/06_fit_primary_cox_models.R) |
| CRP spline | [Script 07](../../src/R/07_fit_crp_spline.R) |
| Auxiliary Schoenfeld | [Script 08](../../src/R/08_auxiliary_schoenfeld_diagnostics.R) |
| Periods and JKn | [Script 09](../../src/R/09_design_based_time_interaction.R) |
| Sensitivities | [Script 10](../../src/R/10_sensitivity_analyses.R), [Script 11](../../src/R/11_alternative_age_sensitivity.R), and [Script 22](../../src/R/22_sensitivity_same_month_deaths.R) |
| MI and supervisor | [Script 14](../../src/R/14_prepare_run_multiple_imputation.R) and [supervisor](../../src/R/14_run_multiple_imputation.py) |
| MI fits and Rubin pooling | [Script 15](../../src/R/15_fit_multiple_imputation_sensitivity.R) |
| Secondary interactions | [Script 16](../../src/R/16_secondary_effect_modification.R) |
| Influence | [Script 17](../../src/R/17_primary_influence_diagnostics.R) |

### External methodological references consulted for the original companion

**S1.** NCHS, [NHANES Weighting Tutorial](https://wwwn.cdc.gov/nchs/nhanes/tutorials/weighting.aspx), supports weight choice and construction. Specific counts and checks come from the project.

**S2.** survival package, [`coxph` documentation](https://www.stat.ethz.ch/R-manual/R-devel/library/survival/html/coxph.html), covers ties, weights, start–stop data, and fitting/variance distinctions. Online documentation may describe a different version; project checks use recorded versions.

**S3.** MICE, [`mice.impute.polyreg` documentation](https://amices.org/mice/reference/mice.impute.polyreg.html), was compared with functions **installed in 3.19.0**. A general description did not replace inspection of that implementation.

**S4.** MICE, [`pool.scalar` documentation](https://amices.org/mice/reference/pool.scalar.html), describes scalar pooling and Barnard–Rubin inputs and outputs. Equations and numbers were checked against Script 15 and saved results.

For further reading, `references.bib` includes Kleinbaum and Klein's *Survival Analysis*, Therneau and Grambsch's *Modeling Survival Data*, and Harrell's *Regression Modeling Strategies*. No direct quotations or unconsulted book page references are attributed in this companion. This language/rendering revision adds no new literature claims.

## Status of this alternative manuscript {#sec-estado}

This document explains decisions and their limits. It is not a new SAP freeze or proof that every methodological concern is resolved. The specific Amendment 001 sensitivity is now completed and linked above. MI calibration and compatibility remain interpretive limitations rather than established assumptions.

This revision changes explanatory language, notation, and rendering, not participant data, imputations, or model estimates. Historical validation reports describe the source versions they checked; documentation changes are separately recorded rather than concealed by editing their manifests. Publication still requires the scientific draft's remaining supplements and author decisions. The immediate aim is to make questions traceable to a specific section and verifiable implementation.
