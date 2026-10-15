# Real multiple-imputation endpoint review: 20 iterations

Date: 14 October 2026. Run: `20261014_fourworker_v1`.
Authorization: the investigator instructed “hace la revision y toma la decision
directamente”. Review and decision were performed by the coding assistant using
saved diagnostics and visual inspection, before any MI Cox fit or pooled effect.

## Decision

**Accept iteration 20 as the final imputation endpoint for the planned secondary
survey-Cox sensitivity. Do not extend to 40 solely to clear the short-window
maximum-autocorrelation flags.** Keep all 50 chains and all accepted methods,
predictors, donor settings, factor levels, frozen knots and survey coding.

This accepts computational and diagnostic readiness of these imputations.
It does not establish MAR, correct conditional models, calibration, exact
survival-model compatibility, or unbiased inference. The secondary/prognostic
interpretation and primary PH/time-variation caveat remain required.
No MI Cox model or pooled association has been inspected or fitted in this review.

## Execution and invariant evidence

All 50 chains reached iteration 20. The supervisor stopped at its diagnostic
endpoint and released its lock. Runtime was approximately 7 h 27 min and sampled
aggregate worker peak RSS was 3.94 GiB. All 3,000 saved multinomial convergence
codes were zero. The completed execution contains 20,000 trace rows and 49,200
final missing-cell draws across the six targets and fifty chains.

The review re-read and verified every final chain checkpoint against the frozen
plan/input/code hashes and package versions. For all fifty completed MICE tables,
all originally observed and fixed columns match the plan exactly, all targets
are complete and categories retain their original levels. Every imputed BMI is
finite, positive and equals an observed donor within 1e-10 after back-transform.
Original observed BMI is not replaced by a back-transformed approximation.
Participant order/identities remain in the immutable input and frozen plan.

## Convergence review

The original export's twenty review flags are retained unchanged. All are
triggered by the maximum absolute lag-1 autocorrelation over fifty short
(ten-iteration) chain traces. No original PSRF exceeds 1.05 and no mean-window
drift exceeds 0.2 within-chain SD.

| Diagnostic | Last ten iterations | All twenty iterations |
| --- | ---: | ---: |
| Maximum classic PSRF over twenty summaries | 1.02453 | 1.00940 |
| Maximum normalized last-five vs preceding-five mean difference | 0.15032 | 0.15049 |
| Summary/chain pairs with positive lag-1 correlation > 0.5 | 10 | 2 |
| Summary/chain pairs with negative lag-1 correlation < −0.5 | 71 | 10 |

Each window has 1,000 summary/chain pairs; some summaries are dependent or
complementary, so these counts are descriptive, not independent tests.
Median signed correlations across chains are close to zero or slightly negative:
last-ten range −0.179 to 0.029, full-twenty range −0.123 to 0.009. A maximum
across fifty short sequences is sensitive to isolated extreme estimates;
negative correlations alone do not demonstrate slow drift or sticky chains.
The classical PSRF is a review tool and can be below one; it is not a proof of
convergence. Both windows are reported, without selecting a favorable subset.

Full-twenty positive correlations above 0.5 occur only for education, Less than
9th grade in chain 4 (0.5263), and Some college/AA in chain 38 (0.5774). Their
individual traces were inspected: chain 4 fluctuates and returns to its early
range; chain 38 has a lower late segment with a recovery at iteration 20. These
remain residual short-chain uncertainty rather than evidence of widespread
separation/drift. No category was merged and no chain was discarded.

Visual inspection of all fifty traces, with the cross-chain mean highlighted,
shows overlapping chains, no sustained global late drift, and fluctuating BMI
variance rather than persistent separation. Three chains have constant
Borderline-diabetes proportions in the final ten iterations; the other chains
and overall variance remain nonconstant. This is recorded rather than replacing
undefined individual-chain autocorrelation by zero.

The extension rule is diagnostic, not automatic threshold chasing. Taken
together, the invariants, overlap, low PSRF, low aggregate drift and isolated
rather than broadly persistent positive autocorrelation support stopping at 20.
No acceptance criterion was changed after inspecting a CRP effect estimate.

## Distribution and rare-category review

BMI density curves overlap well. Observed BMI mean/SD are 28.667/6.493; across
final chains the mean imputed BMI is 28.936 and mean imputed SD is 6.856.
Imputed chain means range 28.580–29.433. BMI summaries were also inspected by
cycle and death status: average imputed cycle means range 27.81–30.38;
death-status means are 28.97 (death = 0) and 28.92 (death = 1).

The observed BMI support is 12.04–130.21, and some imputed chains reuse the
extreme observed donor 130.21. This can affect tail/variance summaries and must
be disclosed; donor trimming was not introduced retrospectively. Central
densities and quantiles show no newly generated impossible values or separate
mode. Donor validity and visual overlap do not prove conditional calibration.

Final mean imputed category proportions differ from observed proportions:
Less than 9th grade 24.9% versus 14.3%, diabetes Yes 18.7% versus 11.1%,
hypertension Yes 20.6% versus 34.1%, prevalent CVD Yes 24.3% versus 11.8%.
These differences are retained and reported, not forced to match observed
marginals. Missing-target groups differ in measured profiles: education/CVD
missing groups have mean age about 62, versus about 50.5 for observed groups;
hypertension missing records have mean age 40.7 versus 50.6. Diabetes missing
records have death proportion 47.4% versus 22.9%. Such differences make
unconditional equality an inappropriate acceptance requirement. They do not,
by themselves, validate the imputed probabilities or MAR. Overall/category and
cycle/death tables are preserved for reporting, including empty subgroup NAs.

Borderline diabetes occurs in zero final draws in 40/50 chains, with 0–3 draws
among each chain's nineteen missing cells. Mean imputed proportion is 1.58%,
close to the observed approximately 1.64%. The category remains available and
is drawn in other chains; zero draws were not treated as a hard failure or
forced to be nonzero. Sparse-category distributions retain substantial uncertainty.

## Reproducible evidence and boundaries

Script: `src/R/14c_review_real_imputation_diagnostics.R`.
Use the **review020_v2** artifacts under `output/tables/` and `output/figures/`.
They include both-window statistics, signed per-chain autocorrelations/slopes,
observed/imputed distributions overall/by cycle/by death, fifty-chain invariant
QC, BMI/category traces and BMI densities. The intermediate v1 review mistakenly
parsed a negative-threshold count as assignment in R; its signed counts/per-chain
AC are invalid and excluded. It is preserved with its executed source. The v2
fix was made before the endpoint decision; original checkpoints, original
execution diagnostics and all imputed draws remain unchanged.

A separate immutable `accepted_endpoint_020.rds` records this decision, final
checkpoint hashes, this report's hash and authoritative review artifact hashes.
The original `review_endpoint_020.csv` continues to record the execution-stage
status `awaiting_diagnostic_review`; it is historical and is not overwritten.
Do not modify the frozen plan/specification or old outputs to update that status.

Next work is the unchanged primary-formula survey-Cox fit in each completed
set and validated scalar Rubin pooling, with exact restoration of observed BMI,
frozen knots and original survey weights/design. That stage is not run by this
review. No new study association, commit or push is produced here.
