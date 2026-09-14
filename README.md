# NHANES CRP and mortality study

Reproducible cohort study of baseline C-reactive protein and subsequent all-cause mortality among US adults participating in the National Health and Nutrition Examination Survey.

## Project status

**Protocol development. No outcome analysis has been performed.**

The exposure, cycle and mortality-linkage audits are complete. No mortality outcome or exposure-outcome association has been examined. Remaining specifications must be completed, reviewed and frozen before outcome analysis.

## Preliminary research question

Among US adults aged 20 years or older, is a higher baseline concentration of C-reactive protein associated with subsequent all-cause mortality?

## Preliminary design

- Retrospective cohort analysis of continuous NHANES participants linked to public-use mortality records.
- Baseline cycles covering 1999–2000 through 2009–2010.
- Baseline CRP analyzed continuously on a base-2 logarithmic scale.
- All-cause mortality through 31 December 2019.
- Survey-weighted Cox proportional hazards regression.
- Restricted cubic splines to assess functional form.

## Methodological guide

The [Cox model guide](docs/methods/cox_model_explained.md) explains the complete model progressively, from censoring and risk sets to survey-weighted estimation and spline interpretation.

Current development documents:

- [Protocol version 0.2](protocol/protocol_v0.2.qmd)
- [Statistical analysis plan version 0.2](protocol/sap_v0.2.qmd)

## Planned workflow

1. Complete and freeze the protocol.
2. Complete and freeze the statistical analysis plan.
3. Download and checksum the public source files.
4. Build and validate the analytic cohort.
5. Execute the pre-specified analysis.
6. Generate reproducible tables, figures and reporting checklists.

## Completed pre-outcome audit

The [CRP cycle audit](docs/audits/crp_cycle_audit.md) documents availability, measurement comparability, detection-limit handling, survey weights and mortality-linkage eligibility for 1999–2010. The [covariate audit](docs/audits/covariate_availability_audit.md) documents variable availability and pre-outcome missingness. The accompanying R scripts reproduce both inventories without reading mortality status or follow-up time.

## Author

Javier Zorrilla de San Martin  
ORCID: [0000-0003-2848-7482](https://orcid.org/0000-0003-2848-7482)
