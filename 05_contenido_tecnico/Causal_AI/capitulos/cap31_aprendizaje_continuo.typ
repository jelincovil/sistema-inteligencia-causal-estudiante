// Capítulo 31: Aprendizaje continuo y panorama de RL causal.
// Plantilla híbrida A/B: Sesión 27. Edición en capas: la regla de promoción y los casos canónicos (capas L2 y L0) son lo que
// dura; el listado y el ejercicio de infraestructura (capa L3) van dentro de #capa-impl. La segunda mitad es un panorama
// fechado (frontera) y no un método.
#import "../template/template.typ": *

#chapter[Aprendizaje continuo y panorama de _Reinforcement Learning_ causal]
<cap-aprendizaje-continuo>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Cuándo y cómo actualizar un sistema causal; cómo la PCH se extiende a decisiones secuenciales],
    [*Primera mitad:*], [Aprendizaje continuo (decisión de ingeniería, Plantilla B)],
    [*Segunda mitad:*], [RL causal (panorama conceptual, Plantilla A, sin implementación completa)],
    [*Patrones:*], [_Shadow deployment_, _champion-challenger_; bandits causales como caso introductorio de RL causal],
    [*Alcance:*], [La segunda mitad es deliberadamente un panorama: RL causal es un programa de investigación activo, no una receta cerrada],
  )
]

Este capítulo tiene dos mitades de naturaleza distinta. La primera es una decisión de ingeniería: cuándo reentrenar un sistema causal y cómo hacerlo sin ponerlo en riesgo. La segunda es un panorama de una frontera de investigación activa: qué cambia cuando la decisión deja de ser única y pasa a ser una secuencia en la que cada acción modifica los datos que se verán después, el problema que estudia el _Reinforcement Learning_ (RL).

== Aprendizaje continuo para sistemas causales
<sec-continuo-parte1>

=== El problema de diseño
<sec-continuo-problema>

El @cap-monitoreo-causal dejó una pregunta abierta. Cuando la primera pregunta que falla es la del efecto y las tres anteriores están en orden, la acción que corresponde es reentrenar (@sec-anatomia-acciones). Falta decir cómo se hace. #cite(<huyen2022dmls>, form: "prose") (Capítulo 9, "Continual Learning and Test in Production") describe el espectro de respuestas posibles, desde no hacer nada hasta reentrenar de forma automática con cada lote de datos nuevo.

En un sistema causal reentrenar tiene una dificultad que el ML predictivo no conoce. Un modelo predictivo nuevo se admite si puntúa mejor que el vigente sobre las etiquetas que van llegando. Del efecto causal no llega ninguna etiqueta: de cada unidad solo se observa el resultado del tratamiento que recibió (@sec-introcausal-problema-fundamental), así que ningún modelo nuevo puede ganar una comparación contra la verdad. Solo puede cumplir condiciones. Además, reentrenar con datos nuevos puede cambiar sin ruido la población para la que el efecto es válido, no solo su varianza, como adelantó el @cap-anatomia-sistema. Un reentrenamiento que mejora el ajuste y cambia la población es peor, no mejor, para quien sigue sirviendo a la población anterior.

=== Opciones y trade-offs
<sec-continuo-opciones>

#opciones[
  - *Reentrenamiento automático.* El estimador se reajusta con los datos más recientes, sea en un calendario fijo o cada vez que el monitoreo lo pide, y sustituye al vigente sin intervención humana. Minimiza el trabajo operativo, pero en un sistema causal el nuevo estimador puede reflejar otra población u otro mecanismo sin que nadie lo audite antes de publicarlo. Es el riesgo que el @cap-cicd-causal buscaba prevenir con pruebas automáticas, y que esas pruebas por sí solas no bastan para descartar: un cambio de población pasa el placebo, como muestra el caso canónico más abajo.
  - *_Champion-challenger_ con regla de promoción.* El modelo reentrenado (el _challenger_) se evalúa en paralelo al que está en producción (el _champion_) y solo lo reemplaza si cumple una regla explícita, que compara las poblaciones y no solo las métricas. Es más lento y exige mantener los dos modelos corriendo, pero es la opción que permite que una persona intercepte un cambio de población antes de que llegue a producción.
]

=== #t-decision
<sec-continuo-decision>

El libro adopta el patrón _champion-challenger_: ninguna actualización reemplaza al servicio vigente de forma automática. El _challenger_ se entrena con datos recientes, pasa por la compuerta de registro del @cap-cicd-causal y, además, se compara su población con la del _champion_ con el chequeo de balance del @cap-datos-entrenamiento-causales. La decisión es una regla de promoción con dos entradas y, como salida, una de las cinco acciones del @sec-anatomia-acciones.

#entero[
#table(
  columns: (1.3fr, 1.3fr, 1.5fr, 3.6fr),
  align: left,
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Compuerta de registro*], [*Población comparable*], [*Acción*], [*Qué ocurre*]),
  [Pasa], [Sí], [Reentrenar], [Se promueve el _challenger_. La ficha registra la fecha, el motivo y el resultado de la comparación.],
  [Cualquiera], [No], [Revisar identificación], [No se promueve. Una persona decide si la población que el servicio atiende cambió de verdad (y entonces cambia la ficha) o si los datos nuevos no la representan.],
  [No pasa], [Sí], [Alertar], [No se promueve. Sigue el _champion_ y una persona recibe la prueba que falló.],
)
]

Cuando las dos entradas fallan prevalece la acción más restrictiva, como en el resto del libro. Promover y reemplazar significan aquí un solo acto: que la versión nueva pase a ser la vigente.

Tres aclaraciones sobre la regla. Primera, el motivo del reentrenamiento no sale de la comparación. Se reentrena porque el monitoreo dijo que el efecto cambió con todo lo demás en orden, o porque hay datos nuevos suficientes para estrechar el intervalo (con el doble de datos y todo lo demás igual, el intervalo se acorta en un factor $1 \/ sqrt(2) approx 0.71$). Segunda, la diferencia entre la estimación del _challenger_ y la del _champion_ no es una condición de la regla: si el motivo fue un cambio de efecto, se espera que sea grande. Se registra en la ficha junto con los dos intervalos (@sec-apG-campos). Tercera, mientras la regla se evalúa, el _champion_ sigue respondiendo; si el @cap-monitoreo-causal ordena abstenerse, esa orden prevalece sobre cualquier reentrenamiento en curso.

*Qué hace el despliegue en sombra aquí.* Antes de promover, el _challenger_ puede correr en sombra (_shadow deployment_): recibe las mismas consultas que el _champion_ y responde, pero su respuesta no llega a nadie. En un modelo predictivo la sombra mide error cuando llegan las etiquetas. Aquí no llegan, de modo que solo mide dos cosas: cuánto se separan las estimaciones de las dos versiones sobre las mismas consultas, y si el _challenger_ se abstiene donde el _champion_ responde, o al revés. La segunda es una pista barata de que el soporte cambió, porque la abstención depende de la población de soporte que declara la ficha (@sec-despliegue-contrato).

*Qué datos se comparan.* La comparación pone frente a frente los datos con que se entrenó el _champion_ y los datos nuevos que el _challenger_ incorpora, no el conjunto completo con que se reentrena. Si el _challenger_ se entrena con los datos viejos más los nuevos, la mezcla diluye la diferencia y el efecto que reporta corresponde a una población intermedia que nadie atiende.

#caso-canonico("Un cambio de población que la compuerta no ve")[
  Tres covariables normales estándar $X_1, X_2, X_3$. El tratamiento es $D tilde "Bernoulli"(sigma(X_1))$ y el resultado, $Y = (0.5 + 0.5 X_2) D + X_1 + 0.5 X_3 + epsilon$ con $epsilon tilde N(0, 1)$. El efecto depende de $X_2$, de modo que el efecto promedio es $0.5 + 0.5 E[X_2]$. El _champion_ se entrena con 3 000 unidades con $X_2 tilde N(0, 1)$. Los datos nuevos son otras 3 000 unidades con $X_2 tilde N(0.4, 1)$: la población se corrió 0,4 desviaciones en la covariable que modula el efecto. El estimador es un DML de modelo parcialmente lineal, con validación cruzada y _gradient boosting_.

  #table(
    columns: (3fr, 2.6fr, 1.4fr, 1.4fr),
    align: (left, left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Modelo*], [*Entrenado con*], [*Efecto verdadero*], [*Efecto estimado*]),
    table.hline(stroke: 0.3pt),
    [_Champion_], [Sus datos], [0,50], [0,51],
    [_Challenger_ A], [Solo los datos nuevos], [0,70], [0,71],
    [_Challenger_ B], [Datos viejos y nuevos], [0,60], [0,61],
    table.hline(stroke: 0.6pt),
  )

  La prueba de placebo rechaza con frecuencias parecidas en las dos poblaciones (6,5 % y 3 % con 200 permutaciones en cada una, una diferencia dentro del error de muestreo), porque al permutar el tratamiento el efecto es nulo en cualquiera de ellas. La de estabilidad compara el efecto reestimado con el que registra la ficha del propio candidato. La compuerta de registro, que se apoya en estas dos pruebas, no distingue a un _challenger_ de otro. La comparación de poblaciones sí: contra los datos nuevos, la diferencia estandarizada de $X_2$ (0,40) supera el umbral de 0,25 en las 100 repeticiones; contra la mezcla (0,20), en ninguna. Comparar contra los datos nuevos es lo que evita promover al _challenger_ B, cuyo 0,61 no es el efecto de ninguna de las dos poblaciones.
]

*El umbral se calibra con la ventana nula.* La comparación usa una diferencia estandarizada y no el $p$-valor de un test, por la misma razón que da el @cap-monitoreo-causal para el _drift_: con muestras grandes un test rechaza diferencias irrelevantes. En una simulación con 20 000 unidades por grupo y un corrimiento de 0,05 desviaciones en una covariable, el test de Kolmogorov–Smirnov al 5 % marcó el cambio en el 98,5 % de las repeticiones y la diferencia estandarizada con umbral 0,25 no lo marcó nunca. Con un corrimiento material de 0,3 desviaciones y 3 000 unidades por grupo, los dos lo detectan (100 % y 98 %).

El umbral de 0,25 es un valor de partida, y cuánto vale depende del tamaño de las muestras. La tabla muestra, para dos muestras de la misma población, la distribución del mayor desbalance estandarizado entre las cuatro covariables.

#caso-canonico("Ventana nula del balance de poblaciones")[
  Dos muestras de $n$ unidades cada una, de la misma población, con cuatro covariables: una normal estándar y tres binarias con proporciones 0,3, 0,4 y 0,6. En 1 000 pares se registra el mayor desbalance estandarizado entre las cuatro.

  #table(
    columns: (1fr, 1.4fr, 1.6fr, 3fr),
    align: (center, center, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*$n$*], [*Mediana*], [*Percentil 98*], [*Pares por encima de 0,25*]),
    table.hline(stroke: 0.3pt),
    [100], [0,20], [0,40], [27 %],
    [300], [0,12], [0,22], [0,6 %],
    [1 000], [0,06], [0,13], [0 %],
    [3 000], [0,04], [0,07], [0 %],
    table.hline(stroke: 0.6pt),
  )

  Con 100 unidades por grupo, dos muestras de la misma población superan 0,25 en más de una de cada cuatro comparaciones. Desde 1 000 unidades el ruido queda muy por debajo del umbral y este pasa a medir materialidad.
]

La regla es que el umbral sea el mayor de dos números: el que fija la materialidad (qué desbalance importaría para el efecto, con 0,25 como valor de partida) y el percentil 98 de la ventana nula con los tamaños reales, que deja una tasa de falsas alarmas de 2 % por comparación. Con 100 unidades por grupo da 0,40, y esa cifra dice algo más que el umbral: la comparación apenas tiene potencia. Con 300 unidades por grupo y un corrimiento de 0,3 desviaciones detecta el 72 % de los casos y con 3 000 unidades, el 98 %.

*Lo que esta comparación no ve.* Solo compara covariables observadas. Un cambio en el mecanismo de asignación, o en una variable que no se mide, no la activa. Para eso están las señales (ii) y (iv) del @cap-monitoreo-causal, aplicadas a los datos nuevos antes de entrenar.

#capa-impl[
== Implementación de referencia
<sec-continuo-implementacion>

El listado implementa la regla de la tabla. Lee las covariables de los roles de la ficha del modelo (@cap-model-card-causal), de modo que no depende de ningún objeto serializado, y devuelve la acción junto con la evidencia para que quede en el historial de la ficha.

#figure(
  kind: raw,
  caption: [Regla de promoción: compara la población del _champion_ con los datos nuevos y devuelve una de las cinco acciones.],
  ```python
import numpy as np

def asmd(a, b):
    """Diferencia media estandarizada absoluta entre dos muestras."""
    sd = np.sqrt((np.var(a, ddof=1) + np.var(b, ddof=1)) / 2)
    return abs(np.mean(a) - np.mean(b)) / sd if sd > 0 else 0.0

def evaluar_challenger(df_champion, df_nuevos, roles, pasa_compuerta, umbral=0.25):
    """df_champion: datos con que se entreno el champion.
    df_nuevos: los datos que el challenger usa y el champion no vio.
    pasa_compuerta: resultado de la compuerta de registro del challenger (Cap. 20).
    umbral: valor de partida; se calibra con ventanas nulas (Cap. 30)."""
    desbalance = {c: asmd(df_champion[c], df_nuevos[c]) for c in roles["covariables"]}
    peor = max(desbalance, key=desbalance.get)
    comparable = bool(desbalance[peor] < umbral)
    if not comparable:
        accion = "revisar_identificacion"   # otra poblacion: decide una persona
    elif not pasa_compuerta:
        accion = "alertar"                  # sigue el champion; se muestra la prueba que fallo
    else:
        accion = "reentrenar"               # se promueve el challenger
    return {"accion": accion, "promover": accion == "reentrenar",
            "poblacion_comparable": comparable, "pasa_compuerta": bool(pasa_compuerta),
            "mayor_desbalance": (peor, round(float(desbalance[peor]), 3))}
```
) <lst-champion-challenger>

Las cifras de esta sección salen de simulaciones con semilla declarada que ejecutan este mismo listado, con un DML de _gradient boosting_ en lugar de EconML. Están en `herramientas/verificaciones/verif_listados_cap31.py`.
]

=== Señales de alerta
<sec-continuo-alertas>

#checklist[
  - Los reentrenamientos se publican en un calendario, con la única condición de que pasen las pruebas de software.
  - La única comparación entre versiones es una métrica de ajuste; ninguna compara la población de entrenamiento de la versión nueva con la de la vigente.
  - El _challenger_ se entrena con datos viejos y nuevos y la comparación se hace contra el conjunto completo, de modo que un corrimiento moderado se diluye.
  - El umbral de la comparación de poblaciones se heredó de otro sistema o de la convención, sin medir el desbalance entre muestras de la misma población con los tamaños reales.
  - Un _challenger_ que no pasó la regla se promovió "por esta vez", o el umbral se cambió en el mismo cambio que lo hizo fallar.
  - La ficha no registra el motivo del reentrenamiento ni el resultado de la comparación.
]

== Panorama de _Reinforcement Learning_ causal
<sec-continuo-parte2>

=== De decisiones únicas a decisiones secuenciales
<sec-continuo-rl-motivacion>

Todo el curso, hasta este punto, trató la decisión como una elección única: estimar un efecto, elegir una política, desplegarla. El RL estudia el caso en que un agente toma una *secuencia* de decisiones, cada una de las cuales afecta el estado futuro del entorno y, por tanto, las decisiones siguientes. Un sistema de recomendación que decide qué mostrar en cada visita, sabiendo que la decisión de hoy cambia los datos que se observarán mañana, es un ejemplo. El RL clásico optimiza esa secuencia suponiendo, casi siempre de forma implícita, que el entorno reacciona a las acciones del agente sin confusión oculta entre sus decisiones y las recompensas.

#cite(<bareinboim2025causalai>, form: "prose") trata este problema en los capítulos que dedica a las tareas del RL causal y a la toma de decisiones. Cuando se aprende de datos observacionales, por ejemplo de las demostraciones de un agente anterior cuyas decisiones respondían a información que el agente nuevo no observa, ignorar la confusión puede llevar a una política sesgada.

=== Bandits causales: el caso introductorio más simple
<sec-continuo-bandits>

El caso más simple, y un puente natural desde el _policy learning_ del @cap-policy-learning, son los *bandits con confusores no observados* @bareinboim2015bandits. Es el problema clásico de bandidos de varios brazos con una complicación: una variable $U$ que el agente no ve afecta tanto a la recompensa de cada brazo como a la inclinación natural del propio agente, el brazo que elegiría si nadie interviniera sobre su decisión. Los algoritmos habituales maximizan la recompensa esperada bajo intervención, $E[Y | "do"(X = a)]$, y los autores muestran que esa meta no es la correcta cuando hay confusión.

Su ejemplo es un casino en el que la inclinación a jugar una máquina depende de si el jugador bebió y de si la máquina parpadea, y esas mismas variables afectan la recompensa. En la construcción del artículo, ambos brazos pagan 0,3 bajo intervención y 0,15 de forma observacional (condicionando en el brazo jugado), de modo que ninguna de las dos distribuciones por separado distingue un brazo del otro. Lo que sí informa es una pregunta contrafactual: dado que mi inclinación era jugar $x$, ¿cuánto ganaría si jugara $a$ en su lugar? Comparar la recompensa de obedecer la inclinación con la de llevarle la contraria es el criterio que proponen, y lo implementan en una variante de _Thompson Sampling_ que toma los datos observacionales como valores iniciales.

En sus simulaciones esta variante acumula menos arrepentimiento que _Thompson Sampling_ estándar y que otra que usa la inclinación como contexto. El resultado es empírico: el artículo no ofrece un teorema de optimalidad ni cotas de arrepentimiento. La lección para el resto del libro es doble. La distribución intervencional no siempre es el objetivo correcto de quien decide, porque con confusión hacen falta tanto lo intervencional como lo observacional. Y la brecha entre ambos no es solo un problema que evitar: delata la existencia de un confusor y puede aprovecharse. La conexión con el @cap-intervencion-contrafactual es directa, porque decidir qué información de contexto es segura de condicionar y cuál introduce sesgo de puerta trasera es una decisión de identificación. La conclusión es más constructiva que en el resto del libro.

#cite(<zhang2019near>, form: "prose") llevan el problema a los *regímenes de tratamiento dinámicos*: secuencias de decisiones en que cada acción cambia el estado sobre el que se toma la siguiente, como un tratamiento médico prolongado o una intervención social por etapas. Es el escenario que más se parece a las decisiones de política pública, y también donde la confusión es más difícil de manejar, porque una variable puede ser a la vez confusor de una decisión posterior y mediador de una anterior. Ningún ajuste por covariables resuelve esa situación, que exige el aparato de las fórmulas $g$ de Robins, fuera del alcance de este libro. Los autores derivan cotas informativas sobre la dinámica del sistema a partir de datos observacionales confundidos y proponen un algoritmo de RL que las aprovecha; según su resumen, con arrepentimiento casi óptimo en línea.

=== Por qué el libro se detiene aquí
<sec-continuo-alcance>

#frontera(2026)[
  RL causal es, en 2026, un programa de investigación activo más que un conjunto de recetas maduras y adoptadas en producción, a diferencia de DML o los meta-learners de la Parte II, que ya cuentan con implementaciones estándar. El libro se detiene en el panorama conceptual: entender *por qué* la confusión importa en RL y *cómo* se conecta con lo aprendido sobre identificación causal, sin pretender una cobertura de implementación que la madurez actual del campo no respalda. Lo que se puede dar por estable es que el RL con datos observacionales hereda todos los problemas de identificación de los capítulos anteriores. Lo que probablemente se mueva son los algoritmos concretos y sus garantías.
]

== Ejercicios y notas bibliográficas
<sec-continuo-ejercicios>

=== Ejercicios conceptuales
<sec-continuo-ejercicios-conceptuales>

+ Explique por qué superar la compuerta de registro del @cap-cicd-causal (placebo y estabilidad del efecto) no basta para promover un modelo reentrenado, y qué comparación adicional pide la regla de promoción de este capítulo. Apóyese en el caso canónico del _challenger_ B.

+ Los datos nuevos tienen un corrimiento de 0,4 desviaciones en una covariable. Si el _challenger_ se entrena con la misma cantidad de datos viejos que de nuevos, ¿qué diferencia estandarizada verá la comparación contra el conjunto completo, aproximadamente, y cuál contra los datos nuevos solos? Explique qué pasa con la decisión si el umbral es 0,25.

+ En el casino de la @sec-continuo-bandits ambos brazos pagan 0,3 bajo intervención. Explique por qué, aun así, un jugador cuya inclinación es el brazo 1 puede preferir el brazo 0, y qué cantidad contrafactual tendría que estimar para saberlo.

#capa-impl[
=== Ejercicio de infraestructura
<sec-continuo-ejercicios-infra>

+ Aplique el #ref(<lst-champion-challenger>, supplement: [listado]) a dos versiones de su modelo#solo-curso[ del Notebook A2], entrenadas con dos submuestras deliberadamente distintas del conjunto de datos para simular un cambio de población. Verifique que devuelve `revisar_identificacion` y que, con dos submuestras de la misma población, devuelve `reentrenar`. Luego mida, con 200 pares de submuestras de la misma población, la distribución del mayor desbalance, fije el umbral con la regla de la sección y registre el valor en la ficha.
]

=== Notas bibliográficas
<sec-continuo-notas>

#cite(<huyen2022dmls>, form: "prose"), Capítulo 9, desarrolla en profundidad los patrones de aprendizaje continuo y de pruebas en producción, incluido el despliegue en sombra, en su versión genérica para ML. #cite(<bareinboim2025causalai>, form: "prose") es la referencia central del panorama de RL causal de este capítulo. #cite(<bareinboim2015bandits>, form: "prose") formaliza el caso introductorio de los bandits con confusores no observados y propone un criterio de decisión basado en la inclinación del agente, con evidencia de simulación. #cite(<zhang2019near>, form: "prose") lo extiende a regímenes de tratamiento dinámicos con cotas derivadas de datos observacionales. La conexión de este capítulo con el @cap-generalizacion-transportabilidad merece señalarse: la pregunta de si se puede promover este _challenger_ se parece a la de si el efecto estimado con datos recientes transporta a la población que el servicio atiende, y la comparación de poblaciones de la regla es su versión operativa mínima. Es mínima porque solo ve covariables observadas y supone que lo que cambió son ellas y no el mecanismo.
