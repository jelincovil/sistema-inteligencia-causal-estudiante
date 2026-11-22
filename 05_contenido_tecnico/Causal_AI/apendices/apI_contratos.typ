// Apéndice I: Contratos numerados del libro
#import "../template/template.typ": *

#chapter[Contratos numerados del libro]
<ap-contratos>

#theorem-number-reset()

Este libro describe cada pieza de ingeniería como un contrato numerado y no como un programa. Un contrato dice qué hace la pieza, qué debe cumplirse siempre y cómo se comprueba, sin decir con qué herramienta se construye. Esa separación es deliberada: las ideas del libro duran más que las librerías, y el material complementario que implementa los contratos puede cambiar sin que cambie el libro. Este apéndice reúne en un solo lugar los ocho contratos, cómo se relacionan, qué prueba de aceptación tiene cada uno y cómo declara un equipo cuáles cumple.

== Cómo se lee un contrato
<sec-apI-lectura>

Todos los contratos usan la misma caja, con los mismos seis campos.

- *Operaciones.* Lo que la pieza ofrece a quien la usa. Un contrato que describe un documento, como la ficha del modelo (C-05), no tiene operaciones y empieza por lo que recibe.
- *Entrada y salida.* Lo que recibe y lo que devuelve, con el nivel de detalle que necesita quien implementa, no el que necesita quien programa.
- *Invariantes.* Lo que debe cumplirse siempre, para cualquier entrada. Cada invariante se puede comprobar: si no hay forma de probarlo, no es un invariante sino un deseo.
- *Modos de fallo.* Cómo falla la pieza y qué hace entonces. Incluye los fallos que el contrato existe para impedir y los que el contrato reconoce no poder ver.
- *Prueba de aceptación.* El procedimiento que decide si una implementación cumple el contrato, sobre datos con verdad conocida cuando el contrato habla de efectos.

La diferencia entre invariante y prueba importa. El invariante dice qué es verdad. La prueba es la evidencia de que lo es en una implementación concreta, y puede cubrir solo una parte de los invariantes. Por eso la declaración de conformidad de más abajo pide decir qué invariantes quedaron sin cubrir.

== Los ocho contratos de un vistazo
<sec-apI-indice>

#entero[
#table(
  columns: (auto, 1.5fr, auto, 3.2fr, 1.3fr),
  align: (left, left, center, left, left),
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Id*], [*Contrato*], [*Cap.*], [*Qué garantiza*], [*Depende de*]),
  [C-01], [Esquema de roles causales], [#ref(<cap-ingenieria-datos-causales>, supplement: none)], [Cada columna tiene un solo rol declarado, y el esquema viaja con los datos.], [Ninguno],
  [C-02], [Comparación de poblaciones], [#ref(<cap-datos-entrenamiento-causales>, supplement: none)], [Dos poblaciones se comparan con una medida de tamaño de efecto y un umbral calibrado, no con un $p$-valor.], [C-01],
  [C-03], [Auditoría de _features_], [#ref(<cap-features-sin-fuga>, supplement: none)], [Ninguna covariable entra sin un rol declarado ni sin verificarse como anterior al tratamiento.], [C-01],
  [C-04], [Servicio de estimación], [#ref(<cap-despliegue-servicio>, supplement: none)], [Cada consulta recibe un efecto con su intervalo, o una abstención sin ningún número.], [C-01, C-05],
  [C-05], [Ficha causal del modelo], [#ref(<cap-model-card-causal>, supplement: none)], [El modelo viaja con sus supuestos clasificados (los observables con su umbral; los no observables con sensibilidad compatible o limitación explícita), su población de soporte y la huella de sus datos.], [C-01, C-03 y los resultados de C-02],
  [C-06], [Compuerta de registro], [#ref(<cap-cicd-causal>, supplement: none)], [Ningún candidato llega al registro sin una decisión de la compuerta.], [C-05],
  [C-07], [Monitoreo causal], [#ref(<cap-monitoreo-causal>, supplement: none)], [Los cambios contemplados se evalúan con las señales y límites declarados, y el reporte termina en una acción que no presume conocer la causa.], [C-01, C-02, C-05],
  [C-08], [Sensibilidad de los supuestos no observables], [#ref(<cap-supuestos-no-observables>, supplement: none)], [Ningún supuesto que ningún dato verifica figura como verificado: lleva su margen frente a la decisión y su fecha de revisión.], [C-05, C-07],
)
]

El @cap-aprendizaje-continuo no define un contrato propio. Su regla de promoción usa la comparación de poblaciones (C-02) y la compuerta de registro (C-06), y devuelve una de las cinco acciones del @cap-anatomia-sistema.

== Una prueba de aceptación por contrato
<sec-apI-pruebas>

Cada contrato se comprueba con un caso de verdad conocida, un proceso generador estilizado cuyo efecto se conoce y cuya descripción cabe en un párrafo. La tabla resume qué caso usa cada uno y qué debe ocurrir.

#entero[
#table(
  columns: (auto, 2.2fr, 3.6fr),
  align: (left, left, left),
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Id*], [*Caso con verdad conocida*], [*Qué debe ocurrir*]),
  [C-01], [Dos análisis sobre la misma tabla, con una experiencia potencial calculada con el tratamiento (@cap-ingenieria-datos-causales).], [Cada fallo estructural se rechaza con un mensaje que nombra la columna, y el esquema escrito y vuelto a leer es igual. La covariable posterior al tratamiento pasa, y la prueba deja a la vista que el contrato no la detecta.],
  [C-02], [Cuarenta covariables y dos mecanismos de asignación (@cap-datos-entrenamiento-causales).], [Con la moneda justa, los rechazos crudos rondan el 5 % de las covariables y los de Holm casi no aparecen. Con asignación que depende de una covariable, solo se activa la bandera de esa covariable.],
  [C-03], [Cuatro tipos de _feature_ y una verdad conocida (@cap-features-sin-fuga).], [La auditoría deja la especificación base con el confusor y la ampliada con el confusor y la de rol desconocido, y las seis estimaciones de la tabla del caso se reproducen.],
  [C-04], [Datos con efecto conocido (@cap-despliegue-servicio).], [La cobertura del intervalo no baja del piso calibrado, una consulta fuera de la población recibe una abstención sin número y dos llamadas idénticas devuelven lo mismo.],
  [C-05], [Una ficha de ejemplo y los datos de referencia con su huella (@ap-model-card-causal).], [La ficha valida contra el esquema versionado, la huella coincide con la de los datos de referencia y el servicio se abstiene fuera del soporte que la ficha declara. Una ficha con un observable sin umbral o con un veredicto que no sale de su valor, y una con un no observable sin sensibilidad, se rechazan.],
  [C-06], [Fallos de causa conocida inyectados en un candidato (@cap-cicd-causal).], [El candidato sano se registra. Quitar un control clave, subestimar el error estándar o cambiar la huella de los datos bloquea, y lo bloquea la prueba que corresponde. Registrar sin una decisión es imposible.],
  [C-07], [Un generador con cuatro cambios posibles (@cap-monitoreo-causal).], [Cada cambio inyectado enciende la señal que le corresponde y no las demás, y sin cambio la tasa de alarmas no supera la declarada en la calibración.],
  [C-08], [Un generador con un confusor oculto de intensidad conocida y un control negativo (@cap-supuestos-no-observables).], [La cota coincide con el sesgo real, el valor crítico coincide con su forma cerrada, el control que comparte el confusor se enciende y el que no lo comparte no supera la tasa nominal, y cada disparador produce su motivo de revisión.],
)
]

== Declaración de conformidad
<sec-apI-conformidad>

Una implementación del material complementario declara qué contratos cumple con una tabla como la siguiente, que se publica junto con el código.

#entero[
#table(
  columns: (auto, auto, 2fr, 2fr, 1.5fr),
  align: (left, left, left, left, left),
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Contrato*], [*Versión*], [*Implementación*], [*Prueba de aceptación ejecutada*], [*Invariantes sin cubrir*]),
  [C-01], [1], [Nombre y versión de la pieza que lo cumple], [Fecha y resultado de la prueba], [Lista, o ninguno],
)
]

Cuatro reglas hacen que la tabla sirva para algo.

+ Se declara un contrato solo si su prueba de aceptación se ejecutó y pasó. Un contrato sin prueba ejecutada no se declara como cumplido, se declara como pendiente.
+ Los invariantes que la prueba no cubre se listan. Es información que el lector necesita para saber hasta dónde puede confiar en la pieza.
+ Una implementación puede cumplir un contrato sin parecerse a la descripción del libro: un servicio web, una biblioteca o una tarea programada que llena una tabla cumplen igual el C-04 si pasan su prueba.
+ La declaración nombra la versión del conjunto de contratos contra la que se probó. Este libro describe la versión 1.

== Cuándo cambia un contrato
<sec-apI-cambios>

Un contrato cambia cuando una edición del libro debilita o endurece un invariante, agrega un modo de fallo que antes no se reconocía o cambia lo que la pieza recibe o devuelve. Cualquiera de esos cambios exige una nueva versión del conjunto de contratos, porque una implementación que pasaba la prueba anterior puede dejar de pasar la nueva. Una aclaración de redacción que no cambia el comportamiento no la exige. La edición declara su versión de contratos en esta sección y el material complementario declara la suya en su tabla de conformidad, de modo que quien lee ambos sabe si coinciden.

== Un orden razonable para adoptarlos
<sec-apI-orden>

Un equipo que empieza de cero no necesita los ocho a la vez. El orden que sigue es una propuesta y se apoya en las dependencias de la tabla inicial.

+ C-01, porque todos los demás consumen el esquema de roles y es la pieza más barata.
+ C-03, porque la lista de covariables que produce es lo que el esquema y la ficha registran, y porque un error aquí contamina todo lo posterior.
+ C-05 y C-04, juntos, porque un servicio sin ficha responde con un artefacto que nadie puede describir, y una ficha sin servicio no cambia ninguna decisión.
+ C-06, cuando haya más de una versión del modelo y alguien deba decidir cuál sirve.
+ C-02 y C-07, cuando el sistema ya esté en producción y haya que saber si el mundo cambió. El C-02 también se usa antes, al auditar los datos de entrenamiento, y ahí no espera a la producción.
+ C-08, junto con el C-07, cuando el sistema ya sirva decisiones y la ficha declare supuestos no observables, que es casi siempre.

== Checklist de conformidad
<sec-apI-checklist>

#checklist[
  - Cada contrato que el equipo dice cumplir tiene su prueba de aceptación ejecutada, con fecha y resultado.
  - La declaración lista los invariantes que la prueba no cubre.
  - La versión del conjunto de contratos de la declaración coincide con la de la edición del libro que se usa.
  - Los casos de verdad conocida de las pruebas están versionados junto al código, con su semilla.
  - Un cambio en una pieza vuelve a ejecutar la prueba de los contratos que declara, no solo la de los tests de la propia pieza.
  - Ningún contrato se declara cumplido porque la pieza "hace lo que dice el libro" sin que nadie haya corrido la prueba.
]
