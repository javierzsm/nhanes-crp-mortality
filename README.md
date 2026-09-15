# NHANES CRP and mortality study

Reproducible cohort study of baseline C-reactive protein and subsequent all-cause mortality among US adults participating in the National Health and Nutrition Examination Survey.

## Project status

**Analysis specification frozen before outcome analysis.**

The exposure, cycle, mortality-linkage, covariate and final eligibility audits are complete. No mortality outcome, follow-up distribution or exposure-outcome association was examined before specification freeze. Protocol version 0.3 and statistical analysis plan version 0.3 define the frozen analysis.

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

- [Protocol version 0.3](protocol/protocol_v0.3.qmd)
- [Statistical analysis plan version 0.3](protocol/sap_v0.3.qmd)

## Planned workflow

1. Complete and freeze the protocol.
2. Complete and freeze the statistical analysis plan.
3. Download and checksum the public source files.
4. Build and validate the analytic cohort.
5. Execute the pre-specified analysis.
6. Generate reproducible tables, figures and reporting checklists.

## Completed pre-outcome audit

The [CRP cycle audit](docs/audits/crp_cycle_audit.md) documents availability, measurement comparability, detection-limit handling, survey weights and mortality-linkage eligibility for 1999–2010. The [covariate audit](docs/audits/covariate_availability_audit.md) documents variable availability and preliminary pre-outcome missingness. The [eligibility and category-code audit](docs/audits/eligibility_category_audit.md) documents special-code recoding, pregnancy handling, participant uniqueness and the final pre-outcome cohort flow. The accompanying R scripts reproduce all inventories without reading mortality status or follow-up time.

After excluding 1,135 participants with confirmed pregnancy, 27,755 participants remain eligible for the primary cohort. Of these, 26,818, or 96.62%, have complete primary-model covariates. These counts precede mortality outcome processing.

## Author

Javier Zorrilla de San Martin

[LinkedIn](https://www.linkedin.com/in/javierzsm/)

ORCID: [0000-0003-2848-7482](https://orcid.org/0000-0003-2848-7482)
