# Stage 5: prepared four-worker study imputation

Date: 14 October 2026. The investigator accepted the four-worker strategy with
“ok, usemos esta estrategia”. This step implements and validates that strategy,
then prepares the study inputs; it does not launch study imputations or fit Cox
models. Section 8 of the technical specification records the prospective
execution changes. Scientific choices remain those in Section 7 and SAP v0.3.

## Concrete implementation

- `src/R/14_prepare_run_multiple_imputation.R`: separate preparation, verified
  status inspection, single-chain/iteration worker and diagnostic export.
- `src/R/14_run_multiple_imputation.py`: four single-thread processes, ascending
  chain queue, iteration barriers, RAM/disk admission and runtime guards,
  immutable checkpoints and explicit diagnostic endpoints.
- `00_functions_imputation_execution.R`: deterministic survey coding and
  transformations, masks/matrix, atomic save/read, strict invariants, compact
  continuation, between-target garbage collection and audited multinomial fits.
- `00_functions_imputation_review.R`: checkpoint-based traces, fit diagnostics,
  final missing-cell draws and last-ten-iteration review flags. It does not
  accept convergence or inspect CRP effect estimates.

Fifty independent L'Ecuyer-CMRG streams are generated prospectively from master
seed 20261013. Each chain has its own `m = 1` state and initialization/iteration
checkpoints. At most four chains run simultaneously; all reach the same
iteration before advancing. Scheduling does not change stream identity. This
is a new prospective stream allocation, not reproduction of a historical
sequential 50-chain RNG sequence.

The round-robin slot table documents intended scheduling groups; actual process
slots can change as workers finish. Only chain ID determines its RNG stream.
The supervisor stops at 20 iterations. A later explicit extension to 40 or 60
requires the previous endpoint and a written diagnostic review, archived with
a content hash. Methods are never automatically changed. No Cox/pooling stage
is implemented or invoked by this supervisor.

## Integrated synthetic checks

`14a_validate_execution_synthetic.R` creates 600 completely artificial records,
six cycles, twelve nested PSUs, six missing targets and four independent streams.
It exercises the exact study worker/supervisor for two iterations. It is a
small control for orchestration, not a new full-size resource or convergence
benchmark; the preceding 13i/13j/13k measurements retain that role.

Fixture v1 failed before fitting because MICE adds row names to `where`; the
prepared masks now explicitly carry data row names. The failed fixture remains
archived. Fixture v2 passed and is archived with its then-executed sources.
Fixture v3 validates the final disk/extension guards and final implementation.
All four chains reached iteration 2 with atomic checkpoint verification,
three accepted multinomial fits per iteration, no warnings/logged events and
successful diagnostic export.

`14b_check_execution_synthetic.R` passed **20 checks**: four exact checkpoint
replays, four matching optimizer audits, four matching trace captures, rejection
of changed input/mask/matrix/method, equality of instrumented/original multinomial
draws and RNG, and rejection of failed optimization and warnings. A second
supervisor invocation at the completed synthetic endpoint changed no checkpoint
SHA-256 hashes and ran no extra fits. Its resume control is archived separately.
This exercises save/read/replay and completed-run idempotence, not arbitrary
mid-fit termination or long-run 50-chain stability.

Evidence is in `data/processed/mi14_synthetic_execution_v3/` and the diagnostic
CSVs prefixed `mi14_synthetic_execution_v3_iter002` under `output/tables/`.
Small-fixture review flags are intentionally not calculated before ten iterations.

## Prepared study run, not started

Run ID: **20261014_fourworker_v1**.
Directory: `data/processed/mi14_20261014_fourworker_v1/`.

Preparation verified 27,755 eligible participants, 6,354 deaths, 26,818 complete
cases and 5,886 complete-case deaths, 937 incomplete participants, participant
ID uniqueness/complete-case membership, unchanged factor types, the four
0.5-month deaths, all accepted target missing counts, 89 strata and 180 nested
PSUs. The mapping contains exactly 83 stratum and 91 PSU columns. Frozen age
knots are read from `analysis_constants.rds`; knots are not estimated again.
The Nelson–Aalen auxiliary is computed once according to the accepted definition.

For preparation rank QC only, missing predictors are temporarily filled in a
separate copy with observed medians/modes. That copy is not saved as imputed
study data, not used to initialize MICE, and not used for analysis. All six
observed-target predictor matrices have full rank (199–202 columns), with
approximate conditioning 192–197. Each actual chain initialization will perform
another observed-row rank check with its own initialized predictor values.

The plan saves data/masks/methods/predictors, scale constants, frozen knots,
design mapping, 50 streams, chain IDs, R/package versions, session information
and hashes of cohort/constants/code/specification. Executed sources are copied
into its `sources/` directory. Real-data status inspection reports all 50
iterations as `NA`: **no real MICE initialization, conditional fit, imputation,
Cox estimate or pooling has been performed**. The preparation manifest records
its creation-stage status; this report records the subsequent completed checks.

## Invocation and remaining boundary

Preparation and status commands used:

```sh
Rscript src/R/14_prepare_run_multiple_imputation.R --prepare 20261014_fourworker_v1
Rscript src/R/14_prepare_run_multiple_imputation.R --status 20261014_fourworker_v1
```

The following is the **future execution command; it was not run in this step**:

```sh
python3 src/R/14_run_multiple_imputation.py 20261014_fourworker_v1 --endpoint 20
```

It checks available RAM against the measured four-worker envelope plus margin
(approximately 4.84 GiB), checks at least 8 GiB free disk, and stops if RAM
falls below 1 GiB or disk below 2 GiB. Immutable compressed checkpoints are
retained; study inputs and prior validated outputs are never overwritten.
Do not edit hashed code/specification/input files during a run. A changed hash
requires a new prospective plan, rather than silently resuming different code.
Inspect logs/processes before removing any lock left by a hard interruption.

Before final analysis, inspect trace plots and observed/imputed distributions,
including cycle/death groups and rare diabetes draws, document convergence
review and decide any prespecified extension without looking at pooled effects.
The exported flags/draws are inputs to that review, not its acceptance. A later
analysis script must restore observed BMI exactly, reconstruct the original
survey-Cox model with frozen knots and perform validated scalar pooling.

R source parsing, Python compilation and `git diff --check` passed. Study
execution, commits and push remain unperformed. Existing study estimates and
completed historical validation outputs remain preserved.
