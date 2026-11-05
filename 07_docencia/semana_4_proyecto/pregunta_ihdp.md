# Pregunta causal de la entrega (se declara ANTES de mirar los datos)

**Escenario:** `real/ihdp` del benchmark local (Hill 2011, sintético, efectos heterogéneos por diseño).

## Pregunta

> ¿Cuál es el efecto del programa de intervención temprana sobre el puntaje
> cognitivo a los 3,5 años de los niños que lo recibieron?

## Estimando

- **ATE** de `treatment` sobre `outcome` (efecto total, en puntos del test cognitivo).
- Población: los 448 individuos de `observed_train.csv` del escenario
  (partición de entrenamiento, hash verificado contra `splits.json`).
- El intervalo cubre **el efecto promedio poblacional**; no es un efecto individual
  ni un CATE. `/consulta` informa, como mucho, la **media de un estrato** con su IC.

## Supuestos (y su clase)

| Supuesto | Clase | Cómo se trata aquí |
|---|---|---|
| No confusión condicional en las 25 covariables pre-tratamiento | `no_observable` | Se declara; la identificación lo exige y ningún dato lo verifica |
| Soporte común (0 < e(X) < 1) | `observable` | Se mide: rango de ê ∈ [0,071; 0,887], ESS de Kish = 388 (ESS/n = 0,87), 100 % de unidades en la zona de solapamiento |
| Consistencia / SUTVA | `no_observable` | Se declara; heredado del diseño del escenario |
| Covariables medidas antes del tratamiento | `observable` | El benchmark lo declara (`identification.json`); la trampa `score_post` muestra qué pasa si no |

## Qué NO afirma esta entrega

- El estimador principal es **AIPW con cross-fitting** (K=5, semilla 4242): doblemente
  robusto y con nuisances fuera de muestra. Las dos piernas siguen siendo **lineales**
  (OLS por brazo y logística en los logits): no hay learners no lineales ni repeated
  cross-fitting — eso es el proyecto final.
- El corte de heterogeneidad es **`bw` dicotomizado en la mediana de entrenamiento**:
  informa dos medias de estrato con su IC, no un CATE continuo ni una política. Su
  regla está en la tarjeta y se declaró antes de mirar los efectos.
- La referencia del DGP (~4,0) **no** se usa para estimar, decidir ni calibrar
  umbrales: solo se compara al final, y el IC del AIPW la contiene.

## Regla del prototipo

Solo `observed_*` alimenta decisiones. El registro, la tarjeta, el servicio y el
monitor trabajan sobre artefactos con hash, nunca sobre datos sueltos.
