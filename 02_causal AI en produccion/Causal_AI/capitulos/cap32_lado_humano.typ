// Capítulo 32: El lado humano de los sistemas causales.
// Plantilla B: Sesión 28. Cierra el recorrido de comunicación; el Cap. 33 cierra la Parte VIII. No lleva capa de implementación: la plantilla de comunicación es un principio
// (no depende de ninguna herramienta) y lo único del curso es el ejercicio de cierre (solo-curso).
#import "../template/template.typ": *

#chapter[El lado humano de los sistemas causales]
<cap-lado-humano>

#theorem-number-reset()

#cuadrodecision[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [Comunicar resultados causales con sus supuestos e incertidumbre explícitos, incluso a audiencias no técnicas],
    [*Alternativas:*], [Comunicación simplificada (solo el número o la historia) vs. comunicación con supuestos e incertidumbre explícitos],
    [*Trade-off clave:*], [Claridad y persuasión inmediata vs. honestidad sobre los límites del hallazgo],
    [*Riesgo principal:*], [Que un resultado válido *bajo supuestos* se comunique y se use como si fuera una verdad incondicional],
  )
]

== El problema de diseño
<sec-ladohumano-problema>

Cada capítulo de este libro terminó con una advertencia sobre límites y supuestos: la sección de riesgos en los capítulos de teoría, la de señales de alerta en los de ingeniería. Ese cuidado se pierde con facilidad en el último paso del ciclo de vida de un sistema causal, que casi nunca es técnico: comunicar el resultado a quien debe tomar una decisión con él. #cite(<huyen2022dmls>, form: "prose") dedica su último capítulo a la dimensión humana del ML, la que la formación técnica rara vez cubre: la experiencia de quien usa el sistema, la organización de los equipos y la responsabilidad. Para un sistema causal el riesgo de desconexión es mayor, porque la diferencia entre "$X$ predice $Y$" y "$X$ causa $Y$", el problema con el que abrió este libro en el @cap-causalidad-elemental, es exactamente el matiz que se pierde primero en una comunicación simplificada.

== Opciones y trade-offs
<sec-ladohumano-opciones>

#opciones[
  - *Comunicación simplificada.* "El programa aumenta el empleo en 12 puntos." Es clara, memorable y persuasiva, y con frecuencia es la única versión que sobrevive varias capas de resumen entre el equipo de datos y quien decide. Su costo es que omite exactamente lo que este libro pasó 31 capítulos formalizando: bajo qué supuestos, para qué población, con qué incertidumbre.
  - *Comunicación con supuestos e incertidumbre explícitos.* "El programa aumenta la probabilidad de conseguir empleo en 12 puntos porcentuales (IC 95 %: 8 a 16), estimado sobre las personas que efectivamente participaron, bajo el supuesto de que no hay factores no observados que determinen a la vez la participación y el empleo." Es honesta y auditable, pero es más difícil de retener y, sin cuidado en la forma, puede sonar a que el equipo técnico no está seguro de nada. El riesgo real es que el matiz se lea como debilidad del hallazgo en lugar de rigor.
]

La resolución de este trade-off no es elegir un extremo sino *estructurar* la comunicación en capas: un titular memorable, respaldado de inmediato por los supuestos y la incertidumbre en un lugar visible y accesible, no enterrado en un apéndice que nadie lee.

La forma de comunicar la incertidumbre tampoco es neutral, y la literatura de comunicación de riesgo ha establecido regularidades que conviene aprovechar en lugar de redescubrir. #cite(<spiegelhalter2019art>, form: "prose") documenta dos que aplican directamente aquí. Primera, las *frecuencias naturales* se comprenden mejor que las probabilidades o los porcentajes: "de cada 100 personas que participan en el programa, entre 8 y 16 más consiguen empleo que si no hubieran participado" se retiene y se razona mejor que "el efecto es de 12 puntos porcentuales (IC 95 %: 8 a 16)", aunque digan lo mismo. Segunda, los *riesgos relativos* suelen inflar la percepción del efecto: "duplica la probabilidad" es correcto y engañoso si la probabilidad basal es de 0,1 %, de modo que conviene reportar siempre el cambio absoluto junto al relativo. A estas dos se suma una tercera, propia de los resultados causales: la comunicación debe explicitar *sobre qué población* aplica el número, porque la audiencia asumirá por defecto que aplica a la suya.

Hay además una asimetría que conviene tener presente al decidir cuánto matizar. Sobreestimar la certeza de un resultado causal produce decisiones que fallan en silencio: el programa se implementa, no funciona, y rara vez se atribuye el fracaso al análisis. Subestimarla produce, en el peor caso, que la decisión se posponga o se tome sin el análisis. Los dos errores tienen costos, pero solo el primero se disfraza de éxito, y esa es una razón práctica, no solo ética, para inclinarse por la comunicación con supuestos explícitos.

== #t-decision
<sec-ladohumano-decision>

#solo-curso[El proyecto final del curso exige]#solo-comercial[Este libro recomienda] que todo resultado se comunique con una estructura de tres capas: *(i)* el hallazgo en una oración, en lenguaje no técnico; *(ii)* los supuestos de identificación y la población de validez, en un párrafo; *(iii)* el detalle técnico completo, para quien necesite auditarlo. Es, en esencia, la misma estructura de la _model card_ causal del @cap-model-card-causal aplicada a la comunicación con personas y no solo a la documentación de un artefacto, y puede derivarse de ella: el hallazgo sale del efecto con su intervalo, la capa (ii) de la población de soporte y los supuestos, y la advertencia de lo que el resultado no implica, de la lista de usos que la ficha prohíbe.

*Cómo se muestra la incertidumbre.* Un intervalo dibujado dice más que un punto con una cifra al lado, y dice más aún si la audiencia puede leerlo. #cite(<galesic2011>, form: "prose") construyeron una escala para medir la alfabetización gráfica y concluyen que no todos se benefician de las visualizaciones estándar, así que conviene acompañar el gráfico con la cifra dicha en palabras. Cuatro prácticas resumen lo anterior: mostrar el intervalo y no solo la estimación puntual; informar cotas cuando la identificación es parcial, o el nivel de confusión no observada que revertiría la conclusión (@sec-cap14_evalue); explicar los supuestos de identificación en lenguaje no técnico; y dar el contexto sobre la magnitud práctica del efecto, porque que un efecto sea estadísticamente distinguible de cero no dice si es grande.

*Qué se comunica cuando el sistema se abstiene o alerta.* Las cinco acciones del @sec-anatomia-acciones también se comunican. Cuando el sistema se abstiene, lo que llega a la persona es "sin respuesta" con su motivo (por ejemplo, la consulta cae fuera de la población donde se estimó el efecto), nunca un cero, ni el último valor, ni un promedio. Cuando alerta, la alerta lleva la señal, su valor y su umbral, no un semáforo. Cuando se promueve una versión nueva, el titular y la ficha dicen desde cuándo vale la estimación y qué cambió. Y un resultado bien comunicado hace un mes puede estar viejo hoy: la capa (ii) indica hasta cuándo se verificaron los supuestos que el monitoreo puede observar (@cap-monitoreo-causal).

== La plantilla de comunicación
<sec-ladohumano-implementacion>

La plantilla no depende de ninguna herramienta: es texto para una persona.

#entero[
#figure(
  kind: raw,
  caption: [Plantilla de tres capas para comunicar un resultado causal.],
  ```markdown
## Hallazgo
Redacte una oración en lenguaje no técnico y sin jerga estadística.

## Lo que esto significa (y lo que no)
- Población para la que es válido: describa las unidades y el periodo cubiertos.
- Principal supuesto detrás del resultado: explique el supuesto de identificación más importante.
- Última verificación de los supuestos observables: indique la fecha y la evidencia revisada.
- Incertidumbre: informe el intervalo de confianza y sus unidades.
- Este resultado no implica: explique qué conclusión quedaría fuera del alcance del análisis.

## Detalle técnico
Indique dónde consultar el documento técnico y la ficha completa del modelo.
```
) <lst-plantilla-comunicacion>
]

== #t-aplicacion: cierre
<sec-ladohumano-cierre>

Este capítulo cierra el recorrido donde lo abrió el @cap-causalidad-elemental: con la distinción entre una pregunta asociativa y una pregunta causal. En el trayecto, el libro desarrolló dos hilos en paralelo. El primero, de identificación y estimación (modelos causales estructurales, criterio de puerta trasera, ortogonalidad de Neyman, DML, _meta-learners_, bosques causales, diseños de panel e instrumentales, descubrimiento de estructura), responde *qué tan bien* se puede responder una pregunta causal con los datos disponibles. El segundo, de ingeniería de sistemas siguiendo a @huyen2022dmls y @kastner2024mlip (anatomía de un sistema, datos de entrenamiento, _features_ sin fuga, despliegue, _model cards_, CI/CD, monitoreo, aprendizaje continuo), responde *cómo* llevar esa respuesta, de forma responsable y verificable, hasta quien la necesita. Ninguno de los dos hilos es completo sin el otro: un estimador impecable que nadie puede auditar en producción es tan poco útil como un servicio impecablemente desplegado que estima la pregunta equivocada. Este capítulo y su plantilla de comunicación son el punto donde ambos hilos le entregan, por fin, algo a una persona que tiene que decidir. Queda una pregunta que ninguno de los dos hilos resuelve por sí solo, y que el @cap-supuestos-no-observables retoma para terminar: qué hace un sistema con los supuestos que ningún dato puede verificar.

== Señales de alerta y checklist operativo
<sec-ladohumano-alertas>

#checklist[
  - El resumen ejecutivo de un resultado causal no menciona ningún supuesto ni intervalo de incertidumbre.
  - Nadie fuera del equipo técnico sabe cuál es la población para la que el efecto estimado es válido.
  - La comunicación usa lenguaje causal ("X causa Y") para un resultado que, honestamente, solo respalda una afirmación asociativa o condicional.
  - No existe una versión accesible (capas 1 y 2 de la plantilla) del resultado; solo existe el documento técnico completo.
  - Cuando el sistema se abstiene, la interfaz muestra un número de todos modos, o no dice por qué no responde.
  - El resultado comunicado no dice hasta cuándo se verificaron sus supuestos observables.
]

== Ejercicios y notas bibliográficas
<sec-ladohumano-ejercicios>

=== Ejercicios conceptuales
<sec-ladohumano-ejercicios-conceptuales>

+ #solo-curso[Tome el resultado del Notebook A2 de su proyecto (o cualquier estimación de este curso)]#solo-comercial[Tome cualquier estimación obtenida con los métodos de este libro] y redáctelo usando la plantilla de tres capas del #ref(<lst-plantilla-comunicacion>, supplement: [listado]).

+ Describa una situación, real o hipotética, en la que una comunicación simplificada de un resultado causal llevó, o podría llevar, a una decisión que el resultado técnico no respaldaba realmente.

+ Un sistema se abstiene en el 12 % de las consultas porque caen fuera de la población de soporte. El equipo de producto propone mostrar en esos casos el efecto promedio de la población de entrenamiento "para no dejar la pantalla vacía". Explique qué se pierde con esa decisión y redacte, con la plantilla, el mensaje que sí debería verse.

=== Ejercicio de cierre#solo-curso[ (proyecto final)]
<sec-ladohumano-ejercicios-cierre>

+ Complete la plantilla de comunicación de tres capas para el sistema desplegado #solo-curso[de su proyecto final]#solo-comercial[que haya construido siguiendo el libro], y agréguela#solo-curso[ como parte de la entrega] junto con la *model card* del @cap-model-card-causal.

=== Notas bibliográficas
<sec-ladohumano-notas>

#cite(<huyen2022dmls>, form: "prose"), Capítulo 11 ("The Human Side of Machine Learning"), es la referencia central de este capítulo. Sobre comunicación de incertidumbre estadística a audiencias no técnicas, #cite(<spiegelhalter2019art>, form: "prose") es la referencia práctica más útil (frecuencias naturales, riesgos absolutos frente a relativos, representación visual de la incertidumbre) y la fuente de las dos primeras regularidades de la @sec-ladohumano-opciones. #cite(<galesic2011>, form: "prose") ofrece la escala de alfabetización gráfica. #cite(<lipton2018mythos>, form: "prose") complementa la discusión desde el otro lado: qué se le está pidiendo realmente a un modelo cuando se pide que sea "interpretable" o "explicable", y por qué esas demandas encubren objetivos distintos (confianza, causalidad, transferibilidad) que conviene separar antes de intentar satisfacerlos. Sobre las buenas prácticas de reporte de resultados causales en particular, véase @imbens2015causal.
