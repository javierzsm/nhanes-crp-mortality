# Stage 5 resource optimization review

Date: 14 October 2026. Review before preparing Script 14. No study imputation,
primary-model rerun, package replacement, or system power change is performed.

## Measured memory and checkpoint cost

The archived 40-iteration synthetic `mids` has an R `object.size` of
1,908,483,392 bytes; its embedded call history accounts for 1,862,159,440 bytes.
These are R object accounting measurements, not peak resident memory or a
prediction of the real 50-chain run. The data frame alone is 21,901,736 bytes.
The previous `do.call(mice::mice.mids, list(obj = obj, ...))` embeds prior states
in calls. Use the already tested symbolic `continue_mice_compact` helper in
Script 14. Its small synthetic control preserved draws, RNG and chain moments.
A full-size equivalence test remains appropriate before study execution.

Replacing only the historical call expression in a copy of the final synthetic
artifact gave the following one-shot checkpoint measurements (includes other
validation fields, not just `mids`):

| Compression | Write seconds | Read seconds | Bytes |
| --- | ---: | ---: | ---: |
| Default gzip | 0.352 | 0.150 | 1,090,044 |
| None | 0.072 | 0.069 | 44,227,916 |

Retain gzip and atomic per-iteration checkpoints: saving a fraction of a second
is negligible compared with fitting time, while gzip greatly reduces storage.
Keep completed input/output archives immutable. Do not reconstruct all completed
large predictor frames for every trace: read missing-value draws directly from
`mids$imp`; complete and fit one analysis data frame at a time at the final stage.

## Execution choices

Current machine: eight physical cores, sixteen logical CPUs, approximately
13 GiB RAM and 8 GiB swap. At inspection only 4.2 GiB RAM was available and
2.3 GiB swap was occupied; this is a snapshot, not evidence that this validation
caused paging. The installed BLAS is the reference system BLAS. CPU boost was
reported disabled. Do not change global libraries or power settings as part of
this review.

Start with sequential execution and compact calls. Parallel workers duplicate
predictor frames and fitting workspaces; sixteen threads do not imply sixteen
independent workers are viable. If parallel chains are later considered, use
at most two workers initially, benchmark peak aggregate RSS and active runtime,
and assign deterministic independent RNG streams. Parallel chains change the
historical draw sequence and require a prospective reproducibility plan and
separate validation. Avoid nested BLAS/worker oversubscription.

A different BLAS could accelerate linear algebra, but is not assumed to speed
up multinomial optimizer work. It changes floating-point trajectories and may
change PMM donors/draws. Benchmark in an isolated environment before any adoption;
revalidate rather than replacing the validated environment immediately.

Avoid system suspension during unattended computation and reduce other heavy
applications before starting. These reduce wall-clock interruptions and memory
contention without changing the statistical model. They do not reduce the
intrinsic CPU work. Swap is a recovery buffer, not a speed optimization.

Retain 50 imputations, all accepted predictors, nominal categorical models,
PMM donors/ridge, missingness masks and convergence-based iteration decisions.
Do not reduce these to obtain a shorter runtime. Do not cache target-specific
fits or factorizations across iterations: the other imputed predictors change.
The large full-rank design coding is a statistical design choice; replacing it
with fewer columns, ordinal categories or a different multinomial engine would
require methodological review and new validation.

## Bounded synthetic timing profile

`13h_profile_imputation_resources_synthetic.R` profiles one continuation iteration
of one chain from a copy of the completed artificial 40-iteration state. It
replaces the diagnostic multinomial wrapper with the installed original method,
adds timing wrappers, sets benchmark seed 20261014, and compacts historical call
metadata. This is a performance sample, not a new convergence validation or an
exact comparison with the preceding run's draws. Saved study/synthetic states
are not modified. Timing wrappers preserve method return values.

| Target | Elapsed seconds |
| --- | ---: |
| BMI | 0.565 |
| Education | 31.780 |
| Smoking | 15.409 |
| Diabetes | 21.254 |
| Hypertension | 3.637 |
| Prevalent CVD | 3.731 |

Total continuation: 83.655 seconds; multinomial targets approximately 82%.
`nnet.default` occupied 76.15% of sampled runtime. Correlation work accounted for
approximately 6.77%. This limits likely benefits of BLAS substitution alone.
A simple 50-chain × 20-iteration scaling gives 23.2 active hours, consistent
with the earlier approximate one-day estimate; this is not a real-data forecast
or a measured before/after speedup. More iterations or a harder optimizer can
increase it. Whole-process peak RSS was 1.88 GiB, including loading the historical
large archive, so it is not an isolated compact-engine peak memory measurement.

Evidence: `output/tables/qc_13h_resource_profile_v1_{timings.csv,rprof.out,profile.log,resources.txt}`.
The checkpoint microbenchmark was one repetition; subsecond times should not
be interpreted as stable throughput estimates.

Priority for Script 14: compact continuation, minimal per-iteration diagnostics,
atomic compressed checkpoints, sequential completion/Cox fitting, and a memory
check immediately before launch. A two-worker timing/memory experiment and a
full-size compact-versus-original equivalence check can be performed on synthetic
data before any decision to parallelize. No runtime reduction from parallelism,
new BLAS, or power settings is claimed or implemented in this review.

## Full-size synthetic execution comparisons

The subsequent 13i benchmark uses the same 27,755 artificial participants and
all accepted predictor columns. Two one-chain states are copied from the
completed synthetic artifact; they share the same initial imputed values but
have distinct deterministic L'Ecuyer-CMRG streams (master seed 20261014).
This tests scheduling and continuation equivalence, not independent-chain
initialization or convergence. Every method, donor count, ridge and optimizer
limit is retained. Existing artifacts are not overwritten. Original and compact
continuations each run one iteration for each stream in separate fresh R
processes. The parallel phase runs those same two jobs concurrently; it does
not compare a new stream allocation with the old multi-chain RNG sequence.

| Execution | Wall seconds for two chains | Peak worker RSS |
| --- | ---: | ---: |
| Original, sequential | 188.08 | 946.48 MiB maximum single worker |
| Compact, sequential | 190.10 | 980.88 MiB maximum single worker |
| Compact, two concurrent workers | 99.18 | 1,832.45 MiB aggregate |

Two-worker speedup: 1.92×, or **47.8% lower wall time** than compact sequential.
Memory samples sum live worker RSS every 0.2 seconds, including startup,
checkpoint save/read and fitting. The table is worker memory, not total system
memory; shared pages may be counted twice and brief peaks may be missed. The
sequential phases' peak is their maximum, not the sum of peaks at different
times. Timings include process startup and checkpoint verification.

For stream 1, compact continuation reduces accounted `mids` bytes from
92,538,904 to 46,063,080; call metadata from 46,477,896 to 2,072; checkpoint
bytes from 2,025,139 to 1,010,143. There is **no demonstrated immediate runtime
or single-iteration peak-RSS reduction** from compact calls in this sample.
Their established benefit is preventing growth across subsequent iterations.

Original-versus-compact and sequential-versus-parallel comparisons preserve
imputations, chain means/variances, final RNG, iteration, original data, masks,
methods, predictor matrix and logged events exactly for both streams. Each
worker writes an atomic compressed checkpoint and checks a substantive
save/read round trip. An additional fresh process reloads the same input
checkpoint and replays stream 1; the final review checks exact output and RNG.
This recovery test concerns one continuation from a saved input; it is not a
multi-iteration parallel failure-injection experiment.

The runner is `src/R/13i_benchmark_imputation_execution_runner.py`; the worker
is `13i_benchmark_imputation_execution_synthetic.R`, and the review is
`13i_review_imputation_execution_benchmark.R`. Input/output checkpoints,
manifest, phase measurements and equality checks are archived under
`data/processed/qc_13i_execution_benchmark_v1/` (ignored by Git).

This is one comparison per configuration, not a replicated performance study.
Execution order, temperature, OS activity and real-data optimizer behavior can
alter the speedup. An approximately 12–15 hour two-worker run is a plausible
planning estimate derived from the previous 23–30 hour sequential estimate,
not a guarantee; checkpoint cadence, scheduling, longer iterations and final
analysis add uncertainty. Fifty chains and long-run memory stability were not
benchmarked here.

Recommendation for Script 14: compact continuation and **two independently
checkpointed workers**, with a fixed chain-to-stream mapping, consistent
iteration barriers for diagnostic review, no nested BLAS threading, and a
preflight memory check. Preserve 50 imputations and the prespecified iteration
review policy. Document the prospective parallel RNG plan before real execution;
parallel scheduling is reproducible under this plan but does not reproduce the
historical sequential multi-chain draw sequence. The study run is not launched
by these tests.

Final review: all five exact-equivalence/replay checks passed; no logged events
were produced. Executed worker, runner, review and compact-helper sources are
archived with SHA-256 hashes beside the benchmark artifacts. R parsing and
`git diff --check` passed. No study outputs, system configuration or installed
packages were changed; no commit or push was made.

## Requested approximately 60% CPU trial: memory preflight

Ten single-thread workers correspond to 62.5% of the sixteen logical CPUs
(eight physical cores with SMT); this is a worker budget, not a guarantee of
sustained utilization. Before launching them, 13j tested one full-size synthetic
chain with explicit garbage collection before/after each target fit. Methods,
predictors, optimizer settings and random streams were retained; only wrapper
names differ. The resulting imputations, chain moments, RNG and substantive
state exactly match the prior compact single-chain result.

Single-worker wall time was 99.59 seconds (96.39 seconds in continuation),
peak sampled RSS 876,108 KiB, or 855.57 MiB. This is about 13% below the earlier
compact single-worker peak, but each configuration has only one timing sample;
no immediate speed improvement is established. No logged events occurred.

The ten-worker admission estimate is deliberately conservative:
`10 * measured_worker_peak * 1.15 + 1 GiB reserve`, giving
11,123,818 KiB (10.61 GiB). Available RAM after preflight was 6,128,880 KiB
(5.85 GiB). Therefore **the ten-worker phase was not launched**. There is no
measured ten-worker speedup or utilization result. The estimate may overcount
shared pages and coincident peaks, but avoids relying on swap for performance.
The runtime guard also terminates benchmark workers if available RAM falls
below 1 GiB; it does not terminate unrelated applications. Swap-free changes
are whole-system observations and cannot be attributed solely to this test.

Sources: `src/R/13j_benchmark_cpu60_synthetic.R` and
`src/R/13j_benchmark_cpu60_runner.py`. Evidence is under
`data/processed/qc_13j_cpu60_benchmark_v1/`, including `preflight.json`,
`phases.csv`, memory samples, checkpoint, timing and `gc_equivalence.csv`.
The ten prepared stream inputs are not ten executed chains. Further execution
requires either substantially more available RAM or a smaller worker budget;
no system setting or unrelated process has been changed.

## User-selected four-worker follow-up

After the ten-worker memory preflight was rejected, the user selected a
four-worker trial. This corresponds to a maximum of 25% of sixteen logical
CPUs, rather than the original 60% request. `13k_benchmark_four_workers_runner.py`
uses the same 13j single-thread worker, garbage-collection wrappers and fixed
streams. Its four-worker preflight required 5,078,672.8 KiB; available RAM was
6,296,736 KiB. It first executes four chains concurrently and then the remaining
three sequential references; the previously measured stream-1 single-worker
run supplies the fourth reference. Thus all comparisons use identical work,
including checkpoints, rather than extrapolating from two different chains.

The four-worker phase completed in 99.316 seconds with peak aggregate worker
RSS 3,441,356 KiB (3.28 GiB). Minimum sampled available RAM was 2,514,792 KiB
(2.40 GiB); the 1-GiB memory guard did not trigger. Whole-system swap-free
space decreased by 1,800 KiB; this is not a per-process paging measurement.
Summed continuation CPU seconds exclude process startup and checkpoint I/O;
normalized by sixteen logical CPUs and phase wall duration, they provide an
approximate observed CPU fraction, not total machine utilization.

Like the two-worker benchmark, this is a single-iteration test of continued
synthetic states, not a test of 50-chain initialization or long-run convergence.
The admitted four workers should not be generalized to ten without a new
memory check. The explicit garbage collection adds overhead, so long-run time
and memory benefits remain to be verified during implementation validation.

Final four-stream comparison: all four exact-equivalence checks passed.
Sequential elapsed time was 371.522 seconds, parallel elapsed time 99.316
seconds: **3.74× speedup and 73.27% lower wall time**. Approximate worker CPU
use from continuation CPU accounting was 22.76% of sixteen logical CPUs
(maximum single-thread worker allocation: 25%). This is not a completed
60%-CPU experiment. No logged events were produced. The benchmark does not
change statistical methods, participant data or primary results.

The measurements and checks are `four_phases.csv`, `four_comparison.csv`,
`four_equivalence.csv`, per-worker checkpoints/timing, and sampled memory CSVs
in the 13j artifact directory. The review script is
`src/R/13k_review_four_workers_benchmark.R`. Executed follow-up sources are
archived with SHA-256 hashes. Parsing and whitespace checks passed.

Updated implementation recommendation: evaluate **four independently
checkpointed, single-thread workers with explicit between-target garbage
collection**, consistent diagnostics barriers and the prospective RNG stream
plan. Run the available-memory admission check before each launch and retain
a runtime memory guard. Ten workers remain untested and were not admitted on
the observed available RAM. Actual study execution still requires preparation
and review of Script 14; this benchmark does not launch it.
