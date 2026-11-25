//! Explicit input limits for every document this crate loads.
//!
//! No document may be large or deep enough to abort, hang, or exhaust the
//! host. Every limit below is enforced before or during parsing and returns
//! a typed [`crate::ContractError`]. Violations are input-contract failures
//! (exit 2), not verdicts about the argument.
//!
//! The limits are deliberately generous for hand-written kernels and receipt
//! files, and deliberately small enough to keep adversarial inputs cheap.

/// Maximum size of any JSON document accepted by this crate, in bytes.
/// Applies to kernels and to receipt files, before any parsing happens.
pub const MAX_DOCUMENT_BYTES: u64 = 4 * 1024 * 1024;

/// Maximum nesting depth of JSON values. The hand-written duplicate-key
/// parser and the expression validator both stop at this depth, so a
/// hostile `[[[...]]]` cannot overflow the stack.
pub const MAX_JSON_DEPTH: usize = 64;

/// Maximum total number of JSON values (objects, arrays, scalars) in one
/// document. Enforced by the duplicate-key pre-parser. Sized so a kernel
/// with `MAX_COLLECTION` minimally-shaped claims still fits: each minimal
/// claim is about a dozen nodes.
pub const MAX_JSON_NODES: usize = 250_000;

/// Maximum number of claims, arguments, or evidence specs in one kernel.
pub const MAX_COLLECTION: usize = 10_000;

/// Maximum number of entries in any `scope` map.
pub const MAX_SCOPE_ENTRIES: usize = 64;

/// Maximum length of a scope key, in bytes.
pub const MAX_SCOPE_KEY_BYTES: usize = 128;

/// Maximum length of a scope value, in bytes.
pub const MAX_SCOPE_VALUE_BYTES: usize = 1024;

/// Maximum length of a claim statement, in bytes.
pub const MAX_STATEMENT_BYTES: usize = 16 * 1024;

/// Maximum length of an identifier, in bytes.
pub const MAX_ID_BYTES: usize = 128;

/// Maximum number of assumptions on one claim.
pub const MAX_ASSUMPTIONS: usize = 1024;

/// Maximum number of premises on one argument.
pub const MAX_PREMISES: usize = 1024;

/// Maximum number of evidence specs linked from one argument.
pub const MAX_LINKED_EVIDENCE: usize = 256;

/// Maximum nodes in one expression AST, however it was constructed.
pub const MAX_EXPRESSION_NODES: usize = 10_000;

/// Maximum number of receipts in one receipt file.
pub const MAX_RECEIPTS: usize = 512;

/// Maximum number of registered targets (`input_hashes`) on one receipt.
pub const MAX_RECEIPT_TARGETS: usize = 256;

/// Maximum number of artifacts on one receipt.
pub const MAX_RECEIPT_ARTIFACTS: usize = 64;

/// Maximum number of operands in one `command_argv`.
pub const MAX_COMMAND_ARGV: usize = 64;

/// Maximum length of one `command_argv` operand, in bytes.
pub const MAX_COMMAND_ARG_BYTES: usize = 4096;

/// Maximum length of a receipt target locator (`input_hashes` key), in bytes.
pub const MAX_TARGET_LOCATOR_BYTES: usize = 512;

/// Maximum number of bytes hashed from a local file for an audit or an
/// admission check. Files larger than this are reported, never hashed.
pub const MAX_LOCAL_FILE_BYTES: u64 = 64 * 1024 * 1024;

/// Buffer size used when streaming a local file for hashing.
pub const HASH_BUFFER_BYTES: usize = 64 * 1024;
