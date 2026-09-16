# Analysis execution, stage 1

## Scope

This stage converts the validated complete-case cohort into a complex survey
design, records the prespecified spline knots and fits the demographic and
primary Cox models. It does not yet fit the CRP spline, test proportional
hazards, evaluate interactions or run sensitivity analyses.

## Execution order

1. `04_build_analysis_cohort.R` constructs the mortality-linked cohorts.
2. `05_describe_survey_cohort.R` audits the design, generates weighted
   descriptive statistics and records survey-weighted spline knots.
3. `06_fit_primary_cox_models.R` fits the demographic and primary models using
   the recorded age knots.

The order is enforced through local RDS data contracts. Script 06 stops if the
cohort does not match the participant and death counts stored by script 05.

## Conceptually major decisions

- NHANES strata, primary sampling units and pooled MEC weights define the
  analysis design.
- Age is adjusted using a restricted cubic spline represented as a natural
  cubic spline with boundary knots at weighted percentiles 5 and 95 and
  internal knots at weighted percentiles 35 and 65.
- The primary CRP coefficient is the log hazard ratio associated with a
  one-unit increase in `log2(CRP)`, therefore its exponent is the hazard ratio
  per doubling of CRP.
- Covariates are prespecified. No variable screening or model selection is
  performed.

## Routine RWE implementation

- verify participant identifiers and frozen cohort counts;
- reject missing or invalid design variables;
- confirm that every sampling stratum contains at least two primary sampling
  units in the analytic cohort;
- save machine-readable QC tables and model objects;
- stop when coefficients or design-based variances are non-finite.

## Deferred analyses

CRP spline estimation, nonlinearity tests, proportional-hazards diagnostics,
effect modification, multiple imputation and other sensitivity analyses will
be implemented only after stage 1 outputs have been reviewed.
