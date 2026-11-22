// Capítulo 8: Razonamiento intervencional y contrafactual.
// Plantilla A (completa). Edición en capas: la teoría (L0), el algoritmo en pseudocódigo (L1) y los casos canónicos (L2) son
// lo que dura; el listado (L3) y el ejercicio computacional van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Razonamiento intervencional y contrafactual]
<cap-intervencion-contrafactual>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Decidir, a partir de un grafo causal, qué controles identifican el efecto y cuáles lo sesgan],
    [*Estimando:*], [$P(y | "do"(x))$ y $P(y_x | e)$],
    [*Identificación:*], [Criterio de puerta trasera (_backdoor_); las tres reglas del cálculo-$"do"$; puerta delantera (_front-door_)],
    [*Método:*], [Ajuste por puerta trasera; abducción-acción-predicción para contrafactuales],
    [*Garantía:*], [Si el criterio de puerta trasera se satisface, $P(y | "do"(x)) = sum_z P(y | x,z) P(z)$. El cálculo-$"do"$ es completo: si sus reglas no identifican el efecto, ningún método lo hace con ese grafo],
    ..if not es-principios {([*Librerías:*], [`dowhy`, `networkx`])},
    [*Validación:*], [Verificación algorítmica del criterio sobre el grafo propuesto],
  )
]

== Problema causal, estimando e identificación
<sec-intervcontra-problema>

El @cap-scm-pch dejó pendiente una pregunta operativa: dado un grafo causal y un conjunto de variables observadas, ¿cómo se determina *qué controles incluir* para que un ajuste estadístico (una regresión, un _matching_, un DML) recupere $P(y | "do"(x))$ en lugar de $P(y | x)$? La intuición de "controlar por todo lo que se pueda medir" es, como muestra este capítulo, no solo insuficiente sino activamente peligrosa: hay variables que, al controlarlas, *introducen* sesgo donde no lo había. Este capítulo formaliza el criterio que resuelve la pregunta, el criterio de puerta trasera, y extiende el procedimiento de cómputo contrafactual que adelantó el @cap-scm-pch.

== Teoría, supuestos y garantías
<sec-intervcontra-teoria>

=== El criterio de puerta trasera
<sec-intervcontra-backdoor>

#definition(name: [Criterio de puerta trasera])[
Un conjunto de variables $Z$ satisface el *criterio de puerta trasera* relativo a un par ordenado $(X,Y)$ en un grafo $G$ si: *(i)* ningún nodo de $Z$ es descendiente de $X$, y *(ii)* $Z$ bloquea todo camino entre $X$ e $Y$ que contenga una flecha *hacia* $X$ (un "camino de puerta trasera").
]

#theorem(name: [Fórmula de ajuste de puerta trasera])[
Si $Z$ satisface el criterio de puerta trasera relativo a $(X,Y)$, entonces el efecto causal de $X$ sobre $Y$ es identificable y está dado por la *fórmula de ajuste*:
$ P(y | "do"(x)) = sum_z P(y | x, z) thin P(z) $
]

#proof(kind: "sketch")[
La condición *(i)* garantiza que condicionar en $Z$ no bloquea el efecto de $X$ sobre $Y$ a través de las rutas causales (no se controla por un mediador) ni abre rutas espurias a través de un descendiente de $X$. La condición *(ii)* garantiza que $Z$ bloquea toda ruta espuria, es decir, toda confusión, entre $X$ e $Y$. Bajo ambas, condicionar en $Z$ dentro de cada estrato hace que $X$ esté "como aleatorizado", y promediar sobre la distribución de $Z$ recupera la distribución interventiva poblacional.
]

El supuesto de "no confusión condicional" (_unconfoundedness_) que los capítulos anteriores usaron sin más formalidad, y que sustenta a DML, a los meta-learners y a los bosques causales de la Parte II, tiene en el criterio de puerta trasera su versión gráfica: si las covariables observadas $X$ satisfacen el criterio relativo al tratamiento y al resultado, la no confusión condicional se cumple. El criterio es una condición suficiente que se lee directamente sobre el grafo. Este capítulo no cambia ningún método de estimación posterior; cambia *cómo se justifica*, con un grafo explícito, la elección de qué controlar.

=== Buenos y malos controles
<sec-intervcontra-controles>

El criterio de puerta trasera implica una clasificación de variables candidatas a control que conviene memorizar, porque en la práctica aplicada el error de incluir un mal control es más frecuente que el de omitir un confusor:

#table(
  columns: (1.1fr, 2fr, 2fr),
  align: left,
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Tipo de variable*], [*Rol en el grafo*], [*¿Controlar?*]),
  [Confusor], [Causa común de $X$ e $Y$ (afecta a ambos)], [*Sí*, es necesario para la puerta trasera],
  [Mediador], [Está en la ruta causal $X arrow.r M arrow.r Y$], [*No*: bloquea parte del efecto que se quiere medir],
  [Collider], [Es afectado tanto por $X$ como por $Y$ (o por sus causas)], [*No*: condicionar en él *crea* una asociación espuria (ver @sec-introcausal-escenas)],
  [Instrumento], [Afecta a $Y$ solo a través de $X$ y no comparte causa con $Y$], [*No* como control directo: se usa de otro modo (Parte III, DML-IV) y, si queda confusión no observada, controlarlo amplifica el sesgo],
  [Variable post-tratamiento], [Medida después de $X$, potencialmente afectada por él], [*No*: riesgo de ser mediador o collider sin que el analista lo note],
)

La fila de mediadores explica formalmente algo que el @cap-ingenieria-datos-causales mencionó sin desarrollar: por qué una variable "post-tratamiento" es peligrosa como control, aunque parezca un predictor razonable de $Y$. Con probabilidad no trivial es un mediador (se controla por parte del efecto que se busca medir) o un collider (se introduce sesgo de selección). La fila de colliders es la que más sorprende a quien viene del _machine learning_ predictivo, porque contradice el reflejo de "controlar por todo". #cite(<elwert2014endogenous>, form: "prose") documentan cómo este *sesgo de selección endógena* aparece de forma encubierta en la práctica aplicada, y no solo al añadir un control explícito: aparece cada vez que la muestra misma se define condicionando en una variable afectada por el tratamiento (restringir el análisis a quienes completaron el programa, a quienes siguen siendo clientes, a quienes respondieron la encuesta de seguimiento). Su tratamiento formal está en esa misma referencia.

En un sistema en producción, esta tabla es la regla que aplica la auditoría de _features_ (contrato C-03 del @cap-features-sin-fuga): el rol declarado de cada candidata decide si entra o no en la matriz de covariables.

#caso-canonico("Cuatro controles con verdad conocida")[
  Primer mundo, sin confusión no observada. La covariable $C$ es un confusor observado: $X = 0.8 C + epsilon_X$. El mediador es $M = 0.5 X + epsilon_M$ y el resultado es $Y = 0.7 X + 0.6 M + C + epsilon_Y$, de modo que el efecto total de $X$ vale $0.7 + 0.6 times 0.5 = 1$. Una cuarta variable, $K = 0.6 X + 0.6 Y + epsilon_K$, es un collider. Con 5 000 unidades y 200 repeticiones, la regresión de $Y$ sobre $X$ y cada conjunto de controles estima:

  #table(
    columns: (3fr, 2fr),
    align: (left, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Controles*], [*Efecto estimado*]),
    table.hline(stroke: 0.3pt),
    [Ninguno], [1,49],
    [$C$ (el confusor)], [1,00],
    [$C$ y $M$ (más el mediador)], [0,70],
    [$C$ y $K$ (más el collider)], [0,34],
    table.hline(stroke: 0.6pt),
  )

  La desviación entre repeticiones es de alrededor de 0,02. Controlar por el confusor recupera el efecto; añadir el mediador lo reduce a su parte directa, y añadir el collider lo destruye.

  Segundo mundo, con confusión no observada y sin mediador ni collider: $X = 0.8 C + Z + U + epsilon_X$ e $Y = X + C + U + epsilon_Y$, donde $U$ no se observa y $Z$ es un instrumento, porque solo llega a $Y$ a través de $X$. El efecto de $X$ vale 1. Controlar por $C$ deja un sesgo de 0,33 (estima 1,33), y controlar además por $Z$ lo amplía a 0,50 (estima 1,50). Es la amplificación de sesgo que describe #cite(<pearl2010amplifying>, form: "prose"): el instrumento explica parte de la variación de $X$ que no tiene relación con $U$, y al condicionar en él la variación restante de $X$ está más cargada de $U$.
]

=== Las tres reglas del cálculo-$"do"$
<sec-intervcontra-docalculus>

Este capítulo formaliza el *criterio de puerta trasera* con su prueba. Las tres reglas del *cálculo-$"do"$* (*do-calculus*, @pearl2009causality) proporcionan un sistema para determinar la identificabilidad causal en grafos arbitrarios.

El criterio de puerta trasera resuelve el caso más frecuente, pero no es la herramienta general. Hay grafos donde ningún conjunto observado satisface el criterio y, sin embargo, el efecto *sí* es identificable por otra vía. La herramienta completa es el *cálculo-$"do"$*: tres reglas de reescritura que transforman una expresión con el operador $"do"()$ en otra equivalente, con el objetivo de eliminar todos los $"do"$ y quedar con una fórmula puramente observacional, es decir, estimable con los datos.

La notación requiere dos operaciones de "cirugía" sobre el grafo $G$. Escribimos $G_(overline(X))$ para el grafo que resulta de *borrar todas las flechas que entran* a los nodos de $X$ (el grafo bajo la intervención $"do"(x)$, donde $X$ deja de responder a sus causas) y $G_(underline(Z))$ para el que resulta de *borrar todas las flechas que salen* de los nodos de $Z$. Ambas operaciones pueden combinarse. La relación $(A perp perp B | C)_G$ denota $d$-separación de $A$ y $B$ dado $C$ en el grafo $G$.

#theorem(name: [Cálculo-$"do"$])[
Sea $G$ el grafo causal de un SCM y sean $X, Y, Z, W$ conjuntos disjuntos de nodos. Las tres igualdades siguientes son válidas siempre que se cumpla la condición gráfica indicada a la derecha.

*Regla 1 (inserción/eliminación de observaciones).* Permite descartar una variable observada que es irrelevante bajo la intervención:
$
P(y | "do"(x), z, w) = P(y | "do"(x), w) quad "si" quad (Y perp perp Z | X, W)_(G_(overline(X))).
$

*Regla 2 (intercambio de acción por observación).* Permite reemplazar un $"do"$ por un condicionamiento ordinario, el paso que convierte una cantidad no estimable en una estimable:
$
P(y | "do"(x), "do"(z), w) = P(y | "do"(x), z, w) quad "si" quad (Y perp perp Z | X, W)_(G_(overline(X) underline(Z))).
$

*Regla 3 (inserción/eliminación de acciones).* Permite descartar una intervención que no afecta al resultado:
$
P(y | "do"(x), "do"(z), w) = P(y | "do"(x), w) quad "si" quad (Y perp perp Z | X, W)_(G_(overline(X) overline(Z(W)))),
$
donde $Z(W)$ es el subconjunto de nodos de $Z$ que no son ancestros de ningún nodo de $W$ en $G_(overline(X))$.
] <thm-do-calculus>

Las tres reglas son *válidas* (todo lo que derivan es correcto) y, además, *completas*: si un efecto es identificable a partir del grafo y de la distribución observacional, existe una secuencia finita de aplicaciones de estas tres reglas que produce su fórmula; y si no existe tal secuencia, el efecto no es identificable, y ningún método, por sofisticado que sea, puede recuperarlo con esos datos y ese grafo. La completitud la demostraron #cite(<shpitser2006identification>, form: "prose") y #cite(<huang2006pearl>, form: "prose"), de forma independiente, junto con algoritmos que deciden la identificabilidad. Esta completitud es lo que convierte al cálculo-$"do"$ en un procedimiento de decisión y no solo en un conjunto de trucos: cuando un algoritmo de identificación responde que un efecto no es identificable, esa respuesta es una afirmación matemática y no una limitación del software.

La fórmula de ajuste de puerta trasera es, desde este punto de vista, un corolario. Por probabilidad total, $P(y | "do"(x)) = sum_z P(y | "do"(x), z) P(z | "do"(x))$. Si $Z$ satisface el criterio, la Regla 2 justifica reemplazar $P(y | "do"(x), z)$ por $P(y | x, z)$, porque condicionar en $Z$ bloquea todas las rutas de puerta trasera y deja por tanto a $Y$ y $X$ #box[$d$-separados] en $G_(underline(X))$. La Regla 3 justifica que $P(z | "do"(x)) = P(z)$, porque ningún nodo de $Z$ es descendiente de $X$. Sustituyendo ambos queda $P(y | "do"(x)) = sum_z P(y | x, z) P(z)$.

=== Cuando la puerta trasera falla: el criterio de puerta delantera
<sec-intervcontra-frontdoor>

El valor práctico del cálculo-$"do"$ se aprecia mejor en un caso donde la puerta trasera *no* sirve. Suponga el grafo $X arrow.r M arrow.r Y$ con un confusor no observado $U$ que afecta a $X$ y a $Y$ pero no a $M$ salvo a través de $X$. No existe ningún conjunto observado que bloquee la ruta $X arrow.l U arrow.r Y$, porque $U$ no se observa, y por tanto ningún ajuste por covariables identifica el efecto. Sin embargo, el mediador $M$ ofrece una vía alternativa. El efecto de $X$ sobre $M$ es identificable (no hay confusión entre ellos), el efecto de $M$ sobre $Y$ es identificable ajustando por $X$ (que bloquea la ruta $M arrow.l X arrow.l U arrow.r Y$), y encadenando ambos se recupera el efecto total:
$
P(y | "do"(x)) = sum_m P(m | x) sum_(x') P(y | m, x') P(x').
$

Esta es la *fórmula de puerta delantera* (_front-door_), derivable por aplicación sucesiva de las tres reglas. El punto conceptual, y la razón de incluirla en un libro orientado a la práctica, es doble. Primero, la identificación no se reduce a "encontrar los controles correctos": el conocimiento sobre *mecanismos* (saber que todo el efecto de $X$ sobre $Y$ pasa por $M$) es una fuente de identificación tan legítima como el conocimiento sobre confusores, y a veces la única disponible. Segundo, como advertencia, el supuesto de que *ninguna* ruta directa $X arrow.r Y$ escapa a $M$ es fuerte y raramente defendible en datos económicos, razón por la cual la puerta trasera, y no la delantera, sigue siendo el caballo de batalla de los métodos de la Parte II.

#caso-canonico("Una puerta delantera con confusor no observado")[
  Cuatro variables binarias. $U$ no se observa y vale 1 con probabilidad 0,5. El tratamiento vale 1 con probabilidad $0.2 + 0.6 U$, el mediador con probabilidad $0.2 + 0.6 X$ y el resultado con probabilidad $0.1 + 0.5 M + 0.3 U$. Por la fórmula de puerta delantera el efecto de $X$ sobre $P(Y = 1)$ vale exactamente $0.5 times 0.6 = 0.30$.

  Con 200 000 unidades, la diferencia de medias entre tratados y no tratados es 0,48, inflada por $U$, y la fórmula de puerta delantera aplicada a los datos observados estima 0,30. Ninguna regresión sobre las variables observadas habría dado ese número, porque $U$ no se observa.
]

=== Cómputo contrafactual: abducción, acción, predicción
<sec-intervcontra-contrafactual>

El @cap-scm-pch adelantó el procedimiento de tres pasos para responder preguntas de $cal(L)_3$. Formalizado: dado un SCM $M$ y evidencia observada $e$ sobre una unidad específica, calcular $P(y_x | e)$ requiere:

+ *Abducción*: actualizar $P(u)$ a $P(u | e)$, es decir, inferir a partir de lo observado qué configuración de variables exógenas es consistente con la evidencia.
+ *Acción*: construir el modelo modificado $M_x$, reemplazando la ecuación de $X$ por la constante $x$ (idéntico al paso interventivo del @cap-scm-pch).
+ *Predicción*: calcular $Y$ en $M_x$ usando la distribución actualizada $P(u | e)$ del paso de abducción, en lugar de la $P(u)$ original.

La diferencia crucial con el cómputo interventivo puro es el paso de abducción: una pregunta contrafactual siempre está condicionada por lo que efectivamente se observó de esa unidad específica, mientras que una pregunta interventiva pura pregunta por el efecto promedio poblacional sin condicionar en ninguna observación particular.

== Algoritmo e implementación
<sec-intervcontra-algoritmo>

#algorithm("Verificación del criterio de puerta trasera")[
  #kwin[Entrada][Grafo dirigido acíclico $G$, tratamiento $X$, resultado $Y$ y conjunto candidato $Z$.]
  #kwout[Salida][Aceptar o rechazar $Z$, con el motivo.]
  Si algún nodo de $Z$ es descendiente de $X$ en $G$, rechazar (falla la condición *(i)*). \
  Construir $G'$ borrando de $G$ todas las flechas que salen de $X$; lo que queda entre $X$ e $Y$ son sus caminos de puerta trasera. \
  Tomar el subgrafo ancestral de $X$, $Y$ y $Z$ en $G'$ y *moralizarlo*: unir con una arista a cada par de padres de un mismo nodo y quitar la dirección de las flechas. \
  Borrar los nodos de $Z$ del grafo moral. \
  Si en el grafo resultante hay un camino entre $X$ e $Y$, rechazar (falla la condición *(ii)*); en otro caso, aceptar. \
  #return-stmt[aceptar o rechazar]
] <alg-backdoor>

El algoritmo #ref(<alg-backdoor>, supplement: none) comprueba un conjunto candidato contra el criterio de puerta trasera con un procedimiento corto, que se apoya en la prueba de $d$-separación por moralización del subgrafo ancestral.

#capa-impl[
El listado implementa el mismo procedimiento con la prueba de $d$-separación de `networkx` (versión 3.3 o posterior).

#entero[
#figure(
  kind: raw,
  caption: [Verificación del criterio de puerta trasera con `networkx`.],
  ```python
import networkx as nx

# Grafo: educ (X) -> wage (Y); ability (confusor) -> educ, wage;
# test_score (mediador) : educ -> test_score -> wage
G = nx.DiGraph([
    ("ability", "educ"), ("ability", "wage"),
    ("educ", "wage"),
    ("educ", "test_score"), ("test_score", "wage"),
])

def satisface_puerta_trasera(G, X, Y, Z):
    G_sin_salientes_X = G.copy()
    G_sin_salientes_X.remove_edges_from(list(G.out_edges(X)))
    # (i) ningun nodo de Z es descendiente de X
    descendientes_X = nx.descendants(G, X)
    if any(z in descendientes_X for z in Z):
        return False, "Z contiene un descendiente de X (posible mediador)"
    # (ii) Z separa X de Y en el grafo sin las aristas salientes de X
    if not nx.is_d_separator(G_sin_salientes_X, {X}, {Y}, set(Z)):
        return False, "Z no bloquea todos los caminos de puerta trasera"
    return True, "Z satisface el criterio de puerta trasera"

print(satisface_puerta_trasera(G, "educ", "wage", {"ability"}))
print(satisface_puerta_trasera(G, "educ", "wage", {"ability", "test_score"}))
# El segundo caso debe fallar: test_score es un mediador (descendiente de X)
```
) <lst-backdoor-check>
]

En la práctica, `dowhy` automatiza esta verificación y además identifica conjuntos de puerta trasera válidos dado un grafo declarado por el usuario, con la función `identify_effect()`; el Apéndice B documenta su uso. Esa misma función busca estimandos por puerta delantera (@sec-intervcontra-frontdoor) y por variable instrumental cuando la puerta trasera falla, de modo que su salida "no identificable" debe leerse con el peso que le da la completitud del cálculo: no es que la librería no sepa cómo, es que con ese grafo y esos datos no se puede.
]

== Caso aplicado: el grafo de educación y salario
<sec-intervcontra-caso>

Considere un grafo con cuatro variables: la habilidad afecta a la educación y al salario, la educación afecta al salario directamente y a través de una prueba de competencias adquiridas en la escuela, y esa prueba afecta al salario. Si el analista incluyera la prueba de competencias (una variable medida *después* de completar los años de educación) como control en la regresión del salario sobre la educación, estaría, según la clasificación de la @sec-intervcontra-controles, controlando por un mediador: parte del efecto de la educación sobre el salario opera precisamente a través de las competencias que la prueba mide. El coeficiente de la educación quedaría sesgado hacia abajo, como el 0,70 del primer mundo del caso canónico de más arriba. El algoritmo de verificación llega a la misma conclusión: el conjunto formado por la habilidad y la prueba falla la condición *(i)*, mientras que la habilidad sola satisface las dos#capa-impl[ (#ref(<lst-backdoor-check>, supplement: [listado]))].

== Riesgos, límites y sensibilidad
<sec-intervcontra-riesgos>

#riesgos[
  - *"Más controles siempre es más seguro".* Es falso en general: agregar un mediador o un collider puede introducir sesgo donde una especificación más parca no lo tenía. El criterio de puerta trasera formaliza exactamente cuándo agregar un control ayuda y cuándo perjudica.
  - *Confundir un instrumento con un confusor.* Un instrumento válido no debe controlarse directamente como si fuera una covariable de puerta trasera; su rol es distinto y se explota con métodos específicos (DML-IV, Parte III). Si queda confusión no observada, incluirlo como control amplifica el sesgo de esa confusión (#cite(<pearl2010amplifying>, form: "prose")), como muestra el segundo mundo del caso canónico.
  - *El grafo es siempre una hipótesis.* Todo lo desarrollado en este capítulo presupone que el grafo declarado es correcto. Ningún algoritmo puede generar el grafo desde los datos solos sin supuestos adicionales (el @cap-descubrimiento-grafos, más adelante en el libro, aborda qué tan lejos se puede llegar con descubrimiento automatizado, y sus límites).
]

== Ejercicios y notas bibliográficas
<sec-intervcontra-ejercicios>

=== Ejercicios teóricos
<sec-intervcontra-ejercicios-teoricos>

+ Para el grafo de la @sec-intervcontra-caso, con habilidad, educación, prueba de competencias y salario, agregue una variable "vecindario" que sea causa común de la habilidad y del salario (pero no de la educación). ¿Sigue la habilidad, sola, satisfaciendo el criterio de puerta trasera? Justifique con el grafo modificado.

+ Explique, en el lenguaje de este capítulo, por qué condicionar en un collider crea una correlación espuria (retome el ejemplo del tamaño del pie y la capacidad de lectura del @cap-causalidad-elemental, agregando explícitamente un collider).

+ Aplique el procedimiento de abducción-acción-predicción a un ejemplo numérico simple: un SCM lineal $Y = 2X + U$, $X = U + epsilon$, con $U tilde N(0,1)$ y $epsilon tilde N(0,1)$ independientes. Dado que se observó $X=1, Y=3$, calcule el valor contrafactual de $Y$ si $X$ hubiera sido 2.

+ Derive la fórmula de ajuste de puerta trasera a partir de las tres reglas del cálculo-$"do"$ de la @sec-intervcontra-docalculus, indicando explícitamente qué regla justifica cada paso y qué condición de $d$-separación se invoca en cada caso.

+ Para el grafo de puerta delantera de la @sec-intervcontra-frontdoor ($X arrow.r M arrow.r Y$ con $U$ no observado afectando a $X$ e $Y$), añada una flecha directa $X arrow.r Y$. Explique por qué la fórmula de puerta delantera deja de ser válida y qué supuesto sustantivo se estaría violando.

+ En el segundo mundo del caso canónico de los cuatro controles, ¿qué estimaría la regresión si se controlara por $Z$ y no por $C$? Explique con el grafo por qué ninguna de las especificaciones identifica el efecto.

#capa-impl[
=== Ejercicios computacionales
<sec-intervcontra-ejercicios-computacionales>

+ Instale `dowhy` (Apéndice B) y reproduzca la verificación del #ref(<lst-backdoor-check>, supplement: [listado]) usando `identify_effect()` en lugar de la función manual. Compare el conjunto de ajuste que identifica automáticamente con el usado en el capítulo.

+ Simule el primer mundo del caso canónico de los cuatro controles y reproduzca la tabla con mínimos cuadrados. Repita con 500 unidades en lugar de 5 000 y compare la desviación entre repeticiones.
]

=== Notas bibliográficas
<sec-intervcontra-notas>

El criterio de puerta trasera, las tres reglas del cálculo-$"do"$, su completitud y la fórmula de puerta delantera se presentan en @pearl2009causality, Capítulo 3, que es la referencia canónica para todo el aparato de identificación gráfica de este capítulo; la clasificación de buenos y malos controles sigue la sistematización de @bareinboim2025causalai. La completitud del cálculo la establecen #cite(<shpitser2006identification>, form: "prose") y #cite(<huang2006pearl>, form: "prose"). #cite(<elwert2014endogenous>, form: "prose") es el tratamiento de referencia del sesgo por _collider_ y de sus formas encubiertas (selección muestral, atrición, condicionamiento en supervivencia), y es la lectura más útil para quien deba auditar un pipeline de datos ya construido; la amplificación de sesgo por instrumentos la describe #cite(<pearl2010amplifying>, form: "prose"). Para una implementación aplicada, #cite(<sharma2020dowhy>, form: "prose") documenta una biblioteca de referencia, cubierta en el Apéndice B de este libro.
