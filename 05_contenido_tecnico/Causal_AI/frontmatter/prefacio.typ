// Prefacio
// Una sola fuente para las tres ediciones (curso, comercial, principios).
// Las tres tesis conceptuales son comunes; lo que cambia entre ediciones es el párrafo sobre material
// complementario. El aparato docente (labs, sílabo, tabla sesión ↔ capítulo) vive en #solo-curso / Apéndice J.
#import "../template/template.typ": *

#chapter[Prefacio]
<sec-prefacio>

Este libro está pensado, en primer lugar, para *profesionales*: analistas de datos, ingenieros de ML, product analytics, riesgo, operaciones y perfiles afines, que ya usan modelos predictivos y deben *decidir o priorizar intervenciones*. También sirve a posgrado aplicado y a economistas de último año con base cuantitativa. Está escrito para leerse y consultarse de forma autónoma. No es un tratado para investigadores básicos: el recorrido prioriza los *casos de estudio*, la *estimación de efectos accionables* y la *puesta en producción*.

Se asume familiaridad con regresión, evaluación de modelos y, de forma deseable, nociones de evaluación de impacto (resultados potenciales, confusión). Quien ya conozca la causalidad aplicada (experimentos, emparejamiento y ponderación, variables instrumentales, diferencias en diferencias) avanzará más rápido; quien no, puede apoyarse en los Caps. 1 a 3. El libro *extiende* ese bagaje al régimen de alta dimensionalidad y de heterogeneidad de efectos, y sobre todo a la ingeniería de sistemas que hace falta para *operar* esos métodos.

El eje conceptual combina tres tesis.

*Primera: el aprendizaje automático no identifica causalidad por sí solo.* Los supuestos de identificación siguen siendo del dominio y deben justificarse. Lo que el ML aporta es flexibilidad para estimar los componentes auxiliares (_nuisance_: propensión, modelos de resultado) sin perder inferencia válida, gracias a la *ortogonalización de Neyman*, el *cross-fitting* y la *honestidad* de los árboles.

*Segunda: un estimador causal validado no es todavía un sistema.* Documentarlo, servirlo, versionarlo y monitorearlo es trabajo de ingeniería (Huyen, 2022), y en un sistema causal tiene una dificultad adicional: los supuestos que lo justifican no se ven en los datos y pueden dejar de valer sin que ninguna métrica lo anuncie. Por eso gran parte de la ingeniería de este libro consiste en dejar por escrito esos supuestos y en vigilar lo que sí se puede vigilar.

*Tercera, la que vertebra el libro: priorizar por puntaje predictivo no es lo mismo que priorizar por efecto.* Un buen predictor responde "quién tiene el peor resultado". Un sistema causal responde "a quién *cambia* el resultado si actuamos". Esa diferencia reordena presupuestos, _targeting_ y riesgo reputacional, y es la que justifica el costo de todo lo demás. Cada bloque del libro cierra con la misma pregunta: *si solo predijéramos, ¿a quién trataríamos? Con el efecto, ¿cambia la decisión?*

== Cómo está organizado

El libro se escribe en cuatro capas: teoría, pseudocódigo, principios con casos canónicos, e implementación. Las tres primeras duran, y la cuarta se renueva con las herramientas. La sección _Cómo usar este libro_ explica las capas y los dos tipos de capítulo, los de método y los de ingeniería. Los capítulos de método responden "cómo se estima esto correctamente", y los de ingeniería, "cómo se lleva esto a producción de forma responsable". Los Caps. 17, 27 y 28 (panel con DML y variables instrumentales, _deep learning_ causal y _matrix completion_) son *profundización electiva*: no hacen falta para cubrir el núcleo, aunque amplían de forma considerable el repertorio de métodos.

*Convenciones.* La notación sigue el estándar de la literatura: $Y(d)$ denota el resultado potencial bajo el tratamiento $d in {0, 1}$, $D$ es la asignación observada y $X$ son las covariables previas al tratamiento. El estimando central es el CATE $tau(x) = E[Y(1) - Y(0) | X = x]$, cuyo promedio $theta = E[tau(X)]$ es el ATE. Los algoritmos se presentan en pseudocódigo de complejidad similar a la de los artículos originales. En el texto corrido los decimales se escriben con coma, y dentro de las fórmulas con punto. La tabla completa de notación está en la sección siguiente.

#if es-principios [
  *Material complementario.* Este libro no depende de ninguna herramienta concreta. Los métodos se escriben en pseudocódigo, y cada pieza de ingeniería se describe como un contrato numerado (C-01, C-02, ...) con su prueba de aceptación. Un material complementario, publicado aparte, implementa esos contratos con herramientas abiertas y puede cambiar sin que cambie el libro. La separación es deliberada: las ideas duran más que las librerías.
]

#solo-curso[
  *Código, datos y material del curso.* La implementación de referencia (laboratorios L01 a L28, notebooks de las series A y B, datos de benchmark y autograders) vive junto a este libro en el repositorio del curso. La tabla sesión ↔ capítulo ↔ laboratorio ↔ entrega y el posicionamiento profesional se detallan en el sílabo y se reproducen en el Apéndice #ref(<ap-guia-instructores>, supplement: none). Cuando un listado de código del libro use un diseño idealizado (por ejemplo, Parquet con #code[CausalSchema]), el monorepo documenta el *equivalente operativo* (CSV con #code[metadata.json] y #code[lib.data_io]).
]

#if modo-edicion == "comercial" [
  *Código y datos.* La implementación de referencia que acompaña al libro, con cuadernos de trabajo, datos de benchmark, configuración de despliegue y listados completos, está disponible en el repositorio complementario. Cuando un listado de código del libro use un diseño idealizado, por ejemplo, Parquet con #code[CausalSchema], el repositorio documenta el *equivalente operativo* (CSV con #code[metadata.json] y #code[lib.data_io]).
]

*Agradecimientos.* Esta obra se apoya en tres fuentes de ingeniería y teoría: _Designing Machine Learning Systems_ (Huyen), _Causal Artificial Intelligence_ (Bareinboim) y _Machine Learning in Production_ (CMU)#if not es-principios [, y en el ecosistema de benchmarks que acompaña al libro (#code[data_benchmark_causal])]. Agradecemos a los autores de los trabajos metodológicos citados a lo largo del texto.
