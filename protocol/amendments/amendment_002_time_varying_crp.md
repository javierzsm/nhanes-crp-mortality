# Amendment 002
## Replacement of the continuous CRP-by-log-time interaction by prespecified follow-up periods

**Study:** NHANES CRP and all-cause mortality, 1999–2010 with mortality follow-up through 2019  
**Protocol/SAP version affected:** v0.3  
**Date:** 17 September 2026  
**Status:** Prospective amendment before execution of the amended analysis

### 1. Background

The prespecified analysis plan evaluates the prognostic association between baseline C-reactive protein (CRP) and all-cause mortality using survey-weighted Cox proportional hazards models that account for the complex NHANES sampling design.

The primary exposure is `log2(CRP mg/L)`, so hazard ratios are interpreted per doubling of baseline CRP.

Supportive Schoenfeld residual diagnostics subsequently indicated evidence compatible with non-proportional hazards for CRP and for the model globally. As prespecified, a design-based assessment of the proportional-hazards assumption was therefore initiated using an interaction between baseline `log2(CRP)` and log follow-up time.

### 2. Original planned analysis

The originally planned design-based time-interaction analysis specified a Cox model containing:

`log2(CRP) × log(follow-up time)`

with inference accounting for the NHANES complex survey design through JKn replicate weights.

The intended implementation used `survival::coxph()` with the `tt()` mechanism to represent the time-varying CRP coefficient, with JKn replicate estimates used to obtain design-based variance estimates.

### 3. Reason for amendment

The planned implementation was found to be computationally infeasible in the available analysis environment.

Use of `coxph()` with `tt()` requires internal expansion of the risk-set data across event times. With the present analytic cohort and covariate structure, a single model fit produced excessive memory consumption and exhausted the available system memory before completion.

Because the complete design-based analysis would require repeating this model across approximately 180 JKn replicates, continuation with this implementation was considered impracticable. Parallelization was not considered an appropriate solution because it would further increase peak memory requirements.

No estimate from the planned `CRP × log(time)` design-based model was successfully obtained.

This amendment is therefore motivated by computational feasibility and not by the magnitude, direction or statistical significance of the results from the replacement analysis.

### 4. Amended analysis

The continuous `CRP × log(time)` interaction will be replaced by a piecewise time-varying association.

Follow-up will be divided into four prespecified periods:

- 0 to 5 years
- more than 5 to 10 years
- more than 10 to 15 years
- more than 15 years

Participant follow-up will be represented in counting-process form, with each participant contributing one record for each period during which that participant remains under observation.

A separate coefficient for `log2(CRP)` will be estimated within each follow-up period. All other covariates from the primary adjusted model will remain unchanged.

The resulting period-specific hazard ratios will therefore represent the adjusted association with all-cause mortality per doubling of baseline CRP within each follow-up interval.

### 5. Test of time-varying association

The primary inferential test for this analysis will be a global design-based test of the null hypothesis:

**H0:** the CRP log-hazard-ratio coefficient is equal across all four follow-up periods.

With four period-specific CRP coefficients, the global interaction test has three numerator degrees of freedom.

Rejection of this null hypothesis will be interpreted as evidence that the prognostic association between baseline CRP and all-cause mortality varies across follow-up periods.

Period-specific hazard ratios and 95% confidence intervals will be reported irrespective of the result of the global interaction test, but interpretation will emphasize the global test rather than separate period-specific significance tests.

### 6. Complex survey design and variance estimation

The analysis will continue to respect the NHANES complex sampling design.

The original pooled MEC weights, strata and PSU identifiers will be used to construct the survey design. JKn replicate weights will then be generated from this design.

The Cox model will be fitted once using the full-sample weights and subsequently once for each JKn replicate. Replicate fits will be processed sequentially rather than in parallel.

The covariance matrix of the model coefficients will be estimated from the JKn replicate estimates and used for:

- period-specific CRP confidence intervals;
- period-specific descriptive Wald tests;
- the global three-degree-of-freedom test of the CRP-by-follow-up-period interaction.

### 7. Computational safeguards

To reduce memory requirements and permit recovery from interrupted runs:

- the follow-up split will create a maximum of four records per participant rather than expanding observations across individual event times;
- JKn replicates will be processed sequentially;
- replicate coefficients will be saved after each completed replicate;
- execution will be resumable from the latest valid checkpoint;
- no parallel processing will be used.

### 8. Elements unchanged by this amendment

This amendment does not modify:

- the study population;
- the primary complete-case cohort;
- the exposure definition;
- the outcome definition;
- the follow-up origin or censoring rules;
- the NHANES pooled MEC weights;
- strata or PSU definitions;
- the primary adjustment set;
- the age spline specification;
- the interpretation of the analysis as prognostic and associational rather than causal;
- the previously documented Amendment 001 concerning deaths with published follow-up equal to zero.

### 9. Interpretation

The amended analysis evaluates whether the adjusted prognostic association between baseline CRP and subsequent all-cause mortality differs across broad periods of follow-up.

The period boundaries are used as an interpretable and computationally tractable representation of possible time variation. They should not be interpreted as biological thresholds or as evidence that the underlying association changes discontinuously at exactly 5, 10 or 15 years.

The analysis remains observational and does not estimate a causal effect of CRP on mortality.

### 10. Timing of the amendment

This amendment was defined after the supportive Schoenfeld diagnostics and after the computational failure of the originally planned `CRP × log(time)` implementation.

The replacement piecewise analysis, including its four follow-up periods and global interaction test, was specified before execution of the amended model and before inspection of any estimates produced by that model.
