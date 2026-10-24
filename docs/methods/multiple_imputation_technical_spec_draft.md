# Stage 5: multiple-imputation technical specification

**Study:** Baseline CRP and all-cause mortality in NHANES, 1999–2010
**Status:** Section 7 accepted for synthetic validation on 13 October 2026; Section 8 four-worker strategy accepted on 14 October 2026. Script 14 preparation is in progress; real-data execution remains pending.
**Governing document:** Frozen SAP v0.3, *Missing covariates* section
**Input QC:** `docs/methods/analysis_execution_stage5_missingness.md`

**Reading order:** Sections 1–7 preserve the dated development and validation record. Section 7 fixes the statistical choices; Section 8 supersedes the earlier sequential execution proposal with the accepted four-worker strategy. Preparation and actual imputation execution remain separate steps.

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

## 7. Prospective specification proposed on 13 October 2026

### 7.1 Governance and interpretation

The frozen SAP determines the eligible population, 50 imputations, PMM/binary/multinomial conditional methods, inclusion of exposure, analysis covariates, survival information and survey information, survey-Cox fitting and Rubin pooling. Amendments 001–003 retain their existing scope; none approves a different MI analysis. The choices below fill implementation details and do not change the primary complete-case analysis or its validated outputs.

The investigator accepted this proposal on **13 October 2026** (instruction: “ok avancemos”) for the next synthetic-validation step. This does not authorize real-data execution. Record the accepted specification hash in each validation manifest and again before any later real-data execution. Require a new prospective review if synthetic validation fails; do not silently fall back to cycle-only imputation, merge categories, drop design columns, change methods or tune against CRP hazard ratios. A material departure from the frozen SAP requires a numbered amendment before execution. No such departure is proposed here.

The final-design synthetic test must validate the exact predictor coding and diagnostics below. Script 13's existing result remains a historical smoke test; do not overwrite it or describe it as validation of this revised specification.

### 7.2 Survival auxiliary variable

Use the event indicator `death` and a **pooled, unweighted marginal Nelson–Aalen cumulative hazard**, `nelson_aalen`, evaluated at the analytic `follow_up_months` of every eligible participant. Compute it once from all 27,755 eligible records, without requiring covariates to be complete and without fitting the primary Cox model. Use the analytic 0.5-month follow-up for the four zero-time deaths under Amendment 001; preserve the released follow-up separately.

For distinct event times, define:

$$
d_j = \sum_i I(T_i=t_j, D_i=1),\qquad
Y_j = \sum_i I(T_i\ge t_j),\qquad
\widehat H_{NA}(T_i)=\sum_{t_j\le T_i} d_j/Y_j.
$$

Include events and censors tied at an event time in its risk set immediately before that time. Aggregate all tied deaths into a single increment. Evaluate the right-continuous step function, including an increment when follow-up equals its event time; assign zero before the first event. Require positive risk sets, finite nonnegative monotone hazards, event-count reconciliation and no missing auxiliary values. Synthetic unit examples must cover tied deaths/censors, pre-event censoring, the last event and 0.5-month follow-up. Use sorted times and cumulative risk counts rather than a participant-by-event-time matrix.

This is a marginal survival summary used to approximate baseline-hazard information, **not** an estimate of the covariate-adjusted baseline hazard or a survey-weighted population survival curve. The unweighted choice follows the established White–Royston auxiliary strategy and keeps weighting in the imputation predictors and final analysis. A weighted hazard is not automatically a better or fully compatible imputation model. Do not replace this term with raw follow-up or log follow-up, and do not recompute it across imputations.

The theoretical rationale is approximate for several covariates and does not establish exact compatibility with PMM, multinomial models, nonlinear age effects or the observed time-varying CRP association. Report these limitations alongside the MI sensitivity; do not claim that the auxiliary solves the PH issue or establishes MAR. [White and Royston (2009)](https://doi.org/10.1002/sim.3618).

### 7.3 Survey information during imputation

Use unweighted conditional MICE fits with **design predictors**: cycle, log pooled MEC weight, stratum effects within cycle, and PSU effects within stratum. The original weights, strata and PSUs remain fixed for the final `svydesign`. Neither fitting MICE with these predictors nor constructing an unweighted hazard replaces design-based analysis.

Read-only inspection of eligible-cohort design fields on 13 October 2026 found 89 strata, 180 nested PSUs and no stratum shared across cycles. Stratum counts by cycle were 13, 15, 15, 15, 16 and 15. Nested PSU sizes ranged from 52 to 265 participants. These checks did not fit or examine an MI CRP–mortality estimate. Recheck these properties at the future execution gate; do not assume the complete-case and eligible designs have identical support.

Represent the fixed design intercept space without redundant factors:

1. Retain `cycle` as the original six-level factor (five contrasts).
2. Within each cycle, choose its lowest sorted stratum ID as reference. Create one 0/1 indicator for each other stratum, zero outside that stratum: 89 − 6 = **83 columns**.
3. Within each stratum, choose its lowest sorted PSU ID as reference. Create one 0/1 indicator for each other nested PSU, zero outside that stratum/PSU: 180 − 89 = **91 columns**.

With an intercept this is a full-rank parameterization of the **same intercept space as a 180-level nested-PSU factor**. It explicitly retains cycle while representing strata and PSU; it reduces redundant columns, not the substantive number of cluster effects. Preserve the mapping table and verify its rank and span synthetically. Do not also enter raw `SDMVSTRA`, raw `SDMVPSU`, or a combined PSU factor as predictors. The numeric PSU label alone has no cross-stratum meaning.

Use `log_weight = log(pooled_mec_weight)`. Center and scale it using the entire eligible input, saving the transformation constants. Include a linear main effect; no automatic weight interactions or model selection. This is a working model for design dependence, not a guarantee of design-consistent MI under arbitrary informative sampling. Fixed cluster effects can be unstable for rare categories; the 454 observed Borderline diabetes records make this a central synthetic stress-test requirement. [He and Zhang (2023), complex-survey MI guidance](https://stacks.cdc.gov/view/cdc/132019).

Before implementation approval, tabulate observed target categories and missing counts within nested PSU using covariate/design fields only. Record absent categories and cluster support; do not collapse categories or design cells because of these tables. Require full column rank for each target's observed-row regression matrix. Check conditioning on scaled matrices and review weak identification rather than hiding it with silent predictor removal. Perfect prediction requires diagnostics even with MICE's default categorical augmentation. If this fixed-effects approach fails the synthetic gate, revisit the design specification prospectively; a multilevel substitute is not preapproved.

### 7.4 Conditional methods and predictor matrix

Keep the existing factor levels and reference levels. Education remains an unordered five-level factor with `polyreg`; smoking and diabetes use `polyreg`; hypertension and prevalent CVD use `logreg`. BMI uses `pmm`, explicitly with five donors, `matchtype = 1` and `ridge = 1e-5`. Retain MICE's documented categorical augmentation; do not add data-dependent penalties or category merging.

For numerical stability, center and scale continuous predictors and BMI inside MICE using observed input means/SDs, retaining invertible transformation constants. PMM donors are still the observed BMI values on the transformed scale. Restore the original observed BMI values exactly during assembly of analysis datasets, and inverse-transform only missing-value draws. Require finite positive SDs. Set `nnet.maxit = 1000` and `nnet.MaxNWts = 5000` prospectively for multinomial optimization, subject to synthetic validation; these are numerical limits, not MICE iteration counts. Inspect the installed implementation rather than assuming defaults from a newer web release.

Let the target set be:

`A = {bmi, education, smoking, diabetes, hypertension, prevalent_cvd}`.

Let the fixed predictor set be:

`F = {age_rcs1, age_rcs2, age_rcs3, sex, race_hispanic_origin, cycle, log2_crp, death, nelson_aalen, log_weight, 83 stratum columns, 91 PSU columns}`.

Derive the three age terms **before imputation from fully observed age using the frozen primary age knots** in `analysis_constants.rds`. Use these terms to represent age's primary functional form; they are fixed predictors with empty methods, never independently imputed. Exclude raw age as an additional column to avoid duplicating the linear component in the spline space. Retain original age in the immutable analysis input and reconstruct its basis with the same knots for Cox fitting. No CRP spline is used in this linear-exposure MI sensitivity; use `log2_crp` alone rather than also entering raw CRP.

Define the matrix for all included MICE fields exactly as follows:

| Matrix element | Value |
| --- | ---: |
| Row in A, column in A excluding itself | 1 |
| Row in A, column in F | 1 |
| Every diagonal element | 0 |
| Every row in F | 0 |

Use no automatic predictor selection. Set `where` true only for originally missing target cells. Use the fixed visit order BMI, education, smoking, diabetes, hypertension, prevalent CVD. All fixed fields have method `""`. Exclude SEQN, raw follow-up, raw weight, raw design IDs, income, derived completeness flags and other redundant derived variables from the MICE table; preserve them in the immutable eligible input. Save the explicit matrix, methods, visit order, transformations and design-column mapping. Any automatically removed term or unexpected logged event fails the gate.

### 7.5 Iterations and convergence review

Recommend **20 initial MICE iterations**, checked in five-iteration blocks. This is a prospective computational starting point, not proof that 20 iterations suffice. Under the same model and continuing RNG state, allow extensions to 40 and then 60 iterations only when imputation diagnostics warrant them. At 60, unresolved instability stops the analysis for methodological review. Extension decisions must precede Cox fitting and must never depend on agreement with the complete-case HR. The final analysis uses one completed dataset per chain at the accepted endpoint, giving 50 datasets; intermediate iterations are diagnostics, not extra independent imputations.

Capture diagnostics at every iteration, separately for the originally missing cells:

- BMI chain means, variances, quantiles and trace plots across chains. Export MICE chain summaries and lag-1 autocorrelation/PSRF for means and SDs where defined.
- For every categorical target, **one proportion per category per chain per iteration**, with traces and window summaries. Numeric factor-code means are inadequate. Capture these summaries during each iteration; the final `mids` alone does not retain every categorical draw at earlier iterations.
- Compare the last two five-iteration windows for drift in means, dispersions and category proportions. Review mixing and chain overlap. Use PSRF above 1.05, absolute lag-1 correlation above 0.5, or a window mean difference above 0.2 pooled within-chain SD as review flags rather than universal validity cutoffs. Document undefined diagnostics for constant traces; do not declare them passing by replacing NA with zero.
- Tabulate final observed versus imputed BMI mean, SD, p1/p5/p25/p50/p75/p95/p99 and ranges, overall and by cycle and death status. Confirm imputed BMI is positive, finite and within observed donor support. PMM does not by itself guarantee plausible conditional distributions.
- Tabulate observed and imputed categorical counts/proportions across all chains, overall and by cycle/death status. Report variation across chains and the Borderline diabetes counts explicitly. With only 19 missing diabetes values, zero Borderline draws in an individual chain can occur; do not force a nonzero count. Do not require imputed distributions to equal observed distributions.
- Record all warnings, logged events, categorical optimization convergence codes, finite coefficients and probabilities, row probability sums and extreme predictions for the originally missing cells. MICE 3.19.0 `polyreg` does not explicitly reject a nonzero `multinom` convergence code; diagnostic instrumentation must expose this without changing its fitting/drawing algorithm. Test the instrumentation against the original routine on synthetic inputs under the same RNG state.

Hard failures include altered observed/fixed values, changed IDs/counts/levels, remaining target NA, nonfinite fits/probabilities, unreviewed warnings or logged events, rank deficiency, and failed categorical optimization. Trace/distribution concerns require documented review or the prespecified extension before release. No automatic convergence statistic establishes MAR, model adequacy or valid inference. The final synthetic test must demonstrate that the diagnostic capture works, including deliberately induced warning/failure cases. [MICE convergence reference](https://amices.org/mice/reference/convergence.html).

### 7.6 Reproducibility, checkpoints and resources

Recommend seed **20261013**, `m = 50` from config, sequential computation in one process, and a single `mids` containing all 50 chains. Record R version, RNG kind/state, `sessionInfo()`, MICE 3.19.0 and all relevant package versions; web documentation currently describes a newer release and is guidance only. Record hashes of input cohort, analysis constants, code and accepted specification. No package upgrade mid-run.

At each five-iteration block, save the full `mids`, RNG state, iteration-specific diagnostics, original missingness masks, transformations, matrix/methods and run manifest to a **new** checkpoint under a unique run prefix in `data/processed/`. Write to a temporary file in the same filesystem, read back and validate, then rename to a previously nonexistent final path. Preserve the last valid checkpoint if interrupted; do not overwrite an existing completed run or prune historical artifacts automatically. Export compact QC tables with the same run prefix under `output/tables/`.

Resume with `mice::mice.mids()` from the latest verified checkpoint with matching hashes, versions, model and all chain identities. Do not reset the seed, create a fresh `mice()` call, change the specification or concatenate repeated draws. If interrupted within a block, replay only that block from the prior checkpoint. Prove on synthetic data that uninterrupted and save/read/resumed runs produce identical imputations and continuation state, including diagnostic instrumentation. [MICE continuation reference](https://amices.org/mice/reference/mice.mids.html).

Cost is not yet benchmarked. One 27,755-by-200 double matrix occupies about 42 MiB before factor expansion and copies; nonlinear/categorical model workspace and augmentation can be much larger. Fifty chains, six conditional fits and 20 iterations entail **6,000 conditional fits**, followed later by 50 sequential Cox fits. Many observed records still contribute to these fits despite low missingness. Benchmark the full predictor dimension on synthetic data, measure peak RSS, checkpoint size and disk headroom, and extrapolate measured times with stated uncertainty. Do not promise a runtime from the small Script 13 test. Avoid parallel chains, retaining 50 completed data frames or 50 model objects; assemble and release one analysis dataset at a time.

### 7.7 Later analysis and pooling contract

Only after specification acceptance, final synthetic QC and real-imputation diagnostic review, fit the unchanged primary Efron survey-Cox formula for each completed dataset with frozen age knots and original `pooled_mec_weight`, `SDMVSTRA`, nested `SDMVPSU`. Do not refit knots on the eligible cohort. Validate finite coefficients/covariance matrices and positive CRP variance. Preserve per-imputation Q and U with model QC, without saving all large models.

Manual scalar Rubin pooling remains:

$$
\bar Q = m^{-1}\sum Q_k,\quad \bar U=m^{-1}\sum U_k,\quad
B=\operatorname{var}(Q_k),\quad T=\bar U+(1+1/m)B.
$$

For the proposed interval convention, use finite-sample Barnard–Rubin degrees of freedom with complete-data df equal to `survey::degf()` of the eligible design, checked consistently across imputations. This is an explicit conservative inference convention for this sensitivity, not the primary model's asymptotic Wald convention. Do not substitute participant N as the survey df or assert exact coverage. With `lambda = (1 + 1/m) B/T`, define `df_old = (m − 1)/lambda^2`, `df_obs = ((df_com + 1)/(df_com + 3)) df_com (1 − lambda)` and `df = 1/(1/df_old + 1/df_obs)`, using `df_old = Inf` when B = 0. Validate these calculations independently before use. Report the t-based interval, pooled SE, HR, within/between/total variance, lambda, relative variance increase and finite-df FMI `(r + 2/(df + 3))/(r + 1)`, where `r = (1 + 1/m) B/Ubar`. FMI is not the percentage of records missing.

Compare the final MI HR descriptively with 1.12985387157305, without selecting methods for agreement. Retain the prognostic, secondary interpretation and time-variation caveat. Do not inspect pooled effects during convergence decisions.

### 7.8 Review boundary and immediate next action

The five previously open design decisions now have concrete proposed settings. Remaining work is acceptance of this specification, covariate/design support QC, and an expanded outcome-blinded synthetic validation of the exact strategy, diagnostics and restart contract. **No real-data MICE run, full-run Script 14, new study estimate, commit or push is authorized or performed by this document update.**

## 8. Execution strategy accepted on 14 October 2026

The investigator selected four processes after the measured two- and
four-worker synthetic comparisons, then instructed “ok, usemos esta estrategia”.
This section supersedes Section 7.6's sequential single-`mids` proposal and
five-iteration checkpoint cadence. It records acceptance of the implementation
strategy and preparation of Script 14, not initiation of real-data imputation.
Sections 1–7 retain their dated development history.

Keep all scientific choices, 50 final imputations, fixed design coding,
conditional methods, donor settings, covariate/outcome boundaries, frozen knots,
20 initial iterations and diagnostic extensions to 40/60. Assign one independent
L'Ecuyer-CMRG stream to each of the 50 chains from master seed **20261013**,
using repeated `parallel::nextRNGStream`. Initialize each chain separately with
`m = 1`, `maxit = 0`; its saved initialization RNG state continues that same
chain. This prospectively replaces the earlier sequential multi-chain random
sequence. Process scheduling must never determine seeds or chain identities.

At most **four single-thread workers** run concurrently. Complete one iteration
for every chain before the next iteration. Persist a compressed, atomic,
read-back-verified checkpoint for every chain at initialization and after every
iteration; never overwrite earlier checkpoints or validated study outputs.
The deterministic queue assigns chain IDs in ascending order; its saved
round-robin slot mapping is a planning convention, not an RNG dependency.
Use compact symbolic continuation calls and explicit garbage collection between
target fits. Multinomial instrumentation records optimizer convergence,
coefficient finiteness and missing-row probability diagnostics without changing
draws. Any warning, logged event, invalid fit/state or failed worker stops the
supervisor for review. Check input/code/specification hashes and package versions
on preparation, status inspection and every worker invocation.

Admission requires the measured four-worker memory envelope with 15% margin
and a 1-GiB reserve (approximately 4.84 GiB available), plus 8 GiB free disk.
Stop benchmark/study workers if available RAM falls below 1 GiB or free disk
below 2 GiB. Do not kill unrelated applications or change power/OS/package
configuration. Hard-killed processes may leave locks: inspect processes/logs
before removing a stale lock and resuming. Completed checkpoints are retained.
Ten workers were not admitted under the observed memory availability; four
workers do not constitute a 60%-logical-CPU test.

Script 14 separates **preparation** (cohort/count/missingness/design/rank QC,
transformations, masks, predictor matrix, hashes and stream plan; no MICE
initialization or conditional fits) from explicit execution. The supervisor
stops at 20 iterations awaiting diagnostics. Extensions to 40 and then 60
require a written diagnostic review of the preceding endpoint, captured by
content hash. No extension is selected by a CRP effect estimate. The first
export supplies all per-iteration target traces, multinomial diagnostics,
last-ten-iteration review flags and final missing-cell draws. Full trace plots
and observed/imputed distribution review remain required before accepting an
endpoint; export alone is not convergence acceptance.

There are no Cox fits or pooled effects in Script 14. Prepare the unchanged
survey-Cox sensitivity and scalar pooling only after accepting actual
imputation diagnostics. Store one completed analysis dataset/model at a time.
Parallel execution equivalence, resource measurements and limitations are
recorded in `analysis_execution_stage5_resource_optimization.md`.
