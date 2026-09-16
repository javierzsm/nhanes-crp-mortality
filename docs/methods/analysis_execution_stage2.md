# Analysis execution, stage 2

## Restricted cubic spline

Script 07 fits the prespecified four-knot restricted cubic spline for
`log2(CRP)`. The basis contains the original linear term and two nonlinear
terms. This construction permits a joint design-based Wald test of all three
CRP terms and a separate Wald test of the two nonlinear terms.

Hazard-ratio contrasts compare CRP concentrations of 2, 4 and 8 mg/L with the
prespecified reference of 1 mg/L. Figure data span weighted CRP percentiles 1
through 99 to prevent very sparse tails from determining the display range.
This display restriction does not exclude observations from model estimation.

## Proportional-hazards diagnostics

Script 08 produces the supportive diagnostics specified in the SAP. It fits an
auxiliary weighted Cox model with standard errors clustered by the nested
survey PSU and applies `cox.zph` using log-transformed time. Its scaled
Schoenfeld residuals and tests are diagnostic only because this auxiliary model
does not reproduce the complete design-based variance calculation of
`svycoxph`.

The planned survey-weighted CRP-by-log-time interaction is deliberately not
implemented in this stage. `svycoxph` forces storage of the fitted model, while
the underlying `coxph` implementation does not safely support that route with a
`tt()` term. A separate implementation based on replicate survey weights will
be validated before the planned design-based interaction is fitted.

## Interpretation order

1. Verify spline-model numerical checks.
2. Review the global CRP and nonlinearity tests.
3. Inspect planned contrasts and the spline curve.
4. Review auxiliary Schoenfeld tests and residual patterns.
5. Implement and validate the design-based time-interaction test.

No proportional-hazards conclusion will be based solely on the auxiliary
diagnostic p-values.
