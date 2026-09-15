# Eligibility and category-code audit

## Status

Pre-outcome audit specification. Run `src/R/03_audit_eligibility_categories.R`
before freezing the protocol and statistical analysis plan. The script never
reads mortality status or follow-up time.

## Purpose

The earlier availability audit counted ordinary `NA` values. NHANES also uses
numeric codes for responses such as *refused* and *don't know*. Those codes
must be converted to missing values before complete-case eligibility is final.

The audit therefore:

1. inventories every observed categorical code by cycle;
2. recodes only documented valid categories as analyzable values;
3. recalculates missingness and complete-case retention;
4. counts confirmed pregnancy and unknown pregnancy status among women aged
   20–44 years;
5. verifies that participant identifiers are unique across pooled cycles;
6. confirms the previously established exposure and linkage denominators.

Confirmed pregnancy at examination is excluded from the primary cohort because
pregnancy changes CRP physiology and makes baseline BMI less comparable. An
indeterminate pregnancy status is retained in the primary cohort and excluded in
a sensitivity analysis.

## Planned coding rules

- Sex: `RIAGENDR` codes 1–2.
- Race and Hispanic origin: `RIDRETH1` codes 1–5.
- Education: `DMDEDUC2` codes 1–5.
- Smoking: never, former or current from valid `SMQ020` and `SMQ040` paths.
- Diabetes: `DIQ010` codes 1–3, retaining *borderline* as a separate category.
- Hypertension: `BPQ020` codes 1–2.
- Prevalent cardiovascular disease: yes if any component is affirmative; no
  only if every component is explicitly negative; otherwise missing.
- BMI: positive measured `BMXBMI` values.
- Income-to-poverty ratio: released values from 0 through 5.

## Outputs

- `output/tables/qc_03_category_codes.csv`
- `output/tables/qc_03_missingness_reclassified.csv`
- `output/tables/qc_03_eligibility_flow.csv`
- `output/tables/qc_03_duplicate_seqn.csv`

## Results

The audit confirmed 28,890 mortality-linkage-eligible participants and no
duplicate `SEQN` values. It identified 1,135 confirmed pregnancies, leaving
27,755 participants eligible for the primary cohort. After recoding numeric
special-missing codes, 26,818 participants, 96.62%, had complete primary-model
covariates. Adding income-to-poverty ratio reduced complete records to 24,683,
or 88.93% of the primary eligible cohort.

The primary cohort retains 209 participants aged 20–44 years whose pregnancy
status was indeterminate. Excluding these participants in the pre-specified
sensitivity leaves 27,546 eligible participants, of whom 26,638 have complete
primary-model covariates.
