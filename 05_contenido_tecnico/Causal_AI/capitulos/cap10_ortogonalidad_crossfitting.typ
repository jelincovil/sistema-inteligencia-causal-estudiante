// Capítulo 10: Ortogonalidad de Neyman, cross-fitting e influence functions. Abre la Parte II.
// Edición en capas: la teoría (L0), los procedimientos (L1) y los casos canónicos con cifras verificadas (L2)
// son lo que dura; los listados (L3) van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Ortogonalidad de Neyman, cross-fitting e influence functions]
<cap-ortogonalidad>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Estimar un efecto con _learners_ de ML sin que su sesgo contamine la inferencia],
    [*Estimando:*], [$theta_0$ en el modelo parcialmente lineal (PLR)],
    [*Identificación:*], [No confusión condicional y ortogonalidad de Neyman del score],
    [*Método:*], [Score ortogonal y _cross-fitting_],
    [*Nuisance:*], [$l_0(X) = E[Y | X]$ y $m_0(X) = E[D | X]$, o bien $g_0(X)$ y $m_0(X)$],
    [*Garantía:*], [$sqrt(n) (hat(theta) - theta_0) arrow.r.double N(0, sigma^2)$ si el error de los _nuisance_ cumple $sqrt(n) a_n^2 -> 0$],
    ..if not es-principios {([*Librerías:*], [#code[scikit-learn] (implementación manual del score); #code[DoubleML] y #code[econml] en el @cap-dml])},
    [*Validación:*], [Perturbación de los _nuisance_ y Monte Carlo de sesgo y cobertura con y sin _cross-fitting_],
  )
]

#notatecnica[
Con el criterio de puerta trasera (@cap-intervencion-contrafactual) y la auditoría de _features_ (@cap-features-sin-fuga) resueltos, la Parte I dejó pendiente una pregunta puramente estadística: ¿cómo combinar _learners_ de ML flexibles para estimar un efecto causal sin que el sesgo de esos _learners_ contamine la inferencia? Este capítulo, que abre la Parte II, responde esa pregunta.
]

== Problema causal, estimando e identificación
<sec-cap10_problema>

Una consultora evalúa el efecto de una reforma tributaria sobre la inversión empresarial con un panel de 5~000 firmas y 200 covariables (financieras, sectoriales, de propiedad y de gobernanza). La asignación de la reforma no fue aleatoria: las firmas grandes y rentables fueron más propensas a ser tratadas. El estimador ideal (i) usa ML para modelar con flexibilidad la asignación al tratamiento, (ii) usa ML para modelar la relación entre covariables e inversión, y (iii) combina ambas estimaciones en un estimador del efecto con inferencia válida.

El problema es que enchufar el ML en un estimador construido para funciones conocidas no da, en general, inferencia válida. El estimador por ajuste de regresión $hat(theta) = n^(-1) sum_i [hat(mu)_1(X_i) - hat(mu)_0(X_i)]$, por ejemplo, hereda directamente el error de estimación de $hat(mu)_d$, y ese error, producto de regularizar un modelo de alta dimensión, no desaparece con la rapidez que exige la inferencia. La salida no es abandonar el ML sino cambiar la función de momento con la que se estima el efecto, de modo que los errores de los _nuisance_ solo entren en segundo orden. Eso es la *ortogonalidad de Neyman*. Combinada con _cross-fitting_, permite estimadores $sqrt(n)$-consistentes y asintóticamente normales aun cuando los _nuisance_ se estimen con ML a tasas más lentas que $sqrt(n)$.

== Teoría, supuestos y garantías
<sec-cap10_teoria>

=== El problema del doble sesgo
<sec-cap10_doble_sesgo>

Considérese el modelo parcialmente lineal (PLR, _partial linear model_):
$
Y = D theta_0 + g_0(X) + epsilon, quad D = m_0(X) + v,
$ <eq-plr>
donde $Y$ es el resultado, $D$ el tratamiento, $X$ las covariables, $g_0$ la regresión del resultado y $m_0$ la función de tratamiento, que no tiene por qué ser una probabilidad. Se supone $E[epsilon | D, X] = 0$ y $E[v | X] = 0$. Para $D$ binario, $m_0(x) = e_0(x) = P(D = 1 | X = x)$. Se definen además $l_0(X) = E[Y | X] = g_0(X) + theta_0 m_0(X)$ y los residuos de Robinson $v = D - m_0(X)$ y $u = Y - l_0(X)$, que cumplen $u = theta_0 v + epsilon$.

El parámetro de interés es $theta_0$. La pregunta es cómo estimarlo cuando $g_0$ y $m_0$ son funciones desconocidas de alta dimensión.

*Primer enfoque ingenuo: ML para $g_0$ y OLS para $theta_0$.* Si $g_0$ fuera conocida, $theta_0$ se estimaría con la regresión de $Y - g_0(X)$ sobre $D$. Como se estima, se sustituye por $hat(g)$ obtenida con ML:
$
tilde(theta) = (sum_i D_i^2)^(-1) sum_i D_i (Y_i - hat(g)(X_i)).
$
El error de $hat(g)$ es $O_p (a_n)$ y, con ML en alta dimensión, $a_n >> n^(-1/2)$. Ese error de primer orden contamina a $tilde(theta)$:
$
tilde(theta) - theta_0 = underbrace((sum D_i^2)^(-1) sum D_i epsilon_i, "ruido" O_p (n^(-1/2))) + underbrace((sum D_i^2)^(-1) sum D_i (g_0(X_i) - hat(g)(X_i)), "sesgo" O_p (a_n)).
$
Como $a_n >> n^(-1/2)$, el sesgo domina la varianza asintótica y la inferencia normal queda invalidada. Para fijar ideas sobre $a_n$: con una función de dos derivadas en una sola dimensión, la tasa óptima de un estimador no paramétrico es del orden de $n^(-2/5)$; con muchas covariables y sin estructura (esparsidad, aditividad), la tasa óptima es aún más lenta.

*Segundo enfoque ingenuo: ML para $m_0$ y regresión sobre el residuo del tratamiento.* Con $hat(v)_i = D_i - hat(m)(X_i)$ y $tilde(theta)' = (sum hat(v)_i^2)^(-1) sum hat(v)_i Y_i$, el mismo problema aparece: el error $hat(m) - m_0$ entra en primer orden, porque $Y$ contiene a $g_0(X)$ y el residuo $hat(v)$ conserva la parte de $m_0$ que el modelo no captó.

=== Ortogonalidad de Neyman
<sec-cap10_ortogonalidad_neyman>

La solución es construir un score $psi(W, theta, eta)$, con $W = (Y, D, X)$ y $eta$ los parámetros _nuisance_, que sea insensible en primer orden a errores en $eta$.

#definition(name: [Score ortogonal de Neyman])[
  Un score $psi(W, theta, eta)$ con $E[psi(W, theta_0, eta_0)] = 0$ es _ortogonal de Neyman_ respecto de $eta$ en $(theta_0, eta_0)$ si la derivada de Gateaux de la esperanza respecto de $eta$ se anula:
  $
  partial_eta E[psi(W, theta_0, eta)] |_(eta = eta_0) [r] = 0 quad "para toda dirección admisible " r.
  $ <eq-neyman-orth>
] <def-neyman-orth>

Con un desarrollo de Taylor de $E[psi(W, theta_0, hat(eta))]$ alrededor de $eta_0$, el término de primer orden desaparece y queda un resto de segundo orden. Su forma depende del score: puede contener productos entre errores de distintos _nuisance_ y términos cuadráticos de uno de ellos. Eso permite que $hat(eta)$ converja más despacio que $n^(-1/2)$ sin que su error contamine a $hat(theta)$ en el orden que importa. La idea es de #cite(<neyman1959>, form: "prose"), que la usó en su test $C(alpha)$ para parámetros de estorbo.

=== Construcción del score ortogonal para PLR
<sec-cap10_score_ortogonal>

Del modelo se obtiene $Y - g_0(X) - theta_0 D = epsilon$ y $D - m_0(X) = v$, con $E[epsilon | D, X] = 0$ y $E[v | X] = 0$. Multiplicar la primera igualdad por $v$ y tomar esperanza da $E[(D - m_0(X))(Y - g_0(X) - theta_0 D)] = E[v epsilon] = 0$, y de ahí se despeja
$
theta_0 = frac(E[(D - m_0(X))(Y - g_0(X))], E[(D - m_0(X)) D]).
$ <eq-plr-score>
Hay dos parametrizaciones de los _nuisance_ que conviene no mezclar, y ambas dan un score ortogonal:

+ *Forma estructural*, con $eta = (g, m)$ y $g_0(X) = E[Y - theta_0 D | X]$: $psi = (D - m(X))(Y - g(X) - theta D)$.

+ *Forma de Robinson*, con $eta = (l, m)$ y $l_0(X) = E[Y | X]$, que es la que usa el DML estándar:
  $
  psi(W, theta, eta) = (D - m(X)) {Y - l(X) - theta (D - m(X))}.
  $ <eq-plr-orth-score>

Mezclar las dos, por ejemplo usar $(D - m)(Y - l - theta D)$ cuando $l = E[Y | X]$, rompe la ortogonalidad respecto de $m$. No debe confundirse tampoco $g_0$ con $mu_d(x) = E[Y | X = x, D = d]$ de los @cap-prediccion-causalidad, @cap-meta-learners y @cap-causal-forests: bajo el PLR, $mu_d(x) = g_0(x) + theta_0 d$, de modo que $mu_1 - mu_0 = theta_0$.

#cite(<robinson1988>, form: "prose") introdujo la transformación de la segunda forma, que consiste en proyectar $Y$ y $D$ sobre $X$ y regresar residuo contra residuo, para el PLR con $g_0$ estimada de forma no paramétrica, y demostró que el estimador resultante es $sqrt(n)$-consistente pese a que las regresiones auxiliares convergen más despacio. Es el antecedente directo del score PLR de DML. Lo que #cite(<chernozhukov2018double>, form: "prose") añaden es el *cross-fitting*, que permite reemplazar los estimadores de núcleo de Robinson por _learners_ de ML arbitrarios sin pagar el sesgo de sobreajuste de estimar y evaluar en la misma muestra. El mismo score reaparece en el @cap-meta-learners como la pérdida del R-learner; la "R" es por Robinson.

#theorem(name: [Ortogonalidad del score PLR])[
  Los dos scores anteriores son ortogonales de Neyman respecto de su $eta$ en $(theta_0, eta_0)$.
] <thm-plr-orth>

#proof[
  Para la forma estructural, la derivada de Gateaux en la dirección $(r_g, r_m)$ es
  $
  partial_eta E[psi] [r_g, r_m] = partial_alpha E[(D - (m_0 + alpha r_m))(Y - (g_0 + alpha r_g) - theta_0 D)] |_(alpha=0) = -E[r_m epsilon] - E[v r_g] = 0,
  $
  porque $E[epsilon | D, X] = 0$ implica $E[r_m (X) epsilon] = 0$ y $E[v | X] = 0$ implica $E[v r_g (X)] = 0$. Para la forma de Robinson, la derivada en la dirección $(r_l, r_m)$ es $-E[v r_l] - E[r_m (u - theta_0 v)] + theta_0 E[v r_m]$, que se anula por el mismo motivo, ya que $u - theta_0 v = epsilon$.
]

Un contraste que aclara qué pide la ortogonalidad: el score no ortogonal $D (Y - g(X) - theta D)$ del primer enfoque ingenuo tiene derivada $-E[D r_g (X)]$, que en general no es cero porque $D$ está correlacionado con $X$. El primer caso canónico de más abajo mide esa diferencia.

#notatecnica[
  *Forma canónica del score ortogonal.* Todos los scores que el libro deriva en capítulos distintos son instancias de un único objeto: un funcional $psi(W, theta, eta)$ con $E[psi(W, theta_0, eta_0)] = 0$ y derivada de Gateaux nula respecto de $eta$ en $(theta_0, eta_0)$ (@sec-cap10_ortogonalidad_neyman). La tabla reúne las instancias.
]

#figure(
  caption: [Instancias del score ortogonal canónico a lo largo del libro.],
  table(
    columns: (1.5fr, 2.6fr, 1fr),
    align: (left, left, left),
    stroke: 0.5pt + gray.lighten(60%),
    table.hline(stroke: 0.8pt),
    table.header([*Estimando*], [*$psi(W, theta, eta)$*], [*$eta$*]),
    table.hline(stroke: 0.4pt),
    [PLR, efecto constante (@cap-dml)], [$(D - m(X))(Y - l(X) - theta (D - m(X)))$], [$(l, m)$],
    [ATE bajo IRM (@cap-dml)], [$mu(1,X) - mu(0,X) + (D(Y - mu(1,X))) / e(X) - ((1-D)(Y - mu(0,X))) / (1 - e(X)) - theta$], [$(mu, e)$],
    [CATE, DR-learner (@cap-meta-learners)], [$Gamma_i$ = score IRM antes de promediar], [$(mu, e)$],
    [CATE, R-learner (@cap-meta-learners)], [Pérdida $[(Y - m_(Y)(X)) - tau(X)(D - e(X))]^2$, cuyo gradiente es ortogonal], [$(m_Y, e)$],
    [PLIV (@cap-panel-dmliv)], [$(Z - r(X))(Y - g(X) - theta D)$], [$(g, r, m)$],
    [Valor de una política (@cap-policy-learning)], [$mu_(pi(X))(X) + (bold(1){D = pi(X)}) / (e_(pi(X))(X)) dot.op (Y - mu_(pi(X))(X)) - V(pi)$], [$(mu, e)$],
    table.hline(stroke: 0.8pt),
  )
) <tab-score-canonico>

*Consecuencia operativa.* Todas las filas reutilizan la idea de separar el ajuste de los _nuisance_ de la evaluación del score mediante _cross-fitting_, pero no heredan una condición de tasa ni un error estándar idénticos. Para funcionales escalares regulares, como un ATE o el valor de una política fija, la inferencia suele apoyarse en una función de influencia y una condición de resto específica del score. Para una función CATE no paramétrica, las tasas y la cobertura son locales y dependen además de la regularidad de $tau(x)$, la dimensión y el método de segunda etapa. Cuando el libro presenta un estimador nuevo (@cap-dml, @cap-meta-learners, @cap-panel-dmliv, @cap-policy-learning), hay que declarar por separado el estimando, el score, el resto de segundo orden y el objeto cubierto por su intervalo. Esa es la perspectiva de funcionales de Riesz que el @cap-deep-causal retoma.

=== Teorema central de DML
<sec-cap10_teorema_dml>

El teorema central de @chernozhukov2018double combina ortogonalidad con _cross-fitting_.

#theorem(name: [DML, versión simplificada])[
  Sea $hat(eta)$ un estimador de $eta_0$ obtenido en una muestra auxiliar independiente de la muestra principal, con $norm(hat(eta) - eta_0)_(L^2) = O_p (a_n)$ y $sqrt(n) a_n^2 -> 0$. Sea $hat(theta)$ la solución de
  $
  (1 / n) sum_(i=1)^n psi(W_i, hat(theta), hat(eta)) = 0.
  $
  Entonces, bajo regularidad estándar y la ortogonalidad @eq-neyman-orth,
  $
  sqrt(n) (hat(theta) - theta_0) arrow.r^(d) N(0, sigma^2), quad sigma^2 = frac(E[psi(W, theta_0, eta_0)^2], (E[partial_theta psi])^2).
  $
] <thm-dml-main>

#proof(kind: "sketch")[
  La ortogonalidad deja el resto de segundo orden $O_p (a_n^2)$, que es $o_p (n^(-1/2))$ por la condición de tasa. Con la muestra auxiliar independiente, el término empírico $(P_n - P)(psi(hat(eta)) - psi(eta_0))$ tiene media cero y varianza $o(n^(-1))$ condicional en $hat(eta)$. Queda el término lineal $n^(-1) sum_i psi(W_i, theta_0, eta_0)$, al que se aplica el teorema central del límite. La prueba formal está en @chernozhukov2018double, Sección 3. $qed$
]

#intuicion[
  La condición $sqrt(n) a_n^2 -> 0$ resume el caso simétrico del teorema. Con $a_n = n^(-2/5)$, la tasa óptima con dos derivadas en una dimensión, $sqrt(n) a_n^2 = n^(-3/10) -> 0$. Para LASSO bajo esparsidad, $a_n = sqrt(s log p \/ n)$ y $sqrt(n) a_n^2 = s log p \/ sqrt(n) -> 0$ si $s log p = o(sqrt(n))$. La virtud de la ortogonalidad es que *no hace falta* estimar $eta$ a tasa $sqrt(n)$.

  En la forma de Robinson del PLR conviene conservar los dos errores por separado. Si $a_n = norm(hat(m)-m_0)_(L^2)$ y $b_n = norm(hat(l)-l_0)_(L^2)$, la esperanza del score en $theta_0$ contiene $E[(hat(m)-m_0)(hat(l)-l_0)] - theta_0 E[(hat(m)-m_0)^2]$. Por tanto, una condición suficiente es $a_n(a_n+b_n)=o(n^(-1/2))$, no solo $a_n b_n=o(n^(-1/2))$. Un $hat(l)$ muy preciso no compensa por sí solo un error cuadrático demasiado grande de $hat(m)$.
]

#notatecnica[
  *Condiciones completas y variantes DML1 y DML2.* El teorema anterior está simplificado. Las condiciones completas (@chernozhukov2018double, Teorema 3.1) son: (C1) ortogonalidad de Neyman del score; (C2) identificabilidad local, $abs(E[partial_theta psi(W, theta, eta_0)]) >= c > 0$ en una vecindad de $theta_0$; (C3) tasas de los _nuisance_, $norm(hat(eta) - eta_0)^2 = o_p (n^(-1/2))$; y (C4) momentos acotados, $E[psi^2] < infinity$ y $E[abs(partial_theta psi)^2]$ acotado en una vecindad de $theta_0$.

  Hay dos formas de agregar los pliegues, y el libro las distingue. *DML1* resuelve el score en cada pliegue $k$, obtiene $hat(theta)_k$ y promedia los $K$ estimadores. *DML2* resuelve una sola ecuación de momento con todas las observaciones, usando para cada una el _nuisance_ de su pliegue. La recomendación de @chernozhukov2018double es DML2, por su mejor comportamiento en muestras finitas. Para reducir la variabilidad que introduce la partición aleatoria se recomienda además el _cross-fitting_ repetido: repetir la partición varias veces y agregar las estimaciones, con la mediana como agregador habitual.
]

#notatecnica[
  La expansión por función de influencia permite escribir $hat(theta) - theta_0 = n^(-1) sum_i psi(W_i, theta_0, eta_0) \/ J_0 + o_p (n^(-1/2))$, con $J_0 = -E[partial_theta psi]$. De ahí sale el error estándar: $hat(sigma)^2$ es la varianza muestral de la función de influencia estimada.
]

== Procedimientos
<sec-cap10_algoritmo>

=== El rol del cross-fitting
<sec-cap10_crossfitting>

El teorema asume que $hat(eta)$ se estima en una muestra independiente de la principal. Sin _cross-fitting_ habría que pedir, en cambio, que $hat(eta)$ pertenezca a una clase de funciones de complejidad limitada (una condición de tipo Donsker), que los _learners_ de ML flexibles y de alta dimensión no cumplen en general; de ahí el riesgo de sobreajuste al estimar y evaluar sobre los mismos datos. La solución que no desperdicia datos es dividir la muestra en $K$ pliegues; para cada pliegue $k$, estimar $hat(eta)_(-k)$ con los otros $K - 1$ y evaluar el score en el pliegue $k$. Así $hat(eta)$ es independiente de los datos donde se evalúa, y todas las observaciones se usan en ambos papeles.

#algorithm("Double Machine Learning con cross-fitting (K pliegues)")[
  #kwin[Entrada][Datos ${(Y_i, D_i, X_i)}_(i=1)^n$, score ortogonal $psi$, número de pliegues $K$, _learners_ para los _nuisance_.]
  #kwout[Salida][Estimador $hat(theta)$ y error estándar.]
  Dividir ${1, ..., n}$ en $K$ pliegues $I_1, ..., I_K$. \
  #for-loop(`k`, 1, `K`)[
    Entrenar $hat(eta)_(-k)$ en ${i : i ∉ I_k}$. \
    Predecir los _nuisance_ en $X_i$ para $i in I_k$.
  ]
  Resolver $hat(theta)$ tal que $(1/n) sum_i psi(W_i, hat(theta), hat(eta)_(-k(i))) = 0$. \
  Estimar $hat(sigma)^2 = hat(E)[psi^2] \/ hat(E)[partial_theta psi]^2$. \
  #return-stmt[$(hat(theta), hat(sigma) \/ sqrt(n))$]
] <alg-dml-cf>

Para el PLR con el score de Robinson el algoritmo se reduce a regresiones de residuos.

#algorithm("DML manual con cross-fitting para PLR")[
  #kwin[Entrada][Datos ${(Y_i, D_i, X_i)}_(i=1)^n$, número de pliegues $K$, _learners_ para $hat(l)$ y $hat(m)$.]
  #kwout[Salida][Estimador $hat(theta)$ y error estándar.]
  Dividir ${1, ..., n}$ en $K$ pliegues $I_1, ..., I_K$. \
  #for-loop(`k`, 1, `K`)[
    Entrenar $hat(l)_(-k)$ para $E[Y | X]$ y $hat(m)_(-k)$ para $E[D | X]$ en ${i : i ∉ I_k}$. \
    Predecir $hat(l)_(-k)(X_i)$ y $hat(m)_(-k)(X_i)$ para $i in I_k$.
  ]
  Residuos: $hat(v)_i = D_i - hat(m)_(-k(i))(X_i)$ y $hat(u)_i = Y_i - hat(l)_(-k(i))(X_i)$. \
  Estimar $hat(theta) = (sum_i hat(v)_i hat(u)_i) \/ (sum_i hat(v)_i^2)$. \
  Calcular $hat(sigma)^2 = (1/n) sum_i [hat(v)_i (hat(u)_i - hat(theta) hat(v)_i) \/ ((1/n) sum_j hat(v)_j^2)]^2$. \
  #return-stmt[$(hat(theta), hat(sigma) \/ sqrt(n))$]
] <alg-dml-manual-cf>

#intuicion[
  *Funciones de influencia.* Una función de influencia dice cuánto cambiaría el estimado al agregar o quitar una observación, y sirve para calcular errores estándar sin _bootstrap_. Para el PLR, $psi_i = v_i (u_i - theta v_i)$ con $v_i = D_i - hat(m)(X_i)$ y $u_i = Y_i - hat(l)(X_i)$, y el error estándar es $sqrt(n^(-1) sum_i psi_i^2)$ dividido por la media de $hat(v)^2$ y por $sqrt(n)$. La ortogonalidad es lo que permite leerlo así: los errores de $hat(m)$ y $hat(l)$ solo entran en segundo orden, de modo que el ML puede ser imperfecto sin romper la inferencia sobre $theta$.
]

== Casos canónicos y validación
<sec-cap10_caso>

Los casos usan el proceso del experimento de #cite(<chernozhukov2018double>, form: "prose"): $theta_0 = 0.5$, $n = 500$ y 20 covariables normales; $m_0 = X_1 + 0.25 thin e(X_3)$ y $g_0 = e(X_1) + 0.25 X_3$, con $e(z) = exp(z) \/ (1 + exp(z))$; $D = m_0 + N(0, 1)$ e $Y = theta_0 D + g_0 + N(0, 1)$.#capa-impl[ El script es #code[herramientas/verificaciones/verif_cap10.py].]

#caso-canonico("Primer orden frente a segundo orden")[
  Se entregan al estimador los _nuisance_ verdaderos más una perturbación $delta h(X)$ con $h = m_0$, con muestras de 200~000 observaciones. El score no ortogonal $D (Y - g - theta D)$ tiene un sesgo que cambia en proporción a $delta$: −0,203 con $delta = 0.4$, −0,102 con 0,2, −0,051 con 0,1 y −0,026 con 0,05, lo que coincide con el valor teórico $-delta E[D h] \/ E[D^2] approx -0.50 delta$. El score ortogonal tiene un sesgo que cambia en proporción a $delta^2$: +0,069, +0,018, +0,004 y 0,000, en línea con $delta^2 (1 - theta) E[h^2] \/ (1 + delta^2 E[h^2])$. Al reducir a la mitad el error de los _nuisance_, el sesgo ingenuo se reduce a la mitad y el ortogonal a la cuarta parte.
]

#caso-canonico("El sobreajuste y el cross-fitting")[
  Con el mismo proceso se comparan, en 40 a 60 muestras independientes, la regresión lineal con las 20 covariables, DML sin _cross-fitting_ (los _nuisance_ se ajustan y se evalúan en la misma muestra) y DML con cinco pliegues. Con bosques aleatorios de 100 árboles y hojas de al menos cinco observaciones, el sesgo es −0,017 sin _cross-fitting_ y −0,006 con él, y la cobertura del intervalo al 95 % es 96,7 % y 98,3 %. Con hojas de una observación, el sesgo pasa a −0,019 y −0,008, y la cobertura a 92,5 % y 95,0 %. Con _boosting_ profundo (300 iteraciones, profundidad 4), que sobreajusta mucho más, el efecto es grande: sin _cross-fitting_ el sesgo es −0,115, el error estándar declarado (0,058) es la mitad de la dispersión real (0,096) y la cobertura cae a 55 %; con _cross-fitting_ el sesgo baja a −0,040 y la cobertura sube a 87,5 %. El _cross-fitting_ mejora siempre y su ganancia crece con el sobreajuste del aprendiz, pero no lo corrige todo: un aprendiz que predice mal sigue dejando sesgo de segundo orden. La regresión lineal queda sin sesgo (−0,002) porque en este proceso la parte no lineal de los _nuisance_ es suave. El ejemplo no dice que DML supere a la regresión lineal aquí, sino que, con ML flexible, el _cross-fitting_ y un aprendiz razonable son parte del método.
]

El retorno al programa de capacitación del NSW es el caso real de referencia del curso: el contraste experimental simple de medias entre tratados y controles da cerca de 1~800 USD en 1978 (#cite(<dehejia1999causal>, form: "prose") reportan 1~794 para la muestra experimental), con un error estándar de unos 650 a 700 USD. Un estimador DML con covariables debe quedar cerca de ese valor con un intervalo comparable. No prueba la identificación, pero es una comprobación de plausibilidad con un resultado experimental conocido.#capa-impl[ La comprobación con datos reales es un ejercicio computacional de este capítulo.]

#capa-impl[
== Implementación en Python
<sec-cap10_implementacion>

#figure(
  kind: raw,
  caption: [Implementación manual de DML para PLR con cross-fitting.],
  ```python
import numpy as np
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import KFold


def dml_plr_manual(Y, D, X, n_folds=5, learner=None, seed=0):
    """DML para el modelo parcialmente lineal con cross-fitting K-fold y score de Robinson.

    Nuisance: l(X) = E[Y|X] y m(X) = E[D|X]. Residuos v = D - m(X), u = Y - l(X).
    theta = sum(v u) / sum(v^2); funcion de influencia psi = v (u - theta v) / E[v^2].
    """
    if learner is None:
        learner = lambda: RandomForestRegressor(n_estimators=100, min_samples_leaf=5,
                                                 random_state=seed, n_jobs=-1)
    n = len(Y)
    l_hat, m_hat = np.zeros(n), np.zeros(n)
    for tr, te in KFold(n_splits=n_folds, shuffle=True, random_state=seed).split(X):
        l_hat[te] = learner().fit(X[tr], Y[tr]).predict(X[te])
        m_hat[te] = learner().fit(X[tr], D[tr]).predict(X[te])
    v, u = D - m_hat, Y - l_hat
    den = np.mean(v * v)
    theta = np.mean(v * u) / den
    psi = v * (u - theta * v) / den
    return theta, np.sqrt(np.mean(psi ** 2) / n)


# Proceso del caso canonico: theta = 0.5, n = 500, p = 20
rng = np.random.default_rng(0)
n, p, theta0 = 500, 20, 0.5
logistica = lambda z: 1 / (1 + np.exp(-z))
X = rng.standard_normal((n, p))
D = X[:, 0] + 0.25 * logistica(X[:, 2]) + rng.standard_normal(n)
Y = theta0 * D + logistica(X[:, 0]) + 0.25 * X[:, 2] + rng.standard_normal(n)

theta, se = dml_plr_manual(Y, D, X)
print(f"theta = {theta:.3f}  se = {se:.3f}  IC 95% = [{theta - 1.96 * se:.3f}, {theta + 1.96 * se:.3f}]")
assert abs(theta - theta0) < 5 * se and 0.01 < se < 0.2     # coherencia
```
) <lst-dml-manual>

#figure(
  kind: raw,
  caption: [DML aplicado a los datos del NSW (Lalonde).],
  ```python
import pandas as pd
from sklearn.ensemble import GradientBoostingRegressor

df = pd.read_csv("../data/datasets/real/public_causaldata/nsw_mixtape/data.csv")
Y = df["re78"].values
D = df["treat"].values
X = df[["age", "educ", "black", "hisp", "marr", "nodegree", "re74", "re75"]].values

theta, se = dml_plr_manual(Y, D, X, learner=lambda: GradientBoostingRegressor(
    n_estimators=200, max_depth=3, random_state=42))
print(f"ATE estimado: {theta:.0f}  (SE: {se:.0f})")
print(f"IC 95%: [{theta - 1.96 * se:.0f}, {theta + 1.96 * se:.0f}]")
```
) <lst-dml-nsw>

El segundo listado usa la función del primero y sobre los datos reales no lleva comprobación automática: su resultado debe compararse con el contraste experimental de referencia del texto.
]

== Riesgos, límites y sensibilidad
<sec-cap10_riesgos>

#riesgos[
  #set text(size: 9pt)
  #figure(
    caption: [Errores comunes en la implementación de DML para el PLR.],
    table(
      columns: (1.3fr, 1.5fr, 1.4fr, 1.6fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Omitir _cross-fitting_], [Sesgo de sobreajuste (caso 2)], [Comparar con y sin él], [Pliegues siempre; $K$ de 4 a 5],
      table.hline(stroke: 0.4pt),
      [Una sola división simple], [Se pierde información y sube la varianza], [Variabilidad entre particiones], [Repetir y agregar],
      table.hline(stroke: 0.4pt),
      [_Learners_ sin revisar su tasa], [Se incumple $sqrt(n) a_n^2 -> 0$], [Curvas de aprendizaje fuera de muestra], [Elegir por validación; ensamblar],
      table.hline(stroke: 0.4pt),
      [Score incorrecto para $l_0$], [Se rompe la ortogonalidad], [Qué _nuisance_ se estima ($g$ o $l$)], [Forma de Robinson con $l_0 = E[Y | X]$],
      table.hline(stroke: 0.4pt),
      [Ortogonalidad tomada por identificación], [No corrige la confusión no observada], [Revisar la no confusión (@cap-intervencion-contrafactual)], [Sensibilidad a confusores],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-dml>
]

*Límites.* El PLR supone un efecto constante de $D$. Si el efecto es heterogéneo en $X$, se requiere el modelo interactivo del @cap-dml. Y la ortogonalidad no resuelve problemas de identificación: si el supuesto de no confusión se vulnera, ningún score ortogonal lo corrige.

== Ejercicios y notas bibliográficas
<sec-cap10_ejercicios>

=== Ejercicios teóricos
<sec-cap10_ejercicios_teoricos>

+ Calcule la derivada de Gateaux del score no ortogonal $D (Y - g(X) - theta D)$ respecto de $g$ y muestre que vale $-E[D r_g (X)]$. ¿En qué caso se anula?

+ Con $theta_0 = 0.5$ y $h = m_0$, deduzca los sesgos teóricos del primer caso canónico, $-delta E[D h] \/ E[D^2]$ para el score no ortogonal y $delta^2 (1 - theta) E[h^2] \/ (1 + delta^2 E[h^2])$ para el ortogonal, y compárelos con las cifras del caso.

+ Con $a_n = n^(-1/4)$, ¿se cumple $sqrt(n) a_n^2 -> 0$? Para la forma de Robinson, use errores $a_n$ de $hat(m)$ y $b_n$ de $hat(l)$ y analice la condición $a_n(a_n+b_n)=o(n^(-1/2))$. Explique por qué mirar solo el producto $a_n b_n$ puede dar una respuesta incorrecta.

+ Explique por qué, sin _cross-fitting_, la condición de tasa no basta y hace falta una condición de complejidad sobre $hat(eta)$.

#capa-impl[
=== Ejercicios computacionales
<sec-cap10_ejercicios_computacionales>

+ Replique la comparación del segundo caso canónico con el #ref(<lst-dml-manual>, supplement: [listado]): DML con y sin _cross-fitting_ (misma muestra para _nuisance_ y score). ¿En cuánto cambian el sesgo y la cobertura con un bosque de hojas pequeñas, y con boosting profundo?

+ Modifique el proceso para que $g_0$ sea lineal y compare DML con OLS. ¿En qué caso son equivalentes?

+ Sobre el conjunto #code[close_college], aplique DML-PLR al retorno a la educación con #code[GradientBoostingRegressor] para los dos _nuisance_ y compare con OLS.

+ Construya un proceso donde $hat(g)$ tenga tasa $a_n = n^(-1/4)$ y verifique que la cobertura se degrada, ya que $sqrt(n) a_n^2$ no tiende a cero.
]

=== Notas bibliográficas
<sec-cap10_notas>

#cite(<neyman1959>, form: "prose") es la referencia original sobre ortogonalidad; la condición @eq-neyman-orth se conoce como ortogonalidad de Neyman por su test $C(alpha)$, construido con la misma idea de insensibilidad de primer orden a los parámetros de estorbo. #cite(<robinson1988>, form: "prose") es la referencia canónica del score de residuo contra residuo que el capítulo usa en el modelo parcialmente lineal y que reaparece en el @cap-meta-learners (R-learner) y en el @cap-panel-dmliv (panel); suele darse por sabida sin citarse, y conviene leerla para ver que la idea de ortogonalizar antecede en tres décadas al uso del ML. #cite(<chernozhukov2018double>, form: "prose") es el artículo fundacional de DML y contiene el desarrollo completo del teorema y de las variantes DML1 y DML2. #cite(<chernozhukov2016locally>, form: "prose") extiende el marco a estimandos más complejos. #cite(<newey1994asymmetric>, form: "prose") y #cite(<robins1995semiparametric>, form: "prose") son precursores por la vía de la eficiencia semiparamétrica, y #cite(<bickel1993efficient>, form: "prose") es el tratamiento de referencia de esa teoría. Para una revisión pedagógica accesible, @chernozhukov2018applied.
