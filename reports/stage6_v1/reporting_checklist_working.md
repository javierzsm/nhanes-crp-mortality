# Working reporting checklist and remaining gaps

Date: 23 October 2026. This is an internal coverage map, not a signed declaration
of STROBE/RECORD compliance. Labels below are paraphrased; use the official
checklists for final submission. Manuscript section references point to
`manuscript_methods_results.md` in this directory. No page numbers are assigned
to an unpaginated draft.

Sources consulted:
[STROBE cohort checklist](https://www.strobe-statement.org/fileadmin/Strobe/uploads/checklists/STROBE_checklist_v4_cohort.pdf),
[RECORD checklist](https://www.record-statement.org/Files/checklist/RECORD%20Checklist.pdf).

| STROBE item | Coverage in current materials | Status / remaining action |
| --- | --- | --- |
| 1 Design and abstract | Title; analytical abstract | Draft; integrate final narrative and journal word count |
| 2 Scientific rationale | Not drafted | Literature review needed |
| 3 Objectives/hypotheses | Frozen SAP; methods context | Add explicit objectives to introduction |
| 4 Design | Methods: Design, participants and measurements | Draft covered |
| 5 Place/time | NHANES cycles, US target, mortality through 2019 | Verify exact access/data-release dates for supplement |
| 6 Eligibility/follow-up | Methods and cohort flow | Full flow diagram and source linkage description needed; no matching used |
| 7 Variables | Exposure/outcome/adjustment listed | Measurement/diagnostic definitions supplement needed |
| 8 Measurement sources | Audit/code references | Add per-variable instruments and comparability evidence |
| 9 Bias | Sensitivities, limitations | Expand bias direction and linkage/selection discussion |
| 10 Study size | All eligible available records | Draft covered; no retrospective power justification |
| 11 Quantitative handling | log2 CRP, splines, BMI, age cutpoint | Insert exact frozen knot values into supplement |
| 12 Statistical methods | Survey Cox, interactions, MI, sensitivities | Expand censoring/linkage assumptions and software versions in submission supplement |
| 13 Participant flow | Counts in results and flow CSV | Final diagram and exclusions before analytic candidate set remain to consolidate |
| 14 Descriptive/follow-up/missing data | Baseline CSV, missingness CSV and follow-up summary | Full formatted Table 1 and missingness supplement needed |
| 15 Events over time | Total deaths; Stage 3 period counts | Add period-event counts to presentation |
| 16 Main estimates/precision | Main/MI table; spline contrasts | Covariate-adjusted estimand intentional; no new unadjusted model added for checklist alone |
| 17 Additional analyses | Sensitivities, interactions, influence | Draft covered; preserve secondary status and late implementation disclosure |
| 18 Main findings | Interpretation paragraph | Expand discussion against objectives |
| 19 Limits | PH, nonlinearity, MAR and bias caveats | Expand plausible directions/magnitude without unsupported quantification |
| 20 Overall interpretation | Noncausal, secondary/multiplicity cautions | Literature comparison pending |
| 21 Applicability | Target population noted | Discuss cycle era, linkage eligibility and complete-case selection |
| 22 Funding | Not supplied | Author input needed; do not infer no funding |

## RECORD applicability map

NHANES examination data are purpose-collected survey measurements; the mortality
linkage introduces routinely collected outcome records. Apply RECORD where that
component makes an item relevant, rather than claiming that all study variables
are routine administrative data.

| Area | Current coverage | Remaining action |
| --- | --- | --- |
| Data identity, region, period, linkage (1.1–1.3) | Title/abstract/methods identify NHANES, US, cycles and linked mortality | Final title/abstract review |
| Selection and variable algorithms (6.1, 7.1) | Audits, source scripts and frozen eligibility | Prepare a reader-facing code/definition supplement |
| External algorithm validation (6.2) | No independent validation study conducted here | Identify existing source validation evidence; do not invent sensitivity/specificity |
| Linkage flow (6.3) | Linkage-eligible count and public-source join | Document NCHS linkage process and final flow diagram |
| Access, cleaning and linkage procedures (12.1–12.3) | Public input pipeline and code available | Explain accessible public fields, restricted fields, data cleaning and NCHS linkage quality |
| Linked-population selection (13.1) | Eligible/complete-case counts | Explain exclusions and unavailable/nonlinked source populations |
| Routine-data limitations (19.1) | Limitations identify selection/linkage | Add evidence-based misclassification and linkage discussion |
| Protocol/code/data access (22.1) | Frozen protocol, code and local manifests | State public source/code URLs; generated execution artifacts are not in Git |

## Author decisions still needed

- Final author list, affiliations and corresponding author.
- Applicable institutional ethics determination and wording.
- Funding, conflicts of interest and contributions.
- Target journal and preferred manuscript language/format.

No missing declaration is replaced with an assumed statement. These gaps do not
require rerunning the validated primary or MI analyses.
