# Analysis execution, stage 3

## Purpose

Script 09 evaluates whether the prognostic association between baseline
`log2(CRP)` and all-cause mortality varies across follow-up time.

Following Amendment 002, the originally planned continuous CRP-by-log-time
interaction was replaced by a piecewise time-varying analysis using four
prespecified follow-up periods:

- 0 to 5 years
- more than 5 to 10 years
- more than 10 to 15 years
- more than 15 years

The analysis remains survey-weighted, prognostic and non-causal.

The methodological change implemented in this stage is documented in
`protocol/amendments/amendment_002_time_varying_crp.md`.

## Piecewise time representation

Participant follow-up is split into counting-process intervals using start and
stop times. Each participant contributes one record for every follow-up period
during which that participant remains under observation.

Separate `log2(CRP)` coefficients are estimated for each follow-up period.
All adjustment variables from the primary Cox model remain unchanged.

The period-specific hazard ratios are interpreted as the adjusted hazard ratio
for all-cause mortality per doubling of baseline CRP within each follow-up
period.

## Replicate-weight implementation

The original stratified NHANES survey design is converted to JKn replicate
weights.

The Cox model is fitted once using the full-sample weights and once for each
JKn replicate. Replicate models are processed sequentially to limit peak memory
use.

Replicate coefficients are checkpointed after every successful fit. If
execution is interrupted, the script resumes from the most recent compatible
checkpoint.

Rows with zero replicate weight correspond to the deleted PSU and are excluded
from that replicate fit. Positive weights are rescaled to mean one for
numerical stability. This rescaling does not change Cox regression
coefficients.

The covariance matrix of the model coefficients is estimated from the JKn
replicate distribution.

## Global test of time variation

The primary inferential test evaluates the null hypothesis that the four
period-specific CRP coefficients are equal:

```math
H_0:
\beta_{0-5}=
\beta_{5-10}=
\beta_{10-15}=
\beta_{15+}.
```
With four coefficients, the global test has three numerator degrees of freedom.

Period-specific hazard ratios and confidence intervals describe the magnitude
of the association within each interval. The global interaction test is used
to assess whether the association differs across follow-up periods.

The period boundaries are an analytical representation of time variation and
must not be interpreted as biological thresholds.

## Computational implementation

To reduce memory requirements:

only variables required for the model are retained before follow-up splitting;
the expanded counting-process dataset contains at most four records per
participant;
unnecessary survey-design objects are removed after JKn parameters and
weights have been extracted;
only columns required for each Cox fit are passed to coxph();
JKn replicates are fitted sequentially;
garbage collection is performed between replicate fits;
checkpointing allows interrupted analyses to resume without repeating
completed replicates.

No parallel processing is used.

## Validation requirements

Before interpretation, the following controls must be verified:

analytic participant count matches the frozen cohort;
death count matches the frozen cohort;
all deaths are retained after follow-up splitting;
participant identifiers remain correctly mapped after splitting;
survey strata and nested PSU counts match the validated design;
all JKn replicates complete successfully;
all model coefficients and covariance estimates are finite;
deaths across follow-up periods sum to the total number of deaths;
the global interaction test has three numerator degrees of freedom.

Results must not be interpreted until these checks have been reviewed.

## Execution and validation

The amended analysis was executed successfully after implementation and
performance optimization.

Observed validation results were:

- analytic participants: 26,818;
- observed deaths: 5,886;
- counting-process interval rows: 81,509;
- survey strata: 89;
- nested PSUs: 180;
- survey design degrees of freedom: 91;
- JKn replicates: 180;
- successfully completed JKn replicates: 180.

Deaths were distributed across follow-up periods as follows:

- 0 to 5 years: 1,675 deaths;
- more than 5 to 10 years: 2,146 deaths;
- more than 10 to 15 years: 1,468 deaths;
- more than 15 years: 597 deaths.

The period-specific death counts sum to 5,886, matching the frozen analytic
cohort.

All period-specific CRP coefficients, standard errors, hazard ratios and
confidence intervals were finite.

The global CRP-by-follow-up-period interaction test used 3 numerator degrees
of freedom and 91 denominator degrees of freedom.

The corresponding QC outputs are:

- `output/tables/qc_09_piecewise_crp_jkn.csv`
- `output/tables/qc_09_followup_period_events.csv`
- `output/tables/table_05_crp_time_interaction_test.csv`
- `output/tables/table_05_crp_hr_by_followup_period.csv`

These checks were reviewed before interpretation of the model estimates.
