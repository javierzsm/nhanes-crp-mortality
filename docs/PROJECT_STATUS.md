# Project continuity checkpoint

Updated: 23 October 2026. Purpose: preserve the current analysis/reporting
state after resumption. This is the current status; dated execution reports preserve
what was known when each stage ran.

## Completed work and authoritative results

The frozen protocol/SAP v0.3, cohort construction, primary survey-Cox analysis,
CRP functional-form/time-variation analyses, Stage 4 sensitivities (including
alternative age specifications) and Stage 5 multiple-imputation sensitivity
are complete. On 23 October, SAP reconciliation found previously unimplemented
sex/age-group interactions and influence diagnostics; these were then completed
and integrated into the first reporting package. Stage 4's old statement that MI is pending is historical;
Stage 5 subsequently completed it.

| Analysis | Participants | Deaths | HR per CRP doubling | 95% CI |
| --- | ---: | ---: | ---: | --- |
| Primary complete-case | 26,818 | 5,886 | 1.129854 | 1.108762–1.151347 |
| Secondary MI | 27,755 | 6,354 | 1.135368 | 1.115083–1.156022 |

Stage 5 used 50 independent chains, four single-thread workers and 20 iterations.
The investigator delegated endpoint review; iteration 20 was accepted before
MI Cox fitting. There is no outstanding extension to 40/60, imputation job,
Cox job or pooling job. All 50 models and independent scalar Rubin checks passed.
No additional statistical run is needed merely to resume this project.

These are prognostic associations, not causal effects. Preserve the documented
CRP PH/time-variation caveat and uncertainty about MAR/conditional model adequacy.
Do not describe diagnostic acceptance as proof of those assumptions.

## Current reporting materials

- [Stage 6 execution and new secondary results](methods/analysis_execution_stage6_reporting.md).
- [Working Methods/Results draft](../reports/stage6_v1/manuscript_methods_results.md).
- [Reporting checklist and remaining author inputs](../reports/stage6_v1/reporting_checklist_working.md).
- Figures are in `reports/stage6_v1/figures/` as PNG and SVG.

Secondary sex interaction p = 0.284; age-group interaction p = 0.021. These are
prespecified secondary hypotheses with implementation details recorded before
those fits, after other study results were known. Interpret alongside existing
nonlinearity/time variation; they do not replace the primary estimate.
Eighteen reporting cross-checks passed; original accepted MI/primary outputs
remain unchanged. The Stage 6 implementation, aggregate reporting package and manuscript draft
are included in the GitHub update requested after review. Consult Git history
for the publication commit; generated HTML previews stay local.

## Read these first when resuming

1. [Stage 5 completion and final interpretation](methods/analysis_execution_stage5_completed.md).
2. [Iteration-20 diagnostic decision and limitations](methods/analysis_execution_stage5_real_imputation_review_020.md).
3. [Stage 3 time-variation analysis](methods/analysis_execution_stage3.md).
4. [Stage 4 sensitivities](methods/analysis_execution_stage4.md).
5. [Technical specification, especially Section 8](methods/multiple_imputation_technical_spec_draft.md).

## Authoritative local artifacts

- Study imputation run: `data/processed/mi14_20261014_fourworker_v1/`.
- Accepted endpoint: `accepted_endpoint_020.rds` in that directory.
- Review: `output/tables/mi14_20261014_fourworker_v1_review020_v2_*` and
  corresponding figures in `output/figures/`.
- Final sensitivity: `output/tables/mi15_20261014_fourworker_v1_v2_*`.
- Final result/closure records:
  `data/processed/mi15_20261014_fourworker_v1_v2/completed_results.rds`
  and `phase_complete.rds`.
- Script 15 implements the unchanged survey-Cox formula and finite Barnard–Rubin
  pooling with survey complete-data df 91. It is not a new primary analysis.

Keep the precise version suffixes. The intermediate review020_v1 signed-AC
counts and MI15 v1 historical-comparison CI columns are invalid and retained
only for audit; the reports document their corrections. Final MI Q/U and pooling
were unchanged by the comparison-table correction.

Historical `review_endpoint_020.csv` still says `awaiting_diagnostic_review`;
it records execution-stage status. The later accepted-endpoint RDS and review
report supersede it. Likewise, old preparation reports saying no MI was run
are historical and must not be mistaken for current status.

## Repository and preservation

The implementation/reports were published to `origin/main` in commit `1af13ea`.
This continuity document is a subsequent housekeeping update. No frozen input,
checkpoint, statistical specification or protected result is changed by it.
A read-only check of the accepted endpoint and phase-completion hashes passed
when this continuity checkpoint was created; no supervisor/chain locks remained.

Code and reports are tracked on GitHub. Participant data, generated CSVs,
figures, models and checkpoints are deliberately ignored by Git and remain on
this computer. A Git clone alone does not restore those execution artifacts.
Keep the local `data/` and `output/` directories when switching projects.

Do not rerun `--prepare` with an existing run ID. Do not rerun completed scripts
to refresh timestamps, overwrite historical results, modify hashes to bypass a
guard or reset the repository. Review the saved manifests before any genuine
future re-execution. Changes to hashed study code/specification require a new
prospective execution plan, not silent reuse of an old plan.

## Next work

The first integrated methods/results draft, aggregate tables, three PNG/SVG
figures and a working STROBE/RECORD coverage map are now available. Remaining:

1. Write the introduction and literature-based discussion.
2. Finish measurement/recoding, linkage/data-access and software supplements;
   consolidate final cohort-flow, baseline and distribution presentations.
3. Obtain author/affiliation, ethics determination, funding/conflicts and target
   journal information; do not fill absent declarations by assumption.
4. Review the manuscript and reporting checklist before submission.

No new MI run or effect-driven selection is needed for these reporting tasks.
