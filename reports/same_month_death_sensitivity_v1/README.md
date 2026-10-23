# Sensibilidad de la enmienda 001: fallecimientos del mismo mes

Fecha de ejecución: 23 de octubre de 2026. Análisis adicional del modelo principal
de casos completos, previsto por la [enmienda 001](../../protocol/amendments/001_zero_followup_time.qmd).

## Pregunta y decisión

¿Depende la asociación estimada entre PCR y mortalidad de asignar 0,5 meses a
los fallecimientos cuyo seguimiento público es de cero meses?

La sensibilidad muestra una influencia muy pequeña sobre la estimación puntual
y su intervalo. Se conserva el análisis principal con la convención de 0,5 meses;
este resultado adicional cierra el compromiso específico de la enmienda. No
constituye una prueba formal de equivalencia ni valida todos los demás supuestos
del estudio.

## Qué se excluyó realmente

Hay cuatro fallecimientos del mismo mes en los 27.755 participantes elegibles.
Dos de ellos, ambos de 2007–2008, ya estaban excluidos del modelo principal por
datos incompletos. Por tanto, excluir los cuatro de la población elegible y
aplicar los mismos requisitos de casos completos elimina **dos observaciones
adicionales** del modelo: una de 2001–2002 y otra de 2003–2004. Las cuatro tienen
seguimiento publicado de cero meses y seguimiento analítico de 0,5 meses.
El [recuento por ciclo](exclusion_audit.csv) documenta esta distinción sin
publicar identificadores individuales.

## Método

Se reprodujo primero el modelo guardado, verificando todos sus coeficientes y
la matriz de covarianza con tolerancia numérica de 1e-10. Luego se ajustó la
misma fórmula de Cox con empates Efron, exposición log2(PCR), los mismos ajustes
y las mismas bases de edad calculadas con los nudos originales 22, 38, 52 y 78.
Se excluyeron únicamente los casos indicados mediante un subconjunto del diseño
de encuesta original, conservando ponderaciones, estratos y conglomerados. Los
grados de libertad del diseño permanecieron en 91.

Los intervalos usan la varianza del diseño y la aproximación normal del análisis
principal: exp(beta ± 1,959964 × SE). No se recalcularon nudos, no se imputaron
datos y no se seleccionaron especificaciones en función del resultado.

## Resultados

| Análisis | Participantes | Fallecimientos | HR por duplicación de PCR | IC del 95 % |
|---|---:|---:|---:|---:|
| Principal | 26.818 | 5.886 | 1,129854 | 1,108762–1,151347 |
| Exclusión de fallecimientos del mismo mes | 26.816 | 5.884 | 1,129632 | 1,108576–1,151088 |

El coeficiente logarítmico cambia de 0,1220883072 a 0,1218918171:
diferencia −0,0001964900. La razón entre ambos HR es 0,9998035293, una
reducción relativa del HR de aproximadamente **0,01965 %**. El exceso relativo
de hazard pasa de 12,9854 % a 12,9632 %: diferencia de −0,02220 puntos
porcentuales. Estas cantidades describen hazard, no riesgo acumulado ni un
efecto causal. No se fijó retrospectivamente un umbral de equivalencia.

## Texto adicional para el manuscrito científico

**Methods.** As specified in Amendment 001, we repeated the primary
complete-case survey-weighted Cox analysis after excluding participants whose
released follow-up was zero months and who died within that monthly interval.
The original model assigned these deaths 0.5 months. We retained the original
covariate specification, age-spline knots, survey weights and design structure.
Of four affected eligible participants, two belonged to the complete-case sample;
the other two were already excluded because of incomplete covariates.

**Results.** Excluding the two applicable same-month deaths yielded 26,816
participants and 5,884 deaths. The adjusted hazard ratio per doubling of CRP
was 1.129632 (95% CI 1.108576–1.151088), compared with 1.129854
(95% CI 1.108762–1.151347) in the primary analysis. The relative change in
the hazard ratio was −0.01965%, indicating little influence of the midpoint
convention on this estimate.

## Verificación y trazabilidad

Las [14 verificaciones](validation.csv) pasaron. Incluyen los recuentos,
la identidad de las filas retenidas, la reproducción del modelo principal,
la comprobación independiente del intervalo y la integridad antes/después
de los resultados anteriores. Los [resultados completos](comparison.csv) y
los [hashes de las fuentes](inputs.csv) permiten auditar el análisis.

Código: [22_sensitivity_same_month_deaths.R](../../src/R/22_sensitivity_same_month_deaths.R).
Ejecución desde la raíz: `Rscript src/R/22_sensitivity_same_month_deaths.R`.
El script detiene la ejecución si ya existen las salidas de esta versión;
no debe repetirse para actualizar fechas. Los coeficientes, la covarianza y el
manifiesto local están en `data/processed/same_month_death_sensitivity_v1.rds`.
Los CSV contienen únicamente resultados agregados.

Este anexo actualiza el estado pendiente señalado en el
[manuscrito metodológico comentado](../metodologia_comentada_v1/manuscrito_metodologico_es.md)
y complementa el [borrador científico](../stage6_v1/manuscript_methods_results.md).
Ambos documentos anteriores y los resultados de imputación se conservaron
sin modificaciones. No se afirma haber repetido aquí el modelo imputado ni
las demás sensibilidades: la enmienda se evalúa sobre el modelo principal.
