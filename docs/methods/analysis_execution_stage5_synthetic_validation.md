# Analysis execution, stage 5: synthetic MICE validation

**Study:** Baseline CRP and all-cause mortality, NHANES 1999–2010
**Execution reported:** 27 September 2026, locally
**Script:** `src/R/13_validate_imputation_synthetic.R`
**Output:** `output/tables/qc_13_synthetic_imputation.csv`
**Status:** Initial synthetic software smoke test **passed**; real-data MI **not yet authorized**

## Purpose and scope

This test validates basic implementation behavior using newly generated synthetic covariates, artificial follow-up/event data, and imposed missingness. It does **not** load the actual NHANES cohort or use observed NHANES CRP–mortality associations to select imputation settings. It is not a proof of MAR, convergence for real data, or an assessment of bias in the actual study.

The synthetic sample contains 2,400 observations distributed over six simulated cycles. The local test uses `mice` 3.19.0, three imputations and five MICE iterations. The six imputation targets are BMI (`pmm`), education (`polyreg`), smoking (`polyreg`), diabetes (`polyreg`), hypertension (`logreg`) and prevalent CVD (`logreg`). Non-imputed predictors include age, sex, race/Hispanic origin, cycle, CRP, event status, a synthetic unweighted Nelson–Aalen cumulative-hazard summary and log survey weight.

## Execution history and correction

The first execution stopped while fitting a synthetic design-based Cox model with a computationally singular variance matrix (`reciprocal condition number = 1.11152e-21`). At that point the synthetic design had 12 strata and 24 PSUs (12 design degrees of freedom) for a relatively parameter-rich Cox model. A **synthetic-test-only** design change was then applied locally: eight strata per cycle, two PSUs per stratum, for 48 strata and 96 PSUs (48 design degrees of freedom), maintaining 2,400 simulated participants. After the change, R parsing succeeded and Script 13 completed.

This correction changes neither the actual NHANES survey design nor the primary study specification. The final locally modified Script 13 must be reviewed before committing; an earlier distributed copy may still contain the original synthetic design.

## Reported synthetic QC

The user executed Script 13 locally and provided the following output from `qc_13_synthetic_imputation.csv`:

| Check | Recorded value |
| --- | ---: |
| Synthetic participants | 2,400 |
| Synthetic deaths | 934 |
| Test imputations | 3 |
| Test iterations | 5 |
| Missing target variables | 6 |
| MICE logged events | 0 |
| All observed and fixed unchanged | TRUE (`1`) |
| All imputed targets complete | TRUE (`1`) |
| All synthetic Cox fits finite | TRUE (`1`) |
| Scalar Rubin pooling matches manual calculation | TRUE (`1`) |
| Synthetic pooled log-HR | 0.0981225943728994 |
| Synthetic pooled variance | 0.000605740850195033 |

The pooled estimates above are **synthetic software-test diagnostics**, not CRP–mortality estimates and not evidence for a scientific association.

## What the smoke test establishes

Under the tested synthetic input and predictor specification, MICE completed without logged events; completed datasets preserved observed and explicitly fixed values and contained no residual missingness among six target covariates. Survey-weighted Cox fits yielded finite estimates in all three synthetic completions. The scalar pooling implementation agreed numerically with a separately calculated Rubin total variance.

## Remaining limitations and next gate

- Three imputations and five iterations, together with zero logged events, **do not establish convergence**. Examine trace behavior and observed-versus-imputed distributions with a more informative diagnostic run once the intended predictor strategy has been settled.
- The synthetic Nelson–Aalen cumulative-hazard predictor is **unweighted**. Its calculation and use for the actual survey population still need methodological justification and testing.
- The synthetic imputation models use cycle and log-weight as design-related predictors, **not** explicit stratum and PSU terms. Survey-aware handling in the imputation stage remains unresolved, even though the downstream synthetic Cox models used a stratified, nested-PSU survey design.
- A globally observed category count does not rule out sparse combinations, separation or unstable multinomial conditional models in the intended real-data predictor matrix; inspect diabetes *Borderline* and categorical education in particular.
- Preserve the actual study's frozen model, survey design and primary-case results. Before real-data execution, approve the final technical strategy, test any substantive revisions on synthetic inputs, and specify 50-imputation convergence and recovery QC.

## Associated materials

- `docs/methods/analysis_execution_stage5_missingness.md`: observed descriptive missingness audit.
- `docs/methods/multiple_imputation_technical_spec_draft.md`: working technical design and unresolved choices.
- `src/R/12_audit_missingness_for_imputation.R`: observed audit implementation, locally optimized.
- `src/R/13_validate_imputation_synthetic.R`: local synthetic implementation; verify final revision before committing.
