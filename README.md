# NHANES CRP and mortality study

Reproducible cohort study of baseline C-reactive protein and subsequent all-cause mortality among US adults participating in the National Health and Nutrition Examination Survey.

## Project status

**Protocol development. No outcome analysis has been performed.**

The repository currently documents the research question and proposed methods. Specifications remain provisional until the protocol and statistical analysis plan are reviewed and frozen before outcome analysis.

## Preliminary research question

Among US adults aged 20 years or older, is a higher baseline concentration of C-reactive protein associated with subsequent all-cause mortality?

## Preliminary design

- Retrospective cohort analysis of continuous NHANES participants linked to public-use mortality records.
- Baseline cycles provisionally covering 1999–2000 through 2009–2010.
- Baseline CRP analyzed continuously on a base-2 logarithmic scale.
- All-cause mortality through 31 December 2019.
- Survey-weighted Cox proportional hazards regression.
- Restricted cubic splines to assess functional form.

## Methodological guide

The [Cox model guide](docs/methods/cox_model_explained.md) explains the complete model progressively, from censoring and risk sets to survey-weighted estimation and spline interpretation.

## Planned workflow

1. Audit variable availability and comparability across cycles.
2. Complete and freeze the protocol.
3. Complete and freeze the statistical analysis plan.
4. Download and checksum the public source files.
5. Build and validate the analytic cohort.
6. Execute the pre-specified analysis.
7. Generate reproducible tables, figures and reporting checklists.

## Author

Javier Zorrilla de San Martin  
ORCID: [0000-0003-2848-7482](https://orcid.org/0000-0003-2848-7482)
