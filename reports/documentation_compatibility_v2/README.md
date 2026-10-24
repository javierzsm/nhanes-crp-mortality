# Markdown equation compatibility and private-note removal

24 October 2026. This revision addresses failures in Markdown math viewers that
were not covered by the earlier native-MathML HTML checks.

## Cause and correction

A reader can consume Markdown punctuation escapes before sending an equation to
its math engine. In particular, losing the escape before a percent sign changes
it into a TeX comment marker. The rest of the line is then ignored, potentially
leaving a subscript group open and producing a missing-brace error.

Confidence-level subscripts now use `0.95`, with the 95% interpretation explained
in prose. Literal braces use named `lbrace`/`rbrace` commands rather than Markdown
punctuation escapes. These are notation changes, not changes to intervals or
statistical inference. Quarto-specific section attributes were removed from
personal reading notes so that ordinary Markdown does not print them as headings.

## Checks

The installed VS Code math extension supplies KaTeX 0.16.21. Each of the 63
public-document equations was checked directly and after simulated loss of the
percent-sign and literal-brace escapes: **126 checks passed**. The failing
percent-sign example reproduced a missing closing-brace error before correction.
All 63 public expressions also converted to native MathML without error.
Separate checks of personal notes remain local and are not published here.

- `katex_validation.csv`: public equation counts and failures by source and mode.
- `mathml_validation.csv`: independent native-MathML conversion counts.
- Artifact and numerical-check CSVs: unchanged saved analyses and agreement with
  the original primary/MI results. Historical documentation hashes continue to
  identify the earlier text versions; no execution manifest was rewritten.

The local artifact check can be run with
`Rscript scripts/audit_documentation_artifacts.R reports/documentation_compatibility_v2`.
The historical validation files in `documentation_quality_v1` were preserved.

## Publication boundary

Personal methodological reading notes and their dedicated validator are removed
from the current tracked repository and ignored for future additions. Local
copies are retained. Public documentation no longer links readers to those notes,
and the public rendering utility excludes ignored files from reports and indexes.
This removal does not itself rewrite prior Git commits or remove previously
published copies from repository history.
