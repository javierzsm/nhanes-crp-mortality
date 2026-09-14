# Covariate availability and missingness audit

**Status:** Pre-outcome audit, 14 September 2026. The audit did not read mortality status, follow-up time or CRP-mortality associations.

## Population audited

The audit included 28,890 adults with baseline CRP, a positive MEC weight and eligibility for public-use mortality linkage across the six 1999–2010 cycles.

## Availability

All six cycles contain the planned variables with stable public variable names:

| Construct | NHANES variables | Planned coding |
|---|---|---|
| Age | `RIDAGEYR` | Continuous; spline specification to be frozen |
| Sex | `RIAGENDR` | NHANES categories |
| Race and Hispanic origin | `RIDRETH1` | Common five-category coding available across cycles |
| Education | `DMDEDUC2` | Adult educational attainment categories |
| Smoking | `SMQ020`, `SMQ040` | Never, former, current |
| Body mass index | `BMXBMI` | Continuous kg/m² |
| Diabetes | `DIQ010` | Doctor-diagnosed diabetes; borderline handled separately |
| Hypertension | `BPQ020` | Doctor-diagnosed hypertension |
| Prevalent cardiovascular disease | `MCQ160B`–`MCQ160F` | Any heart failure, coronary disease, angina, myocardial infarction or stroke |
| Income-to-poverty ratio | `INDFMPIR` | Continuous; sensitivity model only |
| Survey design | `WTMEC2YR`, `WTMEC4YR`, `SDMVSTRA`, `SDMVPSU` | Cycle-specific combined MEC design |

`SMQ040` is asked only of ever-smokers. Its structural absence among never-smokers is not missing smoking status when `SMQ020` identifies never smoking.

## Missingness before outcome analysis

| Variable or derived construct | Missing, n | Missing, % |
|---|---:|---:|
| Age | 0 | 0.00 |
| Sex | 0 | 0.00 |
| Race and Hispanic origin | 0 | 0.00 |
| Education | 1 | <0.01 |
| Smoking status | 31 | 0.11 |
| Body mass index | 590 | 2.04 |
| Diabetes | 2 | 0.01 |
| Hypertension | 116 | 0.40 |
| Prevalent cardiovascular disease | 147 | 0.51 |
| Income-to-poverty ratio | 2,320 | 8.03 |

Complete primary-model covariates are available for 28,031 participants, or 97.03%. Adding income-to-poverty ratio reduces complete records to 25,800, or 89.30%.

## Consequences for the SAP

The primary analysis will use complete primary-model covariates. A multiple-imputation sensitivity analysis will assess the effect of missingness. Income-to-poverty ratio will be added only in a sensitivity model because its missingness is substantially greater and education already provides a more complete socioeconomic adjustment variable.

The next audit must verify category codes, including refused, unknown and borderline responses, before the analytic dataset is constructed.
