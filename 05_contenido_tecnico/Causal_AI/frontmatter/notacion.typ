// Notación y convenciones
#import "../template/template.typ": *

#chapter[Notación y convenciones]
<sec-notacion>

La siguiente tabla resume los símbolos principales utilizados a lo largo de la monografía.

#show figure: set block(breakable: true)

#figure(
  caption: [Símbolos y convenciones de notación.],
  numbering: none,
  table(
    columns: (1.25fr, 2.6fr, 1.15fr),
    align: (left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Símbolo*], [*Significado*], [*Uso*]),
    table.hline(stroke: 0.4pt),
    [$Y_(i)(d)$], [Resultado potencial bajo tratamiento $d$], [Capítulos 1, 5],
    [$D_i$], [Tratamiento observado], [Todo el libro],
    [$X_i$], [Covariables pre-tratamiento], [Todo el libro],
    [$tau(x)$], [CATE: $E[Y(1) - Y(0) | X = x]$], [5, 10--14, 21--22, 25, 27],
    [$theta_0$], [Parámetro causal verdadero], [Capítulos 6, 10--11, 16--17],
    [$"ATE"$ o $theta_("ATE")$], [ATE: $E[tau(X)]$], [Todo el libro],
    [$mu_(d)(x)$], [Outcome condicional: $E[Y | X = x, D = d]$], [Capítulos 5, 10--14, 21, 27],
    [$g_(0)(x)$], [Componente estructural PLR], [Capítulos 10--11, 17],
    [$l_(0)(x)$], [Outcome regression PLR: $E[Y | X = x]$], [Capítulos 10--11],
    [$e_(0)(x)$], [Propensity score: $E[D | X = x]$], [Capítulos 5, 10--14, 21--22],
    [$m_(0)(x)$], [Tratamiento condicional: $E[D | X = x]$], [Capítulos 10--11],
    [$psi(W, theta, eta)$], [Score ortogonal], [Capítulos 10--11, 17],
    [$eta$], [Nuisance parameter], [Capítulos 10--11],
    [$W_i = (Y_i, D_i, X_i)$], [Observación $i$-ésima], [Todo el libro],
    [$Z$, $Z_i$], [Instrumento (en el Cap. 8, conjunto de ajuste de puerta trasera)], [Capítulos 3, 8, 16--17],
    [$Y_i^star$], [_Transformed outcome_], [Capítulos 14, 24],
    [$bold(W)$], [Matriz de adyacencia (NOTEARS)], [Capítulo 29],
    [$bold(w)$], [Pesos del control sintético], [Capítulo 28],
    [$omega_(i)(x)$], [Pesos locales (GRF)], [Capítulo 13],
    [$cal(V)$], [Varianza asintótica], [Capítulos 10--11],
    [$V(pi)$], [Valor de la política], [Capítulos 21--22],
    [$A$], [Atributo protegido], [Capítulo 23],
    [$alpha_i$], [Efecto fijo de unidad], [Capítulo 17],
    [$cal(L)_m$], [Hoja $m$-ésima del árbol], [Capítulo 13],
    [$u_i$], [Residuo Robinson (outcome)], [Capítulos 10--11],
    [$v_i$], [Residuo Robinson (tratamiento)], [Capítulos 10--11],
    [$lambda$], [Penalización / multipl. presupuestario], [Capítulos 6, 16, 21--22, 28],
    [$n, N, T$], [Obs. i.i.d. / unidades / periodos], [Todo el libro],
    table.hline(stroke: 0.8pt),
  )
) <tab-notacion>
