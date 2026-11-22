// Cómo usar este libro
// Describe la organización por capas (L0 a L3), los dos tipos de capítulo y las tres ediciones.
// El mapa sesión ↔ capítulo ↔ lab y la organización del trabajo práctico del curso viven en el
// Apéndice J (guía para instructores), solo edición de curso.
#import "../template/template.typ": *

#chapter[Cómo usar este libro]
<sec-como-usar>

Este libro presenta los métodos de aprendizaje automático causal, los principios para llevarlos a producción y la razón por la que la teoría causal hace que esa producción tenga efecto real. Tiene nueve partes y treinta y tres capítulos, y está escrito en capas para que cada lector entre por el nivel que necesita.

== Las capas de un capítulo

Todo capítulo se construye con las mismas capas, de la más estable a la más cambiante.

- *Capa 0, teoría.* Definiciones, supuestos, proposiciones y demostraciones o bosquejos. Responde la pregunta "¿qué se puede afirmar, y bajo qué supuestos?".
- *Capa 1, pseudocódigo.* Algoritmos numerados, escritos sin referencia a ningún lenguaje. Responde "¿qué pasos hay que dar?".
- *Capa 2, principios y casos canónicos.* Las ideas que sobreviven al cambio de herramientas, y casos pequeños con números verificados por simulación. Un caso canónico sirve de prueba de aceptación: cualquier implementación del método, con la herramienta que sea, debe reproducir su orden de magnitud. Responde "¿cómo sé que lo hice bien?".
- *Capa 3, implementación.* Listados, configuración y guías de herramientas. Responde "¿cómo lo hago hoy, con estas piezas?". Es la capa que más rápido envejece.

#if es-principios [
  Esta es la *edición de principios*: contiene las capas 0 a 2 y ninguna dependencia de una herramienta concreta. Un equipo puede aplicarla con la plataforma que ya tenga. La implementación de referencia se publica aparte, y puede cambiar sin que cambie este libro.
] else if modo-edicion == "comercial" [
  Esta es la *edición comercial*: contiene las cuatro capas. Quien quiera una versión sin código y sin dependencia de herramientas dispone de la edición de principios, que comparte las capas 0 a 2 palabra por palabra.
] else [
  Esta es la *edición de curso*: contiene las cuatro capas, los laboratorios y el material docente de los apéndices. Las capas 0 a 2 son idénticas a las de las otras ediciones del libro; lo que cambia es la capa 3 y el aparato de curso.
]

== Dos tipos de capítulo

*Capítulos de método* (todos los que no son de ingeniería). Siguen este orden: problema, estimando e identificación; teoría, supuestos y garantías; procedimientos, con su pseudocódigo; casos canónicos y validación; #if not es-principios [implementación; ]riesgos, límites y sensibilidad; y ejercicios con notas bibliográficas. Responden "¿cómo se estima esto correctamente?".

*Capítulos de ingeniería* (Caps. 2, 4, 7, 9, 15, 19, 20 y 30 a 33). Siguen la filosofía de _Designing Machine Learning Systems_ (Huyen, 2022): no entregan recetas únicas sino decisiones de diseño con costos y beneficios explícitos. Sus pasos son: el problema de diseño; las opciones y sus compromisos, con al menos dos alternativas reales; la decisión de referencia; #if es-principios [el contrato de la pieza con su prueba de aceptación;] else [el contrato de la pieza y su implementación de referencia;] la aplicación al sistema causal de referencia; las señales de alerta con su checklist operativo; y los ejercicios. Responden "¿cómo se lleva esto a producción de forma responsable?".

Los dos tipos comparten el cuadro resumen del inicio (el *cuadro sinóptico* en los de método y el *cuadro de decisión* en los de ingeniería), el sistema de referencias cruzadas y la numeración de figuras, tablas y algoritmos.

== Partes del libro

#table(
  columns: (auto, 3.2fr, 1fr),
  align: (left, left, center),
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Parte*], [*Contenido*], [*Caps.*]),
  [0], [Introducción: causalidad elemental y anatomía de un sistema de ML en producción.], [1–2],
  [I], [Fundamentos estructurales y de datos: SCM, Jerarquía Causal de Pearl, regularización, criterio de puerta trasera, ingeniería de datos y *features* sin fuga causal.], [3–9],
  [II], [Estimación causal flexible y primer despliegue: ortogonalidad, DML, meta-learners, bosques causales, validación y el primer servicio causal desplegado.], [10–15],
  [III], [Diseños de identificación con ML: Post-Double-Selection, panel e instrumentos, mapa de decisión metodológica.], [16–18],
  [IV], [Registro y operación en producción: fichas causales (*model cards*) e integración continua.], [19–20],
  [V], [Heterogeneidad, políticas y *targeting*: *policy learning* y *uplift modeling*.], [21–22],
  [VI], [Explicación, equidad y decisión estructural: descomposición causal de la equidad, interpretabilidad, decisiones bajo incertidumbre y transportabilidad.], [23–26],
  [VII], [Métodos avanzados: *deep learning* causal, control sintético y *matrix completion*.], [27–28],
  [VIII], [Estructura, monitoreo y frontera: descubrimiento de grafos, monitoreo en producción, aprendizaje continuo, panorama de RL causal, comunicación de resultados y supuestos no observables en operación.], [29–33],
)

== Elementos del libro

Algunos elementos se repiten en todos los capítulos.

- *Cuadro sinóptico o de decisión:* el resumen ejecutivo del capítulo, al comienzo.
- *Algoritmos:* pseudocódigo numerado, independiente del lenguaje.
- *Casos canónicos:* recuadros con un experimento pequeño y sus números, que sirven de prueba de aceptación.
- *Intuición y notas técnicas:* la primera explica una idea sin fórmulas; las segundas desarrollan un detalle matemático opcional o enlazan capítulos.
- *Tablas de riesgos:* riesgos, consecuencias, diagnósticos y mitigaciones.
- *Checklists:* listas de verificación de validación o de señales de alerta operativas.
- *Apéndices:* fundamentos matemáticos (@ap-fundamentos), #if not es-principios [guía de herramientas y entorno (@ap-librerias), ]datos y procesos generadores (@ap-datos-dgp), glosario (@ap-glosario)#solo-curso[, plantilla de proyecto y rúbrica (@ap-proyecto-rubrica)], checklists por método (@ap-checklists), plantilla de ficha causal (*model card*) (@ap-model-card-causal), checklist de arquitectura de despliegue (@ap-checklist-despliegue) y contratos numerados de ingeniería (@ap-contratos)#solo-curso[, más la guía para instructores y equipos de curso (@ap-guia-instructores)].

== Audiencia profesional y camino crítico

El camino crítico para profesionales (★) prioriza: identificación y datos (Caps. 1–4, 6–9), luego DML y validación (10–11, 14), el primer servicio (15), CATE y políticas (12–13, 21–22), el registro y las pruebas de despliegue (19–20), la explicación y la decisión (23–26), y por último el monitoreo, la comunicación y los supuestos no observables (29–33). Los Caps. *16–18* y *27–28* son profundización electiva (◇): útiles, pero no bloquean la puesta en producción de un sistema.

#solo-curso[
  Este libro se lee junto al *#repo-corto*: laboratorios, notebooks de las series A/B, datos de benchmark y proyecto final. El detalle de esa organización, y su correspondencia con cada capítulo, está en el Apéndice #ref(<ap-guia-instructores>, supplement: none).
]

#if modo-edicion == "comercial" [
  El libro se acompaña de un *repositorio complementario* con los cuadernos de trabajo, los datos de benchmark y los listados completos de cada capítulo. No hace falta clonarlo para seguir la teoría: cada capítulo es autosuficiente, y el repositorio sirve para reproducir los resultados y adaptar los ejemplos a un caso propio.
]

*Pregunta de valor (se repite en cada bloque).* Si solo predijéramos el resultado, ¿a quién trataríamos? Si estimamos el efecto, ¿cambia el ranking, el presupuesto o el riesgo?

== Cómo leer un capítulo de ingeniería

1. Cuadro de decisión, con los compromisos principales.
2. Problema de diseño *propio de un sistema causal*.
3. Opciones reales, no una sola receta.
4. #if es-curso [Decisión de referencia del curso.] else [Decisión de referencia del libro.]
5. #if es-principios [Contrato de la pieza y su prueba de aceptación.] else [Contrato de la pieza e implementación de referencia, con el código en un recuadro propio.]
6. Checklist operativo y señales de alerta.
7. Ejercicios y actividades prácticas.
