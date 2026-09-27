# Stage 5: multiple-imputation technical specification

**Study:** Baseline CRP and all-cause mortality in NHANES, 1999–2010
**Status:** Technical design **draft**; basic synthetic software smoke test passed; real-data imputation design not yet approved
**Governing document:** Frozen SAP v0.3, *Missing covariates* section
**Input QC:** `docs/methods/analysis_execution_stage5_missingness.md`

## 1. Objective and boundary

Assess the sensitivity of the primary, complete-case Cox association between baseline `log2(CRP mg/L)` and all-cause mortality to missingness in the primary adjustment covariates. The frozen SAP specifies **50 multiply imputed datasets**, survey-weighted Cox models, and Rubin pooling. The multiple-imputation analysis is secondary and remains prognostic, not causal.

Use the 27,755-person primary eligible cohort, contingent on the existing count/identifier QC. Preserve the primary model's follow-up origin, exposure and adjustment set. Do not add income-to-poverty ratio to this principal MI sensitivity; it was separately audited and examined as an additional-adjustment sensitivity.

## 2. Variables and proposed imputation methods

| Variable | Role | Proposed MICE method | Validation needed |
| --- | --- | --- | --- |
| BMI | Imputed continuous | Predictive mean matching (`pmm`) | Plausibility/range and observed-versus-imputed distributions |
| Education | Imputed categorical | Multinomial (`polyreg`) tested synthetically; consider ordinal (`polr`) only if ordering, proportional-odds assumptions and stable fit justify it before real-data execution | Ordering, sparse levels, convergence |
| Smoking | Imputed categorical | Multinomial (`polyreg`) | Sparse categories/separation |
| Diabetes | Imputed categorical | Multinomial (`polyreg`) provisionally | Low-frequency *Borderline* category and separation |
| Hypertension | Imputed binary | Binary logistic (`logreg`) | Separation and predicted probabilities |
| Prevalent CVD | Imputed binary | Binary logistic (`logreg`) | Separation and predicted probabilities |
| Age, sex, race/Hispanic origin, cycle | Fully observed analysis covariates | No imputation; eligible as predictors | Factors and level integrity |
| CRP, death, follow-up, survey weights, strata, PSU | Fixed variables | **Never impute** | Identity checks before and after each synthetic run |

The initial synthetic smoke test used `polyreg` for education, smoking and diabetes; `pmm` for BMI; and `logreg` for hypertension and prevalent CVD. These methods passed a basic synthetic execution test, not the full real-data diagnostic gate. The exact factor coding and admissible predictor matrix must be confirmed by further diagnostics. Do not collapse levels or silently switch imputation methods in response to convergence warnings. Any change requires written rationale and a new dry run.

## 3. Survival information and survey structure

Include `death` and a cumulative-baseline-hazard summary in the **imputation predictor set**, without imputing either. For an initial candidate, compute a Nelson–Aalen cumulative hazard estimate at each participant's observed follow-up time using the eligible population. The specific estimation procedure, handling of tied event times, and any design weighting must be documented and tested before real-data execution; a naive cumulative hazard is not assumed to account for the complex survey automatically.

Include the NHANES survey cycle, pooled MEC weight, and available strata and PSU information as fixed predictors or otherwise explicitly account for them in the chosen imputation strategy. Verify that this is compatible with all conditional models and avoids unstable, high-cardinality dummy matrices. Distinguish inclusion of design information in the imputation model from correct survey design specification during Cox fitting; neither substitutes for the other.

**Open methodological choices to resolve before implementation:**

1. How survey design variables and weights will enter the MICE predictor system (including possible weight transformation and PSU/stratum handling).
2. Whether multinomial education and diabetes remain stable with observed factor levels in the intended real-data predictor specification; consider a justified alternative for education if necessary.
3. How to compute and use cumulative baseline hazard so survival/censoring information is represented consistently.
4. Iteration count, convergence criteria, seed, and validated checkpointing/output format for 50 imputations.

These are implementation choices, not retrospective revisions of the frozen scientific hypothesis. If a choice materially changes the SAP's method, document it prospectively as a numbered amendment before fitting the real-data MI sensitivity.

## 4. Synthetic validation gate: initial smoke-test result

`src/R/13_validate_imputation_synthetic.R` was executed locally on 27 September 2026 with `mice` 3.19.0. The initial 12-stratum/24-PSU synthetic design produced a computationally singular covariance matrix during `svycoxph`; the local synthetic design was revised to eight strata per cycle and two PSUs per stratum (48 strata, 96 PSUs, 48 design degrees of freedom), keeping the 2,400 synthetic observations. R parsing and the rerun succeeded. Inspect the final local Script 13 before committing to ensure it contains this revision.

The resulting `output/tables/qc_13_synthetic_imputation.csv` records three imputations, five iterations, six missing target variables, zero MICE logged events, preservation of observed and fixed values, complete target imputations, finite synthetic survey-Cox fits, and agreement of scalar Rubin pooling with an independent calculation. The synthetic pooled log-HR (0.0981225943728994) and variance (0.000605740850195033) are *software-test outputs only*, not study estimates. Full details and limitations are in `docs/methods/analysis_execution_stage5_synthetic_validation.md`.

The initial smoke test does not establish convergence, calibration, adequacy of imputation distributions, an appropriate survey-aware imputation model, or validity of the MAR assumption. Its Nelson–Aalen predictor was unweighted, and the MICE predictor set included survey cycle and log-weight but not explicit stratum or PSU indicators. Accordingly, **real-data MI is not authorized by this smoke-test result alone**.

### Remaining diagnostic gate


Before running imputation on actual study records, generate a separate outcome-blinded synthetic dataset with realistic dimensions, factor levels, approximately observed missingness patterns, and valid but artificial follow-up and event indicators. Do **not** copy the study's observed mortality outcomes into a dataset described as outcome-blinded synthetic data.

Check at minimum:

- matching factor levels and compatible imputation methods;
- preservation of every observed value and every explicitly non-imputed field;
- no unexpected new missing values or implausible imputed values;
- no silent changes to eligible participant count or participant identifiers;
- absence of iteration-specific errors, separation, and unstable predictions;
- per-variable observed/imputed distributions and trace diagnostics;
- construction of the age spline using the previously frozen age-knot values *after* completed age-related covariate preparation;
- consistent survey design reconstruction and successful `svycoxph` on each completed synthetic dataset;
- a tested pooling implementation with controlled example inputs and Rubin's rules.

The small **synthetic** pilot is complete. Before real-data MI, document and test the final survey design representation, cumulative-hazard method, real-data predictor matrix, convergence diagnostics, and computational plan. This software test is **not** a substitute for the SAP's 50 real-data imputations.

## 5. Real-data execution gate (not yet authorized)

Only after approval of the final technical specification and synthetic QC:

1. Establish fixed random seed, package versions, final conditional methods, predictor matrix and convergence settings.
2. Run 50 imputations on the primary eligible cohort; estimate memory and disk needs before execution and avoid uncontrolled parallel execution.
3. Fit the *same primary* survey-weighted Cox model within each completed dataset using the original pooled MEC weights, strata and nested PSUs and the frozen age-spline knots.
4. Extract the `log2_crp` coefficient and its design-based variance from each model. Combine with Rubin's rules, including within- and between-imputation uncertainty and appropriate degrees-of-freedom/interval calculations.
5. Compare the pooled HR and confidence interval descriptively with the original primary complete-case estimate; report MI diagnostics and limitations.

Checkpointing must not lead to accidental reuse of imputation draws from a different seed, method specification, package version, or input cohort. Preserve the Script 10 and Script 11 outputs unchanged.

## 6. Proposed file boundaries and immediate next step

- `src/R/12_audit_missingness_for_imputation.R` — existing audit, validate and commit after review.
- `docs/methods/analysis_execution_stage5_missingness.md` — observed audit documentation.
- `docs/methods/multiple_imputation_technical_spec_draft.md` — this draft, revise and approve before treating it as frozen execution instructions.
- `src/R/13_validate_imputation_synthetic.R` — locally validated synthetic smoke test, pending final local diff review and commit.
- `docs/methods/analysis_execution_stage5_synthetic_validation.md` — records Script 13 QC and limitations.
- Future real-imputation scripts: implementation to be set after outstanding methodological choices are resolved.

**Immediate next step:** settle and document the survey-aware predictor strategy and cumulative-hazard construction, followed by more complete synthetic diagnostics where the implementation changes. Do not start 50 imputations yet.
