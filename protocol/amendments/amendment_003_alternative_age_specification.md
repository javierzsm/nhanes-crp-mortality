# Amendment 003
## Alternative age specification for sensitivity analysis

**Study:** Baseline CRP and all-cause mortality in NHANES 1999–2010, linked through 2019
**Affected plan:** Frozen SAP v0.3
**Date:** 27 September 2026
**Status:** Post-primary-analysis specification, established before executing the alternative-age sensitivity

### 1. Background and timing

The frozen SAP lists an alternative age specification as a sensitivity analysis but does not define its functional form. The primary model adjusts for age using three natural cubic spline basis terms, with survey-weighted knot locations frozen before outcome modeling.

The primary analysis, the time-varying CRP analysis, and the initial sensitivity analyses have already been completed and examined. Consequently, this amendment is **not** described as a pre-outcome decision. It records the single alternative age specification chosen before its implementation, execution, or inspection of its estimate.

### 2. Alternative model

Replace the three age-spline basis terms (`age_rcs1`, `age_rcs2`, `age_rcs3`) with **one continuous linear age term (`age`, in years)** on the Cox model's log-hazard scale. Leave the exposure and every other covariate unchanged.

The alternative model formula is:

```r
survival::Surv(follow_up_months, death) ~
  log2_crp + age +
  sex + race_hispanic_origin + cycle +
  education + smoking + bmi +
  diabetes + hypertension + prevalent_cvd
```

Use `survey::svycoxph()` with the same NHANES pooled MEC weights, strata, nested PSUs, and Efron handling of ties as the primary model. This more restrictive age specification is a sensitivity test of the CRP estimate, not an assumption that the biological effect of age is genuinely linear.

### 3. Elements unchanged

Use the validated primary complete-case cohort (expected: **26,818 participants and 5,886 observed deaths**). Do not change the exposure definition (`log2(CRP in mg/L)`), mortality outcome, time origin or follow-up, survey design, or any covariates other than the functional form of age. The primary model and its frozen age knots remain intact.

### 4. Planned comparison

Report the alternative model's adjusted CRP hazard ratio per doubling, its 95% confidence interval, and the difference in the CRP log-hazard-ratio coefficient relative to the primary model (with the corresponding ratio of HRs). This comparison is descriptive; no significance-driven selection or post hoc equivalence threshold will be used. The primary model remains the principal analysis regardless of the alternative estimate.

This sensitivity does not reassess the CRP-by-follow-up-period interaction reported in Stage 3.

### 5. Validation

Before interpreting the new result:

1. Reproduce the saved primary CRP coefficient using the existing Script 10 reproducibility check.
2. Verify that the alternative model includes exactly one linear age term and no age-spline basis terms.
3. Verify that participant and event counts match the primary reference, and that survey design degrees of freedom remain valid.
4. Verify finite model coefficients, variance estimates, CRP standard error, HR, and 95% confidence interval.
5. Preserve the previously validated sensitivity results; record this result and update the deferred-analysis register in a traceable manner.

The implementation, QC, and results will be described in a subsequent update to `docs/methods/analysis_execution_stage4.md`.

### 6. Transparency and version control

Commit this amendment **before executing** the alternative-age model. Do not retrospectively modify frozen SAP v0.3. When reporting the study, disclose that the alternative age form was selected after inspection of previous outcome analyses but before this particular sensitivity was run. The analysis remains prognostic, observational, and non-causal.
