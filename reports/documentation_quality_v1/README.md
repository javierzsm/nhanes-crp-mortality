# English documentation and equation-rendering audit

Revision date: 24 October 2026. All maintained prose is English, including the
commented methodological manuscript and same-month-death sensitivity addendum.
Legacy filenames remain stable for existing links; earlier wording is available
in Git history. The companion retains its mathematical development and incorporates
the already completed Amendment 001 sensitivity.

## Rendering changes

Display equations now use `$$` delimiters rather than fenced `math` code blocks.
This works in Quarto/Pandoc HTML and common Markdown readers with math support.
Inline equations use `$...$`. English mathematical labels and decimal points
replace Spanish labels and decimal commas in the companion. Explicit braces and
spacing make command arguments and indices unambiguous. Long derivations use
aligned lines, and the local preview provides horizontal scrolling for equations
that exceed a narrow reading window.

The HTML preview uses native MathML with embedded resources and does not require
an external equation engine or font download. A reader must support mathematical
Markdown or MathML; opening a Markdown source as plain text will show delimiters.
No repository configuration can force every third-party preview to support math.

## Reproduce the check

Dependencies: Python 3 with `beautifulsoup4`, and Quarto. From the repository root:

```sh
python3 scripts/render_documentation.py
```

Open `output/documentation_preview/index.html` for all rendered documents.
The reading copies and browser QA screenshots remain local and ignored by Git.
The companion also retains its standalone rendering command in its README.
No analysis code is executed while rendering; execution is disabled centrally.

`render_validation.csv` reports each document, equation counts, unconverted
math, MathML errors, raw math-code blocks, render warnings, and HTML language.
`language_scan.csv` records a targeted untranslated-prose scan; this complements
manual translation review rather than claiming universal language detection.
`source_manifest.csv` identifies the revised source versions. The browser review
also checks equation boxes and visible output at desktop and narrow widths.

## Verified results

- 40 documents rendered in English.
- All 219 source equations have corresponding native MathML elements.
- No conversion warnings, MathML error nodes, or leftover math-code blocks.
- All seven equation-bearing documents passed browser checks at widths 1440
  and 480 pixels (fourteen document/width checks). Long equations remain locally
  scrollable when necessary. Complex Cox, spline, and Rubin expressions were
  also reviewed in screenshots.
- Thirteen numerical/text checks passed against saved primary and MI results.
- All 119 non-document artifact references matched their recorded hashes.
- The archived MI technical specification matched its original recorded hash.

Reproduce the read-only artifact and number checks using
`Rscript scripts/audit_documentation_artifacts.R`. Browser inspection uses
`python3 scripts/check_documentation_browser.py` with Chrome/Chromium and the
Python `websockets` package. It uses a disposable profile, opens only local
reading copies, and does not use personal browser sessions.

## Historical integrity

This task explicitly authorizes documentation translation and equation-format
changes, including presentation-only changes to previously hashed method notes.
`documentation_changes.csv` records original and revised document MD5 hashes.
Old execution manifests and validation CSVs were not rewritten, and their
source-text hashes still refer to the earlier wording. Consequently, a historical
check that compares those old hashes with revised prose should identify a change;
that does not mean the saved model or imputation checkpoint changed.

`historical_artifact_checks.csv` separately verifies recorded non-document inputs,
analysis code, checkpoints, and outputs. `historical_document_references.csv`
identifies changed documentation referenced by historical manifests. Original
text can be retrieved from commit `fa5f39d` for a historical source check.
Do not rerun completed analyses or alter a manifest to bypass a mismatch. A future
execution requiring exact source hashes needs a new versioned plan or the exact
historical source version, even when the current change is purely explanatory.

No participant data, seeds, imputation states, covariate specifications, fitted
coefficients, or inference procedures were changed in this revision. The
historical numerical findings remain the findings reported in the manuscripts.
