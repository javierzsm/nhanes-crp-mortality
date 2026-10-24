# Amendment 001 sensitivity: same-month deaths

Executed on 23 October 2026; English documentation revision on 24 October 2026.
This additional analysis of the primary complete-case model was specified by
[Amendment 001](../../protocol/amendments/001_zero_followup_time.qmd).

## Question and decision

Does assigning 0.5 months to deaths with zero released follow-up affect the
estimated CRP–mortality association?

The sensitivity has very little influence on the point estimate or interval.
The primary analysis retains the 0.5-month convention; this additional result
closes the specific amendment commitment. It is neither a formal equivalence
test nor validation of all other study assumptions.

## What was actually excluded?

There are four same-month deaths among 27,755 eligible participants. Two, both
from 2007–2008, were already absent from the primary model because of incomplete
covariates. Excluding all four from the eligible population while retaining the
same complete-case requirements therefore removes **two additional observations**
from the model: one from 2001–2002 and one from 2003–2004. All four have zero
released months and 0.5 analytic months. The [cycle counts](exclusion_audit.csv)
document this distinction without publishing individual identifiers.

## Method

First, the saved primary model was reproduced, checking all coefficients and
the covariance matrix at numerical tolerance 1e-10. The same Cox formula was
then fitted with Efron ties, log2(CRP), the original adjustments, and the same
age bases from knots 22, 38, 52, and 78. Only the specified records were removed
by subsetting the original survey design, preserving weights, strata, and
clusters. Design degrees of freedom remained 91.

Intervals use design variance and the primary normal approximation:

$$
\mathrm{CI}_{0.95}=\exp\lbrace \widehat\beta\pm1.959964\,SE\rbrace .
$$

Knots were not recalculated, data were not imputed, and specifications were not
selected based on results.

## Results

| Analysis | Participants | Deaths | HR per CRP doubling | 95% CI |
| --- | ---: | ---: | ---: | ---: |
| Primary | 26,818 | 5,886 | 1.129854 | 1.108762–1.151347 |
| Exclude same-month deaths | 26,816 | 5,884 | 1.129632 | 1.108576–1.151088 |

The log coefficient changes from 0.1220883072 to 0.1218918171, a difference
of −0.0001964900. The ratio of HRs is 0.9998035293, a relative HR reduction
of approximately **0.01965%**. Excess relative hazard changes from 12.9854%
to 12.9632%, a −0.02220-percentage-point difference. These describe hazard,
not cumulative risk or a causal effect. No equivalence threshold was chosen
retrospectively.

## Additional scientific manuscript text

**Methods.** As specified in Amendment 001, we repeated the primary
complete-case survey-weighted Cox analysis after excluding participants whose
released follow-up was zero months and who died within that monthly interval.
The original model assigned these deaths 0.5 months. We retained the original
covariate specification, age-spline knots, survey weights and design structure.
Of four affected eligible participants, two belonged to the complete-case sample;
the other two were already excluded because of incomplete covariates.

**Results.** Excluding the two applicable same-month deaths yielded 26,816
participants and 5,884 deaths. The adjusted hazard ratio per doubling of CRP
was 1.129632 (95% CI 1.108576–1.151088), compared with 1.129854
(95% CI 1.108762–1.151347) in the primary analysis. The relative change in
the hazard ratio was −0.01965%, indicating little influence of the midpoint
convention on this estimate.

## Verification and provenance

All [fourteen checks](validation.csv) passed at execution. They cover counts,
retained rows, reproduction of the primary model, an independent interval
calculation, and before/after integrity of earlier artifacts. The
[full results](comparison.csv) and [input hashes](inputs.csv) support audit.
These checks refer to the source versions at execution. Later English and
rendering changes are disclosed in the [documentation audit](../documentation_quality_v1/README.md);
old manifests were not rewritten to disguise documentation changes.

Code: [22_sensitivity_same_month_deaths.R](../../src/R/22_sensitivity_same_month_deaths.R).
Run from the root using `Rscript src/R/22_sensitivity_same_month_deaths.R`.
It stops if this version's outputs already exist; do not rerun to refresh dates.
Coefficients, covariance, and the local manifest are stored in
`data/processed/same_month_death_sensitivity_v1.rds`. CSVs contain aggregates only.

This addendum is incorporated into the [current scientific draft](../stage6_v3/manuscript_methods_results.md).
It evaluates the primary model, without claiming to repeat the imputed model
or all other sensitivities. Participant data and fitted results are unchanged.
