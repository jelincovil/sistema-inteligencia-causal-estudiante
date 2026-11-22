// Capítulo 13: Servicio y abstención.
// Edición de ingeniería de datos (main_de.typ). Caso canónico: scripts/cap13_servicio.py (semilla 20260713).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Servicio y abstención]
<de-cap-servicio>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [El servicio que siempre responde sirve números que nadie puede defender fuera del soporte],
    [*Decisión:*], [El servicio responde con efecto, intervalo y versión dentro del soporte; fuera, se abstiene sin dar número],
    [*Pieza contratada:*], [Contrato C-04 (servicio de estimación): el bundle viaja, el dato no],
    [*Casos canónicos:*], [Dentro del soporte responde 1596.0 IC [1004.8, 2187.3]; fuera (age 99) se abstiene (semilla 20260713)],
    [*Conecta:*], [El bundle viene del registro C-09; el soporte de la tarjeta C-05; la puerta C-06 decide qué versión se sirve],
  )
]

== El bundle viaja, el dato no
<sec-de-13-bundle>

Un servicio causal en producción no lee la tabla de entrenamiento: lee el *bundle* — la versión registrada del registro, con su estimación, su tarjeta y su soporte declarado. Esa separación es la diferencia entre un notebook que corre y un sistema que opera. El dato de entrenamiento puede pesar gigabytes y contener columnas que el servicio no debe ver (la pared del Capítulo 5); el bundle pesa kilobytes y contiene exactamente lo que el servicio necesita para responder: efecto, intervalo, versión, y el rango del soporte.

La implicación operativa es directa: el despliegue — Docker, Kubernetes, una función serverless — empaqueta el bundle, no los datos. La imagen es pequeña, reproducible y auditable: cualquier persona puede verificar que el número servido es el registrado.

#figure(
  diagram(
    node-stroke: 0.6pt + gray.lighten(40%),
    node-fill: light,
    node-outset: 4pt,
    node-corner-radius: 3pt,
    spacing: (5mm, 8mm),
    edge-stroke: 0.8pt + accent,
    node((0, 0), [registro C-09#linebreak()champion]),
    node((2.8, 0), [bundle#linebreak()efecto + IC + tarjeta], fill: rgb("EEF4F8")),
    node((5.6, 0.8), [consulta dentro#linebreak()respuesta], fill: green.lighten(88%)),
    node((5.6, -0.8), [consulta fuera#linebreak()abstención], fill: crimson.lighten(92%)),
    edge((1.0, 0), (2.0, 0), "-|>"),
    edge((3.8, 0.2), (4.8, 0.8), "-|>", stroke: 0.8pt + green),
    edge((3.8, -0.2), (4.8, -0.8), "-|>", stroke: 0.8pt + crimson),
  ),
  caption: [El servicio sirve el bundle del registro, no los datos de entrenamiento. Dentro del soporte responde con efecto e intervalo; fuera, se abstiene sin número.],
) <de-fig-servicio>

== La abstención es una respuesta de primera clase
<sec-de-13-abstencion>

Un servicio predictivo devuelve siempre un número: la predicción es su trabajo. Un servicio causal tiene una opción más que es más honesta que cualquier número: la abstención. Si la consulta cae fuera del soporte — la población donde el efecto fue estimado —, el número que se daría sería una extrapolación sin respaldo, y servirlo en silencio es exactamente el fallo que este libro existe para evitar.

La abstención no es un error técnico: es una respuesta operativa con estado, motivo y versión. Devuelve HTTP 200, no 500; el motivo nombra la covariable y el rango del soporte; y la versión dice a qué registro pertenece la respuesta. Un cliente puede distinguir entre "no puedo responder" y "fallé al responder", y esa distinción es la que permite operar.

El soporte se declara en la tarjeta (C-05): el rango de cada covariable en el conjunto de entrenamiento, o una regla más refinada si el sistema la tiene. El servicio lo verifica en cada consulta: si cualquier covariable del perfil cae fuera, la respuesta es abstención sin ningún número.

== El contrato C-04: servicio de estimación
<sec-de-13-contrato>

#contrato(
  "C-04",
  "Servicio de estimación causal",
  operaciones: [
    _consultar_: responde a un perfil con efecto, intervalo, versión y nota de cobertura, o con abstención y motivo; _salud_: reporta la versión servida y su estado; _resolver_version_: lee el alias champion del registro y carga el bundle correspondiente.
  ],
  entrada: [
    El perfil de consulta (valores de las covariables del esquema) y el bundle del registro (C-09) con su soporte declarado en la tarjeta (C-05).
  ],
  salida: [
    Dentro del soporte: estado respuesta, efecto, IC 95, unidad, qué cubre el IC, versión, nota. Fuera: estado abstención, motivo nombrando la covariable y el rango, versión. Ningún número en la abstención.
  ],
  invariantes: [
    (1) El servicio no lee datos de entrenamiento: solo el bundle del registro. (2) La respuesta incluye siempre efecto, intervalo, qué cubre el intervalo y versión. (3) Fuera del soporte declarado, la respuesta es abstención sin ningún número. (4) Dos consultas idénticas devuelven respuestas idénticas (determinismo). (5) El motivo de la abstención nombra la covariable y el rango del soporte. (6) La versión servida es la que el alias champion resuelve, no una hardcodeada.
  ],
  fallos: [
    Servir un número fuera del soporte. Leer la tabla de entrenamiento en lugar del bundle. Responder sin versión o sin qué cubre el intervalo. Una abstención que devuelve el efecto en otro campo. Dos consultas idénticas con respuestas distintas.
  ],
  aceptacion: [
    (a) Una consulta dentro del soporte responde con efecto 1596.0 e IC [1004.8, 2187.3] sobre real/jobs (semilla 20260713). (b) Una consulta con age 99 se abstiene con motivo que nombra age y el rango [18, 54], sin número. (c) Dos consultas idénticas devuelven la misma respuesta.
  ],
)

== Caso canónico: respuesta y abstención
<sec-de-13-caso>

#caso-canonico("El servicio que responde y el que se abstiene")[
  Sobre `observed_train.csv` de `real/jobs` (semilla 20260713 del script), el servicio sirve el bundle v0001 del registro. Dos consultas lo ejercitan:

  #entero[
  #table(
    columns: (1.8fr, 1.6fr, 2.8fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Consulta*], [*Estado*], [*Respuesta*]),
    table.hline(stroke: 0.3pt),
    [Perfil dentro], [respuesta], [efecto 1596.0, IC [1004.8, 2187.3], versión v0001, nota de cobertura poblacional],
    [age 99 (fuera)], [abstención], [motivo: age 99 fuera de [18.0, 54.0], versión v0001, sin número],
    table.hline(stroke: 0.6pt),
  )
  ]

  El perfil dentro del soporte (age 30, educ 10, black 1, hispan 0, married 0, nodegree 1, re74 2000, re75 1500) recibe el efecto con su intervalo y su versión. El perfil con age 99 — muy por encima del rango de entrenamiento — recibe abstención con el motivo nombrando la covariable y el rango. Determinismo: dos consultas idénticas devuelven exactamente la misma respuesta. El humo del servicio (tres verificaciones del contrato) pasa.
]

#repo-ref[
  Script #code[Causal_AI/scripts/cap13_servicio.py] (semilla 20260713) reproduce la tabla de respuesta y abstención. La implementación de referencia del servicio con FastAPI y abstención: #code[07_docencia/semana_4/solucion/servicio.py] y #code[servicio_core.py]; el Dockerfile correspondiente empaqueta el bundle, no los datos.
]

== Despliegue: local y nube
<sec-de-13-despliegue>

El mismo contrato corre en local y en nube, porque el bundle es portable. En local, `uvicorn servicio:app --port 8000` sirve la API en el puerto de la máquina. En nube, el mismo servicio se empaqueta en una imagen Docker que copia el bundle (no los datos) y se despliega en cualquier plataforma que ejecute contenedores: Kubernetes, Cloud Run, Lambda con adaptadores. La prueba de humo es idéntica en los dos casos: dentro del soporte responde, fuera se abstiene, determinismo.

Lo que cambia entre local y nube no es el contrato: es la operación alrededor. En nube se añaden secretos, escalado, logging y monitoreo de plataforma; el contrato C-04 sigue siendo el mismo y la prueba de aceptación sigue siendo las tres verificaciones del caso canónico. Un despliegue que pasa el humo en local y falla en nube no tiene un problema de contrato: tiene un problema de infraestructura, y se diagnostica como tal.

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ El servicio responde HTTP 200 tanto para la respuesta como para la abstención. ¿Por qué la abstención no es un error 4xx o 5xx, y qué gana el cliente con esa distinción? _Pista:_ un error 500 significa "fallé"; una abstención significa "no puedo sostener ese número aquí".

+ Una consulta llega con age 55, apenas por encima del rango [18, 54]. El equipo propone "responder igual, con una nota". ¿Qué invariante del C-04 rompe esa propuesta? _Pista:_ (3): fuera del soporte la respuesta es abstención sin ningún número; no hay "número con nota".

+ ¿Por qué el servicio lee el bundle del registro y no la tabla de entrenamiento? Dé dos razones: una de operación (tamaño, pared) y una de auditoría (reconstrucción). _Pista:_ la pared del Capítulo 5 prohíbe que la verdad llegue al servicio; el hash del bundle permite reconstruir qué versión se sirvió.

=== Notas bibliográficas

El servicio de estimación es el Capítulo 15 de la edición de método (despliegue) traducido al plano de datos: el bundle viaja, el dato no. La abstención como respuesta de primera clase es la decisión del Capítulo 2 de este libro (las cinco acciones del sistema). La implementación de referencia con FastAPI, humo y Docker está en el repositorio de la semana 4 de docencia: #code[servicio.py], #code[servicio_core.py], #code[humo.py] y #code[Dockerfile].

#verdad-datos[
  Que el servicio responda siempre con efecto, intervalo, qué cubre el intervalo y versión dentro del soporte, y que fuera del soporte la respuesta sea abstención sin ningún número, con motivo que nombra la covariable y el rango. Que el servicio lea el bundle del registro y no la tabla de entrenamiento. Que dos consultas idénticas devuelvan la misma respuesta. Se comprueba con la semilla 20260713: dentro responde 1596.0 [1004.8, 2187.3], age 99 se abstiene con motivo, determinismo. Lo que el servicio no garantiza: que el número dentro del soporte sea causalmente correcto — eso lo decidieron la identificación, la estimación y la puerta antes de llegar aquí.
]
