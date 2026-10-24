# Commented methodological manuscript

Alternative learning document, originally prepared on 23 October 2026 and
revised in English on 24 October 2026. It complements the scientific manuscript
without replacing the protocol, SAP, or analyses. The legacy source filename
is retained for link compatibility; its full content is now English.

- Source: [methodological manuscript](manuscrito_metodologico_es.md).
- Local navigable reading copy: `manuscrito_metodologico_es.html`, built with Quarto.
- Thirty-four main sections explain rationale, alternatives, assumptions,
  mathematics, results, chronology, glossary, and fifteen questions with answers.
- `verificaciones.csv`: sixteen checks passed against the original source version.
- `auditoria_filtro_pesos.csv`: original read-only comparison of two-/four-year
  weight-positivity membership in the first two cycles.
- `fuentes_verificadas.csv`: original input and verification-script hashes.
- `mice_3.19.0_algoritmos_inspeccionados.R`: inspection snapshot of installed MICE
  functions, from MICE 3.19.0; the original package license applies. This is not
  new code to run MI.

Recreate the standalone HTML from the repository root:

```sh
XDG_CACHE_HOME=/tmp/nhanes-methodology-quarto-cache DENO_DIR=/tmp/nhanes-methodology-deno-cache quarto render reports/metodologia_comentada_v1/manuscrito_metodologico_es.md --to html
```

HTML uses native MathML and embedded resources, so reading does not require
external font or equation-engine downloads. External references need a network
connection when opened. Local links require the repository directory structure.
Generated HTML and auxiliary render assets remain excluded from Git.

The historical checks were produced by
`src/R/21_validate_methodological_manuscript.R`. Do not rerun that script to
replace existing validation files: it verifies the original wording and status,
including the then-pending amendment sensitivity. Current documentation checks
are recorded in the [English/rendering audit](../documentation_quality_v1/README.md).
The prior numerical checks remain historical evidence; changes to documentation
are disclosed rather than hidden by changing old hashes.

## Amendment 001 status

The original writing task identified an outstanding sensitivity excluding only
same-month deaths. This was completed later on 23 October. Only two of the four
affected eligible participants belonged to the primary complete-case sample.
The [sensitivity addendum](../same_month_death_sensitivity_v1/README.md) and
[current scientific manuscript](../stage6_v2/manuscript_methods_results.md)
report the result. The English companion incorporates that update.

## Scope limits

Inspection of `polyreg` is distinguished from a claim of exact posterior
parameter sampling. Passing programming checks does not establish MAR, calibration,
or Rubin coverage. Participant data, accepted checkpoints, and fitted results
remain unchanged. Documentation-only changes and their effects on historical
source-hash checks are recorded in the current audit.
