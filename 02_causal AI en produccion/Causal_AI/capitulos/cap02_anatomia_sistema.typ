// Capítulo 2: anatomía de un sistema de ML en producción.
// Plantilla B: capítulo de ingeniería/producción, estilo DMLS. En el curso incluye el Lab 0 (entorno).
#import "../template/template.typ": *

#chapter[Anatomía de un sistema de ML causal en producción]
<cap-anatomia-sistema>

#theorem-number-reset()

#cuadrodecision[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Decisión:*], [Tratar el modelo como un componente de un sistema, no como el sistema entero],
    [*Alternativas:*], [Enfoque centrado en el modelo (_model-centric_) vs. enfoque centrado en el sistema (_system-centric_, DMLS)],
    [*Trade-off clave:*], [Velocidad de iteración académica vs. confiabilidad operativa],
    ..if not es-principios {([*Stack:*], [Python y Git#solo-curso[ (Lab 0 de este capítulo)]; Docker es opcional])},
    [*Riesgo principal:*], [Confundir “el modelo entrena bien” con “el sistema está listo para producción”],
  )
]

== El problema de diseño
<sec-anatomia-problema>

Un equipo de análisis de datos entrena un estimador de efectos causales (digamos, un modelo DML del tipo que se construirá en la Parte II de este curso) y obtiene un intervalo de confianza razonable, diagnósticos de identificación satisfactorios y una historia convincente sobre el mecanismo económico. El equipo concluye, con toda razón desde el punto de vista estadístico, que "el modelo funciona". Y sin embargo, si ese modelo se entrega tal cual a un equipo de producto para que decida a quién ofrecer un subsidio, casi con certeza algo saldrá mal en cuestión de semanas: la función que calcula las covariables en el entorno de producción no coincide exactamente con la que se usó para entrenar; nadie sabe qué hacer cuando llegan datos con un valor faltante; no existe forma de saber, tres meses después, si la población a la que se le sigue aplicando el modelo todavía se parece a la población de entrenamiento; y si el modelo empieza a fallar, nadie recibe una alerta hasta que un usuario se queja.

El problema de diseño de este capítulo es reconocer, antes de escribir una sola línea de código de estimación, que *un modelo entrenado y un sistema en producción son dos objetos distintos*, y que la distancia entre ambos no se cierra con más precisión estadística sino con decisiones de ingeniería. Como señala @huyen2022dmls, cuando la mayoría de las personas piensan en "un sistema de machine learning" piensan únicamente en el algoritmo; sin embargo, el algoritmo es apenas un componente de un sistema que también incluye la interfaz con la que interactúan usuarios y desarrolladores, el stack de datos que alimenta al modelo, el _backend_ de cómputo sobre el que corre, y la infraestructura que permite desarrollarlo, desplegarlo, monitorearlo y actualizarlo. Este curso dedica su segunda mitad a esos componentes no-algorítmicos, precisamente porque suelen ser el motivo real por el que un proyecto de ciencia de datos técnicamente correcto fracasa en producción.

== Opciones y trade-offs
<sec-anatomia-opciones>

Existen, en la práctica, dos filosofías de desarrollo que compiten por el tiempo y la atención de un equipo de datos.

*Opción 1. Enfoque centrado en el modelo (_model-centric_).* El foco está en mejorar la especificación, el algoritmo o la arquitectura, manteniendo los datos y el entorno de despliegue relativamente fijos. Es el modo de trabajo dominante en la academia y en competencias como Kaggle: se compite por una décima de mejora en una métrica sobre un dataset fijo. Su ventaja es la velocidad de iteración sobre la pregunta metodológica; su límite es que ignora, por construcción, todo lo que ocurre antes de tener el dataset y después de tener el modelo entrenado.

*Opción 2. Enfoque centrado en el sistema (_system-centric_, DMLS).* El foco se reparte deliberadamente entre datos, modelo e infraestructura, entendiendo que mejorar cualquiera de los tres puede mejorar el desempeño observado del sistema. Requiere invertir tiempo en aspectos que no son estadísticamente "interesantes" (formato de almacenamiento, *feature stores*, *logging*, *tests*) y por eso suele sentirse, al principio, como una desviación del trabajo "real". Su ventaja es que es, empíricamente, el único enfoque que sobrevive el contacto con datos reales que cambian con el tiempo y con usuarios reales que dependen del sistema.

Un segundo trade-off, ortogonal al anterior, es el del *proceso* de desarrollo:

#table(
  columns: (1.3fr, 2.2fr, 2.2fr),
  align: left,
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Dimensión*], [*Proceso lineal ("waterfall")*], [*Proceso iterativo (DMLS)*]),
  [Estructura], [Recolectar datos → entrenar → desplegar → fin], [Ciclo continuo: diseño → datos → desarrollo → despliegue → monitoreo → vuelve a diseño],
  [Supuesto implícito], [El mundo (los datos, los usuarios) no cambia después del despliegue], [El mundo cambia; el sistema debe detectarlo y adaptarse],
  [Cuándo falla], [En cualquier entorno de producción real, tarde o temprano], [Requiere infraestructura de monitoreo que el proceso lineal no contempla],
)

El proceso lineal no es una decisión de diseño defendible en 2026 para un sistema que opera de forma continua; se incluye en la tabla porque sigue siendo, de hecho, cómo se enseña y se ejecuta gran parte de los proyectos de ciencia de datos aplicada, y reconocerlo como la opción por defecto, y como opción inadecuada, es el primer paso para adoptar deliberadamente la alternativa.

== #t-decision
<sec-anatomia-decision>

Este curso adopta explícitamente el *enfoque centrado en el sistema* y el *proceso iterativo* de DMLS como su filosofía de trabajo. Los formaliza en cuatro requisitos que todo sistema descrito aquí debe satisfacer, reinterpretados para el caso en que el objetivo del sistema es estimar un efecto causal y no solo predecir:

#opciones[
  - *Confiabilidad*: el sistema sigue produciendo el comportamiento correcto incluso en presencia de errores de datos o de infraestructura. Para un sistema causal, esto incluye algo que un sistema puramente predictivo no necesita: que el efecto estimado siga siendo *válido bajo los supuestos de identificación declarados*, no solo que el servicio esté "arriba".
  - *Escalabilidad*: el sistema puede crecer en volumen de datos, de tratamientos o de usuarios sin un rediseño completo. Para un sistema causal, incluye poder re-estimar el efecto sobre subpoblaciones nuevas sin invalidar el pipeline de identificación existente.
  - *Mantenibilidad*: otra persona del equipo, y no quien lo construyó, puede entender, auditar y modificar el sistema. Para un sistema causal, esto exige que los supuestos de identificación estén *documentados y sean auditables*, no solo el código.
  - *Adaptabilidad*: el sistema puede ajustarse a cambios en el entorno (nuevos datos, nuevas poblaciones, nuevas políticas). Para un sistema causal, incluye poder *detectar* cuándo un supuesto causal (no confusión, soporte común, fuerza del instrumento) dejó de sostenerse, tema que retomaremos en #solo-curso[el Módulo 5]#solo-comercial[el Capítulo #ref(<cap-monitoreo-causal>, supplement: none)].
]

Estos cuatro requisitos, y no la precisión del estimador considerada de forma aislada, son el criterio con el que se evalúa #solo-curso[cada notebook de producción (Serie B) del curso]#solo-comercial[cada sistema que se describe en este libro].

== El sistema desplegado es una intervención
<sec-anatomia-intervencion>

Hasta aquí hemos tratado al sistema como algo que mira el mundo y responde. Esa imagen es cómoda y es falsa. En cuanto el sistema decide a quién se le ofrece el subsidio, a quién se le llama o a quién se le concede el crédito, deja de ser un observador: sus decisiones son una intervención sobre el mundo que mide, y esas decisiones se convierten en los datos con los que se entrenará su próxima versión.

El bucle es corto. El modelo de la semana $t$ recomienda una acción para cada persona, la recomendación se aplica o se anula, el resultado se observa y se registra, y ese registro alimenta al modelo de la semana $t + 1$:

#import "@preview/cetz:0.3.4"   // or whatever is the latest on Universe right now

#figure(
  cetz.canvas(length: 1cm, {
    import cetz.draw: *
    set-style(content: (size: 9pt), stroke: 0.6pt)

    let caja(x, y, body, fill: aqua.lighten(75%)) = {
      // Modern, reliable centered rect
      rect(
        (x - 0.95, y - 0.32),
        (x + 0.95, y + 0.32),
        fill: fill,
        stroke: 0.6pt,
        radius: 3pt,
      )
      content((x, y), body)
    }

    // Fila superior
    caja(0, 0, [datos $t$])
    caja(3, 0, [modelo $t$], fill: yellow.lighten(75%))
    caja(6, 0, [decisión $t$], fill: red.lighten(80%))

    // Fila inferior
    caja(6, -2.6, [mundo $t+1$])
    caja(0, -2.6, [datos $t+1$])

    // Flechas horizontales
    line((0.95, 0), (2.05, 0), mark: (end: ">", size: 0.22))
    line((3.95, 0), (5.05, 0), mark: (end: ">", size: 0.22))
    line((5.05, -2.6), (0.95, -2.6), mark: (end: ">", size: 0.22))

    // Flechas verticales
    line((0, -2.28), (0, -0.32), mark: (end: ">", size: 0.22))
    line((6, -0.32), (6, -2.28),
      mark: (end: ">", size: 0.22),
      stroke: (paint: red, thickness: 1.3pt))

    // Etiqueta de la intervención
    content((6.85, -1.3),
      std.rotate(-90deg, reflow: true)[#text(fill: red)[*intervención*]],
      frame: none)

    // Etiqueta del bucle
    content((3, -3.25),
      text(size: 8pt, style: "italic")[
        el sistema decide sobre el mundo que luego lo reentrena
      ])
  }),
  caption: [
    El sistema desplegado como bucle causal. La flecha *roja* no observa el
    mundo: lo modifica. Por eso `decisión_t` aparece como causa de `datos_{t+1}`,
    y el modelo de la semana siguiente se entrena sobre una muestra que el
    modelo de esta semana seleccionó.
  ],
) <fig-bucle-causal>

Dibujado como un grafo causal, la decisión pasada aparece como causa del dato futuro. De ahí salen tres consecuencias que ningún diagnóstico de predicción detecta, y que organizan buena parte de lo que sigue.

*Primera: la asignación del tratamiento pasa a ser la política del propio modelo.* Si el sistema recomienda siempre la misma acción a las personas con las mismas covariables, la probabilidad de recibir el tratamiento dado $X$ es 0 o 1 en los datos nuevos. Sin variación en quién recibe qué para un mismo perfil no hay con quién comparar, y el efecto deja de estar identificado por los datos que el sistema mismo produce. Es la condición de soporte común del @cap-prediccion-causalidad, que aquí se rompe por construcción y no por mala suerte.

*Segunda: solo se observa el resultado de quienes recibieron la acción.* El crédito que no se concedió no deja registro de si habría sido pagado, y el cliente a quien no se llamó no dice si habría renovado. El modelo nuevo aprende entonces de una muestra que el modelo viejo seleccionó. Es el problema de las _etiquetas selectivas_, y su efecto es acumulativo: el sesgo de la versión de ayer entra en los datos de hoy y puede amplificarse con cada reentrenamiento @sculley2015hiddendebt.

*Tercera: lo que se quiere medir puede cambiar con la política.* Un modelo de riesgo que dispara una intervención preventiva consigue que muchos de los casos que marcó no ocurran, y con eso su precisión aparente empeora: los aciertos se ven como falsas alarmas. Cuando la predicción influye en el resultado que pretende predecir se habla de predicción _performativa_ @perdomo2020performative, y la pregunta correcta deja de ser qué tan bien acertó el modelo para pasar a ser qué habría ocurrido sin él.

La salida no es dejar de decidir con modelos. Es diseñar el sistema para que siga siendo identificable mientras opera. Tres prácticas lo logran. La primera es reservar de forma permanente un grupo pequeño, asignado al azar, que el modelo no gobierna (un _holdout_ permanente). La segunda es registrar con qué probabilidad se asignó cada acción a cada persona, porque sin ese registro no se puede corregir después por la forma en que se decidió. La tercera es mantener un piso de exploración, una fracción mínima de asignación aleatoria dentro de cada perfil para que ninguno quede sin comparación. Las tres cuestan algo de valor de corto plazo, porque una parte de las personas recibe una acción que el modelo no habría elegido, y compran la posibilidad de seguir midiendo el efecto del sistema. Este capítulo solo instala la idea; los Capítulos #ref(<cap-monitoreo-causal>, supplement: none) y #ref(<cap-aprendizaje-continuo>, supplement: none) tratan cómo vigilar un sistema que decide y cómo reentrenarlo sin perder la identificación.

== Las cinco acciones del sistema
<sec-anatomia-acciones>

Un sistema que opera necesita un vocabulario cerrado para lo que hace frente a lo que observa. Este libro usa cinco acciones, siempre con el mismo sentido, de modo que "alertar" o "abstenerse" signifiquen lo mismo en el servicio, en la ficha del modelo, en las pruebas automáticas, en el monitoreo y en el aprendizaje continuo. La tabla las ordena de la más restrictiva a la menos restrictiva.

#table(
  columns: (1.2fr, 3.4fr, 1.4fr),
  align: left,
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Acción*], [*Qué significa*], [*Quién actúa*]),
  [Abstenerse], [El sistema no devuelve un número: responde "sin respuesta" a esa consulta, o a todas, porque no puede sostener el efecto (por ejemplo, la consulta está fuera de la población de soporte).], [El sistema],
  [Revisar identificación], [Un supuesto de identificación dejó de sostenerse o dejó de poder comprobarse. No se promueve ninguna versión nueva hasta que alguien revise el diseño, el grafo y los supuestos.], [Una persona],
  [Alertar], [Una señal superó su umbral de aviso. El sistema sigue respondiendo y una persona recibe la señal junto con su evidencia.], [Una persona],
  [Reentrenar], [El estimador se ajusta de nuevo con datos nuevos, sin cambiar el estimando ni la población declarados.], [El sistema, bajo una regla de promoción],
  [Continuar], [Ninguna señal supera su umbral. El sistema sigue respondiendo con la versión vigente.], [El sistema],
)

Cuando varias acciones aplican a la vez, prevalece la más restrictiva. El orden tiene una razón en cada peldaño. Abstenerse va primero porque un número sin sustento es peor que ningún número. Revisar la identificación va antes que alertar porque un supuesto roto no se arregla con un aviso. Y reentrenar queda por debajo de alertar a propósito: ante un cambio en los datos, lo primero es preguntar qué cambió (el @cap-generalizacion-transportabilidad desarrolla esa pregunta), y reentrenar solo es la respuesta cuando cambió la distribución de las covariables y el efecto sigue siendo el mismo. Si el cambio altera quién recibe el tratamiento o cómo se mide el resultado, reentrenar produce un modelo nuevo para un problema distinto.

Qué señal dispara cada acción y con qué umbral lo decide cada capítulo de producción, y esos umbrales son valores de partida que se calibran con datos propios. Aquí solo se fija el vocabulario.

== #t-esqueleto
<sec-anatomia-implementacion>

Un sistema causal en producción, con la tecnología que sea, tiene seis piezas. Los *datos*, versionados y con el papel de cada columna declarado (tratamiento, resultado, covariables, identificadores, marcas de tiempo). Una *preparación de variables* única, que es la misma función en entrenamiento y en servicio. El *estimador* con su procedimiento de ajuste, de modo que las semillas y la versión de los datos queden registradas. Un *servicio de estimación* que responde con efecto, intervalo y población, o se abstiene. Las *pruebas*, que separan lo determinista (el servicio hace lo que dice) de lo estadístico (el efecto sigue siendo válido). Y una *ficha del modelo* que viaja con el artefacto y declara el estimando, la población y los supuestos. Los capítulos siguientes describen cada pieza como un contrato: qué entra, qué sale, qué debe cumplirse siempre y cómo falla.

#capa-impl[
#solo-curso[Todo el trabajo práctico del curso (Serie A y Serie B de notebooks, y el proyecto final) se organiza sobre un mismo esqueleto de repositorio, que se establece en este capítulo y no vuelve a discutirse:]#solo-comercial[El repositorio complementario organiza estas piezas sobre un esqueleto que se establece en este capítulo y no vuelve a discutirse:]

#if es-curso [
```
proyecto-causal/
├── data/                 # datos crudos y procesados (no versionados en git salvo muestras pequeñas)
├── notebooks/
│   ├── serie_a_caso_estudio/     # A1–A4: identificación y estimación
│   └── serie_b_produccion/       # B1–B4: despliegue local
├── src/
│   ├── identification/   # DAGs, diagnósticos de no confusión y soporte común
│   ├── estimation/        # DML, meta-learners, bosques causales
│   └── service/            # función de inferencia, app FastAPI
├── tests/                 # pruebas de humo y de sanidad estadística
├── scripts/                # CI local (se detalla en el Capítulo 20)
├── Dockerfile             # opcional: empaquetado del servicio
└── model_card.md           # plantilla del Apéndice G
```
] else [
```
proyecto-causal/
├── data/                 # datos crudos y procesados (no versionados en git salvo muestras pequeñas)
├── notebooks/            # cuadernos de trabajo del repositorio complementario
├── src/
│   ├── identification/   # DAGs, diagnósticos de no confusión y soporte común
│   ├── estimation/        # DML, meta-learners, bosques causales
│   └── service/            # función de inferencia, app FastAPI
├── tests/                 # pruebas de humo y de sanidad estadística
├── scripts/                # CI local (se detalla en el Capítulo 20)
├── Dockerfile             # opcional: empaquetado del servicio
└── model_card.md           # plantilla del Apéndice G
```
]

#solo-curso[*Lab 0 de esta sesión*]#solo-comercial[*Primer ejercicio de infraestructura*] consiste en dejar este esqueleto funcionando localmente: entorno de Python con las librerías del Apéndice B, repositorio Git inicializado y una prueba de humo que se ejecuta con un solo comando. Docker no es necesario para este laboratorio; si más adelante empaqueta el servicio en un contenedor (Capítulos #ref(<cap-despliegue-servicio>, supplement: none) y #ref(<cap-cicd-causal>, supplement: none)), instálelo entonces. No se estima ningún efecto causal todavía; el objetivo es puramente de infraestructura.
]

== #t-aplicacion
<sec-anatomia-aplicacion-causal>

Vale la pena ser explícitos sobre qué cambia, en esta anatomía de sistema, cuando el "modelo" no predice sino que estima un efecto. Primero, *el artefacto que se sirve no es solo un objeto entrenado*: es un estimador más un conjunto de supuestos de identificación que deben viajar junto con él. De nada sirve servir los coeficientes de un DML sin la documentación de qué variables se controlaron y bajo qué DAG supuesto, porque sin eso nadie puede saber si el efecto sigue siendo válido para una nueva observación. Segundo, *la interfaz con el usuario debe comunicar algo más que un número*: un sistema predictivo puede mostrar una predicción puntual; un sistema causal responsable debe comunicar el intervalo de confianza y, cuando sea posible, la población para la cual el efecto fue estimado, para evitar que se use fuera de su dominio de validez. Y a veces la respuesta correcta es no comunicar ningún número: si la consulta cae fuera de esa población, el sistema se abstiene. Tercero, *reentrenar no es inocuo*: en un sistema predictivo, reentrenar con datos nuevos casi siempre es deseable si mejora la métrica de error. En un sistema causal, incorporar datos nuevos puede cambiar silenciosamente la población para la que el efecto estimado es representativo, un problema de validez externa y no solo de varianza. Este libro vuelve sobre esto en el Capítulo #ref(<cap-aprendizaje-continuo>, supplement: none) (aprendizaje continuo).

== Señales de alerta y checklist operativo
<sec-anatomia-alertas>

#checklist[
  - La estimación no tiene asociada ninguna versión de los datos ni del código (no hay forma de reproducir el resultado).
  - La función que calcula las covariables en el entrenamiento y la que las calculará en producción no son literalmente la misma función (riesgo de *training-serving skew*).
  - No existe un libro de supuestos: ningún documento, ni siquiera informal, que enumere cada supuesto de identificación, de qué tipo es (observable, falsable o no observable) y cómo se vigila o se trata.
  - Nadie en el equipo, aparte de quien entrenó el modelo, podría explicar bajo qué población es válido el efecto estimado.
  - No hay ningún mecanismo, ni manual, para detectar si las covariables que llegan en producción se parecen a las de entrenamiento.
  - El sistema siempre responde, incluso cuando la consulta cae fuera de la población donde se estimó el efecto: no existe ninguna condición en la que devuelva "sin respuesta".
  - Todas las personas reciben la acción que el modelo recomienda. No hay un grupo, por pequeño que sea, al que el sistema no gobierne, ni registro de con qué probabilidad se asignó cada acción.
]

Si dos o más de estas señales están presentes, el sistema, por preciso que sea el estimador, no está listo para producción según los criterios de este curso.

== Ejercicios y notas bibliográficas
<sec-anatomia-ejercicios>

=== Ejercicios conceptuales
<sec-anatomia-ejercicios-conceptuales>

+ Enumere los componentes de un sistema de ML según @huyen2022dmls (más allá del algoritmo) y, para cada uno, dé un ejemplo concreto de cómo fallaría específicamente si el sistema estima un efecto causal en lugar de predecir.

+ Explique, con sus propias palabras, por qué "reentrenar con datos nuevos" es una decisión más delicada en un sistema causal que en uno puramente predictivo.

+ Revise los cuatro requisitos de la @sec-anatomia-decision (confiabilidad, escalabilidad, mantenibilidad, adaptabilidad) y ordénelos según cuál cree que es más fácil de descuidar en un proyecto real. Justifique.

+ Un banco usa un modelo para decidir a quién ofrecer un crédito y cada mes lo reentrena con los créditos que otorgó y su desempeño. Dibuje el bucle y explique qué información sobre los solicitantes a quienes el modelo no ofreció crédito llega al modelo del mes siguiente. ¿Qué cambiaría si el banco otorgara crédito al azar al 2 % de los solicitantes, sin importar su puntaje?

+ Para cada situación indique cuál de las cinco acciones de la @sec-anatomia-acciones corresponde y por qué. Si más de una aplica, diga cuál prevalece. (a) La distribución de una covariable se desplazó, la señal superó su umbral de aviso, el soporte común se sigue cumpliendo y los diagnósticos de identificación no empeoraron. (b) Llega una consulta con una covariable fuera del rango de la población donde se estimó el efecto. (c) Un cambio de política interna hace que los clientes de ingreso alto ya no reciban nunca la oferta. (d) Ninguna señal supera su umbral.

#solo-curso[
=== Ejercicio de infraestructura (Lab 0)
<sec-anatomia-ejercicios-lab0>

+ Complete el Lab 0: cree el esqueleto de repositorio de la @sec-anatomia-implementacion, inicialice Git y deje una prueba de humo que se ejecute con un solo comando. Entregue la salida de ese comando.
]

=== Notas bibliográficas
<sec-anatomia-notas>

#cite(<huyen2022dmls>, form: "prose") es la fuente principal de este capítulo y del enfoque pedagógico de todo el curso; sus Capítulos 1 y 2 ("Overview of Machine Learning Systems" e "Introduction to Machine Learning Systems Design") desarrollan en detalle la distinción entre modelo y sistema, y los cuatro requisitos aquí adaptados al caso causal. #cite(<sculley2015hiddendebt>, form: "prose") es el artículo seminal que documentó por primera vez, de forma sistemática, cómo el código del modelo de aprendizaje automático suele ser una fracción pequeña del sistema real, y cómo la "deuda técnica" se acumula en el resto de los componentes. #cite(<breck2017mltestscore>, form: "prose") ofrece una rúbrica operativa, el "ML Test Score", que puede usarse como complemento al checklist de la @sec-anatomia-alertas para auditar la preparación de un sistema para producción. #cite(<paleyes2022challenges>, form: "prose") complementa a ambos con evidencia empírica: una revisión sistemática de casos documentados de despliegue que clasifica los puntos de fallo a lo largo del ciclo de vida completo (gestión de datos, desarrollo del modelo, despliegue, monitoreo) y confirma que la fracción de fallos atribuible al algoritmo mismo es minoritaria, el argumento central de este capítulo contrastado contra la práctica industrial en lugar de solo argumentado. Sobre el bucle de la @sec-anatomia-intervencion, #cite(<sculley2015hiddendebt>, form: "prose") describe los bucles de retroalimentación ocultos, en los que un modelo influye en los datos con los que se reentrena, como una fuente de deuda técnica, y #cite(<perdomo2020performative>, form: "prose") formalizan la predicción performativa, el caso en que la predicción cambia el resultado que predice.