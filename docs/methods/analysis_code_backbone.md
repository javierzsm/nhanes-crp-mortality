# Analysis code backbone

## Status

Implementation guide for the frozen pre-outcome specification tagged
`analysis-spec-v0.3`.

## Separation of responsibilities

- `00_config.R` contains shared constants and frozen analysis definitions.
- `00_functions_data.R` contains reusable ingestion, joining and recoding
  functions but performs no analysis when sourced.
- `04_build_analysis_cohort.R` is the first outcome-aware script. It constructs
  and validates the mortality-linked cohorts but fits no association model.

Later scripts will separately describe the cohort, construct the complex survey
design, fit the primary Cox models, evaluate the CRP spline, check assumptions,
run sensitivity analyses and generate presentation outputs.

## Data contracts

The cohort builder produces two local RDS files:

- `mortality_linked_eligible_cohort.rds`, which retains incomplete covariates for
  missing-data analyses;
- `primary_complete_case_cohort.rds`, which contains the frozen primary analysis
  population.

Both files are reproducible, local processed data and are not versioned. QC tables
record cohort reconciliation and mortality follow-up by survey cycle.

The cohort retains `follow_up_months_released` exactly as published by NCHS.
Four participants died in the same month as their MEC examination and therefore
have a released follow-up value of zero months. The analysis variable
`follow_up_months` assigns these records 0.5 months, the midpoint of the first
monthly interval. `zero_follow_up_death` identifies every affected record. This
prospective post-freeze decision is documented in amendment 001. A sensitivity
analysis will exclude these four participants.

## Defensive checks

The pipeline stops if it detects duplicate participant identifiers, non-unique
component records, invalid mortality status, unexpected zero or negative
follow-up, invalid weights or disagreement with the pre-outcome cohort counts.
These checks prevent an association model from running on an unreconciled cohort.

## Mortality fields

The 2019 public-use linked mortality file is parsed as a fixed-width file using
the NCHS layout: `SEQN` at positions 1–6, `ELIGSTAT` at 15, `MORTSTAT` at 16 and
`PERMTH_EXM` at 46–48. `PERMTH_EXM` is follow-up in person-months from the MEC
examination to death or administrative censoring on 31 December 2019.

NCHS notes that public follow-up time may include disclosure-protection
perturbation. The study uses the released values and will document this limitation.
