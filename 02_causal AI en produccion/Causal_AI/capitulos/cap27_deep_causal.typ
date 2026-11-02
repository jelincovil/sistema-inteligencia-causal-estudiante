// Capítulo 27: Deep learning para inferencia causal
// Edición en capas: la teoría (L0), los algoritmos en pseudocódigo (L1) y el caso canónico (L2) son lo que dura;
// los listados de PyTorch (L3) y los ejercicios computacionales van dentro de #capa-impl.
#import "../template/template.typ": *

#chapter[Deep learning para inferencia causal]
<cap-deep-causal>

#theorem-number-reset()

#cuadrosinoptico[
  #table(
    columns: (auto, 1fr),
    align: (left, left),
    stroke: none,
    [*Problema:*], [Estimar CATE con no linealidades complejas usando redes neuronales],
    [*Estimando:*], [$tau(x) = E[Y(1)-Y(0) | X=x]$],
    [*Identificación:*], [No confusión, soporte común, SUTVA],
    [*Método:*], [TARNet, CFRNet (IPM), DeepIV],
    [*Nuisance:*], [$mu_1(x), mu_0(x), Phi(x)$],
    [*Garantía:*], [Cota de error bajo no confusión y representación balanceada; inferencia válida solo cuando la red actúa como _nuisance_ dentro de un score ortogonal],
    ..if not es-principios {([*Librerías:*], [PyTorch, econml])},
    [*Validación:*], [Balance de representación, MMD, comparación con meta-learners],
  )
]

#notatecnica[
Con la Parte VI completa, #solo-curso[el curso]#solo-comercial[el libro] ya cubrió estimación, decisión, equidad y generalización con los métodos "estándar" de ML causal, y esta Parte VII reúne dos familias de métodos más especializados. Este capítulo extiende los meta-learners y los bosques causales (@cap-meta-learners y @cap-causal-forests) con arquitecturas de _deep learning_ diseñadas específicamente para balancear representaciones entre grupos de tratamiento.
]

== Motivación aplicada
<sec-cap27_motivacion>

Una plataforma de salud digital desea estimar el efecto de un programa de recordatorios personalizados sobre la adherencia a medicamentos. Cada usuario tiene cientos de características (historial médico, comportamiento en la app, demografía). El efecto del tratamiento es altamente no lineal: para algunos subgrupos el recordatorio es muy efectivo, para otros es nulo. Los métodos basados en árboles (_causal forest_) pueden no capturar la estructura compleja; una red neuronal podría.

El _deep causal learning_ aplica redes neuronales al problema de estimación causal. La innovación central, introducida por @shalit2017estimating con TARNet y CFRNet, es aprender una _representación balanceada_ $Phi(X)$ tal que las distribuciones de $Phi(X)$ para tratados y controles sean similares, permitiendo estimar $mu_0(Phi(X))$ y $mu_1(Phi(X))$ con la misma red.

Este capítulo desarrolla TARNet y CFRNet, presenta DeepIV @hartford2017deep para variables instrumentales y discute las extensiones modernas (CEVAE, contrastive balance). Su mensaje de fondo es doble: la representación balanceada no sustituye al supuesto de no confusión, y la inferencia válida con redes llega por el aparato ortogonal, no por la red.

== Teoría, supuestos y garantías
<sec-cap27_teoria>

=== TARNet: representación compartida
<sec-cap27_tarnet>

TARNet (_Treatment-Agnostic Representation Network_) tiene arquitectura:

+ *Capa de representación* $Phi: R^p arrow.r R^k$ que mapea covariables a un embedding.
+ *Cabezas de outcome* $h_0, h_1: R^k arrow.r R$ separadas para tratados y controles.

La predicción es $hat(mu)_d (x) = h_(d)(Phi(x))$. El CATE estimado es $hat(tau)(x) = h_1(Phi(x)) - h_0(Phi(x))$.

La _loss_ es el error cuadrático medio:
$
cal(L)_"TARNet" = (1 / n) sum_i (Y_i - h_(D_i)(Phi(X_i)))^2.
$

=== CFRNet: balance con una métrica integral de probabilidad
<sec-cap27_cfrnet>

CFRNet (_Counterfactual Regression with IPM_) añade a TARNet una penalización de _Integral Probability Metric_ (IPM) que fuerza el balance entre las distribuciones de $Phi(X)$ para tratados y controles:
$
cal(L)_"CFRNet" = cal(L)_"TARNet" + alpha dot.c "IPM"(Phi(X | D = 0), Phi(X | D = 1)).
$ <eq-cfrnet-loss>

Aquí $alpha$ es el peso de la penalización IPM, no el nivel de significación.

La IPM puede ser la distancia de Wasserstein, la discrepancia máxima de medias (MMD) o una pérdida adversarial, como en las redes neuronales de adaptación de dominio.

#theorem(
  name: [Shalit, Johansson y Sontag, 2017]
)[
  Bajo no confusión y soporte común, y para una representación $Phi$ invertible y diferenciable, el error esperado en $tau$ (el error de estimación del efecto heterogéneo) está acotado por una suma de tres términos: (i) los errores factuales de las dos cabezas de resultado, (ii) un múltiplo de la IPM entre las distribuciones de $Phi(X)$ para tratados y controles y (iii) el ruido irreducible del resultado. La versión de muestra finita añade un término de complejidad de la clase de funciones.
] <thm-cfrnet>

La cota explica por qué se penaliza la IPM, pero es una cota, no una igualdad: minimizarla no equivale a minimizar el error en $tau$, un punto que la @sec-cap27_limites_balance desarrolla.

=== DeepIV
<sec-cap27_deepiv>

Para casos con variable instrumental, @hartford2017deep proponen DeepIV. El modelo es $Y = h(D, X) + epsilon$, con $E[epsilon | Z, X] = 0$ pero $epsilon$ posiblemente correlacionado con $D$, de modo que la regresión directa de $Y$ sobre $D$ y $X$ sesga la función estructural $h$. La estimación se hace en dos etapas con dos redes:

+ *Red de tratamiento* $g(z, x)$, que modela la densidad $p(D | Z, X)$ y se ajusta por máxima verosimilitud.
+ *Red estructural* $h(d, x)$, que estima la función causal y se ajusta minimizando el error cuadrático del resultado frente a la esperanza de $h(D, x)$ bajo la densidad estimada en la primera etapa.

Las dos etapas no se combinan en una sola pérdida: la segunda toma la primera como dada. La identificación descansa en las condiciones habituales de un instrumento (relevancia, exclusión e independencia) y en la forma aditiva del error.

== Algoritmos de entrenamiento
<sec-cap27_algoritmo>

El siguiente pseudocódigo describe el procedimiento de entrenamiento de TARNet y su extensión CFRNet. La diferencia clave es la penalización IPM que fuerza el balance de la representación latente $Phi(X)$ entre grupos de tratamiento y control.

#algorithm("Entrenamiento TARNet/CFRNet")[
  #kwin[Entrada][Datos $(X_i, D_i, Y_i)_(i=1)^n$, red de representación $Phi$ con cabezas $h_0, h_1$, épocas $E$, tasa de aprendizaje $eta$, peso IPM $alpha >= 0$]
  #kwout[Salida][Estimación del CATE $hat(tau)(x) = h_1(Phi(x)) - h_0(Phi(x))$]
  #for-loop(`epoch`, 1, `E`)[
    Calcular representación $Phi_i = Phi(X_i)$ para todo $i$ \
    Predecir $hat(Y)_i = h_(D_i)(Phi_i)$ \
    $cal(L)_"MSE" <- (1 / n) sum_(i=1)^n (Y_i - hat(Y)_i)^2$ \
    *if* #h(2pt) CFRNet *then* \
    #h(1.5em) $"IPM" <- "MMD"({Phi_i : D_i = 0}, {Phi_i : D_i = 1})$ \
    #h(1.5em) $cal(L) <- cal(L)_"MSE" + alpha dot.c "IPM"$ \
    *else* \
    #h(1.5em) $cal(L) <- cal(L)_"MSE"$ \
    *end if* \
    Actualizar parámetros con $nabla cal(L)$ vía Adam($eta$)
  ]
  #return-stmt[$hat(tau)(x) = h_1(Phi(x)) - h_0(Phi(x))$]
] <alg-tarnet-cfrnet-training>

#algorithm("DeepIV en dos etapas")[
  #kwin[Entrada][Datos $(Z_i, X_i, D_i, Y_i)_(i=1)^n$, familia de redes para la densidad $p_theta (d | z, x)$ y para la función estructural $h_phi (d, x)$, número de simulaciones $M$]
  #kwout[Salida][Función estructural estimada $h_phi (d, x)$]
  *Etapa 1.* Ajustar $theta$ maximizando $sum_i log p_theta (D_i | Z_i, X_i)$. \
  *Etapa 2.* Para cada $i$, simular $tilde(D)_(i 1), dots, tilde(D)_(i M)$ de $p_theta (dot | Z_i, X_i)$. \
  Ajustar $phi$ minimizando $sum_i (Y_i - (1 / M) sum_(m=1)^M h_phi (tilde(D)_(i m), X_i))^2$. \
  #return-stmt[$h_phi$]
] <alg-deepiv>

#capa-impl[
== Implementación en Python
<sec-cap27_implementacion>

#figure(
  kind: raw,
  caption: [Implementación de TARNet en PyTorch.],
  ```python
import torch
import torch.nn as nn
import torch.optim as optim
import numpy as np
from torch.utils.data import DataLoader, TensorDataset

class TARNet(nn.Module):
    def __init__(self, in_dim, rep_dim=64, hidden=128):
        super().__init__()
        # Representacion compartida
        self.rep = nn.Sequential(
            nn.Linear(in_dim, hidden), nn.ReLU(),
            nn.Linear(hidden, hidden), nn.ReLU(),
            nn.Linear(hidden, rep_dim),
        )
        # Cabezas separadas para D=0 y D=1
        self.h0 = nn.Sequential(
            nn.Linear(rep_dim, hidden), nn.ReLU(),
            nn.Linear(hidden, 1),
        )
        self.h1 = nn.Sequential(
            nn.Linear(rep_dim, hidden), nn.ReLU(),
            nn.Linear(hidden, 1),
        )
    def forward(self, X, D):
        Phi = self.rep(X)
        out = torch.where(D.unsqueeze(-1) == 1, self.h1(Phi), self.h0(Phi))
        return out.squeeze(-1)
    def predict_cate(self, X):
        Phi = self.rep(X)
        return (self.h1(Phi) - self.h0(Phi)).squeeze()

# DGP
def make_dgp(n=3000, seed=0):
    rng = np.random.default_rng(seed)
    X = rng.uniform(-1, 1, (n, 10))
    e = 1/(1 + np.exp(-1.0 - 0.5*X[:, 0]))
    D = (rng.uniform(size=n) < e).astype(np.float32)
    tau = 2 + 3*X[:, 0] - X[:, 1]**2
    mu0 = np.sin(X[:, 2]) + X[:, 3]
    Y = mu0 + D * tau + rng.standard_normal(n) * 0.5
    return X.astype(np.float32), D.astype(np.float32), Y.astype(np.float32), tau

X, D, Y, tau_true = make_dgp(3000, seed=42)
X_t = torch.from_numpy(X); D_t = torch.from_numpy(D); Y_t = torch.from_numpy(Y)

# Entrenamiento
torch.manual_seed(42)
model = TARNet(in_dim=X.shape[1])
opt = optim.Adam(model.parameters(), lr=1e-3, weight_decay=1e-4)
for epoch in range(200):
    model.train()
    opt.zero_grad()
    pred = model(X_t, D_t)
    loss = ((pred - Y_t)**2).mean()
    loss.backward()
    opt.step()
    if epoch % 50 == 0:
        print(f"Epoch {epoch}: loss={loss.item():.4f}")

# Evaluacion
model.eval()
with torch.no_grad():
    cate_hat = model.predict_cate(X_t).numpy()
rmse = np.sqrt(np.mean((cate_hat - tau_true)**2))
print(f"RMSE en CATE: {rmse:.4f}")
```
) <lst-tarnet>

=== CFRNet con penalización MMD
<sec-cap27_cfrnet_mmd>

#figure(
  kind: raw,
  caption: [CFRNet con penalización MMD.],
  ```python
def mmd_loss(Phi0, Phi1, sigma=1.0):
    """Maximum Mean Discrepancy entre representaciones de tratados y controles."""
    def kernel(A, B):
        # RBF kernel
        diff = A.unsqueeze(1) - B.unsqueeze(0)
        return torch.exp(-diff.pow(2).sum(-1) / (2 * sigma**2))
    K00 = kernel(Phi0, Phi0); K11 = kernel(Phi1, Phi1); K01 = kernel(Phi0, Phi1)
    return K00.mean() + K11.mean() - 2 * K01.mean()

class CFRNet(TARNet):
    def forward_loss(self, X, D, Y, alpha=1.0):
        Phi = self.rep(X)
        pred = torch.where(D.unsqueeze(-1) == 1, self.h1(Phi), self.h0(Phi)).squeeze(-1)
        mse = ((pred - Y)**2).mean()
        Phi0 = Phi[D == 0]; Phi1 = Phi[D == 1]
        if len(Phi0) > 1 and len(Phi1) > 1:
            mmd = mmd_loss(Phi0, Phi1)
        else:
            mmd = torch.tensor(0.0)
        return mse + alpha * mmd

# Entrenamiento CFRNet
model_cfr = CFRNet(in_dim=X.shape[1])
opt = optim.Adam(model_cfr.parameters(), lr=1e-3, weight_decay=1e-4)
for epoch in range(200):
    model_cfr.train(); opt.zero_grad()
    loss = model_cfr.forward_loss(X_t, D_t, Y_t, alpha=1.0)
    loss.backward(); opt.step()
    if epoch % 50 == 0:
        print(f"Epoch {epoch}: loss={loss.item():.4f}")

model_cfr.eval()
with torch.no_grad():
    cate_cfr = model_cfr.predict_cate(X_t).numpy()
print(f"CFRNet RMSE: {np.sqrt(np.mean((cate_cfr - tau_true)**2)):.4f}")
```
) <lst-cfrnet>
]

== Arquitectura de TARNet/CFRNet
<sec-cap27_arquitectura>

La figura #ref(<fig-cap27-tarnet>, supplement: none) muestra la arquitectura común de TARNet y CFRNet. Una red de representación compartida $Phi(X)$ mapea las covariables a un embedding de menor dimensión; dos cabezas separadas $h_0, h_1$ estiman $mu_0(Phi(X))$ y $mu_1(Phi(X))$ respectivamente. El CATE se obtiene por diferencia: $hat(tau)(X) = h_1(Phi(X)) - h_0(Phi(X))$. CFRNet añade a TARNet una penalización IPM (Integral Probability Metric) que fuerza el balance entre las distribuciones de $Phi(X)$ para tratados y controles, reduciendo el desbalance observado de covariables en el espacio de representación, bajo el supuesto previo de no confusión.

#figure(
  image("../figuras/fig_cap27_tarnet_arch.png", width: 95%),
  caption: [Esquema elaborado para esta edición a partir de la arquitectura de TARNet / CFRNet descrita por Shalit, Johansson y Sontag (2017). La capa de representación compartida $Phi$ es seguida por dos cabezas separadas $h_0, h_1$ para $D = 0$ y $D = 1$. CFRNet añade una penalización IPM (Wasserstein o MMD) que fuerza el balance entre las distribuciones de $Phi(X)$ condicionales al tratamiento.],
) <fig-cap27-tarnet>

== Caso empírico y validación
<sec-cap27_caso_empirico>

#caso-canonico("Balance perfecto, información nula")[
  Diez covariables independientes y uniformes en $[-1, 1]$. El tratamiento se asigna con probabilidad $1 / (1 + e^(-1 - 0.5 x_0))$, el resultado sin tratamiento es $mu_0 = sin(x_2) + x_3$ y el efecto es $tau(x) = 2 + 3 x_0 - x_1^2$, de modo que el efecto es heterogéneo y quienes reciben el tratamiento tienen $x_0$ más alto.

  Una representación $Phi$ constante logra balance perfecto, porque la distribución de $Phi(X)$ es la misma para tratados y controles, y la IPM vale cero. Pero entonces las dos cabezas ven la misma entrada y la estimación del efecto es una constante, la diferencia de medias entre tratados y controles. Esa constante estima el efecto sobre los tratados, que es mayor que el efecto medio, y ningún valor constante puede acertar el efecto individual: el error cuadrático medio es al menos la varianza del propio efecto, $"Var"(tau) = "Var"(3 x_0) + "Var"(x_1^2) = 3.00 + 0.09 = 3.09$, es decir, una desviación típica de 1,76 unidades en un efecto cuyo promedio ronda 1,67.

  Un valor de $alpha$ suficientemente grande empuja la representación hacia ese extremo. Un valor intermedio puede ayudar o perjudicar según el DGP, y por eso $alpha$ se valida, no se fija.
]

La ventaja de los métodos profundos aparece, si aparece, cuando el DGP tiene no linealidades complejas o interacciones de alto orden y la muestra es grande; en DGPs simples o con muestras pequeñas los métodos basados en árboles son competitivos y más rápidos de entrenar. Cuál domina en un caso concreto es una pregunta empírica que depende del DGP y del tamaño muestral, y la literatura no encuentra una arquitectura que gane siempre (#cite(<curth2021inductive>, form: "prose")).

#intuicion[
*Caja de profundización: Representaciones balanceadas y diagnóstico de balance*

*Objetivo.* Entender por qué TARNet/CFRNet aprenden una representación intermedia y cómo verificar si está bien balanceada.

*La idea.* En lugar de estimar $mu_1(X)$ y $mu_0(X)$ directamente sobre las covariables originales, la red primero aprende una "representación" compacta $Phi(X)$. Luego estima los outcomes a partir de esa representación.

*¿Por qué balancear?* Si la distribución de $Phi(X)$ es similar entre tratados y controles, cualquier diferencia en outcomes se debe más probablemente al tratamiento y no a confusores observados. CFRNet agrega una penalización que fuerza este balance.

*Cómo diagnosticar el balance.* Una vez entrenada la red, podemos calcular:
- Diferencia de medias de $Phi(X)$ entre tratados y controles (debe ser cercana a cero).
- MMD (Maximum Mean Discrepancy): distancia entre las dos distribuciones.
- Si el MMD es grande, la red no está balanceando bien y podemos aumentar el peso de la penalización.

*Advertencia importante.* El balance de $Phi(X)$ NO garantiza identificación causal. Si hay confusores no observados que no están en $X$, ninguna red puede solucionarlo.
]

== Límites y errores comunes
<sec-cap27_limites>

#riesgos[
  #figure(
    caption: [Riesgos comunes en deep causal learning],
    table(
      columns: (1fr, 1fr, 1fr, 1fr),
      align: (left, left, left, left),
      stroke: none,
      table.hline(stroke: 0.8pt),
      table.header([*Riesgo*], [*Consecuencia*], [*Diagnóstico*], [*Mitigación*]),
      table.hline(stroke: 0.4pt),
      [Balance sin identificación], [Falsa seguridad: balancear $Phi(X)$ no crea el supuesto de no confusión], [DAG y supuestos declarados; el balance es sobre covariables *observadas*], [No confusión explícita y justificada; ningún ajuste arquitectónico la sustituye],
      [Overfitting profundo], [Mala generalización], [Train/test loss], [Regularización, _early stopping_, validación],
      [$alpha$ (peso IPM) fijado sin validar], [Representación sobre-balanceada y poco informativa; error en $tau$ mayor que sin penalización @curth2021inductive], [Barrido de $alpha$ incluyendo $alpha = 0$ (TARNet) y comparación del error en $tau$ sobre un DGP con _ground truth_], [Tratar $alpha$ como hiperparámetro a validar y reportar su valor; no asumir que CFRNet domina a TARNet],
      [Reportar $hat(tau)(x)$ sin cuantificar incertidumbre], [Decisiones sobre personas basadas en un punto sin intervalo], [Verificar qué objeto cubre el IC del pipeline], [Usar la red como _nuisance_ dentro de DML (@sec-cap27_inferencia), o _bootstrap_ asumiendo su costo; no llamar intervalo individual al conforme del pseudoresultado (@sec-cap14_conformal)],
      table.hline(stroke: 0.8pt),
    )
  ) <tab-riesgos-cap13>
]

Los métodos profundos suelen requerir muestras grandes y un ajuste cuidadoso de hiperparámetros; con muestras pequeñas, los basados en árboles son preferibles. Dos límites merecen un tratamiento más detenido, porque la literatura reciente los ha precisado y en ambos casos la lectura ingenua del método es la equivocada.

=== ¿Balancear la representación ayuda realmente?
<sec-cap27_limites_balance>

La penalización IPM de CFRNet se presenta habitualmente como una mejora inequívoca sobre TARNet, y la ecuación #ref(<eq-cfrnet-loss>, supplement: none) lo sugiere: forzar $Phi(X | D=0)$ y $Phi(X | D=1)$ a parecerse debería reducir el término de discrepancia de la cota de #cite(<shalit2017estimating>, form: "prose"). #cite(<curth2021inductive>, form: "prose") muestran que el argumento es más frágil de lo que parece, y por una razón instructiva: la cota que justifica la penalización es *laxa*, y minimizarla no equivale a minimizar el error en $tau$.

El mecanismo del problema es directo. El balance es una restricción sobre la representación compartida; hacerla más fuerte reduce la información sobre $X$ que $Phi$ conserva, y parte de esa información puede ser necesaria para estimar bien $mu_0$ y $mu_1$. Con $alpha$ grande, la red aprende una representación tan balanceada como poco informativa; en el extremo, $Phi$ constante logra balance perfecto y error máximo, como en el caso canónico de más arriba. Empíricamente, el $alpha$ óptimo depende del DGP y con frecuencia es cercano a cero; TARNet sin penalización es un competidor serio, no un _baseline_ trivial.

La lección que Curth y van der Schaar extraen, y que este capítulo adopta, es que lo determinante no es la penalización IPM sino los *sesgos inductivos* de la arquitectura: cómo se comparte información entre las dos cabezas, si se modela $tau$ directamente o por diferencia, si se usa el _propensity_ como entrada. Operativamente: $alpha$ debe tratarse como un hiperparámetro a validar, no como un interruptor que se activa porque "balancear es bueno", y su valor óptimo debe reportarse.

=== Redes como estimadores de _nuisance_ e inferencia válida
<sec-cap27_inferencia>

Es cierto que TARNet y CFRNet, tal como se han presentado, no producen intervalos de confianza: se optimiza una pérdida predictiva y no hay ninguna garantía distribucional sobre $hat(tau)(x)$. Pero sería inexacto concluir que la inferencia con redes neuronales sea un problema sin tratamiento teórico. Dos líneas de trabajo lo abordan directamente y conviene conocerlas.

#cite(<farrell2021deep>, form: "prose") establecen tasas de convergencia no asintóticas para redes profundas con activaciones ReLU y, sobre esa base, demuestran normalidad asintótica e inferencia válida para funcionales semiparamétricos, incluido el ATE, estimados con redes como _nuisance_. El resultado es exactamente la pieza que faltaba: muestra que las redes satisfacen la condición de tasa $sqrt(n) a_n^2 -> 0$ del @cap-ortogonalidad bajo condiciones explícitas sobre profundidad, anchura y suavidad de la función objetivo. La consecuencia práctica es que *usar una red como estimador de cada _nuisance_ dentro de DML está respaldado por la teoría*, y es probablemente la forma más sensata de combinar _deep learning_ e inferencia causal en producción hoy.

La segunda línea automatiza el paso de ortogonalización. #cite(<chernozhukov2022riesznet>, form: "prose") observan que el término de corrección de un score ortogonal es siempre un *representador de Riesz* del funcional de interés, y proponen aprenderlo directamente con una red (RieszNet) o un bosque (ForestRiesz), en lugar de derivarlo a mano para cada estimando. Esto convierte la construcción del score, que en los @cap-ortogonalidad y @cap-dml se hizo analíticamente para el modelo lineal parcial y el modelo de regresión interactivo, en un problema de aprendizaje, y extiende DML a funcionales para los que nadie ha derivado la fórmula.

La conclusión operativa para este capítulo es una inversión de la práctica habitual: en vez de usar una red para estimar $tau$ directamente y luego buscar cómo hacer inferencia sobre ella, conviene usar la red donde su capacidad de aproximación aporta, en los _nuisance_ de alta dimensión, y dejar la inferencia al aparato ortogonal que ya la tiene resuelta. El _bootstrap_ sobre TARNet/CFRNet sigue siendo una opción práctica para cuantificar incertidumbre, pero es costoso y sus garantías bajo regularización y optimización no convexa son mucho menos claras.

== Ejercicios propuestos
<sec-cap27_ejercicios>

=== Ejercicios teóricos
<sec-cap27_ejercicios_teoricos>

+ Muestre que si $Phi$ es constante la IPM vale cero y la estimación del CATE es constante. Calcule el menor error cuadrático medio posible para un efecto $tau(x) = 2 + 3 x_0 - x_1^2$ con $x_0, x_1$ independientes y uniformes en $[-1, 1]$.

+ Explique por qué balancear $Phi(X)$ no sustituye el supuesto de no confusión. Dé un ejemplo con un confusor no observado en el que el balance sobre $X$ sea perfecto y el efecto siga sesgado.

+ Explique por qué conviene usar una red como estimador de los _nuisance_ dentro de DML en lugar de estimar $tau$ directamente con TARNet. ¿Qué garantía se gana y qué se pierde?

+ En DeepIV, ¿por qué la regresión directa de $Y$ sobre $D$ y $X$ sesga $h$ y qué papel cumple el instrumento en la segunda etapa?

#capa-impl[
=== Ejercicios computacionales
<sec-cap27_ejercicios_computacionales>

+ Replique el #ref(<lst-tarnet>, supplement: [listado]) variando la profundidad de la red (1, 2, 3 capas ocultas). ¿Cuándo aparece overfitting?

+ Implemente CFRNet con penalización Wasserstein en lugar de MMD (usar #code[geomloss] o #code[POT]).

+ Compare TARNet, CFRNet y Causal Forest sobre un DGP con no linealidades crecientes. ¿En qué punto el deep causal supera a los árboles?

+ Barra el peso de la penalización IPM en $alpha in {0, 0.1, 1, 10, 100}$ y grafique el error en $tau$ contra el MMD de la representación. Verifique que el $alpha$ que minimiza el MMD *no* es el que minimiza el error, y relacione el resultado con la @sec-cap27_limites_balance.

+ Use la red TARNet (sin las cabezas causales: solo la representación más una cabeza) como #code[model_y] y #code[model_t] dentro de #code[LinearDML], y compare el ATE con IC obtenido así frente al ATE que produce TARNet directamente por promedio de $hat(tau)(x)$. ¿Cuál de los dos permite reportar un intervalo con respaldo teórico, y por qué (@sec-cap27_inferencia)?

+ Implemente DeepIV sobre el dataset #code[iv_noncompliance] (sintético) y verifique que recupera la función estructural conocida.
]

== Lecturas complementarias
<sec-cap27_lecturas>

#cite(<shalit2017estimating>, form: "prose") es la referencia fundacional de TARNet/CFRNet y de la cota de error con IPM. #cite(<hartford2017deep>, form: "prose") introduce DeepIV. #cite(<louizos2017causal>, form: "prose") propone CEVAE. #cite(<shi2019adaptively>, form: "prose") extiende a DragonNet, que incorpora el _propensity_ como cabeza adicional y aplica una corrección dirigida al estimando.

Tres lecturas son indispensables para no quedarse en el estado del arte de 2017. #cite(<curth2021inductive>, form: "prose") revisan críticamente la familia completa desde el ángulo de los sesgos inductivos y son la fuente del análisis de la @sec-cap27_limites_balance sobre los límites de la representación balanceada; su comparación empírica sistemática es también el mejor punto de partida para elegir arquitectura. #cite(<farrell2021deep>, form: "prose") establecen las tasas y la teoría de inferencia que hacen de las redes profundas un _nuisance learner_ legítimo dentro de DML. #cite(<chernozhukov2022riesznet>, form: "prose") proponen aprender el representador de Riesz, y con él el score ortogonal, en lugar de derivarlo analíticamente, extendiendo el aparato de la Parte II a funcionales arbitrarios.
