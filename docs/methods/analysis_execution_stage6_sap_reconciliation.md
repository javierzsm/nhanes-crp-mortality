# Stage 6: reporting reconciliation and outstanding SAP analyses

Date: 23 October 2026. The investigator requested resumption and further progress.
The frozen SAP v0.3 was re-read against actual saved outputs before drafting a
manuscript. Stage 5 is complete, but two separate prespecified secondary
interaction analyses and influence diagnostics had no recorded implementation.
Earlier project handoff text did not identify these gaps. Do not describe the
whole SAP as complete merely because primary and sensitivity analyses finished.

## Implementation choices recorded before new estimates

The SAP explicitly names sex and age group (20–64 versus 65+) as separate
secondary effect modifiers. Use the original complete-case cohort, age knots,
primary adjustment set, survey weights/strata/nested PSUs and Efron ties.
Fit two independent extensions of the primary formula:

1. Add `log2_crp:sex`; sex main effects already exist in the primary model.
2. Add `age_group` and `log2_crp:age_group`, with age_group = 20–64 or 65+.
   Retain the original continuous-age spline; the additional group main effect
   maintains interaction hierarchy and permits a discontinuity at age 65 in
   this secondary working model. Do not replace age adjustment by a binary term.

Use `survey::regTermTest(..., method="Wald")` for each interaction with its
model-residual denominator df, following the existing spline Wald-test helper.
Report the test df explicitly; do not assume denominator df equals design df.
Compute each group's log-HR by a linear contrast of the same interaction model
and its design covariance. Use asymptotic normal 95% intervals, as in the primary
model. Also report the between-group ratio of HRs and interval. No new cutpoint,
subgroup, screening or multiplicity-driven selection is introduced. These are
secondary tests without a general multiplicity correction under the frozen SAP.
Known nonlinearity/time variation means these linear constant-coefficient
subgroup summaries do not establish modification across all CRP/time values.
The hypotheses are pre-outcome; these implementation details are recorded after
other study results became available, before these interaction estimates.

For influence, inspect the saved primary model's weighted case-deletion
linearization (`residuals(...,type="dfbeta",weighted=TRUE)`) and its sum within
each nested PSU. Standardize the CRP component by the original design-based SE
for descriptive comparison. These are first-order diagnostics, not exact
participant/PSU deletion refits or design-adjusted hypothesis tests. Do not
exclude observations, change the model or define a pass/fail cutoff from these
diagnostics. Record approximate concentration and tail summaries; omit person
identifiers from publication-facing summaries. Check row alignment and agreement
of grouped residuals with independently aggregated individual residuals.

Reference for residual definitions and weighted/collapse arguments:
[official survival documentation](https://www.stat.ethz.ch/R-manual/R-devel/library/survival/html/residuals.coxph.html).
All original datasets, checkpoints, estimates and frozen protocol/SAP documents
remain unchanged. Publication reporting/checklists will distinguish completed
work from outstanding narrative, metadata and author decisions.
