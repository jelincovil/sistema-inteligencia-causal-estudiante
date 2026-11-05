= Dataset, efecto y método

Prototipo «Puente» — semana 4. Documento de referencia de los datos que acompañan
este paquete y del razonamiento causal que los usa.

#set page(margin: 2.2cm, numbering: "1")
#set text(size: 10.5pt)
#set par(justify: true)

== 1. Qué hay en `datasets/`

Dos escenarios *sintéticos* (generados por simulación, no participantes reales),
con la misma estructura de archivos:

#table(
  columns: (1.2fr, 2.6fr, 2.2fr),
  inset: 6pt,
  align: (left, left, left),
  table.header([*Escenario*], [*`real/ihdp`*], [*`real/jobs`*]),
  [Referencia], [Hill (2011), JCGS 20(1)], [LaLonde (1986), AER 76(4)],
  [Unidades], [747 (448 / 149 / 150)], [1722 (1033 / 344 / 345)],
  [Covariables], [25 (`bw` … `was`)], [8 (`age` … `re75`)],
  [Tratados (train)], [191 (42,7 %)], [262 (25,4 %)],
  [Resultado], [`outcome`: puntaje cognitivo a 3,5 años], [`re78`: ingresos de 1978 (USD)],
  [Escala del resultado], [puntos], [dólares de 1978],
)

Cada carpeta contiene:

- `observed.csv` — el pool completo; `observed_{train,validation,test}.csv` — las particiones
  sembradas (60/20/20, semilla 20240701) con hash en `splits.json`.
- `metadata.json` — ficha del escenario; `identification.json` — conjunto de ajuste válido.
- `interventions.json` — contiene `ate`, `att` y `tau_summary`. *No se usa*: es la
  referencia que el proyecto no debe mirar antes de estimar (la pared).
- No hay `truth_*.csv`: la verdad por unidad no está en el paquete.

== 2. El efecto que se estima

El estimando declarado —antes de mirar los datos— es el *efecto promedio del tratamiento*
(ATE) sobre la población de entrenamiento:

$ tau = E[Y(1) - Y(0)] $

- *Unidad:* puntos del test cognitivo en `ihdp`; dólares de 1978 en `jobs`.
- *Población:* los 448 individuos de `observed_train.csv` (ihdp) o los 1033 (jobs).
- *Cobertura del intervalo:* el efecto *promedio* poblacional. No es un efecto individual
  ni un CATE; `/consulta` informa, como mucho, la media de un estrato declarado.
- *No es el ATT.* La pregunta original dice «de los niños que lo recibieron», que describe
  el efecto en los tratados; el estimando implementado es el ATE. En este DGP se parecen
  (3,92 frente a 4,15), pero no son lo mismo y conviene decirlo en voz alta.

== 3. Método de inferencia causal

Estimador principal: *AIPW (augmented IPW) con cross-fitting* $K = 5$, doblemente robusto.
Para cada unidad $i$, con $D_i$ el tratamiento, $Y_i$ el resultado y $X_i$ las covariables:

$ psi_i = hat(mu)_1 (X_i) - hat(mu)_0 (X_i)
  + frac(D_i (Y_i - hat(mu)_1 (X_i)), hat(e)(X_i))
  - frac((1 - D_i)(Y_i - hat(mu)_0 (X_i)), 1 - hat(e)(X_i)) $

$ hat(tau) = 1/n sum_(i=1)^n psi_i , quad
  hat("se") = frac("sd"(psi), sqrt(n)) $

Componentes:

- $hat(mu)_1, hat(mu)_0$: regresión lineal del resultado *por brazo*.
- $hat(e)(X)$: probabilidad de tratamiento por regresión logística.
- *Cross-fitting:* los *nuisances* se ajustan fuera del pliegue que predicen; ninguna
  unidad contribuye a su propia predicción (la exigencia central del cap. 9).
- *Trimming* declarado: $hat(e)$ recortada a $[0,05, 0,95]$.
- Referencia: *OLS* con las covariables del esquema (y una columna trampa derivada del
  resultado, que vacía el coeficiente sin lanzar error).

¿Por qué doble robustez? El estimador es consistente si *cualquiera* de las dos piernas
($hat(mu)$ o $hat(e)$) está bien especificada; el término de augmentación corrige el sesgo
del plug-in cuando la regresión del resultado falla.

== 4. Supuestos declarados (y su clase)

#table(
  columns: (2.4fr, 1.1fr, 3.1fr),
  inset: 6pt,
  table.header([*Supuesto*], [*Clase*], [*Cómo se trata*]),
  [No confusión condicional en las covariables observadas], [`no_observable`],
    [Se declara; la identificación lo exige y ningún dato lo verifica],
  [Soporte común, $0 < e(X) < 1$], [`observable`],
    [Se mide: rango de $hat(e)$, ESS de Kish y fracción en zona de solapamiento],
  [Consistencia / SUTVA], [`no_observable`],
    [Se declara; heredado del diseño del escenario],
  [Covariables medidas antes del tratamiento], [`observable`],
    [Los metadatos del escenario lo declaran; la trampa `score_post` muestra qué pasa si no],
)

== 5. Diagnósticos que acompañan a cada número

#table(
  columns: (1.6fr, 3.2fr, 2.2fr),
  inset: 6pt,
  table.header([*Diagnóstico*], [*Qué responde*], [*Valor (ihdp)*]),
  [ESS de Kish], [cuántas unidades «cuentan» bajo la ponderación IPW], [388 de 448 (0,87)],
  [Rango de $hat(e)$], [dónde vive la probabilidad estimada], [[0,071; 0,887]],
  [Fracción en solape], [proporción con $hat(e) in [0,05, 0,95]$], [100 %],
  [SMD máximo], [desequilibrio máximo entre brazos], [0,43],
  [PSI], [deriva de una ventana frente a la referencia], [0,88 (`bw`, +1 DE)],
)

== 6. Qué *no* afirma este prototipo

- No estima un CATE validado: el efecto por perfil es una proyección lineal del score,
  con $R^2 = 0,095$ y advertida como de discriminación baja.
- No estima políticas ni efectos de intervenciones distintas de la observada.
- No usa la verdad del escenario ($approx 3,92$) para estimar, decidir ni calibrar umbrales;
  solo se compara al final.
- Las dos piernas son lineales: con 25 covariables y formas no lineales, el sesgo de
  especificación sigue siendo el riesgo principal.

== 7. Resultado de referencia (semilla 4242, $K = 5$)

#table(
  columns: (2.6fr, 2.2fr, 2.2fr),
  inset: 6pt,
  table.header([*Cantidad*], [*`real/ihdp`*], [*`real/jobs`*]),
  [Diferencia cruda], [10,3 puntos], [1600,8 USD],
  [ATE OLS (referencia)], [4,8], [1596,0],
  [*ATE AIPW*], [*5,2* [$3,9; 6,4$]], [*1638,6* [$1001,6; 2275,7$]],
  [ESS / n], [388 / 448], [729 / 1033],
)

== 8. Reproducir

```sh
make demo                              # escenario por defecto: real/jobs
SIC_ESCENARIO=real/ihdp make demo      # escenario de la entrega
```

Cada corrida regenera `artifacts/estimacion.json` y la versión inmutable
`artifacts/registro/vNNNN/` con su manifiesto SHA-256.
