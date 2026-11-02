// Capítulo 25: Decisiones estructurales bajo incertidumbre.
// Edición en capas: la teoría (L0), el procedimiento (L1) y los casos canónicos con cifras verificadas (L2)
// son lo que dura; el listado (L3) va dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Decisiones estructurales bajo incertidumbre]
<cap-decisiones-estructurales>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Elegir entre acciones, no solo estimar el efecto de una acción dada],
    [*Estimando:*], [Utilidad esperada bajo cada acción candidata, $E[U(Y("do"(d)))]$, y el valor de reducir la incertidumbre antes de decidir],
    [*Identificación:*], [Efecto identificado y con soporte en los datos para cada acción candidata, más una función de utilidad declarada],
    [*Método:*], [Maximización de utilidad esperada, con criterios de peor caso y de arrepentimiento cuando la incertidumbre importa],
    [*Garantía:*], [Si cada efecto está identificado y bien estimado, la acción elegida es la óptima mientras la mejor se separe de la segunda; cerca de un empate la elección es inestable],
    ..if not es-principios {([*Librerías:*], [numpy; `scipy.optimize` y los módulos de política de econml para espacios de acciones grandes])},
    [*Validación:*], [Comparación con el _status quo_, mapa de regiones de decisión según los parámetros normativos y valor de la información],
  )
]

== Problema causal, estimando e identificación
<sec-decisionesestructurales-problema>

El @cap-policy-learning resolvió una versión de este problema: dado un CATE estimado, a quién asignar un tratamiento binario bajo una restricción de presupuesto. Este capítulo generaliza la pregunta en dos direcciones, que Bareinboim agrupa bajo el nombre de *decisiones estructurales*. Primero, la acción no tiene por qué ser binaria ni consistir en tratar o no tratar a cada unidad: puede ser elegir entre varios programas alternativos, fijar un parámetro continuo o intervenir sobre más de una variable a la vez. Segundo, la decisión exige una *función de utilidad* explícita y no solo un efecto estimado, porque comparar acciones distintas obliga a decir cuánto vale cada resultado posible y no solo cuál es más probable.

Tres ideas organizan el capítulo. La utilidad es en parte una decisión normativa y debe escribirse. La incertidumbre sobre los efectos entra en la decisión por vías precisas, y ninguna de ellas es la de ensanchar un intervalo y esperar que cambie la recomendación. Y la acción de recolectar información pertenece al conjunto de acciones factibles, aunque casi nunca se la incluya.

== Teoría, supuestos y garantías
<sec-decisionesestructurales-teoria>

=== La decisión como maximización de utilidad esperada
<sec-decisionesestructurales-formalizacion>

#definition(name: [Decisión óptima])[
Dado un conjunto de acciones factibles $cal(D)$ y una función de utilidad $U: cal(Y) arrow.r RR$ que asigna un valor a cada resultado posible, la *acción óptima* es
$ d^* = op("argmax", limits: #true)_(d in cal(D)) E[U(Y("do"(d)))] $
donde $E[U(Y("do"(d)))]$ se calcula con la distribución interventiva de Nivel 2 de la PCH (@cap-scm-pch) inducida por cada acción candidata $d$.
]

La diferencia con la estimación de los capítulos anteriores es sutil pero importante. Estimar $tau(x)$ responde cuál es el efecto; resolver $d^*$ responde qué debería hacerse, y esa segunda pregunta siempre exige una función de utilidad, aunque nadie la haya escrito. Cuando el @cap-policy-learning maximizaba el valor de la política sujeto a un presupuesto, ya usaba una utilidad particular, lineal en el resultado y con una restricción de costo. Este capítulo hace explícito que elegir esa utilidad es una decisión de modelado con consecuencias.

Hay un resultado elemental que conviene tener presente antes de hablar de incertidumbre. Sea $U(d, tau) = v tau_d - c_d$ la utilidad de la acción $d$, con $v$ el valor de una unidad de efecto, $c_d$ el costo de la acción y $tau = (tau_d)_(d in cal(D))$ el vector de efectos, que quien decide no conoce. La distribución con que se describe esa ignorancia es la del analista (una distribución posterior, o la aproximación normal centrada en la estimación y con su error estándar); es una elección de modelado y no un dato.

#proposition(name: [Utilidad lineal e incertidumbre])[
  Si $tau$ tiene media $bar(tau)$ bajo esa distribución, entonces $E[U(d, tau)] = v bar(tau)_d - c_d$ para toda acción $d$. La acción de máxima utilidad esperada depende solo de las medias $bar(tau)_d$, y no cambia si la incertidumbre alrededor de ellas se ensancha, se estrecha o se reparte de otra manera.
]
#proof[
  Es la linealidad de la esperanza: $E[v tau_d - c_d] = v E[tau_d] - c_d$.
]

La proposición es casi trivial y sus consecuencias no lo son. Con utilidad lineal, un intervalo de confianza ancho no modifica la acción que recomienda la utilidad esperada; informa, pero no decide. Los intervalos de utilidad que se añaden a las tablas de decisión sirven para otra cosa: para saber si conviene fiarse de la recomendación. La incertidumbre cambia la decisión por tres vías, que las secciones siguientes desarrollan: cuando la utilidad no es lineal (aversión al riesgo), cuando el criterio no es la esperanza (peor caso, arrepentimiento) y cuando puede comprarse información antes de decidir.

=== Criterios de decisión cuando el efecto no está identificado con precisión
<sec-decisionesestructurales-criterios>

Maximizar la utilidad esperada con la estimación puntual es el criterio por defecto, pero no el único defendible, y adoptarlo sin decirlo esconde un supuesto fuerte: que la incertidumbre cabe en una media y que el estimador puntual puede tratarse como el valor verdadero. La teoría estadística de la decisión ofrece un vocabulario preciso para las alternativas. #cite(<manski2004statistical>, form: "prose") lo llevó al problema de elegir una regla de tratamiento con datos de un experimento, usando el criterio de arrepentimiento minimax, y el mismo criterio se aplica cuando el efecto está solo *parcialmente identificado*, es decir, cuando datos y supuestos acotan $tau$ dentro de un conjunto en vez de fijarlo.

Tres criterios cubren el espectro de posturas razonables:

#table(
  columns: (1.2fr, 1.8fr, 2fr),
  align: left,
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Criterio*], [*Qué maximiza*], [*Cuándo es defendible*]),
  [Utilidad esperada], [$E[U(Y("do"(d)))]$ bajo la distribución de incertidumbre elegida], [Efecto bien identificado y estimado con precisión; decisión repetida muchas veces, de modo que los promedios se realizan],
  [_Maximin_ (Wald)], [El peor resultado posible dentro del conjunto de escenarios: $max_d min_(tau in cal(T)) U(d, tau)$], [Decisiones irreversibles o con consecuencias graves en el peor escenario; aversión fuerte a la ambigüedad],
  [_Minimax regret_ (Savage)], [La menor pérdida máxima respecto de la mejor acción en cada escenario: $min_d max_(tau in cal(T)) [max_(d') U(d', tau) - U(d, tau)]$], [Cuando el maximin resulta paralizante por concentrarse en escenarios extremos poco plausibles],
)

Los dos criterios de la derecha dependen de un conjunto de escenarios $cal(T)$ que alguien debe declarar. En este capítulo se usa el intervalo de confianza de 95 % de cada efecto como sustituto práctico de ese conjunto. Es una simplificación: un intervalo de confianza resume el error de muestreo, mientras que un conjunto identificado genuino resume lo que los datos y los supuestos no pueden distinguir, y no se estrecha al crecer la muestra. Quien tenga cotas de identificación parcial debe usarlas en su lugar.

La diferencia entre los criterios no es académica. Con un efecto cuyo intervalo cruza el cero, la utilidad esperada puede recomendar intervenir porque el punto estimado es positivo, mientras el maximin recomienda no hacerlo porque el peor caso es dañino. El minimax regret puede recomendar una tercera cosa. Reportar cuál criterio se aplicó es tan importante como reportar el efecto estimado, porque la recomendación depende de ambos.

=== El valor de la información
<sec-decisionesestructurales-informacion>

Una acción que el marco de utilidad esperada suele dejar fuera del conjunto $cal(D)$, y que casi siempre debería estar dentro, es *no decidir todavía y obtener más datos*. Su valor se calcula con las mismas piezas.

#definition(name: [Valor esperado de la información perfecta])[
$ "EVPI" = E_tau [max_(d in cal(D)) U(d, tau)] - max_(d in cal(D)) E_tau [U(d, tau)] $
Es lo que se ganaría en promedio si el verdadero $tau$ se conociera antes de elegir.
]

#proposition(name: [Cota del valor de un estudio])[
  Se cumple $"EVPI" >= 0$, con igualdad si y solo si existe una acción que es óptima con probabilidad uno. Además, para cualquier estudio con resultado $S$, su valor esperado $"EVSI" = E_S [max_d E[U(d, tau) | S]] - max_d E[U(d, tau)]$ cumple $0 <= "EVSI" <= "EVPI"$.
]
#proof(kind: "sketch")[
  El máximo de esperanzas no supera a la esperanza del máximo, y coinciden solo si la misma acción alcanza el máximo casi seguramente. Para el EVSI, $max_d E[U | S] <= E[max_d U | S]$ para cada resultado $S$; tomando esperanza sobre $S$ se obtiene $"EVSI" <= "EVPI"$, y $0 <= "EVSI"$ porque $E_S [max_d E[U | S]] >= max_d E_S [E[U | S]] = max_d E[U]$.
]

El EVPI es un techo y no una tarifa: ningún estudio real resuelve toda la incertidumbre, de modo que su valor es el EVSI, siempre menor. Sirve igual para decidir. Si el EVPI es pequeño frente al costo de un estudio, lo razonable es decidir con lo que se tiene; si es grande, el experimento compite legítimamente con las acciones sustantivas, y omitirlo del conjunto de acciones sesga la decisión hacia intervenir con la información actual. La idea viene de la teoría de la decisión bayesiana de Raiffa y Schlaifer, y encaja con el @cap-aprendizaje-continuo, donde los bandits tratan la exploración como parte de la decisión.

=== Identificación y soporte de cada acción
<sec-decisionesestructurales-multivariable>

Todo lo anterior supone que el efecto de cada acción candidata está identificado, y es el supuesto que más se olvida cuando el conjunto de acciones crece. Cuando la acción involucra más de una variable de intervención (por ejemplo, el monto de una transferencia y el requisito de asistencia a capacitaciones), $cal(D)$ pasa de un binario a un espacio multidimensional, y las combinaciones que ningún hogar recibió no tienen efecto identificado por los datos: tienen una extrapolación del modelo, cuya utilidad estimada hereda toda la fragilidad de extrapolar (@cap-generalizacion-transportabilidad). El análogo del soporte común del @cap-prediccion-causalidad debe comprobarse acción por acción, y las acciones sin soporte deben marcarse como tales en la recomendación en vez de mezclarse con las identificadas. Las intervenciones suaves, que modifican un mecanismo en lugar de fijar un valor, tienen sus propias condiciones de identificación, tratadas en el mismo capítulo.

La incertidumbre entra, además, por dos vías que conviene no confundir. La *estadística* es el error de estimación de cada efecto, la misma que cuantifican los intervalos de los capítulos anteriores. La *estructural* es la duda sobre si el SCM supuesto es siquiera el correcto: ningún intervalo la captura, y solo un análisis de sensibilidad al grafo, como el del @cap-intervencion-contrafactual, la aborda parcialmente.

== Procedimiento: decidir entre acciones con incertidumbre
<sec-decisionesestructurales-algoritmo>

#algorithm("Decisión entre acciones con incertidumbre")[
  #kwin[Entrada][Conjunto de acciones factibles, estimaciones de efecto con su incertidumbre, costos, función de utilidad con sus parámetros normativos.]
  #kwout[Salida][Acción recomendada, regiones de decisión y valor de la información.]
  Declarar $cal(D)$, incluyendo el _status quo_ y la acción "obtener más información". \
  Escribir la función de utilidad y marcar qué parámetros son normativos y quién los fija. \
  Comprobar para cada acción que su efecto está identificado y tiene soporte en los datos; marcar las que son extrapolación. \
  Calcular la utilidad esperada de cada acción y la acción óptima. \
  Calcular el peor caso y el arrepentimiento máximo de cada acción sobre el conjunto de escenarios declarado. \
  Recorrer los parámetros normativos y trazar las regiones donde cada criterio recomienda cada acción. \
  Calcular el valor esperado de la información perfecta y compararlo con el costo de un estudio. \
  #return-stmt[Recomendación, criterio aplicado, regiones de decisión y valor de la información; todo registrado en la ficha del modelo (@cap-model-card-causal).]
] <alg-decision-estructural>

El error más común es entregar solo el resultado del cuarto paso, la acción óptima, sin decir a qué distancia está del umbral donde cambiaría. Una recomendación que se invierte con un cambio pequeño de un parámetro normativo es una recomendación frágil, y el mapa de regiones es la forma de verlo.

== Casos canónicos y validación
<sec-decisionesestructurales-caso>

Los tres casos usan las mismas tres políticas candidatas de un programa social. Cada una tiene un efecto estimado (media y error estándar, en puntos del resultado) y un costo por beneficiario:

#table(
  columns: (2fr, 1fr, 1fr, 1fr),
  align: (left, right, right, right),
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Política*], [*Efecto*], [*Error estándar*], [*Costo*]),
  [Sin intervención], [0], [0], [0],
  [Transferencia simple], [0,12], [0,03], [500],
  [Transferencia más capacitación], [0,19], [0,05], [900],
)

La utilidad es $U = v tau_d - c_d$, con $v$ el valor monetario de un punto de efecto, un parámetro normativo que ningún dato determina. Las cifras son deterministas salvo el valor de la información, que se calcula por Monte Carlo con semilla fija.#capa-impl[ El script es #code[herramientas/verificaciones/verif_cap25.py].] El peor caso usa el extremo inferior del intervalo de 95 % de cada efecto, y el arrepentimiento se evalúa sobre los 27 escenarios que combinan el extremo inferior, el centro y el extremo superior de los tres intervalos.

#caso-canonico("Las regiones de decisión dependen de un parámetro normativo")[
  La utilidad esperada recomienda no intervenir si $v$ es menor que 4~167 (el costo de 500 dividido por el efecto de 0,12), la transferencia simple entre 4~167 y 5~714 y la capacitación por encima de 5~714 (el costo adicional de 400 dividido por el efecto adicional de 0,07). Los otros dos criterios cortan en lugares distintos:

  #table(
    columns: (1.1fr, 1.3fr, 1.3fr, 1.5fr),
    align: (right, left, left, left),
    stroke: 0.5pt + gray.lighten(60%),
    table.header([*$v$*], [*Utilidad esperada*], [*Maximin*], [*Minimax regret*]),
    [3~000], [ninguna], [ninguna], [ninguna],
    [5~000], [simple], [ninguna], [ninguna],
    [7~000], [capacitación], [ninguna], [capacitación],
    [10~000], [capacitación], [simple], [capacitación],
    [15~000], [capacitación], [capacitación], [capacitación],
  )

  Con $v = 5000$ la transferencia simple gana por 100 contra 50, pero el intervalo de 95 % de su utilidad va de −194 a 394 y el de la capacitación de −440 a 540: se solapan casi por completo y el peor caso de ambas es negativo, de modo que el maximin recomienda no intervenir. El arrepentimiento máximo es 540 para no intervenir, 734 para la simple y 834 para la capacitación, y el minimax regret coincide con el maximin. Tres criterios, tres respuestas posibles con el mismo efecto estimado.
]

#caso-canonico("Ensanchar el error estándar no mueve la utilidad esperada")[
  Se duplica el error estándar de la capacitación, de 0,05 a 0,10, con el mismo efecto estimado. La utilidad esperada no cambia para ningún valor de $v$, como anticipa la proposición de la @sec-decisionesestructurales-formalizacion. El maximin sí cambia: con 0,10 el efecto en el peor caso de la capacitación es $0.19 - 1.96 times 0.10 = -0.006$, su utilidad de peor caso es negativa para todo $v$ y deja de ser recomendada. Por encima de 12~990 el maximin elegía la capacitación con 0,05; con 0,10 se queda en la transferencia simple. El minimax regret no cambia en el rango probado (de 3~000 a 30~000): el umbral sigue en unos 6~470, porque el ancho adicional entra con el mismo coeficiente en el arrepentimiento de no intervenir (el escenario donde la capacitación resulta alta) y en el de la capacitación (el escenario donde resulta baja), y se cancela en la comparación entre ambos.
]

#caso-canonico("Cuánto vale saber más")[
  Se describe la incertidumbre de cada efecto con una normal centrada en su estimación y con su error estándar, independientes entre políticas. Con $v = 5000$, la utilidad de la transferencia simple es $N(100, 150^2)$ y la de la capacitación $N(50, 250^2)$. El valor esperado de la información perfecta entre las tres acciones es 100 por beneficiario: la mejor acción vale hoy 100 y, sabiendo los efectos verdaderos antes de elegir, valdría en promedio 200. Por cada acción por separado frente a no intervenir, el valor de la información es 22,7 para la simple y 76,7 para la capacitación. Depende del parámetro normativo: con $v = 3000$ vale 3, porque no intervenir es robusto, y entre 100 y 135 para $v$ entre 5~000 y 15~000. Si el programa alcanzara a 10~000 hogares, el techo del valor de un estudio con $v = 5000$ sería de 1~000~000 en las mismas unidades.
]

Las políticas son estilizadas. En un programa real, los efectos vendrían de un estimador de la Parte II con su inferencia (@cap-dml), y los costos incluirían los administrativos y los legales de cada diseño. La lección no cambia: la acción óptima depende de un parámetro normativo, de un criterio declarado y de cuánta incertidumbre vale la pena reducir antes de comprometerse.

#capa-impl[
== Implementación en Python
<sec-decisionesestructurales-implementacion>

#figure(
  kind: raw,
  caption: [Criterios de decisión y valor de la información para tres políticas candidatas.],
  ```python
import itertools
import numpy as np

# Tres politicas candidatas: efecto estimado (media, error estandar) y costo por beneficiario
politicas = {
    "sin_intervencion": {"efecto": 0.0, "se": 0.0, "costo": 0},
    "transferencia_simple": {"efecto": 0.12, "se": 0.03, "costo": 500},
    "transferencia_mas_capacitacion": {"efecto": 0.19, "se": 0.05, "costo": 900},
}
V = 5000   # valor monetario de un punto de efecto: parametro normativo, no un dato
Z = 1.96   # los intervalos de 95 % hacen de conjunto de escenarios


def utilidad(efecto, costo, v=V):
    return v * efecto - costo


def evaluar(v=V):
    """Utilidad esperada, utilidad de peor caso y arrepentimiento maximo de cada politica."""
    nombres = list(politicas)
    eu = {k: utilidad(p["efecto"], p["costo"], v) for k, p in politicas.items()}
    peor = {k: utilidad(p["efecto"] - Z * p["se"], p["costo"], v) for k, p in politicas.items()}
    niveles = [[p["efecto"] - Z * p["se"], p["efecto"], p["efecto"] + Z * p["se"]]
               for p in politicas.values()]
    arrep = dict.fromkeys(nombres, 0.0)
    for esc in itertools.product(*niveles):          # 27 escenarios
        u = {k: utilidad(e, politicas[k]["costo"], v) for k, e in zip(nombres, esc)}
        mejor = max(u.values())
        for k in nombres:
            arrep[k] = max(arrep[k], mejor - u[k])
    return eu, peor, arrep


def recomienda(v=V):
    eu, peor, arrep = evaluar(v)
    return max(eu, key=eu.get), max(peor, key=peor.get), min(arrep, key=arrep.get)


def valor_informacion_perfecta(v=V, n=400_000, semilla=0):
    """EVPI con efectos normales independientes: E[max_d U] - max_d E[U]."""
    rng = np.random.default_rng(semilla)
    U = np.column_stack([utilidad(p["efecto"] + p["se"] * rng.standard_normal(n), p["costo"], v)
                         for p in politicas.values()])
    return U.max(axis=1).mean() - U.mean(axis=0).max()


for v in (3000, 5000, 7000, 10000):
    eu, peor, arrep = evaluar(v)
    print(f"v={v:>6}  recomienda (EU, maximin, minimax regret): {recomienda(v)}  EVPI={valor_informacion_perfecta(v):6.1f}")

# Coherencia simple con las cifras del texto
assert abs(500 / 0.12 - 4166.7) < 0.1 and abs(400 / 0.07 - 5714.3) < 0.1
assert recomienda(5000) == ("transferencia_simple", "sin_intervencion", "sin_intervencion")
assert recomienda(10000) == ("transferencia_mas_capacitacion", "transferencia_simple", "transferencia_mas_capacitacion")
assert 95 < valor_informacion_perfecta(5000) < 105
```
) <lst-decision-optima>

Con pocas acciones basta recorrerlas todas. Si el espacio de acciones es continuo o combinatorio (montos, umbrales, combinaciones de requisitos), la maximización de $E[U]$ se hace con optimización numérica (`scipy.optimize`) o, para reglas por unidad, con los módulos de política de #code[econml], y el peor caso y el arrepentimiento se aproximan sobre una muestra de escenarios. El listado usa tres acciones para que cada cifra pueda comprobarse a mano.
]

== Riesgos, límites y sensibilidad
<sec-decisionesestructurales-riesgos>

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Riesgos en la decisión entre acciones bajo incertidumbre.],
    table(
      columns: (1.3fr, 1.5fr, 1.4fr, 1.6fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Función de utilidad implícita], [Decisión con valores que nadie aprobó], [¿Está escrita $U$ y quién fijó sus parámetros?], [Escribir $U$ y asignar un responsable],
      table.hline(stroke: 0.4pt),
      [Sensibilidad al parámetro normativo], [Mismo efecto estimado, acciones distintas (caso 1)], [Distancia de $v$ al umbral más cercano], [Reportar el mapa de regiones],
      table.hline(stroke: 0.4pt),
      [Leer el error estándar como si moviera la utilidad esperada], [Un intervalo ancho no cambia la recomendación (caso 2)], [¿La utilidad es lineal en el efecto?], [Usar peor caso, aversión al riesgo o valor de la información],
      table.hline(stroke: 0.4pt),
      [Intervalo de confianza como conjunto identificado], [Peor caso y arrepentimiento ignoran lo que los datos no distinguen], [Separar error de muestreo y cotas de identificación], [Usar cotas de identificación parcial o sensibilidad],
      table.hline(stroke: 0.4pt),
      [Omitir "obtener más información"], [Se interviene cuando un estudio valdría más (caso 3)], [EVPI frente al costo del estudio], [Incluir el estudio como acción],
      table.hline(stroke: 0.4pt),
      [Acción sin soporte en los datos], [Una extrapolación se presenta como estimación], [Positividad acción por acción], [Marcar como extrapolada o experimentar],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap25>
]

*Límites.* El minimax regret depende del conjunto de escenarios que se declare, y un conjunto distinto puede dar otra acción. Los valores de información de este capítulo suponen efectos independientes y normales; con dependencia entre ellos, o con colas pesadas, cambian. Y ninguna de estas cuentas sustituye la discusión normativa de qué resultado vale cuánto y para quién, que es la parte que la tecnología no puede decidir.

== Ejercicios y notas bibliográficas
<sec-decisionesestructurales-ejercicios>

=== Ejercicios teóricos
<sec-decisionesestructurales-ejercicios-teoricos>

+ Explique por qué el problema de policy learning del @cap-policy-learning (a quién tratar bajo presupuesto) es un caso particular del problema de decisión estructural de este capítulo, identificando cuál es $cal(D)$ y cuál es $U$ en ese caso.

+ Para el programa de la @sec-decisionesestructurales-caso, proponga una función de utilidad alternativa que dé peso explícito a la equidad distributiva (por ejemplo, que penalice que el efecto se concentre en un subgrupo). ¿Cambiaría la acción óptima?

+ Sea $w tilde N(mu, sigma^2)$ el beneficio neto de una acción y $u(w) = -e^(-a w)$ una utilidad con aversión al riesgo. Muestre que la utilidad esperada equivale a la de recibir con certeza $mu - a sigma^2 \/ 2$. Con $v = 7000$, encuentre el valor de $a$ por encima del cual la transferencia simple supera a la capacitación y el valor por encima del cual conviene no intervenir. Sugerencia: la desviación estándar de la utilidad es $v$ por el error estándar del efecto; el primer valor es $a approx 0.0023$.

+ Deduzca que, para una sola acción con utilidad $N(m, s^2)$ y $m > 0$ frente a no intervenir, el valor de la información perfecta es $s [phi(m \/ s) - (m \/ s) Phi(-m \/ s)]$, con $phi$ y $Phi$ la densidad y la función de distribución normal estándar. Verifique que vale 22,7 para la transferencia simple con $v = 5000$.

+ Explique por qué, con utilidad lineal, no tiene sentido comparar dos estimaciones de igual media y distinto error estándar mediante la utilidad esperada, y qué criterio o qué dato adicional haría que la diferencia importara.

#capa-impl[
=== Ejercicios computacionales
<sec-decisionesestructurales-ejercicios-computacionales>

+ Modifique el #ref(<lst-decision-optima>, supplement: [listado]) con al menos dos valores distintos de `V` (uno bajo, uno alto) y reporte si la acción óptima cambia según cada criterio. Discuta qué implica para la robustez de la recomendación.

+ Repita el cálculo con el error estándar de la capacitación en 0,05 y en 0,10, para valores de $v$ entre 3~000 y 30~000. ¿Qué criterios cambian su recomendación al ampliar el error estándar? ¿Por qué la utilidad esperada nunca cambia y por qué, en este ejemplo, tampoco lo hace el minimax regret?

+ Añada al listado una cuarta acción, "piloto aleatorizado", con un costo fijo y que reduzca a la mitad el error estándar de ambos efectos si se elige, y compruebe si compite con las acciones sustantivas para algún valor de $v$.
]

=== Notas bibliográficas
<sec-decisionesestructurales-notas>

Este capítulo sigue la formalización de decisiones estructurales de @bareinboim2025causalai. El marco de la teoría de la decisión bajo incertidumbre, con funciones de pérdida, admisibilidad y utilidad esperada, está en @berger1985statistical. #cite(<manski2004statistical>, form: "prose") es la lectura clave de la @sec-decisionesestructurales-criterios: formula la elección de una regla de tratamiento como un problema de decisión con datos de un experimento, desarrolla el criterio de arrepentimiento minimax para ese contexto y deriva sus implicaciones para la asignación de tratamientos según las covariables. Es también el antecedente directo de la _Empirical Welfare Maximization_ del @cap-policy-learning. Los criterios de peor caso y de arrepentimiento se deben a Wald y a Savage, y el valor de la información a Raiffa y Schlaifer. Los usos más aplicados de este marco en la práctica de targeting son el @cap-policy-learning y el @cap-uplift-targeting.
