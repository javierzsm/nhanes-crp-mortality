# Stage 6: secondary-analysis reconciliation and first reporting package

Date: 23 October 2026. User requested resumption and further progress.

## Scope and correction of project status

Re-reading frozen SAP v0.3 identified two prespecified effect-modification
analyses (sex and age 20–64 versus 65+) and influence diagnostics without
recorded execution. The earlier handoff correctly closed Stage 5, but omitted
these separate outstanding items. They were completed before treating the
whole analysis set as ready for manuscript reporting. The prospective
implementation note is `analysis_execution_stage6_sap_reconciliation.md`;
no frozen SAP, primary estimate, MI endpoint or old result file was changed.

## Secondary interaction results

Both models use 26,818 complete cases, 5,886 deaths, unchanged survey design,
Efron ties, frozen age splines and primary covariates. The age-group model
includes the group main effect in addition to the continuous-age spline.

| Modifier | Group | N | Deaths | HR per CRP doubling | 95% normal CI |
| --- | --- | ---: | ---: | ---: | --- |
| Sex | Male | 13,376 | 3,276 | 1.14317 | 1.11725–1.16968 |
| Sex | Female | 13,442 | 2,610 | 1.11497 | 1.07625–1.15509 |
| Age | 20–64 | 19,901 | 1,743 | 1.16369 | 1.12628–1.20234 |
| Age | 65+ | 6,917 | 4,143 | 1.10819 | 1.08254–1.13445 |

The sex interaction has F(1,66) = 1.16743, p = 0.283862.
The age interaction has F(1,65) = 5.57547, p = 0.021222.
The denominator df are model-residual df from `survey::regTermTest`, not the
91 design df. Group CIs retain the original asymptotic normal convention.

The female/male ratio of HRs is 0.97533 (0.93213–1.02054); the age-65+/20–64
ratio is 0.95231 (0.91445–0.99173). Formal interaction tests and normal ratio
intervals use related but different reference distributions, as disclosed.
The age result is secondary evidence of heterogeneity in the linear summary,
not a biological threshold or causal finding. Lack of a clear sex interaction
is not evidence of equivalence. Existing CRP nonlinearity/time variation and
secondary multiplicity restrict interpretation of both models. No primary
model was selected based on these tests. The hypotheses were prespecified;
implementation details were recorded after other study results, before these
new estimates were computed.

## Influence diagnostics

Weighted DFBETA linearizations from the saved primary model were inspected at
participant and nested-PSU levels. The maximum absolute CRP contribution was
0.001414 log-HR units (0.14704 original design SE) per participant and 0.002337
(0.24303 SE) per nested PSU. The 95th percentile was 0.01258 SE per participant
and 0.15967 SE per PSU. Grouped residuals matched independently summed case
contributions. All 26,818 rows and 180 PSUs were retained; no observation was
dropped and no model was refitted to optimize the result.

These are first-order diagnostics using the partial-likelihood information
matrix for DFBETA and the saved design SE for normalization. They are not exact
deletion effects, influence hypothesis tests or proof against unmeasured bias.
Two implementation issues were resolved before diagnostic output: explicitly
loading survival/survey for S3 residual dispatch, and restoring coefficient
column labels dropped by multiplication with an unnamed naive variance matrix.
Row alignment, finite dimensions and grouped-sum checks then passed.

## Reproducible manuscript materials

`reports/stage6_v1/` contains:

- `manuscript_methods_results.md`: English working draft, methods/results and
  cautious analytical abstract; not a complete submission-ready manuscript.
- Copied aggregate tables, integrated primary/MI and sensitivity tables, and
  a descriptive follow-up summary with weighted/unweighted distinctions.
- `figures/`: primary/sensitivity forest, saved CRP spline curve, and secondary
  interaction contrasts, each as PNG and SVG; all three PNGs visually reviewed.
- `reporting_checklist_working.md`: STROBE-cohort and applicable RECORD coverage
  map, consulted against the official checklists; remaining gaps are explicit.
- Input manifests and `validation.csv`: eighteen checks passed.

Scripts 16/17 produce the new secondary/diagnostic outputs under fresh filenames;
Scripts 18/19 assemble reporting artifacts; Script 20 validates them without
refitting. Tests independently reproduce scalar interaction Wald F/p values,
contrast ratio identities, sample partitions, source hashes and primary/MI
numbers; original accepted imputation and Stage 5 result hashes still match.
No long-running MI, primary-model rerun or new variable-selection exercise was
performed. R parsing and whitespace checks passed.

## Remaining reporting work

Complete the source-based introduction/discussion, detailed measurement/code
supplement, final cohort-flow/baseline/distribution presentation, and software/
data-access/linkage description. Obtain author/affiliation, applicable ethics
wording, funding/conflict/contribution declarations and target-journal details.
No absent declaration has been inferred. The checklist remains a working map,
not an attestation of full STROBE/RECORD compliance.

This stage is ready for author review; publication preparation remains ongoing.
Changes are local; no commit or push was performed in this resumption step.
