use std::collections::BTreeSet;
use std::fs;
use std::path::Path;

use anyhow::{bail, Context, Result};
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct Contract {
    pub schema_version: String,
    pub dataset_id: String,
    pub description: String,
    pub source: SourcePin,
    pub unit_id: ColumnContract,
    pub treatment: ColumnContract,
    pub outcome: ColumnContract,
    pub epoch: Option<ColumnContract>,
    pub features: Vec<FeatureContract>,
    pub split: SplitSpec,
    pub estimator: EstimatorSpec,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SourcePin {
    pub raw_url: String,
    pub documentation_url: String,
    pub expected_bytes: u64,
    pub expected_sha256: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ColumnContract {
    pub name: String,
    pub dtype: DataType,
    pub required: bool,
    pub minimum: Option<f64>,
    pub maximum: Option<f64>,
    pub categories: Option<Vec<String>>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct FeatureContract {
    #[serde(flatten)]
    pub column: ColumnContract,
    pub available_at: String,
    pub causal_role: String,
    pub transform: NumericTransform,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum DataType {
    String,
    Integer,
    Number,
    Binary,
    Categorical,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum NumericTransform {
    Identity,
    Log1p,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SplitSpec {
    pub strategy: SplitStrategy,
    pub protocol_salt: String,
    pub train_fraction: f64,
    pub calibration_fraction: f64,
    pub holdout_fraction: f64,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum SplitStrategy {
    EntityHash,
    EpochDisjoint,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
#[serde(deny_unknown_fields)]
pub struct EstimatorSpec {
    pub name: String,
    pub folds: usize,
    pub logistic_max_iterations: usize,
    pub logistic_tolerance: f64,
    pub ridge: f64,
    pub primary_propensity_clip: f64,
    pub sensitivity_propensity_clips: Vec<f64>,
    pub confidence_level: f64,
}

impl Contract {
    pub fn load(path: &Path) -> Result<Self> {
        let bytes = fs::read(path).with_context(|| format!("reading {}", path.display()))?;
        let contract: Self = serde_json::from_slice(&bytes)
            .with_context(|| format!("parsing strict contract {}", path.display()))?;
        contract.validate()?;
        Ok(contract)
    }

    pub fn validate(&self) -> Result<()> {
        if self.schema_version != "1.0" {
            bail!("contract schema_version must be 1.0");
        }
        if self.dataset_id.trim().is_empty() || self.description.trim().is_empty() {
            bail!("dataset_id and description must not be empty");
        }
        if self.source.expected_bytes == 0
            || self.source.expected_sha256.len() != 64
            || !self
                .source
                .expected_sha256
                .bytes()
                .all(|b| b.is_ascii_hexdigit() && !b.is_ascii_uppercase())
        {
            bail!("source pin requires nonzero bytes and lowercase SHA-256");
        }
        if !self.source.raw_url.starts_with("https://")
            || !self.source.documentation_url.starts_with("https://")
        {
            bail!("source and documentation URLs must use HTTPS");
        }
        for (role, column) in [
            ("unit_id", &self.unit_id),
            ("treatment", &self.treatment),
            ("outcome", &self.outcome),
        ] {
            validate_column(column).with_context(|| format!("invalid {role} contract"))?;
        }
        if self.unit_id.dtype != DataType::String {
            bail!("unit_id must have string dtype");
        }
        if self.treatment.dtype != DataType::Binary {
            bail!("treatment must have binary dtype");
        }
        if !matches!(self.outcome.dtype, DataType::Number | DataType::Integer) {
            bail!("outcome must be numeric");
        }
        if let Some(epoch) = &self.epoch {
            validate_column(epoch).context("invalid epoch contract")?;
            if epoch.dtype != DataType::Integer {
                bail!("epoch must have integer dtype");
            }
        }
        if self.features.is_empty() {
            bail!("at least one adjustment feature is required");
        }
        let mut names = BTreeSet::new();
        for feature in &self.features {
            validate_column(&feature.column)
                .with_context(|| format!("invalid feature {}", feature.column.name))?;
            if feature.available_at.trim().is_empty()
                || feature.causal_role != "pre_treatment_adjustment"
            {
                bail!("features require an availability timestamp and pre-treatment role");
            }
            if feature.column.transform_is_invalid(feature.transform) {
                bail!("categorical features cannot have numeric transforms");
            }
            if feature.transform == NumericTransform::Log1p
                && feature.column.minimum.is_none_or(|minimum| minimum < 0.0)
            {
                bail!("log1p features require a declared nonnegative minimum");
            }
        }
        for column in std::iter::once(&self.unit_id)
            .chain(std::iter::once(&self.treatment))
            .chain(std::iter::once(&self.outcome))
            .chain(self.epoch.iter())
            .chain(self.features.iter().map(|feature| &feature.column))
        {
            if !names.insert(column.name.clone()) {
                bail!("duplicate contract column {}", column.name);
            }
        }
        let fractions = [
            self.split.train_fraction,
            self.split.calibration_fraction,
            self.split.holdout_fraction,
        ];
        if fractions
            .iter()
            .any(|value| !value.is_finite() || *value <= 0.0)
            || (fractions.iter().sum::<f64>() - 1.0).abs() > 1e-9
        {
            bail!("split fractions must be positive and sum exactly to one");
        }
        if self.split.protocol_salt.trim().is_empty() {
            bail!("split protocol_salt is required");
        }
        if self.split.strategy == SplitStrategy::EpochDisjoint && self.epoch.is_none() {
            bail!("epoch_disjoint strategy requires an epoch column")
        }
        let e = &self.estimator;
        if e.name != "cross_fitted_aipw_logistic_linear_v1"
            || !(2..=20).contains(&e.folds)
            || e.logistic_max_iterations == 0
            || !e.logistic_tolerance.is_finite()
            || e.logistic_tolerance <= 0.0
            || !e.ridge.is_finite()
            || e.ridge < 0.0
            || !(0.5..1.0).contains(&e.confidence_level)
        {
            bail!("unsupported or invalid estimator specification");
        }
        for clip in
            std::iter::once(&e.primary_propensity_clip).chain(e.sensitivity_propensity_clips.iter())
        {
            if !clip.is_finite() || *clip <= 0.0 || *clip >= 0.5 {
                bail!("propensity clips must lie strictly between zero and 0.5");
            }
        }
        if e.sensitivity_propensity_clips.is_empty() {
            bail!("predeclare at least one sensitivity clip");
        }
        Ok(())
    }

    pub fn encoded_feature_names(&self) -> Vec<String> {
        let mut names = Vec::new();
        for feature in &self.features {
            if feature.column.dtype == DataType::Categorical {
                let categories = feature.column.categories.as_ref().expect("validated");
                // The first, contract-pinned category is the reference level.
                for category in categories.iter().skip(1) {
                    names.push(format!("{}={}", feature.column.name, category));
                }
            } else {
                names.push(feature.column.name.clone());
            }
        }
        names
    }
}

fn validate_column(column: &ColumnContract) -> Result<()> {
    if column.name.trim().is_empty() {
        bail!("column name must not be empty");
    }
    if let (Some(minimum), Some(maximum)) = (column.minimum, column.maximum) {
        if !minimum.is_finite() || !maximum.is_finite() || minimum > maximum {
            bail!("invalid numeric range for {}", column.name);
        }
    }
    match column.dtype {
        DataType::Categorical => {
            let categories = column
                .categories
                .as_ref()
                .context("categorical column requires ordered categories")?;
            if categories.len() < 2 || categories.iter().any(|category| category.is_empty()) {
                bail!("categorical column requires at least two nonempty categories");
            }
            let unique = categories.iter().collect::<BTreeSet<_>>();
            if unique.len() != categories.len() {
                bail!("categorical levels must be unique");
            }
        }
        DataType::String => {
            if column.minimum.is_some() || column.maximum.is_some() || column.categories.is_some() {
                bail!("string columns cannot have numeric ranges or numeric encodings");
            }
        }
        _ if column.categories.is_some() => bail!("only categorical columns declare categories"),
        _ => {}
    }
    Ok(())
}

impl ColumnContract {
    fn transform_is_invalid(&self, transform: NumericTransform) -> bool {
        self.dtype == DataType::Categorical && transform != NumericTransform::Identity
    }
}
