// Capítulo 3: Modelos Causales Estructurales y la Jerarquía Causal de Pearl.
// Plantilla A (completa). Edición en capas: la teoría (L0) y los casos canónicos (L2) son lo que dura; los listados (L3)
// y los ejercicios computacionales van dentro de #capa-impl.
#import "../template/template.typ": *
#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

#chapter[Modelos Causales Estructurales y la Jerarquía Causal de Pearl]
<cap-scm-pch>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Formalizar matemáticamente qué significa "causa" y qué pregunta responde cada nivel de causalidad],
    [*Estimando:*], [Distribuciones $P(v)$, $P(y | "do"(x))$ y $P(y_x | "evidencia")$],
    [*Identificación:*], [Un Modelo Causal Estructural (SCM) más su grafo asociado],
    [*Método:*], [Do-calculus (adelanto; formalización completa en el @cap-intervencion-contrafactual)],
    [*Garantía:*], [Cada nivel de la PCH requiere estrictamente más supuestos que el anterior],
    ..if not es-principios {([*Librerías:*], [#code[networkx], #code[dowhy], #code[causal-learn]])},
    [*Validación:*], [Contraste de las independencias condicionales que el grafo supuesto implica],
  )
]

== El problema: formalizar "causa" matemáticamente
<sec-scmpch-problema>

El @cap-causalidad-elemental introdujo, de forma intuitiva, la distinción entre preguntas de asociación, de intervención y de contrafactual, junto con el marco de *resultados potenciales*. Este capítulo formaliza esa distinción con una segunda herramienta, el marco de *Modelos Causales Estructurales* (SCM) de Judea Pearl, que Elias Bareinboim y su escuela extienden hasta la *Jerarquía Causal de Pearl* (PCH). Los dos marcos son equivalentes para el uso que les da este libro, pero difieren en lo que hacen explícito. Los resultados potenciales son más naturales para razonar sobre un tratamiento y un resultado. Los SCM lo son para razonar sobre sistemas con muchas variables relacionadas entre sí, que es justo el tipo de sistema que aparece en un pipeline de datos de producción, y por eso son el lenguaje de la segunda mitad del libro cuando se habla de arquitectura de datos y de despliegue.

La pregunta que este capítulo responde es doble: *(i)* ¿qué objeto matemático representa por completo un sistema causal?, y *(ii)* dado ese objeto, ¿qué tres tipos de pregunta, y solo tres, se le pueden hacer, y qué información mínima requiere responder cada una?

== Teoría: SCM y la Jerarquía Causal de Pearl
<sec-scmpch-teoria>

=== Modelos Causales Estructurales
<sec-scmpch-scm>

#definition(name: [SCM])[
Un *Modelo Causal Estructural* (SCM) es una tupla $M = ⟨U, V, F, P(u)⟩$ donde: $U$ es un conjunto de variables exógenas (no modeladas, "de fondo"); $V = {V_1, ..., V_n}$ es un conjunto de variables endógenas (las que el modelo explica); $F = {f_1, ..., f_n}$ es un conjunto de funciones estructurales tales que cada $V_i = f_i ("pa"_i, U_i)$, donde $"pa"_i subset.eq V without {V_i}$ son los "padres" de $V_i$ (sus causas directas dentro del modelo) y $U_i subset.eq U$; y $P(u)$ es una distribución de probabilidad sobre las variables exógenas.
]

#figure(
  kind: image,
  placement: none,
  caption: [Grafo causal (DAG) inducido por un modelo causal estructural (SCM) de tres variables endógenas, con confusión de $Z$ sobre $X$ e $Y$. Cada nodo depende de sus padres estructurales y de un término de ruido exógeno independiente.],
  [
    #diagram(
      node-shape: fletcher.shapes.circle,
      node-fill: light,
      node-stroke: 1pt + navy,
      edge-stroke: 1pt + navy,
      spacing: (2.4cm, 1.6cm),

      node((0, 1), $U_Z$, stroke: 0.6pt + gray, fill: gray.lighten(85%), radius: 0.55cm, name: <uz>),
      node((0, 0), $Z$, radius: 0.7cm, name: <z>),
      node((2, 1), $U_X$, stroke: 0.6pt + gray, fill: gray.lighten(85%), radius: 0.55cm, name: <ux>),
      node((2, 0), $X$, radius: 0.7cm, name: <x>),
      node((4, 1), $U_Y$, stroke: 0.6pt + gray, fill: gray.lighten(85%), radius: 0.55cm, name: <uy>),
      node((4, 0), $Y$, radius: 0.7cm, name: <y>),

      edge(<uz>, <z>, "-|>", stroke: 0.6pt + gray),
      edge(<ux>, <x>, "-|>", stroke: 0.6pt + gray),
      edge(<uy>, <y>, "-|>", stroke: 0.6pt + gray),

      edge(<z>, <x>, "-|>"),
      edge(<x>, <y>, "-|>"),
      edge(<z>, <y>, "-|>", bend: 35deg),
    )
    #v(0.5em)
    #align(center)[
      #text(font: sans-font, size: 9pt, style: "italic", fill: gray)[
        $Z := f_Z (U_Z)$ #h(1.2em) $X := f_X (Z, U_X)$ #h(1.2em) $Y := f_Y (X, Z, U_Y)$
      ]
    ]
  ]
) <fig-scm-dag>

Cada SCM induce un *grafo causal* $G$: un nodo por cada variable en $V$ y una flecha $V_j arrow.r V_i$ si $V_j in "pa"_i$. Este grafo, el mismo objeto que el @cap-causalidad-elemental usó de manera informal para hablar de confusores, no es una descripción estadística sino una afirmación sobre *mecanismos*: cada ecuación $V_i = f_i ("pa"_i, U_i)$ representa un proceso físico, biológico, económico o social real, y no una relación estadística ajustada a los datos. Esta es la diferencia esencial entre un modelo causal y un modelo predictivo. Un modelo predictivo puede ajustar $Y$ en función de $X$ sin comprometerse con ninguna afirmación sobre mecanismos; un SCM afirma que si se *intervinieran* las causas de $Y$, $Y$ cambiaría exactamente según su ecuación estructural.

La conexión con el marco de resultados potenciales del @cap-causalidad-elemental es directa. Dado un SCM con variable de tratamiento $D$ y resultado $Y = f_Y (D, X, U_Y)$, el resultado potencial $Y(d)$ se define como el valor que toma la ecuación estructural de $Y$ al fijar $D = d$: $Y(d) := f_Y (d, X, U_Y)$. Bajo esta correspondencia, los dos marcos son dos lenguajes para el mismo objeto.

=== Los tres niveles de la Jerarquía Causal de Pearl
<sec-scmpch-pch>

Cada SCM $M$ induce tres distribuciones de probabilidad distintas, que corresponden exactamente a los tres niveles adelantados en el @cap-causalidad-elemental:

#entero[
#table(
  columns: (1fr, 2.3fr, 2.3fr),
  align: left,
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Nivel (PCH)*], [*Distribución inducida*], [*Se calcula con*]),
  [$cal(L)_1$: Asociación], [$P(v)$: la distribución observacional conjunta de $V$], [Los datos observados, sin modificar $M$],
  [$cal(L)_2$: Intervención], [$P(y | "do"(x))$: la distribución de $Y$ tras _reemplazar_ la ecuación de $X$ por la constante $x$], [El SCM "quirúrgicamente modificado" $M_x$ (se borra $f_X$ y se fija $X=x$)],
  [$cal(L)_3$: Contrafactual], [$P(y_x | e)$: la distribución de "$Y$ hubiera sido $y$ si $X$ hubiera sido $x$", dada la evidencia $e$ efectivamente observada], [Un procedimiento de tres pasos: abducción, acción, predicción (ver más abajo)],
)
]

El operador $"do"(x)$ formaliza qué significa "intervenir". No es lo mismo *observar* que $X=x$, lo que simplemente selecciona el subconjunto de unidades con $X=x$ y por tanto puede estar contaminado por confusión, como en las tres escenas del @cap-causalidad-elemental, que *forzar* $X=x$ mediante una intervención externa que anula el mecanismo natural por el que $X$ se determinaba. Formalmente, $P(y | "do"(x)) != P(y | X=x)$ en general. Las dos coinciden cuando no hay confusión entre $X$ e $Y$, la condición que el resto del libro dedica tanto esfuerzo a verificar o inducir; con confusión pueden coincidir solo por una cancelación fortuita.

#example[
*Los tres niveles sobre el mismo SCM.* Considere el SCM simplificado $D = f_D (U_D)$, $Y = f_Y (D, X, U_Y)$, $X = f_X (U_X)$, con $U_D$ y $U_Y$ correlacionados (confusión no observada entre $D$ e $Y$). En $cal(L)_1$, $P(y | D=d)$ mezcla el efecto de $D$ sobre $Y$ con la correlación espuria inducida por $U_D$ y $U_Y$ compartidos. En $cal(L)_2$, $P(y | "do"(D=d))$ se calcula sobre el modelo modificado donde $f_D$ se reemplaza por la constante $d$, lo que corta el vínculo entre $U_D$ y $D$ y elimina así exactamente la confusión. En $cal(L)_3$, dado que se observó a un individuo específico con $D=0, Y=y_0$, la pregunta "¿qué $Y$ habría tenido si $D$ hubiera sido 1?" requiere primero *inferir* la distribución de $U_D, U_Y$ compatible con lo observado (abducción), luego *forzar* $D=1$ en el modelo (acción) y finalmente *propagar* para predecir $Y$ (predicción). De ahí el nombre del procedimiento de tres pasos de Pearl para el cómputo contrafactual.
]

#let peldanio(num, color, nombre, notacion, pregunta, sangria) = block(
  width: 100%,
  inset: (left: sangria),
)[
  #block(
    fill: color.lighten(88%),
    stroke: (left: 3pt + color),
    radius: 3pt,
    inset: (left: 12pt, right: 10pt, top: 8pt, bottom: 8pt),
    width: 100%,
  )[
    #grid(
      columns: (auto, 1fr),
      column-gutter: 10pt,
      align: (center + horizon, left + horizon),
      circle(radius: 0.8em, fill: color, inset: 0pt)[
        #align(center + horizon)[#text(font: sans-font, fill: white, weight: "bold", size: 12pt)[#num]]
      ],
      [
        #text(font: sans-font, fill: color.darken(10%), weight: "bold", size: 11pt)[#nombre]
        #linebreak()
        #text(size: 10pt)[#notacion]
        #linebreak()
        #text(size: 9.5pt, style: "italic", fill: gray)[#pregunta]
      ]
    )
  ]
]

#figure(
  kind: image,
  placement: auto,
  caption: [La escalera de causalidad. Cada peldaño responde un tipo de pregunta que los datos del peldaño inferior, por sí solos, no pueden resolver sin supuestos adicionales.],
  [
    #peldanio(1, gray.darken(10%), "Asociación", $P(y|x)$, [«¿Qué me dice ver $X=x$ sobre $Y$?»], 0cm)
    #v(0.4em)
    #align(center)[#text(fill: gray, size: 12pt)[$arrow.t$]]
    #v(0.4em)
    #peldanio(2, accent, "Intervención", $P(y|op("do")(x))$, [«¿Qué pasa con $Y$ si yo fijo $X=x$?»], 1cm)
    #v(0.4em)
    #align(center)[#h(1cm)#text(fill: accent, size: 12pt)[$arrow.t$]]
    #v(0.4em)
    #peldanio(3, navy, "Contrafactual", $P(y_x|x', y')$, [«¿Qué habría pasado con $Y$ si $X$ hubiera sido $x$, dado lo que de hecho ocurrió?»], 2cm)
    #v(0.6em)
    #frontera(2022)[
      *Teorema de jerarquía causal* (Bareinboim, Correa, Ibeling e Icard). Las tres capas de la jerarquía de Pearl son, en general, estrictamente distintas: salvo en un conjunto de SCM de medida nula (casos degenerados, p. ej. sin confusión o sin componentes aleatorias), ninguna distribución de intervención o de contrafactual se recupera a partir de las capas inferiores sin supuestos estructurales adicionales. La separación no es solo pedagógica: casi ningún SCM colapsa estas capas.
    ]
  ]
) <fig-escalera-pearl>

Hay aquí un punto que suele perderse en presentaciones más elementales de esta jerarquía: la separación entre niveles no es una limitación práctica de los métodos disponibles, sino un resultado formal.

#theorem(name: [Teorema de la Jerarquía Causal])[
Sea $Omega$ el espacio de SCM sobre un conjunto de variables $V$, equipado con una medida de probabilidad natural sobre las funciones estructurales y las distribuciones exógenas. El conjunto de SCM para los cuales las distribuciones de nivel $cal(L)_(k+1)$ quedan *determinadas* por las de nivel $cal(L)_k$ tiene medida cero en $Omega$, para $k = 1, 2$.
] <thm-cht>

En términos operativos, salvo en un conjunto excepcional de casos (de medida nula), dos SCM distintos pueden inducir exactamente la misma distribución observacional $P(v)$ y, sin embargo, distintas distribuciones interventivas $P(y | "do"(x))$, y análogamente entre $cal(L)_2$ y $cal(L)_3$. Por eso ningún procedimiento que opere únicamente sobre $P(v)$ puede, sin supuestos adicionales, recuperar $P(y | "do"(x))$: la información no está ahí. El *Teorema de la Jerarquía Causal* (#cite(<bareinboim2022pch>, form: "prose")) establece que, casi siempre, los tres niveles de la escalera causal están estrictamente separados. Este resultado, presentado de forma integrada con el resto del programa de IA causal en @bareinboim2025causalai, es la razón formal, y no solo intuitiva, de la tesis del @cap-causalidad-elemental: los datos observacionales solos no responden preguntas causales.

Dos consecuencias prácticas se siguen de inmediato, y estructuran el resto del libro. Primera: todo método de estimación causal a partir de datos observacionales (DML, PDS, meta-learners, bosques causales) debe importar información externa a los datos, y esa información es siempre un supuesto de identificación, típicamente la afirmación de que las covariables observadas cierran todas las rutas de puerta trasera (@cap-intervencion-contrafactual). Segunda: ese supuesto no se puede validar con los datos que se están usando, porque su función es suplir justamente lo que los datos no contienen. A lo sumo puede *refutarse* si genera implicaciones observacionales que los datos contradicen (@sec-scmpch-caso), o someterse a análisis de sensibilidad (@cap-validacion). Ninguna cantidad de datos ni ningún algoritmo cambia esta situación.

#import "@preview/fletcher:0.5.8" as fletcher: diagram, node, edge

#figure(
  placement: none,
  diagram(
    spacing: (16mm, 13mm),
    node-stroke: 0.9pt,
    edge-stroke: 0.9pt,
    mark-scale: 65%,
    
    // ========== Fila superior: las 3 orientaciones equivalentes ==========
    
    // Cadena A → B → C
    node((0, 2), $A$, name: <a1>),
    node((1, 2), $B$, name: <b1>),
    node((2, 2), $C$, name: <c1>),
    edge(<a1>, <b1>, "->"),
    edge(<b1>, <c1>, "->"),
    // etiqueta
    node((1, 2.55), text(size: 8pt)[cadena], stroke: none),

    // Cadena inversa C → B → A
    node((3.8, 2), $C$, name: <c2>),
    node((4.8, 2), $B$, name: <b2>),
    node((5.8, 2), $A$, name: <a2>),
    edge(<c2>, <b2>, "->"),
    edge(<b2>, <a2>, "->"),
    node((4.8, 2.55), text(size: 8pt)[cadena inversa], stroke: none),

    // Bifurcación A ← B → C
    node((7.6, 2), $A$, name: <a3>),
    node((8.6, 2), $B$, name: <b3>),
    node((9.6, 2), $C$, name: <c3>),
    edge(<b3>, <a3>, "->"),
    edge(<b3>, <c3>, "->"),
    node((8.6, 2.55), text(size: 8pt)[bifurcación], stroke: none),

    // ========== Fila inferior ==========
    
    // CPDAG (aristas sin orientar)
    node((2.2, 0.3), $A$, name: <a4>, stroke: 1.1pt + navy),
    node((3.4, 0.3), $B$, name: <b4>, stroke: 1.1pt + navy),
    node((4.6, 0.3), $C$, name: <c4>, stroke: 1.1pt + navy),
    edge(<a4>, <b4>, "--"),
    edge(<b4>, <c4>, "--"),

    // Flecha de implicación
    node((5.7, 0.3), $=>$, stroke: none),

    // Colisionador (fuera de la clase) en rojo
    node((7.2, 0.3), $A$, name: <a5>, stroke: 1.1pt + red.darken(20%)),
    node((8.4, 0.3), $B$, name: <b5>, stroke: 1.1pt + red.darken(20%)),
    node((9.6, 0.3), $C$, name: <c5>, stroke: 1.1pt + red.darken(20%)),
    edge(<a5>, <b5>, "->", stroke: red.darken(20%)),
    edge(<c5>, <b5>, "->", stroke: red.darken(20%)),
  ),
  caption: [
    Clase de equivalencia de Markov del esqueleto $A - B - C$. 
    La cadena, la cadena inversa y la bifurcación codifican la misma independencia 
    $A perp C | B$ y colapsan en el mismo CPDAG (aristas sin orientar). 
    El colisionador $A -> B <- C$ codifica en cambio $A perp C$ (marginal) y 
    queda fuera de la clase; su CPDAG conserva ambas flechas porque la 
    v-estructura es identificable a partir de los datos.
  ]
) <fig-scm-dag>


== De la ecuación a los números: un caso canónico
<sec-scmpch-algoritmo>

Simular una intervención sobre un SCM conocido es un procedimiento corto. Se conservan las ecuaciones de todas las variables salvo la de $D$, se sustituye la de $D$ por la constante $d$, se generan las demás variables con las mismas exógenas y se calcula la cantidad de interés. Lo que se obtiene es $P(y | "do"(D=d))$, que se compara con $P(y | D=d)$ calculada sobre los datos sin intervenir.

#caso-canonico("Becas y motivación no observada")[
  Una versión estilizada del ejemplo de becas y calificaciones del @cap-causalidad-elemental. La motivación $U$ es normal estándar y no se observa. Una persona pide la beca ($D = 1$) cuando $U + epsilon_D > 0.3$, con $epsilon_D$ normal estándar, de modo que las más motivadas piden más becas. La calificación es $Y = 0.4 D + 0.9 U + epsilon_Y$, con $epsilon_Y$ de desviación 0,5, y el efecto causal verdadero de la beca vale 0,4 por construcción.

  Con 50 000 unidades, la diferencia de medias entre quienes recibieron la beca y quienes no es 1,43, es decir, 3,6 veces el efecto verdadero. Al simular $"do"(D=1)$ y $"do"(D=0)$ sobre toda la población, la diferencia es 0,40. La diferencia asociativa está inflada por la confusión a través de $U$; el efecto interventivo recupera el 0,4 porque $"do"()$ anula el mecanismo que generaba $D$ a partir de $U$.
]

#capa-impl[
El listado construye ese SCM y calcula las dos cantidades.

#entero[
#figure(
  kind: raw,
  caption: [SCM simulado: divergencia entre asociación e intervención.],
  ```python
import numpy as np
import pandas as pd

rng = np.random.default_rng(7)
n = 50_000

# U: motivación no observada (confusor de D y de Y)
U = rng.normal(size=n)

# D (beca): depende de U -- estudiantes mas motivados piden mas becas
D_obs = (U + rng.normal(size=n) > 0.3).astype(int)

# Y (calificacion): depende de D (efecto causal verdadero = 0.4) y de U
Y_obs = 0.4 * D_obs + 0.9 * U + rng.normal(scale=0.5, size=n)

df = pd.DataFrame({"U": U, "D": D_obs, "Y": Y_obs})

# Nivel 1 (asociacion): P(Y | D=1) observacional
assoc = df.loc[df["D"] == 1, "Y"].mean() - df.loc[df["D"] == 0, "Y"].mean()

# Nivel 2 (intervencion): simular do(D=1) para TODA la poblacion,
# reemplazando la ecuacion estructural de D por la constante 1
Y_do1 = 0.4 * 1 + 0.9 * U + rng.normal(scale=0.5, size=n)
Y_do0 = 0.4 * 0 + 0.9 * U + rng.normal(scale=0.5, size=n)
intervencion = Y_do1.mean() - Y_do0.mean()

print(f"Diferencia asociativa  P(Y|D=1)-P(Y|D=0):  {assoc:.3f}")
print(f"Efecto interventivo    P(Y|do(D=1))-do(0): {intervencion:.3f}")
print(f"Efecto causal verdadero (por construccion): 0.400")
# La diferencia asociativa esta inflada por la confusion via U;
# el efecto interventivo recupera el 0.4 verdadero porque do()
# anula el mecanismo que generaba D a partir de U.
```
) <lst-scm-do-simulacion>
]
]

En la práctica no se observa $U$ ni se puede "reemplazar la ecuación de $D$", porque la simulación conoce el SCM verdadero. El problema aplicado de identificación, que el resto del libro desarrolla, es cómo estimar $P(y | "do"(x))$ *sin* conocer el SCM completo, usando solo datos observacionales más supuestos sobre el grafo (por ejemplo, con Post-Double-Selection o DML, si se asume no confusión condicional en las covariables observadas).

== Consistencia del grafo supuesto con los datos
<sec-scmpch-caso>

Antes de estimar un efecto conviene comprobar que el grafo supuesto sea *consistente* con los datos. Todo grafo implica, por d-separación, ciertas independencias condicionales entre las variables observadas (la definición se da en el @cap-descubrimiento-grafos), y esas sí se pueden contrastar. El chequeo es *necesario pero no suficiente*, y el Teorema de la Jerarquía Causal explica por qué. Varios grafos distintos inducen exactamente el mismo conjunto de independencias condicionales: son observacionalmente equivalentes y forman lo que el @cap-descubrimiento-grafos llamará su *clase de equivalencia de Markov*, de modo que pasar el contraste no los distingue. Lo que el contraste sí puede hacer es *refutar*: si el grafo implica una independencia que los datos rechazan, alguno de sus supuestos es falso.

Hay dos precauciones, y la segunda es la que más se olvida. La primera es que el contraste refuta el conjunto de supuestos y no dice cuál de ellos falla. La segunda es que *la independencia hay que derivarla del grafo antes de contrastarla*: condicionar en la variable equivocada puede destruirla, y un grafo correcto sale entonces "refutado" por una prueba que nunca debió aplicarse.

#caso-canonico("Una cadena con y sin confusión no observada")[
  Tres variables continuas: $Z$ (por ejemplo, la cercanía a una universidad), $D$ (educación) e $Y$ (salario). En el primer mundo, $D = 0.8 Z + epsilon_D$ e $Y = 0.5 D + epsilon_Y$. La cadena $Z arrow.r D arrow.r Y$, sin confusión entre $D$ e $Y$, implica $Z perp perp Y | D$. En el segundo mundo se añade una variable $U$ no observada que entra con coeficiente 1 en $D$ y en $Y$, el tipo de confusión que justifica usar $Z$ como instrumento.

  Con 2 000 unidades y 300 repeticiones, la correlación parcial de $Z$ e $Y$ dado $D$ vale en promedio −0,001 en el primer mundo, y el contraste de Fisher rechaza al 5 % en el 4,7 % de las repeticiones, el nivel nominal. En el segundo, la correlación parcial vale en promedio −0,27 y el contraste rechaza en el 100 % de las repeticiones.

  El grafo del segundo mundo es el correcto, y el contraste lo rechaza igual. Condicionar en $D$, que es un collider en el camino $Z arrow.r D arrow.l U arrow.r Y$, abre ese camino y crea una asociación que el grafo nunca declaró como independencia. De hecho, el modelo de variable instrumental con confusión no observada no implica ninguna independencia condicional entre las tres variables observadas: no hay nada que contrastar.
]

La lección tiene dos caras. Cuando el analista afirma que no hay confusión no observada entre $D$ e $Y$ (la no confusión condicional que usan los métodos del libro) y dispone de una variable $Z$ que, según el grafo, solo afecta a $Y$ a través de $D$, la independencia $Z perp perp Y | D$ es una implicación contrastable de esa afirmación, y rechazarla es un motivo serio para dudar de ella. Cuando en cambio el diseño admite confusión no observada, como en un instrumento, esa misma independencia no existe y la prueba carece de sentido.

#capa-impl[
El segundo listado implementa el contraste gaussiano (correlación parcial por residuos de mínimos cuadrados y la transformación $z$ de Fisher) y lo aplica a los dos mundos del caso canónico. Las bibliotecas de descubrimiento causal del Apéndice B ofrecen este mismo contraste y otros que no suponen normalidad.

#entero[
#figure(
  kind: raw,
  caption: [Contraste de independencia condicional con correlación parcial, aplicado a una cadena con y sin confusión no observada.],
  ```python
import numpy as np
from scipy import stats


def correlacion_parcial(a, b, c):
    """Correlacion parcial de a y b dado c (matriz n x k), por residuos de minimos cuadrados."""
    C = np.c_[np.ones(len(a)), c]
    ra = a - C @ np.linalg.lstsq(C, a, rcond=None)[0]
    rb = b - C @ np.linalg.lstsq(C, b, rcond=None)[0]
    return np.corrcoef(ra, rb)[0, 1]


def contraste_fisher(a, b, c):
    """Contraste de independencia condicional (gaussiano): z de Fisher de la correlacion parcial."""
    c = np.asarray(c).reshape(len(a), -1)
    r = correlacion_parcial(a, b, c)
    z = np.sqrt(len(a) - c.shape[1] - 3) * np.arctanh(r)
    return r, 2 * (1 - stats.norm.cdf(abs(z)))


def mundo(n, semilla, con_confusion, efecto_directo=0.0):
    """Cadena Z -> D -> Y; con_confusion agrega U no observada en D e Y; efecto_directo agrega Z -> Y."""
    g = np.random.default_rng(semilla)
    z = lambda: g.normal(size=n)
    Z = z()
    U = z() if con_confusion else np.zeros(n)
    D = 0.8 * Z + U + z()
    Y = 0.5 * D + U + efecto_directo * Z + z()
    return Z, D, Y


for con in (False, True):
    Z, D, Y = mundo(2000, 0, con)
    r, p = contraste_fisher(Z, Y, D)
    print(f"confusion no observada: {con!s:5}  correlacion parcial {r:+.3f}  p = {p:.3g}")
```
) <lst-contraste-fisher>
]
]

== Qué cambia en un sistema desplegado
<sec-scmpch-sistema>

Los tres niveles no son solo una clasificación teórica. Cada salida de un sistema en producción responde a uno de ellos, y el sistema tiene que saber a cuál. Un puntaje predictivo vive en $cal(L)_1$. Un efecto de política (qué pasa si se asigna el tratamiento a esta población) vive en $cal(L)_2$. Una explicación para un caso individual (qué habría pasado con esta persona si...) vive en $cal(L)_3$ y exige supuestos sobre las ecuaciones estructurales que ni siquiera un experimento puede comprobar. El nivel que una salida responde forma parte, por eso, de su contrato con quien la consume: la ficha del modelo (@cap-model-card-causal) lo declara en el campo del estimando, y el servicio (@cap-despliegue-servicio) devuelve un efecto con su intervalo y no un puntaje.

Hay además un segundo efecto, que el @cap-anatomia-sistema desarrolla en la @sec-anatomia-intervencion. Al desplegarse, el sistema sustituye en el mundo la ecuación estructural por la que se asignaba el tratamiento por una regla de decisión propia. Es el operador $"do"()$ aplicado al mundo real, y por eso los datos que el sistema produce después ya no provienen del SCM con que se entrenó.

== Riesgos, límites y sensibilidad
<sec-scmpch-riesgos>

#riesgos[
  - *Confundir $P(y | X=x)$ con $P(y | "do"(x))$.* Es, con diferencia, el error más frecuente entre practicantes de _machine learning_ que se acercan por primera vez a la inferencia causal: tratar un filtro de la tabla como si fuera una intervención. Son el mismo objeto solo si no hay confusión.
  - *Asumir que el grafo es "el verdadero".* Un SCM formaliza supuestos, no los verifica. Ningún test estadístico puede confirmar que un grafo causal es correcto; solo puede refutarlo si es inconsistente con los datos. La responsabilidad de argumentar el grafo es del analista, no del algoritmo.
  - *Contrastar una independencia que el grafo no implica.* Condicionar en un collider, o en un descendiente suyo, crea la asociación que se pretendía descartar. Antes de usar un contraste para refutar un grafo hay que derivar la independencia con la regla de d-separación.
  - *Tratar $cal(L)_3$ como si fuera $cal(L)_2$.* Una pregunta contrafactual ("¿habría aprobado María si...?") no se responde con el mismo procedimiento que una pregunta interventiva poblacional ("¿qué pasaría si becáramos a todos?"). Colapsar ambas, algo muy común en la comunicación de resultados a audiencias no técnicas, puede llevar a promesas que el modelo no puede respaldar.
]

== Ejercicios y notas bibliográficas
<sec-scmpch-ejercicios>

=== Ejercicios teóricos
<sec-scmpch-ejercicios-teoricos>

+ Escriba el SCM (variables, ecuaciones estructurales, grafo) para el ejemplo de la paradoja de Simpson del @cap-causalidad-elemental (tratamiento, gravedad del caso, recuperación). Indique cuál nodo es el confusor.

+ Para el SCM del ejercicio anterior, escriba explícitamente el modelo modificado $M_{"do"(D=1)}$ y explique, en términos del grafo, qué arista(s) desaparece(n).

+ Explique por qué, en general, $P(y | "do"(x))$ no puede calcularse a partir de $P(v)$ sin supuestos adicionales sobre el grafo (Teorema de la Jerarquía Causal). Dé un ejemplo de dos SCM distintos que induzcan la misma $P(v)$ pero distinta $P(y | "do"(x))$.

+ Para el grafo con $Z arrow.r D$, $D arrow.r Y$, $U arrow.r D$ y $U arrow.r Y$, donde $U$ no se observa, liste las independencias condicionales que implica entre $Z$, $D$ e $Y$. ¿Cuántas hay? Relacione la respuesta con el caso canónico de la @sec-scmpch-caso.

#capa-impl[
=== Ejercicios computacionales
<sec-scmpch-ejercicios-computacionales>

+ Modifique el #ref(<lst-scm-do-simulacion>, supplement: [listado]) para que el efecto causal verdadero de $D$ sobre $Y$ sea 0 (sin efecto), manteniendo la confusión vía $U$. Verifique que la diferencia asociativa sigue siendo distinta de cero mientras que el efecto interventivo converge a 0.

+ Con las funciones del #ref(<lst-contraste-fisher>, supplement: [listado]), agregue al mundo sin confusión un camino directo $Z arrow.r Y$ de coeficiente 0,3 (parámetro `efecto_directo`). ¿Qué hace el contraste? ¿Puede decir si el rechazo se debe al camino directo o a una confusión no observada? Explique.
]

=== Notas bibliográficas
<sec-scmpch-notas>

La referencia canónica del Teorema de la Jerarquía Causal, incluida la construcción precisa de la medida sobre el espacio de SCM que da sentido a la expresión "medida cero", es #cite(<bareinboim2022pch>, form: "prose"); su enunciado aquí es deliberadamente informal en ese punto. El capítulo sigue por lo demás la formalización de @bareinboim2025causalai, fuente principal de contenido teórico-causal del libro, y la exposición clásica de @pearl2009causality, que introduce el operador $"do"()$, el procedimiento de tres pasos para el cómputo contrafactual y el cálculo-$"do"$ que se enuncia formalmente en el @cap-intervencion-contrafactual. #cite(<imbens2015causal>, form: "prose") discute en detalle la equivalencia formal entre el marco de resultados potenciales y el de SCM. Para una introducción visual y menos técnica a la jerarquía, véase de nuevo @pearlmackenzie2018, ya citado en el @cap-causalidad-elemental. El conjunto de datos de #cite(<card1995>, form: "prose"), que los capítulos de estimación usan como ejemplo, es el contexto en que la cercanía a una universidad se propone como instrumento de la educación.
