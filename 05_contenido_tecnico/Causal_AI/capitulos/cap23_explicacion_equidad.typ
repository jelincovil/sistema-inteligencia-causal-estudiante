// Capítulo 23: Explicación causal y equidad algorítmica. Abre la Parte VI.
// Edición en capas: la teoría (L0), el procedimiento (L1) y los casos canónicos con cifras verificadas (L2)
// son lo que dura; el listado (L3) va dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Explicación causal y equidad algorítmica]
<cap-explicacion-equidad>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Descomponer el efecto de un atributo protegido en rutas directas e indirectas],
    [*Estimando:*], [Efecto total, directo controlado (CDE), directo e indirecto naturales (NDE, NIE) y efectos específicos por ruta],
    [*Identificación:*], [Grafo causal con rutas etiquetadas como legítimas o no, e ignorabilidad secuencial],
    [*Método:*], [Fórmulas de mediación de Pearl; equidad contrafactual; discriminación por proxy y no resuelta],
    [*Garantía:*], [Descomposición exacta del efecto total en directo más indirecto, bajo el grafo y las ignorabilidades supuestas],
    ..if not es-principios {([*Librerías:*], [dowhy (estimación de mediación)])},
    [*Validación:*], [Sensibilidad al grafo de rutas propuesto y a confusores mediador-resultado],
  )
]

== Problema causal, estimando e identificación
<sec-explicacionequidad-problema>

El @cap-etica-interpretabilidad, que sigue a este capítulo, trata la interpretabilidad en el sentido más difundido en _machine learning_: explicaciones locales que atribuyen una predicción a sus variables de entrada por su contribución estadística. Ese tipo de explicación es *asociativa*: describe cómo covarían las variables con la salida del modelo, no si esa covariación refleja un mecanismo causal legítimo o discriminatorio. Este capítulo se ubica en la tradición de la equidad causal y pregunta algo distinto y más difícil: si un algoritmo de decisión (contratación, crédito, libertad condicional) produce resultados distintos según un atributo protegido (género, raza, origen), *¿ese efecto pasa por una ruta legítima o por una discriminatoria?* Responderlo exige descomponer el efecto total en sus componentes causales por ruta, y no solo medirlo.

== Teoría, supuestos y garantías
<sec-explicacionequidad-teoria>

=== Efectos directos, indirectos y espurios
<sec-explicacionequidad-directoindirecto>

Sea $A$ un atributo protegido (por ejemplo, género), $M$ un mediador que $A$ afecta (por ejemplo, la elección de ocupación) e $Y$ el resultado (por ejemplo, el salario). Con resultados potenciales $Y(a, m)$ y $M(a)$, se definen cuatro efectos.

#definition(name: [Descomposición directo e indirecto])[
  - *Efecto total:* $"TE" = E[Y(1, M(1)) - Y(0, M(0))]$.
  - *Efecto directo controlado:* $"CDE"(m) = E[Y(1, m) - Y(0, m)]$, el efecto de $A$ sobre $Y$ cuando el mediador se fija en $m$.
  - *Efecto directo natural:* $"NDE" = E[Y(1, M(0)) - Y(0, M(0))]$, el efecto de $A$ cuando el mediador se mantiene en el valor que tendría sin cambiar $A$.
  - *Efecto indirecto natural:* $"NIE" = E[Y(1, M(1)) - Y(1, M(0))]$, la parte que pasa por el cambio que $A$ induce en $M$.

  Con estas definiciones $"TE" = "NDE" + "NIE"$.
]

La pregunta de equidad no es si el efecto total de $A$ sobre $Y$ es distinto de cero. Eso puede ser enteramente legítimo si el efecto pasa por una ruta que la organización considera aceptable, por ejemplo si hombres y mujeres eligen, en promedio, ocupaciones distintas por preferencia genuina y esas ocupaciones pagan distinto. La pregunta es qué parte del efecto viaja por rutas que no se aceptan. El efecto directo, la parte de $A$ sobre $Y$ que no pasa por ningún mediador, es el indicio causal del *trato diferencial directo*, la noción más estricta de discriminación. Las rutas indirectas por mediadores que la organización no acepta como legítimos también cuentan, y cuáles son es una decisión normativa.

La descomposición solo es válida bajo supuestos que el grafo declara.

#proposition(name: [Identificación de la descomposición])[
  Sean $X$ las covariables previas a $A$. Si (i) $Y(a, m) perp perp A | X$ (sin confusión de $A$ con el resultado) y (ii) $Y(a, m) perp perp M | A, X$ (sin confusión del mediador con el resultado), entonces
  $
  "CDE"(m) = E_X [E[Y | A = 1, M = m, X] - E[Y | A = 0, M = m, X]].
  $
  Si además (iii) $Y(a, m) perp perp M(a') | X$ para $a != a'$ (independencia entre mundos) y $M(a) perp perp A | X$, entonces
  $
  "NDE" &= sum_(x, m) (E[Y | 1, m, x] - E[Y | 0, m, x]) P(m | 0, x) P(x), \
  "NIE" &= sum_(x, m) E[Y | 1, m, x] (P(m | 1, x) - P(m | 0, x)) P(x).
  $
  En un modelo lineal sin interacción $A times M$, con $M = gamma A + dots$ e $Y = delta A + beta M + dots$, el efecto directo es $delta$ y el indirecto es $beta gamma$.
] <prop-mediacion>

La condición (ii) es la que más se incumple en la práctica: cualquier causa común de $M$ e $Y$ que no se observe, como el entorno familiar que influye en la ocupación y en el salario, invalida el efecto directo estimado. La condición (iii) no se puede contrastar ni siquiera con un experimento sobre $A$ y $M$, porque involucra resultados de mundos distintos; por eso los efectos naturales exigen más fe en el modelo que el efecto directo controlado.

=== Equidad contrafactual
<sec-explicacionequidad-contrafactual>

#cite(<kusner2017counterfactual>, form: "prose") formaliza una noción de equidad en el Nivel 3 de la jerarquía causal de Pearl (@cap-scm-pch). Sea $U$ el vector de variables latentes de un modelo estructural. Una decisión $hat(Y)$ es *contrafactualmente justa* si, para todo $x$, $a$ y $a'$,
$
P(hat(Y)_(A <- a)(U) = y | X = x, A = a) = P(hat(Y)_(A <- a')(U) = y | X = x, A = a),
$
es decir, si la decisión de un individuo no cambiaría en el mundo donde su atributo protegido fuera distinto, manteniendo fijo lo que no depende causalmente de $A$. Es una noción más exigente que la paridad demográfica o la igualdad de tasas de error, ambas puramente asociativas (Nivel 1), porque exige razonar sobre el mundo contrafactual de cada individuo y no solo sobre promedios poblacionales. Calcularla requiere un modelo estructural con el que inferir $U$ a partir de lo observado, y por tanto supuestos que el análisis asociativo no necesita.

#cite(<kilbertus2017avoiding>, form: "prose") desarrollan la contraparte de Nivel 2 con dos criterios operativos. Una decisión *no discrimina por proxy* si no cambia cuando se interviene sobre los *proxies*, las variables que se declaran sustitutos del atributo protegido (el código postal como proxy de raza, el patrón de compras como proxy de género): $P(hat(Y) | "do"(P = p))$ no depende de $p$. Una decisión *no discrimina de forma no resuelta* si no existe una ruta dirigida de $A$ a $hat(Y)$ que no esté bloqueada por una *variable resolutora*, una variable cuya influencia sobre la decisión la organización acepta como no discriminatoria. Los dos criterios exigen declaraciones normativas previas (qué es proxy, qué es resolutora); lo técnico, y verificable, es comprobar en el grafo si se cumplen y neutralizar los proxies, algo que se puede hacer sin observar $A$.

La consecuencia para el diseño de un sistema en producción es directa. Ante un algoritmo que discrimina hay dos remedios de naturaleza distinta: uno *técnico*, que identifica los proxies en el grafo y los neutraliza, y uno *normativo*, que declara qué rutas se aceptan y que ningún método puede automatizar. Confundir ambos es el error característico de las auditorías que se limitan a quitar las variables sensibles del modelo: eliminan $A$ y dejan intactos todos sus proxies, sin tocar ninguna de las dos fuentes reales del problema.

== Procedimiento: auditoría causal de equidad
<sec-explicacionequidad-algoritmo>

#algorithm("Auditoría causal de equidad")[
  #kwin[Entrada][Decisión o resultado $Y$, atributo protegido $A$, datos con covariables, grafo causal propuesto.]
  #kwout[Salida][Descomposición del efecto, lista de rutas aceptadas y rechazadas, y acciones correctivas.]
  Declarar el atributo protegido, la decisión y la población afectada. \
  Dibujar el grafo y *etiquetar cada ruta de $A$ a $Y$* como aceptada (resolutora), proxy o no clasificada, con las partes interesadas. \
  Verificar las ignorabilidades de la proposición de la @sec-explicacionequidad-directoindirecto para el efecto que se quiere estimar y declarar las que no se cumplen. \
  Estimar el efecto total, el directo (CDE y, si (iii) es creíble, NDE) y el indirecto por cada mediador. \
  Analizar la sensibilidad a un confusor mediador-resultado y a mediadores omitidos. \
  Neutralizar los proxies en el modelo de decisión y recalcular la brecha. \
  #return-stmt[Descomposición, rutas declaradas, sensibilidad y acciones; todo documentado en la ficha del modelo (@cap-model-card-causal).]
] <alg-auditoria-equidad>

El paso de etiquetado es el único que no tiene forma estadística: una ruta aceptada o rechazada es un juicio legal, ético y organizacional. El procedimiento lo hace explícito *antes* de estimar, en vez de dejarlo implícito en la elección de los controles.

== Casos canónicos y validación
<sec-explicacionequidad-caso>

Las cifras de los tres casos provienen de simulaciones con muestras de 200~000 observaciones, promediadas sobre 20 repeticiones en los dos primeros.#capa-impl[ El script es #code[herramientas/verificaciones/verif_cap23.py].]

#caso-canonico("Mediación lineal: efecto directo e indirecto")[
  $A$ binaria con probabilidad 1/2, $M = 0.5 A + epsilon_M$ e $Y = 0.15 A + 0.6 M + epsilon_Y$, sin confusión. El efecto total verdadero es $0.15 + 0.6 times 0.5 = 0.45$, el directo es 0,15 y el indirecto es $0.6 times 0.5 = 0.30$. Estimados: efecto total 0,449 (diferencia de medias), efecto directo controlado 0,150 (coeficiente de $A$ en la regresión de $Y$ sobre $A$ y $M$) y efecto indirecto 0,299 (la diferencia). La descomposición recupera lo que se sembró. Si $M$ es una ocupación aceptada, dos tercios del efecto total son legítimos y un tercio (0,15) es discriminación directa.
]

#caso-canonico("Un confusor mediador-resultado deforma el efecto directo")[
  Mismo proceso, pero con una variable $U$ no observada que afecta a $M$ y a $Y$: $M = 0.5 A + 0.8 U + epsilon_M$, $Y = 0.15 A + 0.6 M + 0.8 U + epsilon_Y$. El efecto total sigue siendo 0,45 y el directo verdadero 0,15. La regresión de $Y$ sobre $A$ y $M$ da un efecto directo de *−0,045*: no solo está lejos del valor verdadero sino que tiene el signo opuesto, de modo que un auditor concluiría que el algoritmo favorece al grupo protegido cuando en realidad lo perjudica. Es la violación de la condición (ii) de la proposición de la @sec-explicacionequidad-directoindirecto, y el error de signo es la razón por la que el análisis de sensibilidad a un confusor mediador-resultado no es opcional.
]

#caso-canonico("Quitar el atributo no quita la brecha")[
  El mérito $S$ es independiente del atributo $A$. Un proxy $P = A + epsilon_P$ (por ejemplo, el código postal) y una etiqueta histórica $Y = S + 0.5 P + epsilon$ que arrastra el proxy. Un modelo de decisión ajustado con $A$, $S$ y $P$ produce una brecha de 0,505 entre los grupos. Ajustado *sin $A$* (con $S$ y $P$) la brecha es 0,504: eliminar la variable sensible no cambia nada, porque el proxy hace el mismo trabajo (coeficientes de $S$ y $P$ de 0,996 y 0,501). Neutralizar el proxy en la decisión, evaluando el modelo con $P$ fijo en su media, reduce la brecha a 0,001.
]

El caso salarial de género es el ejemplo clásico de la literatura: el efecto total observado se descompone en una parte explicada por ocupación, experiencia y sector (efecto indirecto, cuya legitimidad es en sí misma objeto de debate normativo y no solo estadístico) y un residuo no explicado por esas variables (una aproximación al efecto directo). La descomposición de Oaxaca y Blinder, de la economía laboral, es un antecesor estadístico de la misma idea; el lenguaje de rutas añade la posibilidad de declarar, antes de estimar, qué mediadores se consideran legítimos.

#capa-impl[
== Implementación en Python
<sec-explicacionequidad-implementacion>

#figure(
  kind: raw,
  caption: [Descomposición de efectos con un modelo estructural lineal simulado.],
  ```python
import numpy as np

rng = np.random.default_rng(3)
n = 20_000

# A: atributo protegido (0/1). M: mediador legítimo (ocupación). Y: resultado (salario).
# Efecto directo deliberado (discriminación) = 0.15; efecto indirecto = 0.6 * 0.5 = 0.30.
A = rng.binomial(1, 0.5, size=n)
M = 0.5 * A + rng.normal(size=n)
Y = 0.15 * A + 0.6 * M + rng.normal(size=n)

efecto_total = Y[A == 1].mean() - Y[A == 0].mean()

# CDE: en un modelo lineal sin interacción A x M coincide con el coeficiente de A en Y ~ A + M.
# Se ESTIMA con los datos; no se usa el 0.15 del generador.
Z = np.column_stack([np.ones(n), A, M])
cde = np.linalg.lstsq(Z, Y, rcond=None)[0][1]

print(f"Efecto total A->Y:         {efecto_total:.3f}")
print(f"Efecto directo controlado: {cde:.3f}  (debería acercarse a 0.15)")
print(f"Efecto indirecto (vía M):  {efecto_total - cde:.3f}")
assert abs(cde - 0.15) < 0.05 and abs((efecto_total - cde) - 0.30) < 0.06   # coherencia
```
) <lst-descomposicion-directo-indirecto>

En un caso real, #code[dowhy] implementa estimadores de mediación que no requieren conocer el modelo estructural verdadero, siempre que el grafo de rutas, incluyendo cuáles se declaran legítimas, esté especificado.
]

== Riesgos, límites y sensibilidad
<sec-explicacionequidad-riesgos>

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos en el análisis causal de equidad.],
    table(
      columns: (1.3fr, 1.5fr, 1.4fr, 1.6fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Declarar legítimo un mediador afectado históricamente por $A$], [Se blanquea discriminación pasada (por ejemplo, acceso restringido a una ocupación por género)], [Análisis histórico de cómo $A$ determinó $M$], [Revisar con las partes interesadas antes de aceptar el mediador],
      table.hline(stroke: 0.4pt),
      [Tratar la legitimidad de una ruta como una cuestión estadística], [Un juicio normativo se presenta como resultado técnico], [Quién etiquetó las rutas y con qué criterio], [Etiquetar antes de estimar y documentar la decisión],
      table.hline(stroke: 0.4pt),
      [Confusor mediador-resultado no observado], [El efecto directo estimado puede errar incluso en el signo (caso 2)], [Análisis de sensibilidad al grado de confusión], [Reportar un rango de efecto directo; no concluir con un valor puntual],
      table.hline(stroke: 0.4pt),
      [Mediador omitido], [Se infla o se deforma el efecto directo], [Contrastar el grafo con datos adicionales], [Ampliar el grafo; sensibilidad al grafo],
      table.hline(stroke: 0.4pt),
      [Quitar solo la variable sensible], [La brecha persiste por los proxies (caso 3)], [Brecha de decisión con y sin $A$], [Neutralizar los proxies identificados en el grafo],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap23>
]

*Límites.* Igual que en el @cap-intervencion-contrafactual, toda la descomposición depende de que el grafo propuesto sea correcto. La equidad contrafactual exige además un modelo estructural completo, algo que pocos sistemas reales tienen. Y ningún análisis causal reemplaza la decisión normativa de qué se considera discriminación.

== Ejercicios y notas bibliográficas
<sec-explicacionequidad-ejercicios>

=== Ejercicios teóricos
<sec-explicacionequidad-ejercicios-teoricos>

+ Para el caso de la brecha salarial de género, proponga dos mediadores: uno que consideraría legítimo y uno que consideraría cuestionable aceptar como legítimo aun si estadísticamente media parte del efecto. Justifique la distinción normativa.

+ Explique por qué la equidad contrafactual de @kusner2017counterfactual es una noción de Nivel 3 y no de Nivel 1, y por qué eso la hace más difícil de verificar que la paridad demográfica.

+ Para el modelo del segundo caso canónico, calcule el límite del coeficiente de $A$ en la regresión de $Y$ sobre $A$ y $M$ en función de los pesos de $U$, y verifique que vale −0,045. Sugerencia: aplique el teorema de Frisch-Waugh-Lovell.

+ Muestre que, en el caso de un modelo lineal sin interacción, $"NDE" = "CDE"(m)$ para todo $m$ y $"NIE" = beta gamma$.

+ Explique por qué eliminar un proxy del conjunto de variables y neutralizarlo (evaluar el modelo con el proxy fijo) son operaciones distintas, y en qué situación darían el mismo resultado.

#capa-impl[
=== Ejercicio computacional
<sec-explicacionequidad-ejercicios-computacionales>

+ Modifique el #ref(<lst-descomposicion-directo-indirecto>, supplement: [listado]) para que el efecto directo verdadero sea 0 y verifique numéricamente que el CDE estimado converge a 0 mientras el efecto indirecto permanece distinto de cero. Luego añada un confusor $U$ entre $M$ e $Y$ y observe cómo cambia el CDE estimado.
]

=== Notas bibliográficas
<sec-explicacionequidad-notas>

Las fórmulas de mediación causal y la descomposición en efecto directo, indirecto y espurio se desarrollan en @pearl2009causality y se sistematizan para la equidad algorítmica en @bareinboim2025causalai. #cite(<kusner2017counterfactual>, form: "prose") introduce la equidad contrafactual como criterio formal de Nivel 3, y #cite(<kilbertus2017avoiding>, form: "prose") la contraparte de Nivel 2 con la distinción entre proxy e influencia no resuelta que estructura la @sec-explicacionequidad-contrafactual. #cite(<plecko2024causal>, form: "prose") sistematizan el análisis causal de equidad (efectos directos, indirectos y espurios) en una monografía de referencia. Los trabajos de Nabi y Shpitser y de Zhang y Bareinboim sobre efectos específicos por ruta separan la discriminación directa de la indirecta con mayor generalidad. El @cap-etica-interpretabilidad complementa este tratamiento causal con las definiciones observacionales estándar de la literatura de _fair machine learning_ (paridad demográfica, _equalized odds_, calibración) y con el resultado de imposibilidad que muestra que no pueden satisfacerse a la vez. La integración de equidad y causalidad es un área activa de investigación.
