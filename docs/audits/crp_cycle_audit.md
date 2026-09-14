# CRP cycle and mortality-linkage audit

**Status:** Pre-outcome audit, 14 September 2026. Mortality status, follow-up time and CRP-mortality associations were not examined.

## Conclusion

The six continuous NHANES cycles from 1999–2000 through 2009–2010 are eligible for the planned analysis. Each contains public baseline CRP as `LBXCRP` in mg/dL, covers adults aged 20 years or older and documents latex-enhanced nephelometry using a Behring Nephelometer. No cycle-specific CRP weight is required; the applicable MEC examination weight is used.

## Cycle inventory

| Cycle | CRP file | Adult CRP with positive MEC weight | Below-detection fill value | Mortality-linkage ineligible | Weight source |
|---|---|---:|---:|---:|---|
| 1999–2000 | `LAB11` | 4,145 | 97 | 3 | `WTMEC4YR × 4/12` |
| 2001–2002 | `L11_B` | 4,729 | 114 | 5 | `WTMEC4YR × 4/12` |
| 2003–2004 | `L11_C` | 4,487 | 72 | 9 | `WTMEC2YR × 2/12` |
| 2005–2006 | `CRP_D` | 4,492 | 92 | 1 | `WTMEC2YR × 2/12` |
| 2007–2008 | `CRP_E` | 5,343 | 131 | 6 | `WTMEC2YR × 2/12` |
| 2009–2010 | `CRP_F` | 5,728 | 178 | 10 | `WTMEC2YR × 2/12` |
| **Total** |  | **28,924** | **684** | **34** |  |

Counts precede other eligibility exclusions and covariate completeness rules. The 34 linkage-ineligible participants represent approximately 0.12% of adults with CRP and positive MEC weight.

## Units and detection limit

`LBXCRP` is released in mg/dL and will be multiplied by 10 for analysis in mg/L. Across all six files, 0.01 mg/dL is the below-detection fill value. The documentation identifies 0.02 mg/dL as the detection limit and describes substitution by the detection limit divided by the square root of two. The 2009–2010 documentation contains an inconsistent unit label in its detection-limit note; the variable label, observed range and preceding cycle documentation support interpreting the value as mg/dL.

The primary analysis will retain the released fill value. Sensitivity analyses will substitute 0.02 mg/dL and exclude below-detection observations.

## Measurement comparability

All six cycle documents describe latex-enhanced nephelometry and a Behring Nephelometer. The 2003–2004, 2005–2006, 2007–2008 and 2009–2010 documentation states that equipment, method or laboratory site did not change from the preceding cycle. This supports pooling, with survey cycle retained in the model to account for baseline-period differences.

## Weight construction

NHANES provides four-year MEC weights for 1999–2002. For a 12-year pooled analysis, those weights contribute four of the twelve represented years and are multiplied by `4/12`. The remaining two-year MEC weights contribute two of the twelve years and are multiplied by `2/12`. Applying `WTMEC2YR/6` to every cycle would incorrectly ignore the special 1999–2002 weighting structure.

## Mortality linkage

The 2019 public-use Linked Mortality Files provide `ELIGSTAT`, `MORTSTAT`, `PERMTH_INT` and `PERMTH_EXM`. This audit read only `SEQN` and `ELIGSTAT`. Linkage-ineligible participants will be excluded and reported; no additional eligibility weight will be estimated.

## Official sources

- [NHANES questionnaires, datasets and documentation](https://wwwn.cdc.gov/nchs/nhanes/)
- [NHANES survey methods and analytic guidelines](https://wwwn.cdc.gov/nchs/nhanes/analyticguidelines.aspx)
- [Public-use Linked Mortality Files through 2019](https://ftp.cdc.gov/pub/Health_Statistics/NCHS/datalinkage/linked_mortality/)
- [Using NCHS linked data](https://www.cdc.gov/nchs/linked-data/about-access/index.html)

## Remaining pre-outcome work

- verify value coding and missingness for every adjustment variable;
- finalize the causal diagram and distinguish primary from explanatory adjustment;
- freeze missing-data rules;
- render and review the protocol and SAP;
- tag the frozen specifications before reading mortality outcomes.
