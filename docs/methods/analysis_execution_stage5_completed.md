# Stage 5 completed: multiple-imputation sensitivity

Date: 14 October 2026. Investigator instruction: “sigue adelante hasta concluir
esta fase de analisis”. This closes the missing-covariate sensitivity specified
in the frozen SAP, following the separately recorded diagnostic acceptance of
50 chains at iteration 20. The primary complete-case analysis is unchanged.

## Results

| Analysis | Participants | Deaths | HR per doubling of CRP | 95% CI |
| --- | ---: | ---: | ---: | --- |
| Original primary complete-case | 26,818 | 5,886 | 1.129854 | 1.108762–1.151347 |
| Secondary multiple imputation | 27,755 | 6,354 | 1.135368 | 1.115083–1.156022 |

The MI sensitivity retains a positive association of similar magnitude to the
primary estimate. This descriptive comparison is not a formal test of the
correlated estimates and is not evidence of causality. Missing covariates are
not shown to explain the observed positive association under this working
imputation model. This does not exclude bias under alternative missingness
mechanisms or misspecified conditional models.

The pooled log-HR is 0.1269569, SE 0.009072739. Within-imputation variance is
8.199734e-5; between-imputation variance 3.110286e-7; total variance 8.231459e-5.
Barnard–Rubin df is 88.71818, using eligible-survey complete-data df 91.
The t-based p-value is 3.589036e-24. Lambda is 0.003854106, relative variance
increase 0.003869018 and finite-df FMI 0.02557599. FMI is not the proportion of
participants missing covariates. The original primary CI remains its historical
asymptotic Wald interval; MI uses the prespecified finite-df convention.

Estimated Monte Carlo SE of the pooled log-HR from between-imputation variance
is `sqrt(B/50) = 0.00007887`, approximately 0.87% of pooled SE. This is a
conditional Monte Carlo precision estimate, not another convergence test or a
bound on model/missingness bias. Per-imputation log-HRs range 0.125740–0.128214.

## Implemented analysis and validation

`src/R/15_fit_multiple_imputation_sensitivity.R` reconstructs one completed
eligible analysis dataset at a time. It inserts draws only in originally
missing target cells. Original observed BMI is restored by retaining its exact
raw value, never by inverse-transforming observed standardized values. All
other observed targets, fixed fields and participant IDs/order are verified
unchanged. Each analysis retains all 27,755 participants and 6,354 deaths.

Age terms use the original frozen knots. The primary formula is checked against
the parsed `primary_formula` assignment in Script 06. `build_survey_design`
uses original pooled MEC weights, strata and nested PSUs. All 50 fits use
`survey::svycoxph`, Efron ties and design-based covariance. Each fit has finite
coefficients/covariance, positive diagonal variances and design df 91. Only
compact per-imputation scalar estimates and QC are retained, not fifty large
model objects or completed data frames.

Manual scalar Rubin calculations agree with `mice::pool.scalar(Q,U,n=92,k=1)`
for Qbar, total variance, Barnard–Rubin df and FMI. A zero-between-variance
control also passes. Seven final QC assertions pass, including cohort/observed
preservation, formula identity, finite fits, pooling agreement and unchanged
protected input/constants/code/checkpoint/historical output hashes.

The fifty sequential model fits and initial pooling took 44.15 seconds with
sampled peak RSS 497,620 KiB (about 486 MiB), much less than the imputation phase.
The original GNU-time log/resources are archived beside the v1 fit artifacts.
No imputation was rerun or extended to select this effect estimate.

## Authoritative outputs and correction provenance

Use **v2** output files:

- `output/tables/mi15_20261014_fourworker_v1_v2_per_imputation.csv`
- `output/tables/mi15_20261014_fourworker_v1_v2_pooled.csv`
- `output/tables/mi15_20261014_fourworker_v1_v2_comparison.csv`
- `output/tables/mi15_20261014_fourworker_v1_v2_qc.csv`
- `data/processed/mi15_20261014_fourworker_v1_v2/completed_results.rds`

The v1 fits and pooled MI result were valid, but its comparison used nonexistent
historical CI field names, causing the MI limits to be recycled onto the
complete-case row. **The v1 comparison is invalid and must not be used.** It is
preserved for audit. V2 corrects the names to `confidence_low/confidence_high`,
verifies the archived v1 source/input/formula/version provenance, and reuses the
same fifty validated Q/U records without fitting again. Parent manifest and
all reused fit hashes are saved in `reused_fits_provenance.rds`. V2 Q/U and MI
pooling are identical to v1; the corrected historical comparison equals the
original primary table exactly. No validated primary output was overwritten.

The corrected reusable Script 15 can reproduce fresh fits under a new output
version, or finalize from the explicitly verified v1 fits via
`--reuse-v1-fits`; completed outputs are protected against overwriting. Its
executed source, manifest and scalar checkpoints are archived beside results.

## Interpretation, closure and limits

The acceptance report is
`analysis_execution_stage5_real_imputation_review_020.md`. It preserves all
original autocorrelation flags and discusses rare diabetes categories, different
observed/imputed marginal distributions, subgroup comparisons and extreme BMI
donors. Acceptance concerns diagnostic readiness, not proof of MAR, imputation
model calibration, exact survival-model compatibility or absence of bias.

The result is a secondary prognostic sensitivity. It does not replace the
primary complete-case analysis, establish causality or remove the documented
CRP proportional-hazards/time-variation issue. Interpret the constant CRP
coefficient with that existing caveat. No new PH/time-interaction or other
validated sensitivity outputs were regenerated.

**Stage 5 is complete:** missingness audit, prospective implementation choices,
synthetic validation and resource optimization, real 50-chain execution,
endpoint review, fifty primary-formula survey-Cox fits, scalar pooling,
comparison and reproducible reporting are recorded. Manuscript integration or
subsequent publication work is separate. No commit or push was made.
