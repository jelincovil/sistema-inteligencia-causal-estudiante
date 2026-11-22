// Capítulo 10: Lo que la heterogeneidad y la política le exigen al dato.
// Edición de ingeniería de datos (main_de.typ). Casos canónicos: scripts/cap10_heterogeneidad.py (semilla 20260710).
#import "../template/template.typ": *
#import "../template/template_de.typ": *
#import "../template/figuras_de.typ": *

#chapter[Lo que la heterogeneidad y la política le exigen al dato]
<de-cap-heterogeneidad>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Del ATE a quién tratar: el pipeline que entrega un CATE sin validar entrega un ranking sin garantía],
    [*Tesis:*], [Heterogeneidad es una afirmación predictiva sobre tau(x): se valida fuera de muestra como cualquier predictor — con PEHE, calibración y Qini],
    [*Trade-off:*], [Ganancia de política vs costo de tratar: el umbral se elige sobre valor estimado OOS, no sobre ajuste],
    [*Pieza contratada:*], [Extensión C-12 (política): bundle + Qini + valor IPW OOS; criterio Q-04],
    [*Casos canónicos:*], [tau(x)=0,3+1,2·x0: PEHE S 0,035 / T 0,048; política $tau>0$ valor 0,56 vs 0,07 aleatorio (semilla 20260710)],
  )
]

== Este capítulo también es de consumo
<sec-de-10-consumo>

Los Capítulos 12, 14, 21 y 22 de la edición de método desarrollan T-learner, S-learner, X-learner y policy learning con sus teoremas. Aquí no se eligen learners: se traduce qué le piden al dato. Un CATE no es un parámetro causal nuevo que la ingeniería deba "entender": es un predictor de $tau(x)$ entrenado con pseudo-outcomes o con dos regresiones, y el pipeline le exige lo mismo que a cualquier predictor — entrenamiento separado de validación, métrica OOS y declaración de cobertura. La política es un corte $pi(x)=1[hat(tau)(x) > c]$; su valor no se infiere: se estima OOS con ponderación por el inverso de la propensión.

== Exigencia 1: CATE como predictor con verdad en el DGP
<sec-de-10-cate>

*Lo que dice la teoría (edición de método, Cap. 12):* bajo no confusión y soporte, $tau(x)=E[Y(1)-Y(0)|X=x]$ se identifica y puede aprenderse con meta-learners. Su riesgo no es identificable sin verdad — por eso en datos reales nunca se conoce el PEHE. En un DGP sí.

*La exigencia al dato:* el bundle C-12 ya trae partición y propensity OOS. Para CATE se añade: pseudoresultados o dos modelos por brazo entrenados solo en train, y evaluación en test contra $tau$ verdadero del DGP (PEHE, correlación, calibración por quintil). Sin partición OOS, el PEHE es optimista y el ranking es tautológico.

#caso-canonico("S-learner vs T-learner sobre heterogeneidad en x0")[
  DGP con $tau(x)=0,3+1,2 x_0$, $n_"tr"=1 500$, $n_"te"=1 000$, semilla 20260710 del script. Ambos learners son lineales y el DGP es lineal en $x_0$: el problema es deliberadamente fácil para aislar la exigencia de validación.

  #entero[
  #table(
    columns: (2fr, 1.2fr, 1.4fr),
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Learner*], [*PEHE OOS*], [*corr($hat(tau), tau$)*]),
    table.hline(stroke: 0.3pt),
    [S-learner], [0,035], [1,00],
    [T-learner], [0,048], [1,00],
    table.hline(stroke: 0.6pt),
  )
  ]

  $tau$ medio 0,33 y desv. 1,18: la heterogeneidad es real (correlación $x_0$–$tau$ de 1,00 por construcción). Los dos learners aciertan porque la forma es lineal; el punto no es quién gana por 0,013 sino que *sin test OOS con verdad no habría forma de saberlo*: en datos reales ese ranking se decide con Qini, no con PEHE (sección siguiente).
]

#repo-ref[
  Script #code[Causal_AI/scripts/cap10_heterogeneidad.py] (semilla 20260710) reproduce la tabla. Mismos datos alimentan la curva Qini de la sección siguiente.
]

== Exigencia 2: el valor de una política se estima, no se asume
<sec-de-10-politica>

*Lo que dice la teoría (Cap. 21):* el valor de una política $pi$ es $V(pi)=E[Y(pi(X))]$ y se estima por IPW OOS: promedio $hat(V)$ sobre $1[D=pi(X)] Y\/e_pi(X)$. Su Qini es el área entre la curva de ganancia ordenada por $hat(tau)$ y la aleatoria.

*La exigencia al dato:* toda política declara umbral $c$, proporción tratada y valor IPW OOS con IC; y la comparación es contra aleatorio y contra tratar-a-todos, no contra el mejor in-sample. La propensión $hat(e)$ usada es la del bundle C-12 OOS, no reestimada para la política.

#caso-canonico("La política $tau>0$ contra el azar")[
  Sobre el mismo test OOS ($n=1 000$), valor IPW (mayor es mejor):

  #entero[
  #table(
    columns: (2.4fr, 1.1fr, 1.1fr),
    align: (left, center, center),
    stroke: none,
    table.hline(stroke: 0.6pt),
    table.header([*Politica*], [*Trata*], [*Valor IPW*]),
    table.hline(stroke: 0.3pt),
    [Tratar a todos], [100 %], [0,257],
    [Aleatorio 50 %], [50 %], [0,068],
    [S-learner $hat(tau)>0$], [60 %], [0,548],
    [T-learner $hat(tau)>0$], [60 %], [0,562],
    table.hline(stroke: 0.6pt),
  )
  ]

  La política $hat(tau)>0$ supera a tratar-a-todos en 0,29 y al azar en 0,48 con el mismo presupuesto de ~60 %. La curva Qini correspondiente (orden por $hat(tau)$) domina a la diagonal aleatoria en todo el rango — pero esa dominancia se declara solo OOS: in-sample toda política con umbral afinado parece ganadora.
]

#figure(
  diagram(
    node-stroke: 0.6pt + gray.lighten(40%),
    node-fill: light,
    node-outset: 4pt,
    node-corner-radius: 3pt,
    spacing: (6mm, 8mm),
    edge-stroke: 0.8pt + accent,
    node((0, 0), [bundle C-12#linebreak()propensión OOS]),
    node((2.8, 0), [CATE $hat(tau)$]),
    node((2.8, 1.5), [política#linebreak()$hat(tau)>c$]),
    node((5.2, 0.75), [valor IPW OOS#linebreak()+ Qini]),
    edge((0.9, 0), (2.0, 0), "-|>"),
    edge((2.8, 0.3), (2.8, 1.2), "-|>"),
    edge((3.6, 1.3), (4.7, 0.9), "-|>"),
    edge((3.6, 0.2), (4.7, 0.6), "-|>"),
  ),
  caption: [Heterogeneidad y política como extensión C-12: del bundle con propensión OOS al CATE y su valor IPW OOS. Sin OOS el ranking es tautológico.],
) <de-fig-cate-politica>

== Contrato C-12 extensión: heterogeneidad y valor de política
<sec-de-10-contrato>

#contrato(
  "C-12",
  "Exigencias del estimador — heterogeneidad y política",
  operaciones: [
    _evaluar_cate_: entrena S/T-learner solo en train y reporta PEHE/corr OOS contra tau del DGP; _valorar_politica_: estima V(pi) IPW OOS y curva Qini/Uplift OOS; _declarar_umbral_: fija c y proporción tratada antes de mirar valor.
  ],
  entrada: [
    Bundle C-12 (partición, propensity OOS, semilla) + learners declarados + umbral candidato.
  ],
  salida: [
    Tabla PEHE/corr OOS por learner + valor IPW OOS por política con IC + Qini OOS + declaración de proporción tratada.
  ],
  invariantes: [
    (1) Todo CATE se evalúa OOS contra verdad del DGP o, sin verdad, con Qini IPW OOS — nunca in-sample. (2) Valor IPW usa propensity del bundle, no reestimado. (3) Umbral y % tratado se declaran antes de mirar valor.
  ],
  fallos: [
    Reportar PEHE train como generalización. Elegir c maximizando valor in-sample. Usar propensity reestimado para inflar V(pi).
  ],
  aceptacion: [
    (a) DGP tau de x0 (semilla 20260710) PEHE menor a 0.05 y ranking correcto. (b) Politica con umbral 0 supera aleatorio OOS.
  ],
)

== Ejercicios y notas bibliográficas

=== Ejercicios conceptuales

+ Con el DGP del caso canónico, un learner con PEHE 0,035 parece excelente. ¿Por qué en datos reales ese número no existe y qué lo sustituye? _Pista:_ Qini IPW OOS.

+ Si eliges $c$ maximizando valor in-sample y luego reportas ese valor, ¿qué invariante violas y cuál es el sesgo? _Pista:_ C-12 ext (3).

+ Dos políticas tratan 60 % pero una ordena mejor por $hat(tau)$. ¿Cómo lo ves en la Qini sin mirar PEHE? _Pista:_ área entre curva y diagonal.

=== Notas bibliográficas

Meta-learners y Qini: @kunzel2019metalearners y @athey2016recursive (Causal Forest). Valor IPW de política: @athey2021policy. La lectura como extensión C-12 es propia: sin propensity OOS no hay valor honesto.

#verdad-datos[
  Que todo CATE traiga su evaluación OOS — PEHE contra verdad sintética o Qini IPW OOS — y toda política su valor IPW OOS con % tratado declarado antes. Se comprueba con el script semilla 20260710: sin OOS el ranking colapsa; con OOS la política $tau>0$ domina al azar en 0,48. Lo que no certifica: que el orden sea causalmente correcto en datos reales — eso exige el diagnóstico del capítulo siguiente.
]
