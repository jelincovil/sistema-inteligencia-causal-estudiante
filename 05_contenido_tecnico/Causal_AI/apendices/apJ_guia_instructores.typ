// Apéndice J: Guía para instructores y equipos de curso
// Exclusivo de la edición de curso: `main.typ` lo incluye solo cuando
// `modo-edicion == "curso"`.
#import "../template/template.typ": *

#chapter[Guía para instructores y equipos de curso]
<ap-guia-instructores>

#theorem-number-reset()

Este apéndice reúne el material de coordinación docente y *no se imprime en la edición comercial del libro*. Quien imparte el curso, o coordina un equipo que lo adopta como capacitación interna, encuentra aquí el mapa entre sesiones, capítulos, laboratorios y entregas, el nivel de madurez declarado del material y la organización práctica del trabajo del estudiante. El contenido metodológico del libro no depende de este apéndice: un lector que estudie por su cuenta puede ignorarlo por completo.

== Mapa sesión → capítulo → lab → entrega (resumen)
<sec-guia-mapa>

La tabla completa está en el sílabo. Resumen del hilo de producto:

#table(
  columns: (auto, 1.4fr, auto, 1.2fr, 1.6fr),
  align: (left, left, left, left, left),
  stroke: 0.5pt + gray.lighten(60%),
  table.header([*Sesiones*], [*Caps. monografía*], [*Lab*], [*Entrega*], [*Valor de negocio*]),
  [S1–S3], [1–3], [L01–L03], [ninguna], [Asociación vs efecto; PCH],
  [S4–S6], [4, 6–7], [L04–L06], [*A1*], [¿Es estimable el programa?],
  [S7–S11], [8–11, 14], [L07–L11], [*A2*], [ATE con IC; sin leakage],
  [S12–S14], [12–13, 15], [L12–L14], [*B1* + A3], [API del efecto; CATE],
  [S15–S16], [repaso], [L15], [*A3* · parcial], [Sistema causal integrado],
  [S17–S18], [19–20], [L17–L18], [*B2*], [Model card local + CI local],
  [S19–S24], [21–26], [L19–L24], [*A4* · *B3*], [Policy + dashboard local],
  [S25–S28], [29–32], [L25–L28], [*B4*], [Monitoreo y comunicación],
  [S29–S32], [Ap. E/G/H], [P1–P4], [*Proyecto*], [Tu caso en producción local],
)

El Cap. 33 no tiene sesión ni laboratorio propio. Se asigna como lectura de cierre antes del proyecto final (S29), y su ejercicio se resuelve dentro del apartado de sensibilidad del proyecto.

El cierre del curso corresponde al proyecto final del Apéndice #ref(<ap-proyecto-rubrica>, supplement: none), que evalúa el sistema completo (identificación, estimación, despliegue, documentación y monitoreo) y no una métrica de predicción aislada.

== Nivel de madurez del material (NMM)
<sec-guia-nmm>

Los materiales de este curso (monografía, Series A/B, laboratorios y diapositivas) se declaran en *NMM 6: validado en entorno controlado*. Esto significa: los notebooks corren de punta a punta sobre los datasets de #code[data_benchmark_causal/], los autograders (#code[grade_a1.py]…#code[grade_b4.py]) pasan de forma reproducible, la suite #code[scripts/audit_repo.sh] verifica la integridad cruzada del monorepo, y el contenido teórico fue auditado contra sus fuentes primarias, con correcciones registradas en #code[CHANGELOG_MEJORA.md]. Lo que aún falta para *NMM 7, validado con usuarios reales*: una cohorte completa de estudiantes que ejercite el material de punta a punta, cuyo *feedback* (encuestas de cierre, incidencias en labs, brechas entre lo que el material asume y lo que hace falta en el aula) retroalimente la próxima edición.

== Práctica del curso: laboratorios, series de notebooks y proyecto
<sec-guia-practica>

El trabajo práctico se organiza en el monorepo del curso (no en un repositorio externo opcional):

- *Labs L01–L28* (#code[05_labs_sesion/]): práctica formativa por sesión (30–50 min).
- *Serie A* (#code[03_notebooks_caso_estudio/]): A1 identificación (Jobs) · A2 DML · A3 CATE · A4 policy.
- *Serie B* (#code[04_produccion_causal/]): B1 FastAPI · B2 ficha causal/CI local · B3 policy local · B4 monitor local.
- *Datos* (#code[data_benchmark_causal/.../datasets/]): CSV + #code[metadata.json] (benchmark documentado; ver callouts "monorepo" en los capítulos de ingeniería).
- *Proyecto* (#code[06_proyecto_final/]): sistema causal local con comparación *predictivo vs causal*.

La *Serie A* aplica la teoría a un caso con pregunta de identificación. La *Serie B* toma el artefacto de A y lo despliega localmente con FastAPI y scripts reproducibles; Docker es opcional y el monitor no exige una interfaz de tablero. El sílabo (#code[01_silabo/silabo_final_vista_previa.pdf]) fija la correspondencia exacta sesión ↔ Cap. N del PDF ↔ lab ↔ entrega.

Los callouts de implementación (*"Implementación en el monorepo del curso"*) aparecen en los capítulos de ingeniería (4, 9, 15, 19, 20 y 30) y conectan cada decisión de diseño con el archivo concreto del monorepo que la implementa. En la edición comercial del libro esos callouts se sustituyen por una nota genérica que remite al repositorio complementario.

== Nota sobre las dos ediciones
<sec-guia-ediciones>

Esta guía y el Apéndice #ref(<ap-proyecto-rubrica>, supplement: none) existen únicamente en la edición de curso. La edición comercial conserva los capítulos 1 a 33 y los apéndices técnicos (A a D y F a I), y omite el aparato docente: el mapa sesión ↔ capítulo ↔ lab, el nivel de madurez del material, la plantilla de proyecto con su rúbrica y esta misma guía. La edición de principios conserva además las mismas capas de teoría, pseudocódigo y casos canónicos, pero omite la capa de implementación y el Apéndice B. El contenido técnico de las capas comunes (teoría, algoritmos, casos canónicos, tablas de riesgos y ejercicios no computacionales) es idéntico en las tres ediciones; solo cambia el envoltorio editorial y, en la de principios, la ausencia de la capa de implementación.
