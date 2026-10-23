# Manuscrito metodológico comentado — español

Documento alternativo para lectura del investigador, 23 de octubre de 2026.
No sustituye el manuscrito científico ni altera análisis previos.

- Fuente: [manuscrito_metodologico_es.md](manuscrito_metodologico_es.md).
- Lectura navegable local: `manuscrito_metodologico_es.html`, generado con Quarto.
- Aproximadamente 11.500 palabras, 34 secciones principales y 158 expresiones
  matemáticas en el HTML. Incluye alternativas, supuestos, resultados concretos,
  cronología, glosario y quince preguntas con respuestas razonadas.
- `verificaciones.csv`: dieciséis controles pasaron.
- `auditoria_filtro_pesos.csv`: comprobación sin refits de equivalencia de
  pertenencia por positividad 2/4 años en los dos primeros ciclos.
- `fuentes_verificadas.csv`: huellas de entradas y script de verificación.
- `mice_3.19.0_algoritmos_inspeccionados.R`: instantánea de inspección de las
  funciones instaladas de MICE; fuente del paquete MICE 3.19.0, cuyo código
  conserva su licencia de paquete. No es código nuevo para ejecutar la MI.

Recrear el HTML desde la raíz del repositorio:

```sh
XDG_CACHE_HOME=/tmp/nhanes-methodology-quarto-cache DENO_DIR=/tmp/nhanes-methodology-deno-cache quarto render reports/metodologia_comentada_v1/manuscrito_metodologico_es.md --to html
```

El HTML usa MathML nativo y recursos embebidos: su lectura no necesita descargar
fuentes o motores matemáticos. Las referencias externas sí necesitan conexión
si se abren. Los enlaces al código/documentos locales requieren conservar la
estructura del repositorio. Los HTML y archivos auxiliares renderizados siguen
excluidos de Git por las reglas existentes.

Los controles se pueden reproducir con
`Rscript src/R/21_validate_methodological_manuscript.R` bajo un nuevo identificador
si los artefactos ya existen. No ejecutar para sobrescribir verificaciones.
La portada y una muestra de fórmulas fueron inspeccionadas visualmente en Chrome;
se comprobaron enlaces locales, pares de delimitadores matemáticos y ausencia de
dependencias externas de renderizado. La representación HTML no es un PDF paginado.

## Pendiente metodológico que quedó visible al escribir

La Enmienda 001 promete excluir sólo cuatro fallecimientos del mismo mes como
sensibilidad. No se encontró una salida específica entre los análisis revisados.
El documento lo marca como pendiente; no atribuye un resultado, no equipara esa
sensibilidad con excluir todas las muertes tempranas y no ejecuta un ajuste nuevo.

## Límites del alcance

La lectura del algoritmo `polyreg` se distingue de una afirmación de muestreo
posterior exacto; no se certifica MAR, calibración o cobertura de Rubin por haber
pasado controles de programación. El original científico, la cohorte, los
checkpoints aceptados y los resultados de etapas 5/6 conservan sus huellas.
