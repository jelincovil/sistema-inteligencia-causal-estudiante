//! Deterministic data governance and doubly robust estimation.
//!
//! This crate validates data and computes statistics. It cannot verify
//! exchangeability, consistency, non-interference, or transportability.

pub mod contract;
pub mod data;
pub mod estimate;
pub mod numeric;
pub mod report;
pub mod split;

pub use contract::{ColumnContract, Contract, DataType, EstimatorSpec, SplitStrategy};
pub use data::{audit_path, prepare, AuditReport, Dataset, Preparation};
pub use estimate::{estimate_from_paths, CausalReport};
pub use report::{render_from_paths, RenderedReport};
pub use split::{validate_assignments_for_contract, Assignment, SplitRole};
