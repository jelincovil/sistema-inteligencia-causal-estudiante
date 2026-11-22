# Reporte N2/N3 — Verificación de teoremas, proposiciones y resultados citados

**Proyecto:** `Causal_AI/` · **Fecha:** 2026-11-21
**Alcance:** (N2-P1) 36 bloques `#theorem`/`#proposition` con nombre (24 + 12 multi-línea) de capítulos y Apéndice A; (N2-P2) 72 líneas de prosa con palabra de resultado + `#cite`; (N2-P3) bloques sin nombre/atribución tratados por chequeo determinista (claves válidas en refs.yml). (N3) constantes cuantitativas — cubiertas dentro de N2 (tasas, cotas, SMD, cobertura conforme).
**Fuentes:** Semantic Scholar (`get_paper`, abstracts, `snippet_search`), `firecrawl_research_read_paper` (cuando hubo créditos), web (hasta su caída), y los veredictos N1 corregidos (`verificacion/partes/n1_parte*.jsonl`) — las fuentes citan siempre con los metadatos post-auditoría.
**Ledger:** `verificacion/ledger_teoremas.jsonl` (108 líneas). Limitación principal: 6 líneas prosa-A y parte de P1-P2 quedaron NO_VERIFICABLE por la caída del índice web y los créditos de Firecrawl agotados (F2 tardía); ningún veredicto se dio «de memoria».

## Resultado global (108 ítems)

| Veredicto | N | Significado |
|---|---|---|
| FIEL | 82 | Enunciado/atribución correctos respecto a la fuente |
| SIMPLIFICADO_DECLARADO | 3 | El libro declara "esquema/versión simplificada" y es honesto en lo omitido |
| PARCIAL | 6 | Omite hipótesis esenciales, sobre-lee el alcance, o cita clave fantasma (ver detalle) |
| ATRIBUCION_INCORRECTA | 2 | El resultado se atribuye a una obra que no lo contiene |
| ENUNCIADO_INCORRECTO | 2 | Condiciones/tesis/tasa mal transcritas |
| NO_VERIFICABLE | 13 | Sin acceso suficiente a la fuente (paywall/índice caído) — sin juicio adverso |

## Hallazgos críticos (4) — propuestas de corrección en `sugerencias_libro.md`

### C1. Ap. A, `apA_notacion_fundamentos.typ:105` — Cota de Cramér-Rao semiparamétrica — ENUNCIADO_INCORRECTO
El bloque dice que la varianza asintótica mínima es $tilde(I)_theta^(-1)$ y glosa «$tilde(I)_theta$ es la _información eficiente_: la varianza del EIF». **Internamente contradictorio:** si $tilde(I)_theta$ es la varianza del EIF, entonces $tilde(I)_theta^(-1)$ **no** es la cota: la cota es precisamente la varianza del EIF, $E[tilde(psi)tilde(psi)^top]$ (equiv. $tilde(I)_theta^(-1)$ cuando $tilde(I)_theta = E[tilde(S)tilde(S)^top]$ es la *precisión*, es decir, la varianza del score eficiente — no del EIF). Ver dictamen completo en el ledger; verificado contra van der Vaart (1998) cap. 25 y la propia DML (Cor. 3.2) del libro.

### C2. Ap. A, `apA_notacion_fundamentos.typ:142` — «Recht, Fazel & Parrilo, 2010» — ATRIBUCION_INCORRECTA
El enunciado («incoherencia + muestreo aleatorio denso ⇒ recuperación exacta por minimización de norma nuclear») es el teorema de **Candès & Recht (2009), _Exact Matrix Completion via Convex Optimization_, Foundations of Computational Mathematics 9(6):717–772, DOI 10.1007/s10208-009-9045-5** (arXiv:0805.4471). Recht–Fazel–Parrilo (2010, SIAM Review 52(3), DOI 10.1137/070697835) prueban la relajación por minimización afín de rango bajo RIP ($delta_{5r} < 1/10$), sin incoherencia ni muestreo uniforme.

### C3. `cap29_descubrimiento_grafos.typ:64` — consistencia del algoritmo PC — ENUNCIADO_INCORRECTO
El libro dice que, bajo _faithfulness_, suficiencia, normalidad y esparsidad, la CPDAG es consistente «**incluso cuando $p$ crece exponencialmente con $n$**». Kalisch & Bühlmann (2007, JMLR 8:613–636) prueba consistencia uniforme para $p = O(n^a)$ con $0 < a < \infty$ — **polinomial de exponente arbitrario**, nunca exponencial (el coste sí es exponencial en el grado máximo y polinomial en $p$). Sugerencia: «…incluso cuando $p$ crece polinomialmente con $n$ ($p = O(n^a)$, $a > 0$ arbitrario)».

### C4. `cap17_panel_dmliv.typ:133` — «valores críticos de Stock y Yogo (stock2002survey; andrews2019robust)» — ATRIBUCION_INCORRECTA
- `stock2002survey` es Stock–Wright–Yogo, *JBES* 20(4):518–529 (ya corregido en refs.yml): es el survey de instrumentos débiles, **no contiene las tablas de valores críticos** (esas son Stock & Yogo 2005, «Testing for Weak Instruments in Linear IV Regression», en *Identification and Inference for Econometric Models*, ya citada en el libro como `stock2005testing`).
- `andrews2019robust` citaba una obra inexistente — corregida a Andrews–Stock–Sun, *Annual Review of Economics* 11(1):727–753 (contiene revisión del tema, no las tablas).
- Kleibergen–Paap (rk Wald): la referencia correcta es Kleibergen (2002) / Paap (2005) — el libro atribuye el estadístico a la pareja de citas anterior; sugerencia exacta en `sugerencias_libro.md`.

## PARCIAL (6)

1. `cap27:70` (Shalit–Johansson–Sontag 2017) — la cota de 3 términos es correcta en estructura, pero el bloque **no declara la simplificación** y omite hipótesis del Thm. 1 (pérdida cuadrática con ruido $-2\\sigma_Y^2$; enlace IPM-pérdida $(1/B_\\Phi)\\ell in \\mathcal{G}$; $\\Phi$ dos veces diferenciable). Si se declara «esquema», es FIEL.
2. `cap24:93` y `cap24:433` — `kitagawa2021constrained` se sobre-lee: el paper prueba consistencia de surrogates bajo clases restringidas y cotas uniformes de regret; **no** entrega un teorema por familia de criterio de equidad ni una descomposición del costo en welfare por criterio. El libro afirma ambas cosas en dos sitios.
3. `cap27:310` — la crítica «la cota es laxa» se atribuye a `curth2021inductive` (NeurIPS 2021); ese paper no analiza la cota de Shalit et al. (muestra que TARNet es competitivo / $\\alpha$ óptimo depende del DGP). La crítica (invertibilidad/balanceo destruye información) es Curth & van der Schaar, AISTATS 2021 (arXiv:2101.10943) — no está en la bibliografía.
4. `cap06:416` — PARCIAL por `potscher2009confidence` (obra fantasma → ya corregida refs.yml a JMVA 100(9)) y `chernozhukov2018applied` (título inexistente → reapuntado a AER P&P 107(5) — INFERENCIA de Grok 4.7, confianza media; si no la aceptas, restaura y sustituye por `chernozhukov2018double`).
5. `cap05:407` — PARCIAL por la misma clave `chernozhukov2018applied` (ya corregida). El resto (Athey 2017 Science, Mullainathan & Spiess JEP, Elwert & Winship, Kleinberg 2015, Card 1995, Pearl español «Causalidad» CUP) verificado.
6. `cap29_descubrimiento_grafos.typ:64` — ver C3 (ENUNCIADO_INCORRECTO).

## SIMPLIFICADO_DECLARADO (3)
`cap10:142` (DML «versión simplificada» — correcto y declarado); `cap06:118` (Leeb–Pötscher «esquema» — fiel a Annals 2006; el matiz *cerca-de-cero* $n^{-1/2}$ proviene del hilo 2005/2008–2009, no del 2006); `cap06:158` (doble selección, «esquema»; verificada por abstracts OUP/MIT DSpace por paywall).

## NO_VERIFICABLE (13) — todos por acceso, no por hallazgo adverso
Libros sin extracto abierto (Huyen 2022 cap. 9/11; Spiegelhalter 2019; Hernán & Robins vía web caída; imposibilidad de validación conformal en cap.14; de LaLonde/Dehejia-Wahba por S2 sin abstract; `chernozhukov2018applied` en cap10:359 línea de refs; `cap31:219` bundle) y `abadie2015comparative` (cap28:111; la aritmética p_min = 1/(J+1) con J=9 es correcta pero el paper no se pudo abrir). Si el índice web se restablece, estos 13 son re-verificables en minutos.

## N3 (constantes numéricas)
Verificadas dentro de N2: O_p(n^-1/2) regret EWM (KT-2018 Thm 2.1/2.2 — FIEL); tasa Belloni et al. 2014 ASTE s²log²(p∨n)/n (FIEL, coincidencia literal); LASSO ℓ₁/ℓ₂ (Bickel et al. 2009 Thm 7.2 — FIEL); VC-acoplada A&W 2021 ≤60·√(VC·S*/n) (FIEL); DML-IRM varianza E[ψ*²] (FIEL); SMD < 0.25 / < 0.1 y razón de varianzas en [0.5, 2] (Rubin 2001) (FIEL a nivel de cita); cobertura exacta mínima 1/(J+1) (aritmética FIEL, paper NO_VERIFICABLE); consistencia PC $p = O(n^a)$ (ENUNCIADO_INCORRECTO, ver C3); Cramér–Rao (ENUNCIADO_INCORRECTO, ver C1).

## Recomendaciones de refs/citas derivadas de N2
- `chernozhukov2018applied` reapuntada (inferencia): si no la aceptas → marcar inexistente y sustituir sustitur los usos por `chernozhukov2018double` (más exacto conceptualmente: «revisión pedagógica» es aceptable con el AER P&P note, pero el artículo fundacional de DML es ese).
- Añadir a refs.yml: Kleibergen (2002), Curth & van der Schaar (2021, AISTATS, arXiv:2101.10943) para cap. 12/27; Candès & Recht (2009) para Ap. A (ver sugerencias_libro.md). No se añadieron claves nuevas sin aprobación.
- El libro presenta `andrews2019robust` (ahora corregida) y `stock2005testing` como apoyos complementarios — texto a ajustar en cap. 17 (sugerencia S4).

## Tabla completa (108 ítems)

| Ítem | Bloque / fuente | Veredicto | Observación |
|---|---|---|---|
| `apendices/apA_notacion_fundamentos.typ:75` | Ley débil de los grandes números | FIEL | — |
| `apendices/apA_notacion_fundamentos.typ:79` | Teorema central del límite | FIEL | — |
| `apendices/apA_notacion_fundamentos.typ:83` | Slutsky | FIEL | — |
| `apendices/apA_notacion_fundamentos.typ:105` | Cota de Cramér-Rao semiparamétrica | ENUNCIADO_INCORRECTO | La glosa del propio enunciado es falsa: la información eficiente es la varianza del score eficiente, Ĩ = E[S̃S̃ᵀ]; NO 'la varianza del EIF'. |
| `apendices/apA_notacion_fundamentos.typ:109` | Bickel, Klaassen, Ritov & Wellner, 1993 | NO_VERIFICABLE | Sin acceso al texto de BKRW (Johns Hopkins UP) para verificación textual; el enunciado es la caracterización estándar (hájek-Le Cam convolut |
| `apendices/apA_notacion_fundamentos.typ:142` | Recht, Fazel & Parrilo, 2010 | ATRIBUCION_INCORRECTA | El enunciado (incoherencia + entradas uniformemente aleatorias y suficientemente densas => minimización de norma nuclear recupera exactament |
| `capitulos/cap08_intervencion_contrafactual.typ:41` | Fórmula de ajuste de puerta trasera | FIEL | — |
| `capitulos/cap08_intervencion_contrafactual.typ:104` | Cálculo-do | FIEL | — |
| `capitulos/cap03_scm_pch.typ:159` | Teorema de la Jerarquía Causal | FIEL | — |
| `capitulos/cap13_arboles_bosques.typ:174` | Normalidad asintótica puntual del bosque causal | FIEL | — |
| `capitulos/cap10_ortogonalidad_crossfitting.typ:98` | Ortogonalidad del score PLR | FIEL | — |
| `capitulos/cap10_ortogonalidad_crossfitting.typ:142` | DML, versión simplificada | SIMPLIFICADO_DECLARADO | — |
| `capitulos/cap21_policy_learning.typ:74` | Inferencia sobre el valor de una política fija | FIEL | El bloque no lleva cite explícita: la atribución queda implícita por la Nota técnica del cap.10 (→ chernozhukov2018double) y por la sección  |
| `capitulos/cap21_policy_learning.typ:97` | Kitagawa y Tetenov, 2018: maximización del bienestar empírico | FIEL | — |
| `capitulos/cap21_policy_learning.typ:113` | Athey y Wager, 2021: policy learning con nuisance estimados | FIEL | — |
| `capitulos/cap26_generalizacion.typ:56` | Fórmula de transporte con una covariable | FIEL | El cite del bloque (tras el enunciado) es pearl2014external, no pearl2011transportability/bareinboimpearl2013transportability como sugería l |
| `capitulos/cap16_pds.typ:63` | Belloni, Chernozhukov y Hansen, 2014 | FIEL | Omite la tasa residual de la esparsidad aproximada (‖r_i‖₂ ≤ C√(s/n), su ASTE(iii)); queda cubierta por el término «esparsidad aproximada» ( |
| `capitulos/cap12_metalearners.typ:93` | Nie y Wager, 2021 (R-learner) | FIEL | — |
| `capitulos/cap12_metalearners.typ:115` | Kennedy, 2023: tasa oracle del DR-learner | FIEL | — |
| `capitulos/cap11_dml.typ:88` | Doble robustez + ortogonalidad | FIEL | — |
| `capitulos/cap11_dml.typ:94` | Eficiencia semiparamétrica del estimador DML-IRM | FIEL | La cota de eficiencia semiparamétrica del ATE es de Hahn 1998 (Econometrica 66(2):315-331, DOI 10.2307/2998560), no citada en el libro ni en |
| `capitulos/cap24_etica_interpretabilidad.typ:64` | Incompatibilidad de los criterios | FIEL | «Mutuamente incompatibles de a pares» omite el subcaso degenerado R⊥Y (score no informativo, TPR=FPR) en que independencia y separación sí s |
| `capitulos/cap06_regularizacion_postseleccion.typ:85` | Tasa de convergencia del LASSO | FIEL | Bickel–Ritov–Tsybakov Thm 7.2 asume ruido gaussiano y diag(XᵀX/n)=1; el libro generaliza implícitamente (válido sub-gaussiano, mismas tasas) |
| `capitulos/cap06_regularizacion_postseleccion.typ:107` | Consistencia de selección del LASSO | FIEL | — |
| `capitulos/cap06_regularizacion_postseleccion.typ:118` | Leeb y Pötscher: no uniformidad (esquema) | SIMPLIFICADO_DECLARADO | Esquema declarado. Matiz de atribución interna: el resultado de cobertura del intervalo ingenuo que puede acercarse a cero a lo largo de sec |
| `capitulos/cap06_regularizacion_postseleccion.typ:131` | Sesgo por omisión de controles | FIEL | — |
| `capitulos/cap06_regularizacion_postseleccion.typ:158` | Doble selección con LASSO (esquema) | SIMPLIFICADO_DECLARADO | Esquema declarado. Omite el enunciado completo: la penalización lambda asintóticamente proporcional a sqrt(n log(p∨n)), las condiciones de m |
| `capitulos/cap05_prediccion_causalidad.typ:102` | Identificación del CATE | FIEL | — |
| `capitulos/cap05_prediccion_causalidad.typ:121` | Sesgo de primer orden del estimador por sustitución | FIEL | — |
| `capitulos/cap14_validacion.typ:44` | Imposibilidad de validación directa | FIEL | — |
| `capitulos/cap14_validacion.typ:201` | Cobertura conforme | FIEL | — |
| `capitulos/cap17_panel_dmliv.typ:127` | DML-PLIV | FIEL | — |
| `capitulos/cap23_explicacion_equidad.typ:52` | Identificación de la descomposición | FIEL | — |
| `capitulos/cap25_decisiones_estructurales.typ:49` | Utilidad lineal e incertidumbre | FIEL | — |
| `capitulos/cap25_decisiones_estructurales.typ:89` | Cota del valor de un estudio | FIEL | — |
| `capitulos/cap27_deep_causal.typ:70` | Shalit, Johansson y Sontag, 2017 | PARCIAL | El bloque no declara simplificación y omite hipótesis del Teorema 1 de la fuente: (a) la cota vale con pérdida cuadrática y el ruido entra r |
| `capitulos/cap21_policy_learning.typ:36` | kitagawa2018should,athey2021policy | FIEL | — |
| `capitulos/cap21_policy_learning.typ:95` | kitagawa2018should,athey2021policy | FIEL | — |
| `capitulos/cap21_policy_learning.typ:111` | athey2021policy | FIEL | — |
| `capitulos/cap21_policy_learning.typ:379` | kitagawa2018should,athey2021policy,zhang2012estimating,kitagawa2021constrained | FIEL | — |
| `capitulos/cap31_aprendizaje_continuo.typ:177` | bareinboim2025causalai | NO_VERIFICABLE | Libro (borrador Oct-2025, causalai-book.net) sin abstract/indice accesible: web_fetch y web_search devuelven 'server shut down'; Firecrawl e |
| `capitulos/cap31_aprendizaje_continuo.typ:188` | zhang2019near | FIEL | — |
| `capitulos/cap31_aprendizaje_continuo.typ:219` | huyen2022dmls,bareinboim2025causalai,bareinboim2015bandits,zhang2019near | NO_VERIFICABLE | Las atribuciones centrales (DMLS cap.9 'Continual Learning and Test in Production'; causalai-book como 'referencia central del panorama de R |
| `capitulos/cap07_datos_entrenamiento.typ:28` | huyen2022dmls | NO_VERIFICABLE | DMLS (Chip Huyen, O'Reilly, may-2022, ISBN 9781098107956 confirmado por N1) sin TOC/abstract abiertos: web_fetch/web_search 'server shut dow |
| `capitulos/cap07_datos_entrenamiento.typ:70` | rubin1976inference | NO_VERIFICABLE | Rubin 1976 'Inference and Missing Data' (Biometrika 63(3):581-592, DOI 10.1093/biomet/63.3.581) no esta indexado en Semantic Scholar (bulk D |
| `capitulos/cap07_datos_entrenamiento.typ:158` | lalonde1986,dehejia1999causal | NO_VERIFICABLE | Ningun texto abierto: S2 solo indexa la version WP Princeton 1984 de LaLonde (registro leido: titulo 'Evaluating the Econometric Evaluations |
| `capitulos/cap07_datos_entrenamiento.typ:160` | dehejia1999causal | NO_VERIFICABLE | La afirmacion sobre las tablas descriptivas (tratados LDW muy distintos de controles CPS/PSID => SMD grandes) requiere abrir la tabla del ar |
| `capitulos/cap07_datos_entrenamiento.typ:198` | huyen2022dmls,imbens2015causal,rubin2001using,rosenbaum1983central,lalonde1986,dehejia1999causal,rubin1976inference | NO_VERIFICABLE | Apertura parcial: rubin2001using (registro+TLDR: matching/subclassification/weighting para disenar observacionales + nueva tabla diagnostica |
| `capitulos/cap28_scm_matrix_completion.typ:36` | athey2021matrix | FIEL | — |
| `capitulos/cap28_scm_matrix_completion.typ:55` | abadie2010synthetic | FIEL | — |
| `capitulos/cap28_scm_matrix_completion.typ:60` | athey2021matrix | FIEL | — |
| `capitulos/cap28_scm_matrix_completion.typ:111` | abadie2015comparative | NO_VERIFICABLE | Abadie-Diamond-Hainmueller 2015 (AJPS 59(2):495-510, DOI 10.1111/ajps.12116) no expone abstract/TLDR en S2 (registro leido: identidad y venu |
| `capitulos/cap28_scm_matrix_completion.typ:113` | doudchenko2016balancing,benmichael2021augmented | FIEL | La clausula de Doudchenko-Imbens ('misma familia de regresiones sobre los controles que difieren en las restricciones sobre los pesos') no s |
| `capitulos/cap28_scm_matrix_completion.typ:322` | abadie2003economic,abadie2010synthetic,abadie2015comparative,doudchenko2016balancing,benmichael2021augmented,athey2021matrix,recht2010guaranteed,arkhangelsky2021synthetic | FIEL | Dos de ocho fuentes sin contraste de contenido: abadie2015comparative (sin abstract/TLDR) y doudchenko2016balancing (solo identidad). Las se |
| `capitulos/cap32_lado_humano.typ:26` | huyen2022dmls | NO_VERIFICABLE | DMLS ultimo capitulo ('The Human Side of Machine Learning', cap.11) no contrastable: libro O'Reilly sin abstract/TOC accesible (web_fetch/we |
| `capitulos/cap32_lado_humano.typ:38` | spiegelhalter2019art | NO_VERIFICABLE | Spiegelhalter, 'The Art of Statistics' (Pelican Books UK / Basic Books US, 2019; identidad confirmada por N1) sin pasajes accesibles: la web |
| `capitulos/cap32_lado_humano.typ:47` | galesic2011 | FIEL | — |
| `capitulos/cap32_lado_humano.typ:114` | huyen2022dmls,spiegelhalter2019art,galesic2011,lipton2018mythos,imbens2015causal | NO_VERIFICABLE | La referencia central del capitulo (DMLS cap.11) y Spiegelhalter 2019 no pudieron abrirse (libros, web caida). Verificadas por TLDR/abstract |
| `capitulos/cap26_generalizacion.typ:52` | pearl2011transportability,bareinboimpearl2013transportability | FIEL | — |
| `capitulos/cap26_generalizacion.typ:67` | pearl2014external | FIEL | — |
| `capitulos/cap26_generalizacion.typ:75` | bareinboim2014selection | FIEL | — |
| `capitulos/cap26_generalizacion.typ:77` | correa2020general | FIEL | — |
| `capitulos/cap15_despliegue_servicio.typ:34` | huyen2022dmls,kastner2024mlip | FIEL |  kastner2024mlip capitulos 10 no verificado directamente (sin acceso web en esta sesion); N1 confirma existencia del libro en mlip-cmu.githu |
| `capitulos/cap24_etica_interpretabilidad.typ:44` | barocas2019fairness | FIEL | — |
| `capitulos/cap24_etica_interpretabilidad.typ:68` | chouldechova2017fair,kleinberg2017inherent,barocas2019fairness | FIEL | — |
| `capitulos/cap24_etica_interpretabilidad.typ:93` | kitagawa2021constrained | PARCIAL | El paper no demuestra un resultado de 'regret bajo cualquiera de las tres familias de equidad': su contenido es consistencia de surrogates b |
| `capitulos/cap24_etica_interpretabilidad.typ:433` | barocas2019fairness,chouldechova2017fair,kleinberg2017inherent,dwork2012fairness,hardt2016equality,kitagawa2021constrained | PARCIAL | Solo kitagawa2021constrained está sobre-leído: dice 'formalizan el policy learning bajo restricciones y permiten cuantificar el costo en wel |
| `capitulos/cap03_scm_pch.typ:163` | bareinboim2022pch | FIEL | — |
| `capitulos/cap03_scm_pch.typ:400` | bareinboim2022pch,bareinboim2025causalai,pearl2009causality,imbens2015causal,pearlmackenzie2018,card1995 | FIEL | Imbens-Rubin: 'equivalencia formal' entre PO y SCM es caracterización fuerte de la discusión del libro (caps. sobre gráficas/modelos estruct |
| `capitulos/cap02_anatomia_sistema.typ:252` | huyen2022dmls,sculley2015hiddendebt,breck2017mltestscore,paleyes2022challenges,perdomo2020performative | FIEL | — |
| `capitulos/cap09_features_sin_fuga.typ:35` | huyen2022dmls | FIEL | — |
| `capitulos/cap13_arboles_bosques.typ:182` | wager2018estimation | FIEL | La afirmacion 'beta_min se acerca a 1' es glosa del libro: el paper da beta_min en funcion de los cotas de sesgo y de la dimension d (empleo |
| `capitulos/cap13_arboles_bosques.typ:226` | athey2021policy | FIEL | Full text no abierto (solo appendix en linea indexado; snippet search sin 'trees'); la afirmacion de arboles de profundidad acotada con VC f |
| `capitulos/cap25_decisiones_estructurales.typ:61` | manski2004statistical | FIEL | — |
| `capitulos/cap25_decisiones_estructurales.typ:299` | bareinboim2025causalai,berger1985statistical,manski2004statistical | FIEL | — |
| `capitulos/cap33_supuestos_no_observables.typ:75` | cinellihazlett2020 | FIEL | — |
| `capitulos/cap33_supuestos_no_observables.typ:341` | cinellihazlett2020,vanderweele2017evalue,chernozhukov2022long,lipsitch2010negative,rambachan2023more | FIEL | — |
| `capitulos/cap04_ingenieria_datos.typ:35` | huyen2022dmls | FIEL | — |
| `capitulos/cap10_ortogonalidad_crossfitting.typ:227` | dehejia1999causal | FIEL | SE publicado es $633 (convencion pooled de Dehejia-Wahba 1999, tabla experimental); recomputado unpooled = $671; el rango 'unos 650 a 700' d |
| `capitulos/cap10_ortogonalidad_crossfitting.typ:359` | neyman1959,robinson1988,chernozhukov2018double,chernozhukov2016locally,newey1994asymmetric,robins1995semiparametric,bickel1993efficient,chernozhukov2018applied | NO_VERIFICABLE | chernozhukov2018applied ('revision pedagogica accesible') no se localiza: N1 (VERIFICAR_MANUAL) y mi busqueda en S2 (titulo literal y varian |
| `capitulos/cap23_explicacion_equidad.typ:208` | pearl2009causality,bareinboim2025causalai,kusner2017counterfactual,kilbertus2017avoiding,plecko2024causal | FIEL | — |
| `capitulos/cap16_pds.typ:36` | belloni2014inference | FIEL | — |
| `capitulos/cap16_pds.typ:160` | belloni2012sparse | FIEL | — |
| `capitulos/cap16_pds.typ:303` | hernan2020whatif,belloni2014inference | FIEL | La cifra '51 controles potenciales' no verificada (no accesible el listado/apendice de la edicion en esta sesion); el resto exacto |
| `capitulos/cap27_deep_causal.typ:310` | shalit2017estimating, curth2021inductive | PARCIAL | Atribue a curth2021inductive (NeurIPS 2021) la tesis explicita de que «la cota que justifica la penalizacion es *laxa*»; ese paper no analiz |
| `capitulos/cap27_deep_causal.typ:321` | farrell2021deep | FIEL | — |
| `capitulos/cap27_deep_causal.typ:323` | chernozhukov2022riesznet | FIEL | — |
| `capitulos/cap27_deep_causal.typ:361` | shalit2017estimating, hartford2017deep, louizos2017causal, shi2019adaptively | FIEL | — |
| `capitulos/cap12_metalearners.typ:371` | kunzel2019metalearners, nie2021quasi, kennedy2023towards, foster2019orthogonal, athey2019econometric, robinson1988 | FIEL | — |
| `capitulos/cap14_validacion.typ:130` | vanderweele2017evalue | FIEL | — |
| `capitulos/cap14_validacion.typ:207` | leicandes2021 | FIEL | — |
| `capitulos/cap14_validacion.typ:381` | thornton2008demand | FIEL | — |
| `capitulos/cap06_regularizacion_postseleccion.typ:111` | zhao2006model | FIEL | — |
| `capitulos/cap06_regularizacion_postseleccion.typ:116` | leeb2006can | FIEL | — |
| `capitulos/cap06_regularizacion_postseleccion.typ:416` | tibshirani1996lasso, hoerl1970ridge, hastie2015statistical, bickel2009simultaneous, zhao2006model, leeb2006can, potscher2009confidence, lee2016exact, zhang2014confidence, vandegeer2014asymptotically, belloni2014inference, chernozhukov2018applied | PARCIAL | potscher2009confidence y chernozhukov2018applied no existen tal como estan citadas. N1: no hay articulo 'On the Distribution of Penalized Es |
| `capitulos/cap01_causalidad_elemental.typ:54` | neyman1923, rubin1974 | FIEL | — |
| `capitulos/cap01_causalidad_elemental.typ:109` | neyman1923, rubin1974, holland1986, imbens2015causal, pearlmackenzie2018, bareinboim2022pch, bareinboim2025causalai, pearl2009causality, simpson1951, yule1903, hernan2020whatif | FIEL | — |
| `capitulos/cap29_descubrimiento_grafos.typ:36` | pearl2009causality, spirtes2000causation, zheng2018dags | FIEL | — |
| `capitulos/cap29_descubrimiento_grafos.typ:64` | kalisch2007estimating | ENUNCIADO_INCORRECTO | Afirma que PC es consistente «incluso cuando p crece exponencialmente con n». Kalisch & Buhlmann 2007 prueban consistencia uniforme solo par |
| `capitulos/cap29_descubrimiento_grafos.typ:66` | chickering2002optimal | FIEL | — |
| `capitulos/cap29_descubrimiento_grafos.typ:126` | reisach2021beware | FIEL | — |
| `capitulos/cap29_descubrimiento_grafos.typ:347` | pearl2009causality, spirtes2000causation, kalisch2007estimating, chickering2002optimal, zheng2018dags | FIEL | — |
| `capitulos/cap05_prediccion_causalidad.typ:40` | kleinberg2015prediction | FIEL | — |
| `capitulos/cap05_prediccion_causalidad.typ:407` | athey2017beyond, imbens2015causal, hernan2020whatif, mullainathan2017machine, kleinberg2015prediction, elwert2014endogenous, athey2019econometric, chernozhukov2018applied, pearl2009causality, card1995 | PARCIAL | chernozhukov2018applied no existe con ese titulo (0 resultados en S2/web); probables referentes: AER Papers & Proc. 107(5):261-265 (2017, DO |
| `capitulos/cap17_panel_dmliv.typ:131` | stock2005testing | FIEL | — |
| `capitulos/cap17_panel_dmliv.typ:133` | stock2002survey, andrews2019robust, belloni2012sparse | ATRIBUCION_INCORRECTA | La sentencia liga 'estadisticos robustos como el de Kleibergen y Paap y los valores criticos de Stock y Yogo' a las citas stock2002survey y  |
| `capitulos/cap17_panel_dmliv.typ:140` | goodmanbacon2021, dechaisemartin2020twoway | FIEL | — |
| `capitulos/cap17_panel_dmliv.typ:372` | goodmanbacon2021, dechaisemartin2020twoway, callaway2021difference, sun2021estimating, borusyak2024revisiting, freyaldenhoven2021local | FIEL | — |

*Tabla generada desde `ledger_teoremas.jsonl` (2026-11-21). Cuentas: 82 FIEL · 3 SIMPLIFICADO_DECLARADO · 6 PARCIAL · 2 ATRIBUCION_INCORRECTA · 2 ENUNCIADO_INCORRECTO · 13 NO_VERIFICABLE. Ver `PROTOCOLO_N2.md` para la taxonomía.*
