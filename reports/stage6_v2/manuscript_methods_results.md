# Baseline C-reactive protein and all-cause mortality in US adults: a survey-weighted NHANES cohort study

**Working methods/results draft v0.2 — 23 October 2026.** Not submission-ready. Introduction, external literature discussion, author information, ethics determination, funding and disclosure statements require completion. Numbers are assembled from validated saved outputs; no new model selection is performed.

## Abstract: analytical summary

We analyzed NHANES 1999–2010 linked to public-use mortality records through 2019. The complete-case analysis included 26,818 adults and 5,886 deaths. The adjusted survey-weighted hazard ratio per doubling of baseline CRP was 1.130 (1.109–1.151); the secondary 50-imputation estimate was 1.135 (1.115–1.156).
The CRP spline supported nonlinearity (p <0.001). The association varied across follow-up periods (interaction p = 0.043); secondary effect modification was observed by age group (p = 0.021), while the sex interaction was not clearly supported (p = 0.284). These findings describe adjusted prognostic associations and do not establish causality.

## Methods

### Design, participants and measurements

This secondary cohort analysis pooled six NHANES cycles from 1999–2000 through 2009–2010, representing the civilian noninstitutionalized US adult population. Adults aged at least 20 years with positive baseline CRP, positive applicable MEC weight and public mortality-linkage eligibility were considered. Confirmed pregnancy was excluded. Indeterminate pregnancy status at ages 20–44 was retained primarily and examined in a sensitivity analysis. The study size comprises available eligible records rather than an outcome-driven sample-size calculation.

CRP was converted from mg/dL to mg/L and analyzed on the base-2 logarithmic scale. Released below-detection fill values were retained primarily. All-cause mortality status and MEC-examination follow-up months came from the public-use mortality linkage through 31 December 2019. Four same-month deaths in the eligible cohort were assigned 0.5 months under Amendment 001; two belonged to the primary complete-case sample. Original released follow-up was retained separately. Detailed covariate definitions and recoding algorithms are documented in the audit reports and data-construction scripts; these must be incorporated into a measurement supplement before submission.

### Survey and primary modeling

Primary inference used pooled MEC weights (WTMEC4YR/3 for 1999–2002; WTMEC2YR/6 for 2003–2010), strata and nested PSUs. There were 89 strata and 180 PSUs (91 design degrees of freedom). Survey-weighted Cox models used elapsed months from examination, Efron ties and design-based covariance. CRP was linear in log2 units in the primary model. Age used three natural-cubic spline terms with four percentile locations frozen before outcome modeling. The demographic model adjusted for age, sex, race/Hispanic origin and cycle. Primary adjustment additionally included education, smoking, BMI, diabetes, hypertension and prevalent CVD; covariates were not screened or selected for significance.

### Functional form, follow-up variation and secondary interactions

A restricted-cubic spline of log2(CRP), with frozen weighted percentile knots, assessed nonlinearity; planned contrasts compared 2, 4 and 8 mg/L with 1 mg/L. Design-based Wald F tests evaluated global association/nonlinearity. Amendment 002 replaced the planned log-time interaction with four follow-up periods (0–5, >5–10, >10–15, >15 years), estimated with counting-process Cox models and 180 sequential JKn replicates. A global three-df contrast tested equality of period-specific CRP coefficients. The constant primary HR is therefore an overall working-model summary, not a uniform effect at every CRP value or follow-up time.

Separate SAP-prespecified secondary models added CRP-by-sex and CRP-by-age-group (20–64 versus 65+) interactions. Both retained the primary covariates and continuous-age spline. The age-group model also included the group main effect to preserve hierarchy. Group HRs and their covariance-based normal intervals were linear contrasts of each interaction model; interaction tests used design-based Wald F tests with model-residual denominator df. The hypotheses and age boundary were prespecified; the detailed implementation was recorded on 23 October 2026 after other study results were known, before these estimates. Secondary tests received no general multiplicity correction and are interpreted cautiously.

### Missing covariates and sensitivities

Complete cases were primary. Fifty independent MICE chains provided a secondary missing-covariate sensitivity, with PMM for BMI, multinomial models for education/smoking/diabetes and binary logistic models for hypertension/CVD. Imputation predictors included analysis covariates, CRP, death, an unweighted marginal Nelson–Aalen auxiliary, log survey weight and a full-rank cycle/stratum/PSU representation. Exposure, outcome, follow-up and survey fields were not imputed. The three fixed age terms used frozen knots. Diagnostic review accepted 20 iterations before outcome-model fitting; short-window autocorrelation flags, rare categories and extreme observed BMI donors were retained and disclosed.

The unchanged primary survey-Cox model was fitted within each completed set; coefficients/design variances were combined with scalar Rubin rules and finite Barnard–Rubin t inference (complete-data survey df 91). This interval convention differs from the primary asymptotic Wald convention. Imputation assumes a working MAR mechanism conditional on included predictors and does not prove model adequacy. Prespecified sensitivities addressed early deaths, CRP >10 mg/L, below-detection handling, income adjustment, indeterminate pregnancy and an unweighted diagnostic; Amendment 003 introduced linear age after primary-result review.

As specified in Amendment 001, we repeated the primary complete-case survey-weighted Cox analysis after excluding same-month deaths with zero released follow-up. We retained the original covariate formula, age-spline knots, weights and survey design through subsetting. Of the four affected eligible participants, two were already absent from the primary model because of incomplete covariates, leaving two additional exclusions. This sensitivity used the primary normal-Wald interval convention. It was executed on 23 October 2026 after the initial reporting draft identified the outstanding amendment commitment.

### Influence diagnostics and transparency

Weighted DFBETA residuals from the saved primary Cox model described first-order coefficient contributions at participant and nested-PSU levels. Their absolute CRP component was scaled by the original design-based SE. Grouped residuals were checked against independently summed individual contributions. These are approximate diagnostics, not exact deletion refits or hypothesis tests; no participant/PSU was removed or pass/fail cutoff applied. The frozen SAP and numbered amendments remain unchanged; the present reporting reconciliation discloses previously unimplemented secondary items.

## Results

### Participants and baseline profile

Of 28,924 adults with positive CRP and MEC weight, 28,890 were eligible for mortality linkage; excluding 1,135 confirmed pregnancies left 27,755 eligible participants. Primary covariates were complete for 26,818 (96.62%); 937 had at least one missing target. The complete-case cohort contained 5,886 deaths, versus 6,354 in the eligible cohort.
Unweighted observed follow-up totaled 346575.2 person-years (median 12.75 years). Survey-weighted mean age was 46.69 years, median CRP 1.90 mg/L and median follow-up 13.75 years. Weighted and unweighted summaries are distinguished; observed deaths are not weighted population counts.

### Primary and imputed estimates

| Analysis | Participants | Deaths | HR (95% CI) |
| --- | --- | --- | --- |
| Demographic | 26818 | 5886 | 1.161 (1.140–1.183) |
| Primary | 26818 | 5886 | 1.130 (1.109–1.151) |
| Multiple imputation | 27755 | 6354 | 1.135 (1.115–1.156) |

Intervals for demographic/primary models use the original asymptotic normal convention; MI uses finite Barnard–Rubin t inference. The MI result is secondary and does not replace the complete-case estimand.

### Nonlinearity and follow-up variation

CRP nonlinearity was supported (F = 9.169, df 2 and 65; p <0.001). Spline contrasts for 2, 4 and 8 mg/L versus 1 mg/L were respectively 1.102 (1.051–1.155), 1.275 (1.172–1.386) and 1.507 (1.387–1.637).

| Period | HR per doubling (95% CI) |
| --- | --- |
| 0-5 years | 1.180 (1.137–1.224) |
| >5-10 years | 1.109 (1.074–1.145) |
| >10-15 years | 1.096 (1.055–1.140) |
| >15 years | 1.156 (1.076–1.241) |

The global period-interaction test was F = 2.824 (df 3, 91), p = 0.043. The pattern was not monotonically declining: the >15-year estimate increased relative to the preceding interval and had less precision. Period boundaries are analytical rather than biological thresholds.

### Secondary effect modification

| Modifier | Group | N | Deaths | HR per doubling (95% CI) |
| --- | --- | --- | --- | --- |
| sex | Male | 13376 | 3276 | 1.143 (1.117–1.170) |
| sex | Female | 13442 | 2610 | 1.115 (1.076–1.155) |
| age_group | 20-64 | 19901 | 1743 | 1.164 (1.126–1.202) |
| age_group | 65+ | 6917 | 4143 | 1.108 (1.083–1.134) |

| modifier | test | numerator_df | denominator_df | f_statistic | p_value |
| --- | --- | --- | --- | --- | --- |
| sex | CRP by sex | 1 | 66 | 1.16743136081226 | 0.283862125045434 |
| age_group | CRP by age_group | 1 | 65 | 5.5754685575007 | 0.021221727098711 |

The age interaction suggests heterogeneity of the linear summary on the multiplicative hazard scale; it does not establish a biological threshold at 65, modification on the absolute-risk scale, or a pattern invariant over time. The sex interaction does not establish equivalence of associations. Neither result warrants choosing a new primary model.

### Sensitivities and influence

| Analysis | N | Deaths | HR (95% CI) |
| --- | --- | --- | --- |
| Primary reference | 26818 | 5886 | 1.130 (1.109–1.151) |
| Exclude same-month deaths (Amendment 001) | 26816 | 5884 | 1.130 (1.109–1.151) |
| Exclude deaths within 12 months | 26575 | 5643 | 1.116 (1.095–1.138) |
| Exclude deaths within 24 months | 26251 | 5319 | 1.108 (1.086–1.130) |
| Exclude CRP > 10 mg/L | 24037 | 5032 | 1.101 (1.073–1.129) |
| Replace below-detection CRP with 0.02 mg/dL | 26818 | 5886 | 1.134 (1.112–1.155) |
| Exclude below-detection CRP | 26158 | 5823 | 1.141 (1.119–1.162) |
| Add family income-to-poverty ratio | 24683 | 5348 | 1.121 (1.099–1.143) |
| Unweighted diagnostic | 26818 | 5886 | 1.117 (1.099–1.135) |
| Exclude indeterminate pregnancy status, ages 20-44 | 26638 | 5880 | 1.129 (1.109–1.151) |
| Sensitivity: linear age | 26818 | 5886 | 1.126 (1.105–1.147) |
| Multiple imputation | 27755 | 6354 | 1.135 (1.115–1.156) |

Excluding the two same-month deaths present in the primary sample yielded an HR of 1.129632 (95% CI 1.108576–1.151088), compared with 1.129854 (1.108762–1.151347) in the primary analysis. The relative change in the HR was −0.01965%, indicating little influence of the 0.5-month midpoint convention on this estimate; this was not a formal equivalence test. Additional precision is shown here because both estimates round to the same three-decimal values in the table.

The unweighted row is diagnostic only. Early-death exclusions remove deaths at or before the specified threshold, not a landmark cohort. Income adjustment changes both sample and adjustment set. Linear age was defined after primary results and is disclosed as such. These sensitivities do not resolve nonlinearity, PH departures or potential unmeasured bias.
Maximum absolute first-order CRP contributions were 0.147 design SE at participant level and 0.243 at PSU level. These approximate diagnostics describe concentration; no deletions or exact leave-one-out claims are made.

## Interpretation and work still required

The adjusted CRP–mortality association is positive in the primary and sensitivity analyses. Its nonlinear form and variation over follow-up limit interpretation of a single HR. These are secondary observational prognostic associations, not evidence that changing CRP causes mortality changes. Residual confounding, selection/linkage eligibility, one-time exposure measurement, conditional-model/MAR assumptions and multiple secondary testing remain relevant limitations.

Before submission: complete source-based background/discussion; verify author/affiliation, ethics, funding and conflicts; specify data-access/linkage restrictions and external validation of recoding/definitions; finish measurement supplement; review target-journal format and reporting checklists. Do not claim RECORD/STROBE compliance solely because a checklist exists.

## Reproducibility

The initial v0.1 draft was assembled by `src/R/18_build_reporting_package.R` from existing validated aggregate outputs and the new prespecified secondary outputs. Input/code hashes and copied aggregate tables accompany this package. It does not replace or overwrite source analysis outputs. No new primary or MI model was fitted by this reporting script.

Version v0.2 integrates the Amendment 001 sensitivity from `src/R/22_sensitivity_same_month_deaths.R`, with its [comparison and 14 validation checks](../same_month_death_sensitivity_v1/README.md). The [original v0.1 reporting package](../stage6_v1/manuscript_methods_results.md), its manifests and accepted analysis outputs remain unchanged. The revision and source hashes are recorded in this version’s validation files. Figures, the reporting checklist and unchanged aggregate tables remain in `reports/stage6_v1/`; the additional sensitivity table remains in `reports/same_month_death_sensitivity_v1/`.
