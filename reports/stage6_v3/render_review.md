# Illustrated manuscript render review

Completed on 24 October 2026. The English v0.3 manuscript contains three
numbered, cross-referenced main figures: cohort flow, CRP spline with the
weighted exposure distribution, and period-specific CRP hazard ratios.
The supplementary document contains the updated sensitivity forest and the
secondary sex/age interaction contrasts.

All eight package checks in `validation.csv` passed. The saved inputs and all
initial package output hashes matched the local versioned manifest after
rendering. Earlier manuscript sources and fitted analysis outputs were retained.
The new exposure histogram is descriptive: its denominator is the total pooled
MEC weight of all 26,818 complete cases, and 1.00% of that weight lies outside
the displayed 0.1–33.4 mg/L range. This plotting range does not restrict fitting.

Both HTML files embed their figures, permitting reading without external image
files. Four browser checks in `browser_validation.csv` passed: each document at
1440 and 480 pixels. All five embedded images loaded, no image extended beyond
the viewport, and main-figure references resolved. PNG exports and screenshots
of the integrated figures and captions were also inspected visually.

Files for reading:

- [Main manuscript](manuscript_methods_results.html).
- [Supplementary figures](supplementary_figures.html).

Figures are supplied as SVG and 240-dpi PNG. Source tables contain aggregates,
not participant records. Their inputs are identified in `input_manifest.csv`.
The local RDS manifest is `data/processed/reporting_stage6_v3_manifest.rds`;
it records the generated sources and figure package before the additional HTML
and browser-review files were created. It is not silently updated by rendering.

To reproduce the browser check after rendering, run
`python3 scripts/review_illustrated_manuscript.py` from the repository root.
It requires Chrome/Chromium and Python `websockets`, uses a disposable profile,
and opens only the local manuscript files. Screenshots stay under the ignored
`output/documentation_preview/stage6_v3_review/` directory.

The manuscript remains a working Methods/Results draft. The listed background,
discussion, supplements, author declarations, and journal preparation tasks
remain to be completed before submission.
