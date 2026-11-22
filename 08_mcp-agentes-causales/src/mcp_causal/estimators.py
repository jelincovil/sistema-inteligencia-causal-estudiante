"""estimators.py — Estimadores de referencia para sistemas causales.

AIPW con cross-fitting para ATE. DGP sintético para verificación.
No reemplaza econml/DoubleML: es la referencia mínima del MCP.
"""
from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any

import numpy as np
from scipy.optimize import minimize


@dataclass
class ResultadoAIPW:
    """Resultado de una estimación AIPW."""
    ate: float
    se: float
    ic: tuple[float, float]
    scores: np.ndarray
    ess: float
    ess_sobre_n: float
    rango_propensidad: tuple[float, float]
    semilla: int
    n: int
    k_folds: int
    n_tratados: int


def _sigmoid(z: np.ndarray) -> np.ndarray:
    return 1.0 / (1.0 + np.exp(-np.clip(z, -30, 30)))


def _fit_lineal(X: np.ndarray, y: np.ndarray) -> np.ndarray:
    M = np.column_stack([np.ones(len(y)), X])
    return np.linalg.lstsq(M, y, rcond=None)[0]


def _fit_propensity(X: np.ndarray, d: np.ndarray):
    med, sd = X.mean(0), np.clip(X.std(0), 1e-9, None)
    Z = (X - med) / sd
    def nll(w):
        eta = Z @ w[1:] + w[0]
        return float(np.sum(np.logaddexp(0, eta) - d * eta))
    r = minimize(nll, np.zeros(Z.shape[1] + 1), method="BFGS")
    def pred(Xn):
        Zn = (Xn - med) / sd
        return _sigmoid(Zn @ r.x[1:] + r.x[0])
    return pred


def estimar_aipw(
    X: np.ndarray,
    D: np.ndarray,
    Y: np.ndarray,
    k_folds: int = 5,
    semilla: int = 4242,
    trimming: float | None = None,
) -> ResultadoAIPW:
    """ATE por AIPW con cross-fitting.

    Args:
        X: matriz de covariables (n x p).
        D: vector de tratamiento binario.
        Y: vector de resultado.
        k_folds: número de folds para cross-fitting.
        semilla: semilla para la partición de folds.
        trimming: si se establece, recorta propensidad a [alpha, 1-alpha].

    Returns:
        ResultadoAIPW con ATE, SE, IC, scores, ESS y diagnósticos.
    """
    n = len(D)
    g = np.random.default_rng(semilla)
    folds = np.array_split(g.permutation(n), k_folds)

    mu1 = np.empty(n)
    mu0 = np.empty(n)
    e = np.empty(n)

    for fold in folds:
        mascara = np.ones(n, bool)
        mascara[fold] = False
        Xtr, Dtr, Ytr = X[mascara], D[mascara], Y[mascara]
        # Outcome por brazo
        b1 = _fit_lineal(Xtr[Dtr == 1], Ytr[Dtr == 1])
        b0 = _fit_lineal(Xtr[Dtr == 0], Ytr[Dtr == 0])
        Mfold = np.column_stack([np.ones(len(fold)), X[fold]])
        mu1[fold] = Mfold @ b1
        mu0[fold] = Mfold @ b0
        # Propensity
        pred = _fit_propensity(Xtr, Dtr)
        e[fold] = pred(X[fold])

    # Trimming opcional (cambia el estimando)
    if trimming is not None:
        alpha = trimming
        e = np.clip(e, alpha, 1 - alpha)

    # Score AIPW (influence function del ATE)
    scores = mu1 - mu0 + D * (Y - mu1) / e - (1 - D) * (Y - mu0) / (1 - e)

    ate = float(np.mean(scores))
    se = float(np.std(scores, ddof=1) / np.sqrt(n))
    ic = (ate - 1.96 * se, ate + 1.96 * se)

    # ESS de Kish
    w = np.where(D == 1, 1 / e, 1 / (1 - e))
    ess = float(w.sum() ** 2 / (w ** 2).sum())

    return ResultadoAIPW(
        ate=ate, se=se, ic=ic, scores=scores,
        ess=ess, ess_sobre_n=ess / n,
        rango_propensidad=(float(e.min()), float(e.max())),
        semilla=semilla, n=n, k_folds=k_folds,
        n_tratados=int(D.sum()),
    )


# ============================================================== DGP sintético

@dataclass
class DGPSintetico:
    """DGP de tratamiento binario con confusión observada.

    X ~ N(0, I_p)
    e(X) = sigmoid(beta @ X)
    D ~ Bernoulli(e(X))
    Y = tau * D + X @ gamma + epsilon

    La confusión viene de que beta y gamma comparten componentes.
    """
    n: int = 2000
    p: int = 4
    tau: float = 0.5
    beta: np.ndarray = field(default_factory=lambda: np.array([0.8, -0.4, 0, 0]))
    gamma: np.ndarray = field(default_factory=lambda: np.array([0.6, 0.3, 0.5, 0]))
    sigma: float = 1.0
    semilla: int = 20260701

    def generar(self, semilla: int | None = None) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        """Genera (X, D, Y) del DGP."""
        g = np.random.default_rng(semilla or self.semilla)
        X = g.normal(size=(self.n, self.p))
        e = _sigmoid(X @ self.beta)
        D = (g.random(self.n) < e).astype(int)
        Y = self.tau * D + X @ self.gamma + g.normal(scale=self.sigma, size=self.n)
        return X, D, Y

    def generar_ventana(
        self, n_ventana: int = 400, drift: float = 0.0,
        regla_cambio: bool = False, efecto_nuevo: float | None = None,
        semilla: int | None = None,
    ) -> tuple[np.ndarray, np.ndarray, np.ndarray]:
        """Genera una ventana de producción con cambios inyectables."""
        g = np.random.default_rng(semilla or (self.semilla + 1))
        X = g.normal(size=(n_ventana, self.p))
        if drift:
            X[:, 2] += drift
        beta = self.beta.copy()
        if regla_cambio:
            # Cambio de regla: la asignación pasa a depender de otra covariable
            beta = np.roll(beta, 1)
        e = _sigmoid(X @ beta)
        D = (g.random(n_ventana) < e).astype(int)
        tau = efecto_nuevo if efecto_nuevo is not None else self.tau
        Y = tau * D + X @ self.gamma + g.normal(scale=self.sigma, size=n_ventana)
        return X, D, Y
