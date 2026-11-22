> **ESTADO: APLICADO 2026-11-21 (sesión 2). Ver `verificacion/APLICADO.md`. Este documento conserva el texto original propuesto durante la auditoría.**
# Sugerencias de corrección para el libro (NO aplicadas)

**Estado:** propuesto por la auditoría 2026-11-21; **pendiente de aprobación del usuario**.
Nada de esto toca el `.typ` todavía. `bibliografia/refs.yml` sí fue corregido (ver
`reporte_referencias.md`; backup en `verificacion/partes/refs.yml.pre-doi-backup`).
Cada sugerencia incluye el texto exacto actual y el propuesto.

## S1 — Ap. A `apA_notacion_fundamentos.typ:105` — Cota de Cramér–Rao semiparamétrica (ENUNCIADO_INCORRECTO)

Actual:
> La varianza asintótica mínima de un estimador regular de $theta$ es $tilde(I)_theta^(-1)$, donde $tilde(I)_theta$ es la _información eficiente_: la varianza del EIF.

Propuesto:
> La varianza asintótica mínima de un estimador regular de $theta$ es $E[tilde(psi) tilde(psi)^top] = tilde(I)_theta^(-1)$, donde $tilde(I)_theta = E[tilde(S) tilde(S)^top]$ es la _información eficiente_ (la precisión del score eficiente); la cota es la varianza del EIF.

## S2 — Ap. A `apA_notacion_fundamentos.typ:142` — atribución del teorema de Matrix Completion (ATRIBUCION_INCORRECTA)

Actual: `#theorem(name: [Recht, Fazel & Parrilo, 2010])[`
Propuesto: `#theorem(name: [Candès y Recht, 2009])[`

Añadir a `refs.yml` (nueva clave, si se acepta):
```yaml
candes2009exact:
  type: article
  author: ["Candès, Emmanuel J.", "Recht, Benjamin"]
  title: "Exact Matrix Completion via Convex Optimization"
  parent:
    title: Foundations of Computational Mathematics
  volume: 9
  issue: 6
  page-range: 717-772
  date: 2009
  doi: "10.1007/s10208-009-9045-5"
```
(Recht–Fazel–Parrilo 2010, `recht2010guaranteed`, queda correctamente citado para su propio resultado — RIP y recuperación por minimización afín de rango — que el Apéndice B/teoría desarrolla después.)

## S3 — `cap29_descubrimiento_grafos.typ:64` — consistencia de PC (ENUNCIADO_INCORRECTO)

Actual:
> …la CPDAG estimada por PC es consistente incluso cuando $p$ crece exponencialmente con $n$.

Propuesto:
> …la CPDAG estimada por PC es consistente incluso cuando $p$ crece polinomialmente con $n$ ($p = O(n^a)$, $a > 0$ arbitrario), nunca de forma exponencial.

## S4 — `cap17_panel_dmliv.typ:133` — fuentes de los valores críticos Stock–Yogo (ATRIBUCION_INCORRECTA)

Actual:
> …y los valores críticos de Stock y Yogo (#cite(<stock2002survey>, form: "prose"); #cite(<andrews2019robust>, form: "prose")) reemplazan al $F$ de un solo instrumento…

Propuesto:
> …y los valores críticos de Stock y Yogo (#cite(<stock2005testing>, form: "prose"); revisión moderna en #cite(<andrews2019robust>, form: "prose")) reemplazan al $F$ de un solo instrumento…

`stock2005testing` (Stock & Yogo 2005, *Identification and Inference for Econometric Models*, Cambridge) ya está en la bibliografía y **es** la fuente de las tablas de valores críticos. Opcional: añadir Kleibergen (2002, Econometrica 70(5):1781-1803, DOI 10.1111/1468-0262.00357) y Kleibergen & Paap (2006, Journal of Econometrics 133(1):97-126) para el estadístico rk — **sin verificar en esta auditoría**; verifícalas antes de incorporarlas.

## S5 — `cap24_etica_interpretabilidad.typ:93` y `:433` — alcance de kitagawa2021constrained (PARCIAL, en dos sitios)

En `:93`, actual:
> …de cualquiera de las familias anteriores, define un problema de *clasificación restringida* cuyas garantías de regret difieren de las del @cap-policy-learning sin restricciones. El resultado operativo es que el costo en _welfare_ de imponer equidad es cuantificable y debe reportarse…

Propuesto:
> …define un problema de *clasificación restringida* cuyas garantías de regret, específicas de cada clase de restricción (no un teorema por familia de criterio), difieren de las del @cap-policy-learning sin restricciones. El resultado operativo es que el costo en _welfare_ asociado a la restricción elegida es cuantificable y debe reportarse…

En `:433`, actual:
> …#cite(<kitagawa2021constrained>, form: "prose") formalizan el policy learning bajo restricciones y permiten cuantificar el costo en _welfare_ de cada criterio.

Propuesto:
> …#cite(<kitagawa2021constrained>, form: "prose") formalizan el policy learning bajo restricciones y acotan el costo en _welfare_ asociado a la restricción impuesta.

## S6 — `cap27_deep_causal.typ:310` — alcance de curth2021inductive (PARCIAL)

Actual:
> #cite(<curth2021inductive>, form: "prose") muestran que el argumento es más frágil de lo que parece, y por una razón instructiva: la cota que justifica la penalización es *laxa*, y minimizarla no equivale a minimizar el error en $tau$.

Propuesto (mínimo, fiel a lo verificado):
> #cite(<curth2021inductive>, form: "prose") muestran que el argumento es más frágil de lo que parece: minimizar la cota que justifica la penalización no equivale a minimizar el error en $tau$, entre otras cosas porque el balance impuesto a $Phi$ puede eliminar información útil para estimar los resultados.

Opcional (si se quiere citar la crítica explícita de la cota): añadir
```yaml
curth2021nonparametric:
  type: article
  author: ["Curth, Alicia", "van der Schaar, Mihaela"]
  title: "Nonparametric Estimation of Heterogeneous Treatment Effects: From Theory to Learning Algorithms"
  parent:
    title: "International Conference on Artificial Intelligence and Statistics (AISTATS)"
  date: 2021
  doi: "10.48550/arXiv.2101.10943"
```
(DOI verificado contra S2: AISTATS 2021, 10.48550/arXiv.2101.10943. Ninguna fuente abierta confirma la palabra exacta «laxa»; por eso el mínimo elimina la palabra y conserva la tesis respaldada.)

## S7 — `cap06_regularizacion_postseleccion.typ:416`, `cap05_prediccion_causalidad.typ:407`, `cap10_ortogonalidad_crossfitting.typ:359`, `cap16_pds.typ:432` — clave reapuntada `chernozhukov2018applied`

Tras la corrección de refs.yml (AER P&P 107(5):261-265, 2017; **INFERENCIA** de Grok 4.7, confianza media), la cita ya apunta a la obra correcta. Matiz opcional de redacción: donde el libro dice «revisión pedagógica», es exacto con el AER P&P note («Double/Debiased/Neyman ML of Treatment Effects», 5 páginas de síntesis). Si **no** aceptas la inferencia A3, la alternativa limpia es: eliminar los usos de `chernozhukov2018applied` y sustituirlos por `chernozhukov2018double` (el artículo fundacional de DML) — son 6 apariciones (cap05:407, cap06:416, cap10:359, cap11:404, cap16:432, cap18:271). Ver `reporte_referencias.md`.

## S8 — Normalizar 7 citas `@key` a `#cite` (N4, cosmético)

| Archivo:línea | Actual | Propuesto |
|---|---|---|
| cap25_decisiones_estructurales.typ:299 | `@berger1985statistical` | `#cite(<berger1985statistical>, form: "prose")` |
| cap06_regularizacion_postseleccion.typ:73 | `Elastic Net @zou2005elasticnet combina` | `Elastic Net #cite(<zou2005elasticnet>, form: "prose") combina` |
| cap11_dml.typ:86 | `de @robins1994estimation ajustada` | `de #cite(<robins1994estimation>, form: "prose") ajustada` |
| cap11_dml.typ:157 | `(@kish1965)` | `(#cite(<kish1965>, form: "prose"))` |
| cap11_dml.typ:328 | `de @angrist1991, que usa` | `de #cite(<angrist1991>, form: "prose"), que usa` |
| cap05_prediccion_causalidad.typ:370 | `y @aronow2017 es una referencia` | `y #cite(<aronow2017>, form: "prose") es una referencia` |
| cap17_panel_dmliv.typ:372 | `véase @freyaldenhoven2021local` | `véase #cite(<freyaldenhoven2021local>, form: "prose")` |

(Coste: puramente sintáctico; el PDF queda idéntico semánticamente. Si prefieres mantener el estilo mixto actual, es válido — Typst lo compila.)

## S9 — Referencias candidatas a añadir a `refs.yml` (sin aplicar; verifícalas antes)

- **van de Geer (2008)**, "High-dimensional generalized linear models and the lasso", *Annals of Statistics* 36(2):614-645 — la fuente de la tasa ℓ₂ bajo restricted eigenvalue que el cap. 6 cita implícitamente (el libro solo cita `vandegeer2014asymptotically`). **No verificada en esta auditoría.**
- **Hahn (1998)** — papel del propensity score en la eficiencia semiparamétrica; fuente del EIF que el cap. 10/11 invoca implícitamente (lo señala el verificador por `cap21:74` y `cap11:94`). **No verificada; venue a confirmar (Econometrica 66(2):315-331).**
- **Candès & Recht (2009)** — ver S2 (verificada, DOI 10.1007/s10208-009-9045-5).
- **Kleibergen (2002)**; **Curth & van der Schaar (2021, AISTATS)** — ver S4/S6.

## S10 — Comentario de cabecera de `refs.yml` (opcional)

Actualizar la línea `# Estado:` a:
> # Estado: 146 entradas, todas citadas en el texto (0 huérfanas). Auditadas 2026-11 contra Semantic Scholar/OpenAlex/Crossref: metadatos corregidos y 80 DOIs añadidos (98/146 con DOI/URL). Informe: `verificacion/reporte_referencias.md`.

(No se aplicó para no tocar el bloque de cabecera sin aprobación explícita.)
