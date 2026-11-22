use anyhow::{bail, Result};
use serde::{Deserialize, Serialize};

use crate::contract::EstimatorSpec;
use crate::data::Record;

#[derive(Debug, Clone)]
pub struct NuisanceModels {
    standardizer: Standardizer,
    propensity: RegressionModel,
    outcome_control: RegressionModel,
    outcome_treated: RegressionModel,
    pub diagnostics: NuisanceDiagnostics,
}

#[derive(Debug, Clone)]
struct Standardizer {
    means: Vec<f64>,
    scales: Vec<f64>,
}

#[derive(Debug, Clone)]
struct RegressionModel {
    intercept: f64,
    coefficients: Vec<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NuisanceDiagnostics {
    pub standardization_means: Vec<f64>,
    pub standardization_scales: Vec<f64>,
    pub propensity: LogisticDiagnostics,
    pub outcome_control: OutcomeDiagnostics,
    pub outcome_treated: OutcomeDiagnostics,
    pub deployed_propensity_coefficients: Vec<f64>,
    pub deployed_outcome_control_coefficients: Vec<f64>,
    pub deployed_outcome_treated_coefficients: Vec<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct LogisticDiagnostics {
    pub observations: usize,
    pub iterations: usize,
    pub converged: bool,
    pub separation_suspected: bool,
    pub maximum_absolute_coefficient: f64,
    pub minimum_raw_probability: f64,
    pub maximum_raw_probability: f64,
    pub coefficients_include_intercept_first: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct OutcomeDiagnostics {
    pub observations: usize,
    pub coefficients_include_intercept_first: bool,
    pub residual_sum_of_squares: f64,
}

impl NuisanceModels {
    pub fn fit(records: &[&Record], spec: &EstimatorSpec) -> Result<Self> {
        if records.is_empty() {
            bail!("cannot fit nuisance models on an empty sample");
        }
        if !records.iter().any(|record| record.treatment == 0.0)
            || !records.iter().any(|record| record.treatment == 1.0)
        {
            bail!("nuisance fitting requires both treatment levels");
        }
        let standardizer = Standardizer::fit(records);
        let design = standardizer.transform(records);
        let treatment = records
            .iter()
            .map(|record| record.treatment)
            .collect::<Vec<_>>();
        let logistic = fit_logistic(&design, &treatment, spec)?;
        let outcome_control = fit_outcome(&design, records, 0.0, spec.ridge)?;
        let outcome_treated = fit_outcome(&design, records, 1.0, spec.ridge)?;
        Ok(Self {
            standardizer: standardizer.clone(),
            propensity: logistic.model.clone(),
            outcome_control: outcome_control.model.clone(),
            outcome_treated: outcome_treated.model.clone(),
            diagnostics: NuisanceDiagnostics {
                standardization_means: standardizer.means,
                standardization_scales: standardizer.scales,
                propensity: logistic.diagnostics,
                outcome_control: outcome_control.diagnostics,
                outcome_treated: outcome_treated.diagnostics,
                deployed_propensity_coefficients: logistic.model.with_intercept(),
                deployed_outcome_control_coefficients: outcome_control.model.with_intercept(),
                deployed_outcome_treated_coefficients: outcome_treated.model.with_intercept(),
            },
        })
    }

    pub fn predict(&self, record: &Record) -> NuisancePrediction {
        let x = self.standardizer.transform_row(&record.features);
        let raw_propensity = self.propensity.predict_logistic(&x);
        NuisancePrediction {
            raw_propensity,
            outcome_control: self.outcome_control.predict_linear(&x),
            outcome_treated: self.outcome_treated.predict_linear(&x),
        }
    }
}

#[derive(Debug, Clone, Copy)]
pub struct NuisancePrediction {
    pub raw_propensity: f64,
    pub outcome_control: f64,
    pub outcome_treated: f64,
}

impl Standardizer {
    fn fit(records: &[&Record]) -> Self {
        let p = records[0].features.len();
        let n = records.len() as f64;
        let mut means = vec![0.0; p];
        for record in records {
            if record.features.len() != p {
                panic!("validated feature vectors must have one dimension");
            }
            for (mean, value) in means.iter_mut().zip(&record.features) {
                *mean += value / n;
            }
        }
        let scales = (0..p)
            .map(|column| {
                let variance = records
                    .iter()
                    .map(|record| (record.features[column] - means[column]).powi(2))
                    .sum::<f64>()
                    / n;
                let scale = variance.sqrt();
                if scale < 1e-12 {
                    1.0
                } else {
                    scale
                }
            })
            .collect();
        Self { means, scales }
    }

    fn transform(&self, records: &[&Record]) -> Vec<Vec<f64>> {
        records
            .iter()
            .map(|record| self.transform_row(&record.features))
            .collect()
    }

    fn transform_row(&self, row: &[f64]) -> Vec<f64> {
        row.iter()
            .zip(&self.means)
            .zip(&self.scales)
            .map(|((value, mean), scale)| (value - mean) / scale)
            .collect()
    }
}

impl RegressionModel {
    fn with_intercept(&self) -> Vec<f64> {
        std::iter::once(self.intercept)
            .chain(self.coefficients.iter().copied())
            .collect()
    }

    fn predict_linear(&self, x: &[f64]) -> f64 {
        self.intercept + dot(&self.coefficients, x)
    }

    fn predict_logistic(&self, x: &[f64]) -> f64 {
        sigmoid(self.predict_linear(x))
    }
}

struct LogisticFit {
    model: RegressionModel,
    diagnostics: LogisticDiagnostics,
}

fn fit_logistic(design: &[Vec<f64>], y: &[f64], spec: &EstimatorSpec) -> Result<LogisticFit> {
    let p = design[0].len() + 1;
    let mut beta = vec![0.0; p];
    let mut converged = false;
    let mut iterations = 0;
    for iteration in 0..spec.logistic_max_iterations {
        iterations = iteration + 1;
        let mut gradient = vec![0.0; p];
        let mut hessian = vec![vec![0.0; p]; p];
        for (row, outcome) in design.iter().zip(y) {
            let full = with_intercept(row);
            let linear = dot(&beta, &full);
            let probability = sigmoid(linear);
            let weight = (probability * (1.0 - probability)).max(1e-12);
            for j in 0..p {
                gradient[j] += full[j] * (outcome - probability);
                for k in 0..=j {
                    let contribution = full[j] * weight * full[k];
                    hessian[j][k] += contribution;
                    if k != j {
                        hessian[k][j] += contribution;
                    }
                }
            }
        }
        for j in 0..p {
            if j > 0 {
                gradient[j] -= spec.ridge * beta[j];
                hessian[j][j] += spec.ridge;
            }
        }
        let step = solve(hessian, gradient)?;
        for (coefficient, change) in beta.iter_mut().zip(&step) {
            *coefficient += change;
        }
        if step
            .iter()
            .all(|value| value.abs() < spec.logistic_tolerance)
        {
            converged = true;
            break;
        }
        if beta.iter().any(|value| !value.is_finite()) {
            bail!("logistic IRLS produced a non-finite coefficient");
        }
    }
    let probabilities = design
        .iter()
        .map(|row| sigmoid(dot(&beta, &with_intercept(row))))
        .collect::<Vec<_>>();
    let maximum_absolute_coefficient = beta.iter().map(|v| v.abs()).fold(0.0, f64::max);
    let minimum_raw_probability = probabilities.iter().copied().fold(1.0, f64::min);
    let maximum_raw_probability = probabilities.iter().copied().fold(0.0, f64::max);
    let separation_suspected = !converged
        || maximum_absolute_coefficient > 50.0
        || minimum_raw_probability < 1e-10
        || maximum_raw_probability > 1.0 - 1e-10;
    Ok(LogisticFit {
        model: RegressionModel {
            intercept: beta[0],
            coefficients: beta[1..].to_vec(),
        },
        diagnostics: LogisticDiagnostics {
            observations: design.len(),
            iterations,
            converged,
            separation_suspected,
            maximum_absolute_coefficient,
            minimum_raw_probability,
            maximum_raw_probability,
            coefficients_include_intercept_first: true,
        },
    })
}

struct OutcomeFit {
    model: RegressionModel,
    diagnostics: OutcomeDiagnostics,
}

fn fit_outcome(
    design: &[Vec<f64>],
    records: &[&Record],
    treatment: f64,
    ridge: f64,
) -> Result<OutcomeFit> {
    let selected = design
        .iter()
        .zip(records)
        .filter(|(_, record)| record.treatment == treatment)
        .map(|(row, record)| (with_intercept(row), record.outcome))
        .collect::<Vec<_>>();
    if selected.is_empty() {
        bail!("outcome regression has no observations for treatment={treatment}");
    }
    let p = design[0].len() + 1;
    let mut xtx = vec![vec![0.0; p]; p];
    let mut xty = vec![0.0; p];
    for (row, outcome) in &selected {
        for j in 0..p {
            xty[j] += row[j] * outcome;
            for k in 0..p {
                xtx[j][k] += row[j] * row[k];
            }
        }
    }
    for (j, row) in xtx.iter_mut().enumerate().skip(1) {
        row[j] += ridge;
    }
    let beta = solve(xtx, xty)?;
    let residual_sum_of_squares = selected
        .iter()
        .map(|(row, outcome)| (outcome - dot(&beta, row)).powi(2))
        .sum();
    Ok(OutcomeFit {
        model: RegressionModel {
            intercept: beta[0],
            coefficients: beta[1..].to_vec(),
        },
        diagnostics: OutcomeDiagnostics {
            observations: selected.len(),
            coefficients_include_intercept_first: true,
            residual_sum_of_squares,
        },
    })
}

/// Solve a dense linear system with partial pivoting. Inputs are consumed.
fn solve(mut matrix: Vec<Vec<f64>>, mut rhs: Vec<f64>) -> Result<Vec<f64>> {
    let n = rhs.len();
    for pivot in 0..n {
        let best = (pivot..n)
            .max_by(|left, right| {
                matrix[*left][pivot]
                    .abs()
                    .total_cmp(&matrix[*right][pivot].abs())
            })
            .expect("nonempty pivot range");
        matrix.swap(pivot, best);
        rhs.swap(pivot, best);
        let diagonal = matrix[pivot][pivot];
        if !diagonal.is_finite() || diagonal.abs() < 1e-12 {
            bail!("singular design matrix at column {pivot}");
        }
        for row in pivot + 1..n {
            let factor = matrix[row][pivot] / diagonal;
            let (previous, current) = matrix.split_at_mut(row);
            for (entry, pivot_entry) in current[0]
                .iter_mut()
                .skip(pivot)
                .zip(previous[pivot].iter().skip(pivot))
            {
                *entry -= factor * pivot_entry;
            }
            rhs[row] -= factor * rhs[pivot];
        }
    }
    let mut solution = vec![0.0; n];
    for row in (0..n).rev() {
        let remainder = (row + 1..n)
            .map(|column| matrix[row][column] * solution[column])
            .sum::<f64>();
        solution[row] = (rhs[row] - remainder) / matrix[row][row];
    }
    if solution.iter().any(|value| !value.is_finite()) {
        bail!("linear solver produced non-finite coefficients");
    }
    Ok(solution)
}

fn with_intercept(row: &[f64]) -> Vec<f64> {
    std::iter::once(1.0).chain(row.iter().copied()).collect()
}

fn dot(left: &[f64], right: &[f64]) -> f64 {
    left.iter().zip(right).map(|(a, b)| a * b).sum()
}

pub fn sigmoid(value: f64) -> f64 {
    if value >= 0.0 {
        1.0 / (1.0 + (-value).exp())
    } else {
        let exponential = value.exp();
        exponential / (1.0 + exponential)
    }
}

pub fn normal_critical_value(confidence: f64) -> f64 {
    inverse_standard_normal(0.5 + confidence / 2.0)
}

// Peter J. Acklam's inverse-normal rational approximation, with absolute
// error below approximately 1.15e-9 over its documented central/tail branches.
fn inverse_standard_normal(probability: f64) -> f64 {
    const A: [f64; 6] = [
        -3.969_683_028_665_376e1,
        2.209_460_984_245_205e2,
        -2.759_285_104_469_687e2,
        1.383_577_518_672_69e2,
        -3.066_479_806_614_716e1,
        2.506_628_277_459_239,
    ];
    const B: [f64; 5] = [
        -5.447_609_879_822_406e1,
        1.615_858_368_580_409e2,
        -1.556_989_798_598_866e2,
        6.680_131_188_771_972e1,
        -1.328_068_155_288_572e1,
    ];
    const C: [f64; 6] = [
        -7.784_894_002_430_293e-3,
        -3.223_964_580_411_365e-1,
        -2.400_758_277_161_838,
        -2.549_732_539_343_734,
        4.374_664_141_464_968,
        2.938_163_982_698_783,
    ];
    const D: [f64; 4] = [
        7.784_695_709_041_462e-3,
        3.224_671_290_700_398e-1,
        2.445_134_137_142_996,
        3.754_408_661_907_416,
    ];
    const TAIL: f64 = 0.024_25;
    if probability < TAIL {
        let q = (-2.0 * probability.ln()).sqrt();
        C.iter()
            .fold(0.0, |value, coefficient| value * q + coefficient)
            / (D.iter()
                .fold(0.0, |value, coefficient| value * q + coefficient)
                * q
                + 1.0)
    } else if probability > 1.0 - TAIL {
        let q = (-2.0 * (1.0 - probability).ln()).sqrt();
        -C.iter()
            .fold(0.0, |value, coefficient| value * q + coefficient)
            / (D.iter()
                .fold(0.0, |value, coefficient| value * q + coefficient)
                * q
                + 1.0)
    } else {
        let q = probability - 0.5;
        let r = q * q;
        A.iter()
            .fold(0.0, |value, coefficient| value * r + coefficient)
            * q
            / (B.iter()
                .fold(0.0, |value, coefficient| value * r + coefficient)
                * r
                + 1.0)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn linear_solver_recovers_a_known_system() {
        let answer =
            solve(vec![vec![3.0, 2.0], vec![1.0, 2.0]], vec![5.0, 5.0]).expect("nonsingular");
        assert!((answer[0] - 0.0).abs() < 1e-10);
        assert!((answer[1] - 2.5).abs() < 1e-10);
    }

    #[test]
    fn sigmoid_does_not_overflow() {
        assert_eq!(sigmoid(-1000.0), 0.0);
        assert_eq!(sigmoid(1000.0), 1.0);
        assert!((sigmoid(0.0) - 0.5).abs() < 1e-12);
    }

    #[test]
    fn normal_quantile_matches_reference() {
        assert!((normal_critical_value(0.95) - 1.959_963_984_540_054).abs() < 1e-8);
        assert!((normal_critical_value(0.90) - 1.644_853_626_951_472_2).abs() < 1e-8);
    }
}
