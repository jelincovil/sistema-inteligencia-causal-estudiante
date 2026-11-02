// Apéndice B: Guía de librerías y entorno reproducible
#import "../template/template.typ": *

#chapter[Guía de librerías y entorno reproducible]
<ap-librerias>

#theorem-number-reset()

Este apéndice reúne las herramientas concretas con las que se implementan los métodos del libro. Es material de implementación: las versiones y las interfaces cambian, y el texto de los capítulos no depende de él.

== Entorno reproducible
<sec-apB_entorno>

Para garantizar la reproducibilidad de los experimentos y facilitar la instalación de todas las dependencias necesarias, se recomienda el uso de entornos virtuales gestionados con #code[conda] o #code[venv]. A continuación se describe la configuración base utilizada en los ejemplos de este apéndice.

La gestión de dependencias puede realizarse mediante un archivo #code[requirements.txt] o un archivo #code[environment.yml] de Conda. Ambas opciones permiten fijar versiones específicas de cada librería, asegurando que los resultados sean replicables en diferentes sistemas.

== econml (Microsoft Research)
<sec-apB_econml>

*Propósito.* Implementación de métodos de ML causal desarrollada por Microsoft Research. Es una de las librerías más completas para estimación de CATE.

*Módulos principales.*

- #code[econml.dml]: Double Machine Learning (#code[LinearDML], #code[CausalForestDML], #code[SparseLinearDML]).
- #code[econml.metalearners]: S/T/X-learners (#code[SLearner], #code[TLearner], #code[XLearner]).
- #code[econml.policy]: Policy trees y forests (#code[PolicyTree], #code[PolicyForest]).
- #code[econml.iv]: Variables instrumentales (#code[DeepIV], #code[OrthoIV]).
- #code[econml.orf]: Orthogonal Random Forests.
- #code[econml.score]: Validation scores (#code[RScorer]); fundamento y protocolo de uso en el @cap-validacion.

*Ejemplo canónico.*

#figure(
  kind: raw,
  caption: [Ejemplo canónico de uso de #code[econml] (#code[LinearDML]).],
  ```python
import numpy as np
from econml.dml import LinearDML
from sklearn.ensemble import GradientBoostingClassifier, GradientBoostingRegressor

# Datos sintéticos con efecto verdadero 1,0 y confusión observada en X[:, 0]
rng = np.random.default_rng(0)
n = 2000
X = rng.normal(size=(n, 3))
D = rng.binomial(1, 1 / (1 + np.exp(-X[:, 0])))
Y = 1.0 * D + X[:, 0] + rng.normal(size=n)

est = LinearDML(model_y=GradientBoostingRegressor(),
                model_t=GradientBoostingClassifier(),
                discrete_treatment=True, cv=5)
est.fit(Y, D, X=X)
ate = est.ate(X=X); cate = est.effect(X)
```
) <lst-apB-econml-canonical>

== DoubleML
<sec-apB_doubleml>

*Propósito.* Implementación del marco DML de Chernozhukov et al. (2018) con foco en inferencia rigurosa.

*Módulos principales.*

- #code[DoubleMLPLR]: Partial Linear Model.
- #code[DoubleMLIRM]: Interactive Regression Model.
- #code[DoubleMLPLIV]: Partial Linear IV Model.
- #code[DoubleMLIIVM]: Interactive IV Model.

*Diferencia con econml.* #code[DoubleML] está más orientado a inferencia (IC, tests); #code[econml] está más orientado a estimación de CATE. Complementarios.

== causalml (Uber)
<sec-apB_causalml>

*Propósito.* Librería de Uber para _uplift modeling_ y _meta-learners_. Fuerte en aplicaciones de marketing.

*Módulos principales.*

- #code[causalml.inference.meta]: S/T/X/R-learners con varias _base learners_ (XGBoost, MLP).
- #code[causalml.metrics]: Qini, AUUC, _uplift curves_.
- #code[causalml.optimize]: Optimización de políticas bajo restricciones presupuestarias.
- #code[causalml.propensity]: Estimación de _propensity score_ con varios modelos.

En versiones recientes, usar #code[BaseSRegressor], #code[BaseTRegressor], #code[BaseXRegressor] o #code[BaseRRegressor] con un _learner_ base (por ejemplo, #code[XGBRegressor]).

== dowhy (PyWhy)
<sec-apB_dowhy>

*Propósito.* Framework de inferencia causal que integra identificación (con DAGs), estimación (con varios métodos), y refutación (_placebo tests_, sensibilidad).

*Pipeline.*

+ *Modelado:* definir tratamiento, _outcome_, y DAG con #code[CausalModel].
+ *Identificación:* #code[model.identify_effect()] aplica el criterio de puerta trasera.
+ *Estimación:* #code[model.estimate_effect()] con el método elegido (_matching_, estratificación o ponderación por _propensity score_, regresión lineal, o estimadores de #code[econml] como DML).
+ *Refutación:* #code[model.refute_estimate()] con _placebos_ y sensibilidad.

== PyTorch
<sec-apB_pytorch>

*Propósito.* Framework de _deep learning_. Usado en #solo-curso[este curso]#solo-comercial[este libro] para implementaciones _from-scratch_ de TARNet, CFRNet, DeepIV.

*Patrones comunes en ML causal.*

#figure(
  kind: raw,
  caption: [Red de representación para TARNet/CFRNet en PyTorch.],
  ```python
import torch.nn as nn

class RepresentationNet(nn.Module):
    def __init__(self, in_dim, rep_dim):
        super().__init__()
        self.net = nn.Sequential(
            nn.Linear(in_dim, 128), nn.ReLU(),
            nn.Linear(128, 64), nn.ReLU(),
            nn.Linear(64, rep_dim),
        )
    def forward(self, X):
        return self.net(X)
```
) <lst-apB-pytorch-repr>

== scikit-learn
<sec-apB_sklearn>

*Propósito.* Base para todos los _learners_ de ML. #code[RandomForestRegressor], #code[GradientBoostingRegressor], #code[LassoCV], #code[LogisticRegressionCV] son los componentes básicos de DML.

== networkx
<sec-apB_networkx>

*Propósito.* Manipulación de grafos. Útil para visualizar DAGs y construir estructuras causales antes de pasar a #code[dowhy].

== statsmodels
<sec-apB_statsmodels>

*Propósito.* Estimación econométrica clásica (OLS, 2SLS, IV) y tests estadísticos. Útil para _benchmarks_ y comparaciones con métodos de ML.

== Tabla comparativa
<sec-apB_tabla>

#figure(
  caption: [Comparación de librerías y versiones vigentes (PyPI, 5 de octubre de 2026).],
  table(
    columns: (0.95fr, 0.68fr, 0.85fr, 1.37fr, 1.5fr),
    align: (left, left, left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Librería*], [*Versión*], [*Foco*], [*Fortaleza*], [*Limitación*]),
    table.hline(stroke: 0.4pt),
    [#code[econml]], [0.17.0], [CATE], [Más completo], [Curva de aprendizaje alta],
    [#code[DoubleML]], [0.11.4], [Inferencia], [IC rigurosos], [Foco en ATE/ATT/LATE; menos orientado a CATE heterogéneo que #code[econml]],
    [#code[causalml]], [0.17.0], [Uplift], [Métricas de marketing], [Enfoque específico en uplift],
    [#code[dowhy]], [0.14], [Pipeline], [Identificación + refutación], [Estimación delegada],
    [#code[PyTorch]], [2.14.1], [Deep causal], [Flexibilidad total], [Requiere experiencia],
    [#code[scikit-learn]], [1.9.1], [Base], [Estándar], [No causal específico],
    [#code[networkx]], [3.7], [Grafos], [DAGs y visualización], [No estima efectos],
    [#code[statsmodels]], [0.15.0], [Econometría clásica], [OLS, 2SLS, IV y tests], [No incluye ML],
    table.hline(stroke: 0.8pt),
  )
) <tab-apB-comparativa>

La columna _Versión_ de la @tab-apB-comparativa indica la última versión estable publicada en PyPI a fecha 5 de octubre de 2026 para los paquetes #code[econml], #code[doubleml], #code[causalml], #code[dowhy], #code[torch], #code[scikit-learn], #code[networkx] y #code[statsmodels]. Para reproducir resultados, fije estas versiones (u otras explícitas) en #code[requirements.txt] o #code[environment.yml] (@sec-apB_entorno).

== Instalación recomendada
<sec-apB_instalacion>

#figure(
  kind: raw,
  caption: [Instalación del stack base de librerías de ML causal.],
  ```bash
pip install econml doubleml causalml dowhy torch scikit-learn networkx statsmodels shap jsonschema
```
) <lst-apB-install-base>

=== Librerías complementarias
<sec-apB_complementarias>

#figure(
  caption: [Librerías complementarias.],
  table(
    columns: (1.2fr, 1.4fr, 1.6fr, 1.4fr),
    align: (left, left, left, left),
    stroke: none,
    table.hline(stroke: 0.8pt),
    table.header([*Librería*], [*Foco*], [*Fortaleza*], [*Limitación*]),
    table.hline(stroke: 0.4pt),
    [#code[causal-learn]], [Causal discovery], [PC, FCI, GES implementados], [Curva de aprendizaje alta],
    [#code[cdt]], [Discovery toolbox], [Muchos algoritmos en un lugar], [Mantenimiento variable],
    [#code[pgmpy]], [Modelos gráficos], [Grafos de probabilidad], [No siempre causal],
    [#code[geomloss]], [Distancias Wasserstein/MMD], [Útil para CFRNet], [Requiere GPU opcional],
    [#code[POT]], [Transporte óptimo], [Flexible y bien documentado], [Costo computacional alto],
    [#code[linearmodels] / #code[pyfixest]], [IV, panel y DiD], [Econometría clásica rápida], [No incluye ML],
    table.hline(stroke: 0.8pt),
  )
) <tab-apB-complementarias>

Instalación opcional:

#figure(
  kind: raw,
  caption: [Instalación de librerías complementarias.],
  ```bash
pip install causal-learn cdt pgmpy geomloss POT linearmodels pyfixest
```
) <lst-install-optional>