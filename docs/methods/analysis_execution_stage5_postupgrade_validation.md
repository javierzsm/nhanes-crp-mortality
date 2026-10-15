# Stage 5: post-upgrade environment and extended synthetic diagnostics

**Dates:** Started 13 October 2026; final diagnostic review 14 October 2026
**Scope:** Synthetic validation only; no real-data MI or Script 14 execution

## Environment regression check

Script `13c_validate_postupgrade_environment.R` repeats the historical small
synthetic fixture from Script 13, under Ubuntu 26.04.1 LTS. Its purpose is to
check numerical operation of MICE, survey-Cox and scalar Rubin pooling after the
OS upgrade, without overwriting the historical fixture or study outputs.

The fixture uses 2,400 artificial participants, three chains and five iterations.
The method mapping and seed 20260927 are retained. Every historical QC value,
including the synthetic pooled coefficient and variance, matched with tolerance
1e-10. Observed/fixed values were preserved, targets were completed, all Cox
fits were finite, and no MICE logged events occurred. These are software
regression-test results, not study estimates or proof of imputation adequacy.

New outputs:

- `output/tables/qc_13c_postupgrade_environment.csv`
- `data/processed/qc_13c_postupgrade_environment.rds`

The RDS records the new session, RNG kind and script/historical-QC hashes.
R remains 4.6.1; MICE 3.19.0, survey 4.5, survival 3.8-12 and nnet 7.3-21
retain their previously validated versions. The OS and system package builds
changed, so old real-run checkpoints would not be considered interchangeable
without explicit validation.

## Extended synthetic execution

Script `13d_validate_imputation_extended_synthetic.R` retains the full 27,755
artificial records, three chains, six targets and 89-stratum/180-PSU design,
and runs **20 initial iterations**. It generates its data afresh under the
current OS, with seed 20261013. The new fixture explicitly matches the primary
race factor's level order; the earlier fixture had the same reference category
and labels but sorted the remaining levels alphabetically. This coding
correction precedes any new synthetic estimates and does not change methods.

The fixed predictor matrix, conditional methods and numerical optimization
settings follow the accepted Section 7 specification. Every iteration saves a
new checkpoint, full imputation RNG state and category-proportion/BMI summaries.
Resume requires identical code, diagnostic helper, specification, session and
predictor settings. The final iteration is replayed from its predecessor to
check exact recovery. Full-size batch equivalence already passed Script 13b;
it is not needlessly repeated for 20 iterations.

The diagnostic helper `00_functions_imputation_diagnostics.R` exports:

- Last-ten-iteration classic PSRF, largest absolute within-chain lag-1
  autocorrelation and changes between the final two five-iteration windows.
- BMI moments, quantiles and ranges, observed versus imputed, overall and by
  synthetic cycle/death status.
- Counts/proportions for every categorical level, including Borderline diabetes,
  separately by chain and overall/cycle/death group; empty groups retain NA.
- BMI and category traces, and observed/imputed BMI density plots.

Trace panels use black/solid for chain 1, red/dashed for chain 2 and
green/dotted for chain 3. The BMI density plot has its own observed/imputed
legend. These are diagnostic figures, not publication-ready study figures.

The helper uses the accepted 1.05/0.5/0.2 review thresholds. Constant traces
produce undefined diagnostics explicitly flagged for review. Classic PSRF is
reported by name, rather than represented as the exact newer MICE diagnostic.
Flags require examination, not automatic declaration of invalidity or a choice
of methods based on Cox agreement. Diagnostics are exported before fitting
synthetic Cox models. Observed/imputed distributions need not be identical.

Initial cost estimate: roughly 1.5–2 hours sequentially, using the prior
full-dimension benchmark. No parallel execution is used. No 50-chain study
execution is prepared by this step. Artifacts use a new
`qc_13d_extended_synthetic_v1` prefix and no-overwrite guards.

## Validation and recovery commands

Run from the repository root:

```sh
Rscript -e 'invisible(parse(file="src/R/13c_validate_postupgrade_environment.R")); invisible(parse(file="src/R/13d_validate_imputation_extended_synthetic.R")); invisible(parse(file="src/R/00_functions_imputation_diagnostics.R"))'
# Fresh execution refuses existing outputs.
Rscript src/R/13d_validate_imputation_extended_synthetic.R
# Only after interruption, with matching manifest and no completed outputs:
Rscript src/R/13d_validate_imputation_extended_synthetic.R --resume
git diff --check
```

## Recovery rejection controls

Script `13e_test_synthetic_checkpoint_rejections.R` exercises the actual resume
branch parsed from Script 13d, without any new MICE fits. A valid serialized
synthetic initialization is accepted; changed manifests, RNG state, predictor
matrices, methods and corrupt RDS contents are rejected. All six controls passed
and were saved to `output/tables/qc_13e_synthetic_checkpoint_rejections.csv`.

A separate small diagnostic-helper control with independent artificial
predictors completed without warnings: constant traces retain undefined PSRF
and are explicitly flagged, rather than passed by replacing NA with zero.

## Execution result

The environment regression check passed. The 20-iteration execution completed
successfully: all 180 original-path multinomial fits converged, MICE logged zero
events, all invariants and three synthetic survey-Cox fits passed, and the final
iteration replay reproduced imputation values, RNG state, traces and fit
records exactly. The trace export has 1,200 rows.

Measured wall time was 1 h 48 min 52 s, with peak RSS 2,596,332 KiB (2.48 GiB)
and GNU time reporting a `Swaps: 0` counter. This counter alone does not establish absence of paging or system swap use. Source, diagnostic helper, log and resources were
archived under the original prefix without overwriting historical outputs.

The automatic summaries flagged 15 of 20 variable/statistic combinations.
There was no constant aggregate trace. BMI mean and median had last-ten-
iteration classic PSRF of 1.144 and 1.216. The full-20-iteration complementary
values were 1.020 and 1.046, illustrating short-window sensitivity; these do not
override the prespecified review flags. Visual inspection did not show clear
monotonic drift, but the late-window chain differences require more evidence.

Final imputed BMI means across three chains were 27.300, 28.083 and 27.527,
versus observed 27.688. Their SDs were 4.332, 4.381 and 4.826, versus observed
4.539; draws remained in positive observed donor support. Observed/imputed
shapes were broadly plausible, not required to match exactly. Diabetes had 19
missing cells; final Borderline draws were 1, 1 and 0, retaining the level in
all datasets. Zero draws in one chain are not an automatic category failure.

## Prespecified continuation to 40 iterations

On review of these diagnostics, the previously specified 20-to-40 extension was
selected, before inspecting any real-data MI estimate and without changing
conditional methods, targets or predictors. Script
`13f_extend_imputation_synthetic_40.R` continues the same chains at iteration 21
from the completed synthetic `mids`, restoring its continuation RNG state. It
regenerates only the artificial fixture to verify exact input and transformation
identity, and checks parent source/helper/specification hashes, session,
methods, normalized MICE missing-cell mask and predictor matrix. An initial
mask comparison was corrected to compare MICE's normalized `where` object with
the newly initialized counterpart; no draws occurred in the refused attempt.

New checkpoints start at iteration 20 under prefix
`qc_13f_extended_synthetic40_v1`; iterations 21–40 extend the existing histories,
rather than create new chains or count old draws as new imputations. The parent
validation hash is included in the manifest. A separate final-iteration replay
checks exact recovery. The 20-iteration output remains immutable.

The extension completed; the detailed review and remaining execution boundaries are recorded below. Existing
methods are not selected for agreement with a Cox coefficient. No real-data MI,
Script 14, study-result replacement, commit or push has occurred.


Continuation commands from the repository root:

```sh
Rscript src/R/13f_extend_imputation_synthetic_40.R
# If interrupted, with matching state and no completed outputs:
Rscript src/R/13f_extend_imputation_synthetic_40.R --resume
```


## Continuation call-history resource control

Inspection identified a resource issue in the earlier `do.call()` wrapper:
`match.call()` can embed the passed `mids` object, recursively retaining prior
call records. The current 40-iteration run is retained with its original code
and manifest; its outputs must not be represented as using the compact helper.

`00_functions_imputation_continuation.R` provides an explicit symbolic call with
the same numerical settings. A five-step, three-chain synthetic control compared
both pathways: imputations, continuation RNG and chain moments were exactly
identical at every step. Call metadata measured 2,376,624 bytes in the embedded
path versus 2,072 bytes in the symbolic path. Results were saved in
`output/tables/qc_imputation_compact_continuation_control.csv`.

Use this evidence when designing later checkpoints; avoid extrapolating memory
from an unnecessarily nested provenance call. Preserve source/settings in the
manifest. This resource control does not change conditional models, methods,
seeds or observed data, and has not executed a study imputation.


## System suspension during continuation

The 40-iteration continuation remained alive across system suspension. Kernel
logs record suspension on 13 October 2026 at 21:03:22 CEST and exit on 14 October
at 09:07:08 CEST; a shorter suspension occurred on 13 October from 20:25:49 to
20:31:16. Checkpoint 29 preceded the overnight suspension and checkpoint 30
was saved after wake. This interval is not an R model failure or a fresh-chain
restart. Report wall duration separately from active CPU cost and do not scale
an overnight suspended wall duration to estimate the study run's compute cost.


## Forty-iteration result and diagnostic review

The continuation finished on 14 October 2026. All 360 original-path multinomial
fits across the complete 40-iteration history converged, with zero MICE logged
events. Targets were complete; observed/fixed values, IDs and factor levels
were preserved. All three synthetic survey-Cox fits and scalar Rubin/finite-df
checks passed. The final-iteration replay reproduced imputations, RNG, traces
and fit records exactly. CSV diagnostics agree with saved state within 1e-12,
and the first 20 trace iterations are unchanged. Parent, source, helper and
specification hashes were verified. Figures were visually inspected.

The last-ten-iteration summaries retain **14 review flags**. They are not
rewritten as passing values. BMI mean and median PSRF improved to 1.015 and
0.975. Remaining flags include BMI variance PSRF 1.054, smoking-current PSRF
1.176, short-window changes and absolute autocorrelation. Signed inspection
shows BMI variance and p5 flags are negative lag-1 correlations (-0.707 and
-0.701), rather than evidence of a persistent positive serial trend; education
college/above has positive lag-1 0.683 in one short window. These are review
findings, not universal rules establishing convergence.

Complementary review explicitly reports **all** 10/20/30/40-iteration windows,
rather than selecting a favorable window. In the full 40 history every classic
PSRF is below 1.05 (maximum 1.046); the last-30 maximum is 1.037. Smoking-current
still has last-20 PSRF 1.058. No constant chain was found in those summaries.
Visual traces show overlapping, fluctuating chains without convincing sustained
monotonic drift. Short summaries from three chains remain noisy and cannot
establish adequacy of a real-data imputation model.

Final imputed BMI means are 27.908, 27.508 and 27.857; SDs are 4.557, 4.485 and
4.695, versus observed mean 27.688 and SD 4.539. Densities are broadly plausible
and draws remain within positive donor support. Final Borderline diabetes draws
are 0/19 in each chain, with the observed category retained and nonzero draws
visible earlier in the traces. With only 19 missing cells, this endpoint alone
does not justify forcing or merging a category. No category was collapsed.

**Review decision:** Complete the synthetic software/diagnostic review at 40,
retaining and disclosing residual short-window flags. The original BMI chain
separation does not persist in the extended history. Do not extend solely to
seek a last-ten window with no flags. This supports proceeding to implementation
planning, not a claim that MAR, survey-aware MI adequacy, real-data convergence
or exact substantive-model compatibility has been demonstrated. Real-data MI
still requires its own diagnostic review before Cox result inspection.

Review reproduction: `13g_review_extended_synthetic_diagnostics.R` exports all
window summaries and signed chain autocorrelations. Its numerical summaries
match the separately recorded interactive review within 1e-12. The raw
execution CSV correctly retains `convergence_review_complete = 0`, because
manual review happened later; this document records that subsequent qualified
review without modifying a completed run's automated QC.

## Resource measurements and next implementation boundary

The continuation consumed 6,046.13 seconds of user CPU and 76.41 seconds of
system CPU (about 1 h 42 min combined), with peak RSS 4,727,436 KiB (4.51 GiB).
Wall duration was 13 h 51 min 20 s and includes the verified suspension
intervals. It must not be presented as active compute time. The 39-iteration
recovery checkpoint is 41,234,307 bytes. The nested-call issue explains an
avoidable resource cost; use the tested compact symbolic continuation before
any study execution. The study runtime estimate remains approximately one day
of sequential active computation, with real-data uncertainty and possible
iteration extensions.

Before Script 14: close the prospective execution settings, incorporate compact
call provenance, input/constants hashes and no-overwrite output boundaries,
and review checkpoint cadence. Recommend **one completed iteration per
checkpoint** instead of five: one real iteration may already take roughly an
hour, and the more frequent checkpoint is an implementation recovery choice,
not a statistical-method change. Preserve all original study outputs and use
fresh run identifiers. No 50-imputation study run or Script 14 was prepared or
executed in this validation step; no commit or push was made.


Read-only final validation commands (completed outputs are preserved):

```sh
Rscript -e 'for (f in c("src/R/13c_validate_postupgrade_environment.R", "src/R/13d_validate_imputation_extended_synthetic.R", "src/R/13e_test_synthetic_checkpoint_rejections.R", "src/R/13f_extend_imputation_synthetic_40.R", "src/R/13g_review_extended_synthetic_diagnostics.R", "src/R/00_functions_imputation_diagnostics.R", "src/R/00_functions_imputation_continuation.R")) invisible(parse(file=f))'
Rscript -e 'print(read.csv("output/tables/qc_13f_extended_synthetic40_v1_convergence.csv"))'
git diff --check
```
