# Analysis execution, stage 4

## Purpose

Script 10 evaluates the robustness of the prespecified primary linear
association between baseline `log2(CRP)` and all-cause mortality under the
sensitivity analyses defined in the frozen SAP.

The primary estimand remains the adjusted prognostic hazard ratio for
all-cause mortality per doubling of baseline CRP. These analyses are
secondary and do not replace either the primary model or the Stage 3
assessment of time variation in the CRP association.

Eight prespecified sensitivity analyses are implemented in this stage:

1. exclude deaths within 12 months;
2. exclude deaths within 24 months;
3. exclude CRP greater than 10 mg/L;
4. replace below-detection CRP with 0.02 mg/dL;
5. exclude below-detection CRP observations;
6. add family income-to-poverty ratio;
7. compare weighted and unweighted estimates as a diagnostic;
8. exclude participants aged 20 to 44 years with indeterminate pregnancy
   status.

Two additional SAP sensitivities are not implemented in Script 10:

- multiple imputation for missing covariates, which requires a dedicated
  imputation workflow;
- an alternative age specification, because the frozen SAP does not define
  the alternative functional form and it must not be selected after viewing
  the outcome results.

## Reference model

All survey-weighted sensitivity analyses use the same primary Cox model
specification as Script 06:

```math
h_i(t)=h_0(t)\exp\{
\beta_{CRP}\log_2(CRP_i)
+f(age_i)
+\boldsymbol{\gamma}^{T}\mathbf{Z}_i
\}.
```

The adjustment set is unchanged:

- restricted cubic spline for age using the frozen age knots;
- sex;
- race and Hispanic origin;
- NHANES cycle;
- educational attainment;
- smoking status;
- body mass index;
- diabetes;
- hypertension;
- prevalent cardiovascular disease.

The income sensitivity adds family income-to-poverty ratio to this model.

Before any sensitivity analysis is interpreted, Script 10 refits the primary
model and verifies that the `log2_crp` coefficient reproduces the coefficient
saved by Script 06 within a numerical tolerance of `1e-10`.

## Survey design handling

The primary complete-case cohort is used to construct the validated NHANES
survey design with pooled MEC weights, `SDMVSTRA` and `SDMVPSU`.

Sensitivity analyses that exclude participants are implemented by subsetting
the existing survey-design object rather than reconstructing a new design
after each exclusion.

The survey-weighted analyses therefore preserve the original design structure
while restricting the analytic population.

The unweighted comparison is intentionally fitted with a conventional Cox
model and is treated only as a diagnostic. It is not used for population-level
inference.

## Early-death exclusions

The SAP specifies exclusion of deaths within 12 months and within 24 months.

Script 10 implements this wording literally: participants whose observed death
occurred at or before the specified time are excluded, while all other
participants are retained.

This is not a landmark analysis and does not exclude otherwise eligible
participants merely because their observed follow-up is shorter than the
specified threshold.

## High-CRP exclusion

Participants with baseline CRP greater than 10 mg/L are excluded using the
indicator created during cohort construction.

The CRP transformation and all other model terms remain unchanged.

This sensitivity evaluates whether the primary linear association is strongly
dependent on participants with high baseline CRP values.

## Below-detection CRP handling

The released NHANES CRP data contain observations represented by the
below-detection fill value of 0.01 mg/dL.

Two prespecified sensitivity analyses are performed.

First, these observations are reassigned to 0.02 mg/dL, equivalent to
0.2 mg/L, and `log2(CRP)` is recalculated for those observations only.

Second, observations identified as below-detection are excluded entirely.

No other CRP values are modified.

## Income-to-poverty ratio

The income sensitivity adds family income-to-poverty ratio to the primary
adjustment model and restricts the analysis to participants with complete
income data.

The expected sample size was frozen before outcome modeling:

- participants with complete primary covariates and income-to-poverty ratio:
  24,683.

Script 10 stops if the observed income-sensitivity cohort does not reproduce
this count.

Because this sensitivity changes both the adjustment set and the complete-case
population, any change in the CRP estimate reflects the combination of these
two differences.

## Unweighted diagnostic

The unweighted diagnostic uses the same cohort, time scale, exposure and
covariate specification as the primary model but fits a conventional
unweighted Cox regression.

The purpose is to evaluate how much the CRP estimate changes when NHANES
sampling weights and design-based variance estimation are ignored.

The survey-weighted model remains the inferential model.

## Indeterminate pregnancy status

The primary cohort excludes confirmed pregnancy but retains participants aged
20 to 44 years with indeterminate pregnancy status, as specified in the frozen
SAP.

The corresponding sensitivity analysis excludes these participants and refits
the primary survey-weighted model.

## Validation requirements

Before interpretation, the following controls must be verified:

- the reference model contains 26,818 participants and 5,886 deaths;
- the reference-model CRP coefficient reproduces the saved Script 06 result;
- all expected sensitivity analyses complete successfully;
- the income sensitivity contains exactly 24,683 participants;
- all fitted CRP coefficients are finite;
- all standard errors are finite;
- all confidence-interval limits are finite;
- participant and death counts change in the expected direction after each
  exclusion;
- survey-weighted models retain valid design degrees of freedom.

Results must not be interpreted until these checks have been reviewed.

## Execution and validation

Script 10 executed successfully.

Observed validation results were:

- primary reference: 26,818 participants and 5,886 deaths;
- exclude deaths within 12 months: 26,575 participants and 5,643 deaths;
- exclude deaths within 24 months: 26,251 participants and 5,319 deaths;
- exclude CRP greater than 10 mg/L: 24,037 participants and 5,032 deaths;
- replace below-detection CRP with 0.02 mg/dL: 26,818 participants and
  5,886 deaths;
- exclude below-detection CRP: 26,158 participants and 5,823 deaths;
- add family income-to-poverty ratio: 24,683 participants and 5,348 deaths;
- unweighted diagnostic: 26,818 participants and 5,886 deaths;
- exclude indeterminate pregnancy status among ages 20 to 44:
  26,638 participants and 5,880 deaths.

All fitted CRP coefficients, standard errors and confidence intervals were
finite.

All survey-weighted sensitivity analyses retained 91 survey design degrees of
freedom.

## Sensitivity-analysis results

The primary reference estimate was:

```math
HR=1.1299
\quad
(95\%\ CI\ 1.1088\text{ to }1.1513).
```

Sensitivity estimates were:

- exclude deaths within 12 months:
  HR 1.1164, 95% CI 1.0950 to 1.1381;
- exclude deaths within 24 months:
  HR 1.1081, 95% CI 1.0863 to 1.1304;
- exclude CRP greater than 10 mg/L:
  HR 1.1009, 95% CI 1.0731 to 1.1295;
- replace below-detection CRP with 0.02 mg/dL:
  HR 1.1336, 95% CI 1.1125 to 1.1551;
- exclude below-detection CRP:
  HR 1.1406, 95% CI 1.1193 to 1.1623;
- add family income-to-poverty ratio:
  HR 1.1209, 95% CI 1.0993 to 1.1429;
- unweighted diagnostic:
  HR 1.1170, 95% CI 1.0992 to 1.1352;
- exclude indeterminate pregnancy status among ages 20 to 44:
  HR 1.1295, 95% CI 1.1085 to 1.1508.

The direction of the CRP association remained positive across all completed
sensitivity analyses.

The largest attenuation of the linear summary occurred after excluding CRP
greater than 10 mg/L, followed by exclusion of deaths within the first
24 months.

Alternative handling of below-detection CRP produced only modest changes in
the estimated association.

Adding family income-to-poverty ratio, ignoring survey weighting as a
diagnostic, and excluding indeterminate pregnancy status did not materially
alter the direction of the association.

These results should be interpreted as robustness checks of the overall
linear summary. They do not override the Stage 3 finding that the magnitude of
the CRP association varies across follow-up periods.

## Additional sensitivity: alternative age specification (Script 11)

Amendment 003 specifies the alternative age model after the primary results
and the initial sensitivity results became available, but before the
alternative-age analysis was run. It does not retrospectively change the
frozen SAP v0.3 or claim that linear age was selected before outcome review.

Script 11 replaces the three age-spline basis terms used in the primary model
with a single continuous linear term for age in years. The study population,
baseline `log2(CRP)` exposure, outcome, follow-up, all other adjustment
variables, Efron handling of ties, pooled MEC weights, strata and nested PSUs
remain identical to the primary analysis. This model is a sensitivity
analysis, not a replacement for the primary specification or evidence that
the age–log-hazard relationship is linear.

### Validation and observed results

The Script 11 QC outputs were reviewed before interpretation:

- Amendment 003 was present;
- the saved primary CRP coefficient was reproduced;
- both models used 26,818 participants and 5,886 observed deaths;
- survey design degrees of freedom were 91;
- the alternative model contained linear age and no age-spline terms;
- coefficients and covariance estimates were finite.

| Model | HR per doubling of CRP | 95% CI |
| --- | ---: | ---: |
| Primary reference: spline age | 1.1299 | 1.1088–1.1513 |
| Sensitivity: linear age | 1.1259 | 1.1054–1.1468 |

The linear-age model estimated a CRP log-hazard ratio of 0.1185804
(standard error 0.0093827). Relative to the primary log-hazard ratio,
the difference was -0.0035079 and the ratio of HRs was 0.9964982.

The alternative age specification produced a very similar estimated overall
CRP association. This descriptive comparison does not establish equivalence,
validate linearity of age, or supersede the Stage 3 finding of time variation
in the CRP association. Its post-primary-analysis specification must be
disclosed in study reporting.

### Script 11 outputs

- `src/R/11_alternative_age_sensitivity.R`
- `output/tables/table_07_alternative_age_sensitivity.csv`
- `output/tables/qc_11_alternative_age_sensitivity.csv`
- `data/processed/alternative_age_sensitivity_models.rds`
- `protocol/amendments/amendment_003_alternative_age_specification.md`

## Remaining sensitivity analysis: multiple imputation

The frozen SAP's 50-dataset multiple-imputation sensitivity remains pending.
It requires an independently validated imputation model, survey-weighted Cox
models within each imputed dataset, and pooling under Rubin's rules.

The `qc_10_deferred_sensitivities.csv` file was generated by Script 10 before
Script 11 and is retained as a historical output. Its designation of the
alternative age sensitivity as deferred describes the status **at the time
Script 10 ran**; Script 11 completed that analysis separately.

## Outputs

Script 10 produces:

- `data/processed/sensitivity_analysis_models.rds`
- `output/tables/table_06_sensitivity_analyses.csv`
- `output/tables/qc_10_sensitivity_analyses.csv`
- `output/tables/qc_10_deferred_sensitivities.csv`

Its implementation is `src/R/10_sensitivity_analyses.R`. Script 11 produces
the additional, independent files identified above. Existing Script 10
results are preserved without modification.
