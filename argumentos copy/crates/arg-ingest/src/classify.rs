use std::path::Path;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum Disposition {
    Parsed,
    MetadataOnly,
    Excluded,
}

impl Disposition {
    pub(crate) fn as_str(&self) -> &'static str {
        match self {
            Self::Parsed => "parsed",
            Self::MetadataOnly => "metadata_only",
            Self::Excluded => "excluded",
        }
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub(crate) enum ParseKind {
    Text,
    JsonDocument,
    JsonLines,
    Yaml,
}

impl ParseKind {
    pub(crate) fn as_str(&self) -> &'static str {
        match self {
            Self::Text => "text_blocks",
            Self::JsonDocument => "json_document",
            Self::JsonLines => "json_lines",
            Self::Yaml => "yaml_lexical_blocks",
        }
    }
}

#[derive(Debug, Clone)]
pub(crate) struct Classification {
    pub(crate) format: String,
    pub(crate) role: String,
    pub(crate) disposition: Disposition,
    pub(crate) source_status: String,
    pub(crate) reason: String,
    pub(crate) parse_kind: Option<ParseKind>,
    pub(crate) candidate_eligible: bool,
}

impl Classification {
    fn new(
        format: &str,
        role: &str,
        disposition: Disposition,
        source_status: &str,
        reason: &str,
        parse_kind: Option<ParseKind>,
        candidate_eligible: bool,
    ) -> Self {
        Self {
            format: format.to_owned(),
            role: role.to_owned(),
            disposition,
            source_status: source_status.to_owned(),
            reason: reason.to_owned(),
            parse_kind,
            candidate_eligible,
        }
    }
}

pub(crate) fn edition_for_root(root: &str) -> String {
    let top = root
        .split('/')
        .find(|part| !part.is_empty() && *part != ".");
    top.and_then(|value| value.split('_').next())
        .unwrap_or("unknown")
        .to_owned()
}

pub(crate) fn classify(
    root: &str,
    collection_path: &Path,
    bytes: u64,
    utf8_known: Option<bool>,
) -> Classification {
    let relative = crate::slash_path(collection_path);
    let name = collection_path
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or_default();
    let components = relative.split('/').collect::<Vec<_>>();
    let extension = collection_path
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();
    let format = format_for(name, &extension, bytes);

    if bytes == 0
        && ((name == ".gitkeep" && components.len() == 1)
            || (name == "main.typ"
                && components.len() == 1
                && root.split('/').any(|part| part.starts_with("02_"))))
    {
        return Classification::new(
            &format,
            "explicit_root_placeholder",
            Disposition::Excluded,
            "placeholder",
            "explicit_empty_root_placeholder",
            None,
            false,
        );
    }

    if is_binary_or_generated_asset(&extension) {
        return Classification::new(
            &format,
            "binary_or_generated_asset",
            Disposition::Excluded,
            "generated",
            "binary_or_generated_asset_excluded_but_inventoried",
            None,
            false,
        );
    }

    if root.split('/').any(|part| part.starts_with("02_"))
        || root.split('/').any(|part| part.starts_with("05_"))
    {
        classify_monograph(format, &relative, name, &components, utf8_known)
    } else {
        classify_mcp(format, &relative, name, &components, utf8_known)
    }
}

fn classify_monograph(
    format: String,
    relative: &str,
    name: &str,
    components: &[&str],
    utf8_known: Option<bool>,
) -> Classification {
    let extension = Path::new(relative)
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();

    if is_code_config_test(components, &extension) {
        return metadata(
            format,
            "implementation_or_test",
            "code_tests_and_configuration_are_metadata_only_and_never_executed",
        );
    }

    if components.contains(&"verificacion") {
        return match extension.as_str() {
            "md" => parsed(
                format,
                "review_record",
                "review_markdown_parsed_without_argument_candidates",
                ParseKind::Text,
                false,
            ),
            "jsonl" => parsed(
                format,
                "review_ledger",
                "review_jsonl_validated_line_by_line_without_argument_candidates",
                ParseKind::JsonLines,
                false,
            ),
            _ => metadata(
                format,
                "review_supplement",
                "non_markdown_non_jsonl_review_files_are_metadata_only",
            ),
        };
    }

    if (name == "refs.yml" || name == "refs.yaml") && components.contains(&"bibliografia") {
        return parsed(
            format,
            "bibliography",
            "bibliography_is_conservative_lexical_source_only",
            ParseKind::Yaml,
            false,
        );
    }

    if extension == "typ"
        && components
            .iter()
            .any(|part| matches!(*part, "template" | "templates" | "figuras"))
    {
        return parsed(
            format,
            "build_layout_source",
            "typst_template_figure_and_layout_source_only",
            ParseKind::Text,
            false,
        );
    }

    if name == "main.typ" || name == "main_de.typ" {
        return parsed(
            format,
            "primary_manuscript",
            "primary_monograph_document",
            ParseKind::Text,
            true,
        );
    }

    if relative == "Causal_AI/README.md" {
        return parsed(
            format,
            "monograph_documentation",
            "current_monograph_readme",
            ParseKind::Text,
            true,
        );
    }

    let in_lexical_section = components.iter().any(|part| {
        matches!(
            *part,
            "capitulos"
                | "capitulos_de"
                | "apendices"
                | "apendices_de"
                | "frontmatter"
                | "frontmatter_de"
                | "partes"
                | "partes_de"
        )
    });
    if in_lexical_section && is_plain_text_format(&extension) {
        return parsed(
            format,
            "monograph_lexical_text",
            "current_monograph_prose_or_structured_source",
            ParseKind::Text,
            true,
        );
    }

    if utf8_known != Some(false) && (utf8_known == Some(true) || utf8_extension(&extension)) {
        metadata(
            format,
            "unknown_utf8_source",
            "utf8_source_without_a_declared_monograph_parsing_role",
        )
    } else {
        Classification::new(
            &format,
            "unknown_binary_source",
            Disposition::Excluded,
            "unknown",
            "unknown_non_utf8_or_unsupported_asset_excluded_but_inventoried",
            None,
            false,
        )
    }
}

fn classify_mcp(
    format: String,
    relative: &str,
    name: &str,
    components: &[&str],
    utf8_known: Option<bool>,
) -> Classification {
    let extension = Path::new(relative)
        .extension()
        .and_then(|value| value.to_str())
        .unwrap_or_default()
        .to_ascii_lowercase();

    if components.contains(&"reports") {
        return metadata_status(
            format,
            "generated_evidence",
            "generated",
            "reports_are_generated_evidence_hash_only",
        );
    }

    let historical = components.contains(&"plan-capitulos")
        || components.contains(&"server")
        || components.contains(&"legacy")
        || components.contains(&"historical")
        || (components.len() >= 3 && components[0] == "docs" && components[1] == "development")
        || name == "ROADMAP.md";
    if historical {
        if is_code_config_test(components, &extension) {
            return metadata_status(
                format,
                "legacy_implementation_or_test",
                "legacy",
                "legacy_code_tests_and_configuration_never_executed_or_duplicated_as_knowledge",
            );
        }
        if is_plain_text_format(&extension) {
            let kind = if extension == "json" {
                ParseKind::JsonDocument
            } else {
                ParseKind::Text
            };
            return parsed_status(
                format,
                "historical_or_legacy_text",
                "historical",
                "historical_or_legacy_text_parsed_without_argument_candidates",
                kind,
                false,
            );
        }
    }

    if is_code_config_test(components, &extension) {
        return metadata(
            format,
            "implementation_or_test",
            "code_tests_examples_and_remaining_configuration_are_metadata_only_never_executed",
        );
    }

    if relative == "README.md" {
        return parsed(
            format,
            "mcp_documentation",
            "current_root_documentation_candidate_eligible",
            ParseKind::Text,
            true,
        );
    }
    if relative == "mcp.json" {
        return parsed(
            format,
            "mcp_configuration",
            "current_mcp_configuration_candidate_eligible",
            ParseKind::JsonDocument,
            true,
        );
    }
    if direct_child(components, "contratos") && matches!(extension.as_str(), "json" | "md") {
        return parsed(
            format,
            "contract",
            "current_contract_candidate_eligible",
            parse_kind_for_extension(&extension),
            true,
        );
    }
    if relative == "contracts/local_v1.json" {
        return parsed(
            format,
            "contract",
            "current_local_contract_candidate_eligible",
            ParseKind::JsonDocument,
            true,
        );
    }
    if direct_child(components, "criterios") && extension == "md" {
        return parsed(
            format,
            "criterion",
            "current_evaluation_criterion_candidate_eligible",
            ParseKind::Text,
            true,
        );
    }
    if direct_child(components, "evals") && extension == "md" {
        return parsed(
            format,
            "evaluation",
            "current_evaluation_candidate_eligible",
            ParseKind::Text,
            true,
        );
    }
    if extension == "json" && has_resource_scope(components, "knowledge") {
        return parsed(
            format,
            "knowledge_resource",
            "current_json_knowledge_is_authoritative_without_python_registration_duplication",
            ParseKind::JsonDocument,
            true,
        );
    }
    if extension == "json" && has_resource_scope(components, "workflows") {
        return parsed(
            format,
            "workflow",
            "current_workflow_candidate_eligible",
            ParseKind::JsonDocument,
            true,
        );
    }
    if relative == "deploy/cloud_adapter.md" {
        return parsed(
            format,
            "deployment_documentation",
            "current_cloud_adapter_candidate_eligible",
            ParseKind::Text,
            true,
        );
    }

    if components.contains(&"docs") && is_plain_text_format(&extension) {
        return parsed(
            format,
            "supplemental_documentation",
            "documentation_parsed_but_not_declared_candidate_eligible",
            if extension == "json" {
                ParseKind::JsonDocument
            } else {
                ParseKind::Text
            },
            false,
        );
    }

    if utf8_known != Some(false) && (utf8_known == Some(true) || utf8_extension(&extension)) {
        metadata(
            format,
            "unknown_utf8_source",
            "utf8_source_without_a_declared_current_parsing_role",
        )
    } else {
        Classification::new(
            &format,
            "unknown_binary_source",
            Disposition::Excluded,
            "unknown",
            "unknown_non_utf8_source_excluded_but_inventoried",
            None,
            false,
        )
    }
}

fn parsed(
    format: String,
    role: &str,
    reason: &str,
    kind: ParseKind,
    candidate_eligible: bool,
) -> Classification {
    parsed_status(format, role, "current", reason, kind, candidate_eligible)
}

fn parsed_status(
    format: String,
    role: &str,
    source_status: &str,
    reason: &str,
    kind: ParseKind,
    candidate_eligible: bool,
) -> Classification {
    Classification::new(
        &format,
        role,
        Disposition::Parsed,
        source_status,
        reason,
        Some(kind),
        candidate_eligible,
    )
}

fn metadata(format: String, role: &str, reason: &str) -> Classification {
    metadata_status(format, role, "current", reason)
}

fn metadata_status(
    format: String,
    role: &str,
    source_status: &str,
    reason: &str,
) -> Classification {
    Classification::new(
        &format,
        role,
        Disposition::MetadataOnly,
        source_status,
        reason,
        None,
        false,
    )
}

fn direct_child(components: &[&str], parent: &str) -> bool {
    components.len() == 2 && components[0] == parent
}

fn has_resource_scope(components: &[&str], terminal_parent: &str) -> bool {
    let expected = ["src", "mcp_causal", "resources", terminal_parent];
    components.len() == 5 && components[..4] == expected
}

fn parse_kind_for_extension(extension: &str) -> ParseKind {
    if extension == "json" {
        ParseKind::JsonDocument
    } else {
        ParseKind::Text
    }
}

fn is_plain_text_format(extension: &str) -> bool {
    matches!(
        extension,
        "md" | "markdown" | "typ" | "txt" | "text" | "json" | "jsonl" | "yml" | "yaml"
    )
}

fn utf8_extension(extension: &str) -> bool {
    is_plain_text_format(extension)
        || matches!(
            extension,
            "py" | "pyi"
                | "rs"
                | "sh"
                | "bash"
                | "zsh"
                | "toml"
                | "lock"
                | "cfg"
                | "ini"
                | "csv"
                | "tsv"
                | "bib"
                | "tex"
                | "gitkeep"
        )
}

fn is_code_config_test(components: &[&str], extension: &str) -> bool {
    components
        .iter()
        .any(|part| matches!(*part, "tests" | "test" | "examples" | "scripts"))
        || matches!(
            extension,
            "py" | "pyi" | "rs" | "sh" | "bash" | "zsh" | "toml" | "lock" | "cfg" | "ini"
        )
}

fn is_binary_or_generated_asset(extension: &str) -> bool {
    matches!(
        extension,
        "pdf"
            | "png"
            | "jpg"
            | "jpeg"
            | "gif"
            | "webp"
            | "bmp"
            | "tif"
            | "tiff"
            | "svg"
            | "ico"
            | "ttf"
            | "otf"
            | "woff"
            | "woff2"
            | "zip"
            | "gz"
            | "tar"
            | "zst"
            | "7z"
            | "pyc"
            | "pyo"
            | "so"
            | "dylib"
            | "dll"
            | "exe"
            | "wasm"
            | "mp4"
            | "mp3"
            | "parquet"
            | "feather"
            | "xlsx"
            | "docx"
            | "pkl"
            | "npy"
            | "npz"
    )
}

fn format_for(name: &str, extension: &str, bytes: u64) -> String {
    if name == ".gitkeep" && bytes == 0 {
        return "empty_placeholder".to_owned();
    }
    if extension.is_empty() {
        return "no_extension".to_owned();
    }
    match extension {
        "md" | "markdown" => "markdown",
        "typ" => "typst",
        "yml" | "yaml" => "yaml",
        "py" | "pyi" => "python",
        "rs" => "rust",
        "sh" | "bash" | "zsh" => "shell",
        other => other,
    }
    .to_owned()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn current_json_resources_are_candidates_but_legacy_python_is_not() {
        let current = classify(
            "08_mcp-agentes-causales",
            Path::new("src/mcp_causal/resources/knowledge/iv.json"),
            10,
            Some(true),
        );
        assert_eq!(current.disposition, Disposition::Parsed);
        assert!(current.candidate_eligible);

        let legacy = classify(
            "08_mcp-agentes-causales",
            Path::new("server/mcp_causal/resources.py"),
            10,
            Some(true),
        );
        assert_eq!(legacy.disposition, Disposition::MetadataOnly);
        assert!(!legacy.candidate_eligible);
        assert_eq!(legacy.source_status, "legacy");
    }

    #[test]
    fn unknown_utf8_is_metadata_and_reports_are_generated() {
        let unknown = classify(
            "02_causal AI en produccion",
            Path::new("Causal_AI/notes.custom"),
            10,
            Some(true),
        );
        assert_eq!(unknown.disposition, Disposition::MetadataOnly);
        assert_eq!(unknown.role, "unknown_utf8_source");

        let report = classify(
            "08_mcp-agentes-causales",
            Path::new("reports/result.json"),
            10,
            Some(true),
        );
        assert_eq!(report.disposition, Disposition::MetadataOnly);
        assert_eq!(report.source_status, "generated");
        assert!(!report.candidate_eligible);

        let non_utf8 = classify(
            "05_contenido_tecnico",
            Path::new("Causal_AI/notes.md"),
            10,
            Some(false),
        );
        assert_eq!(non_utf8.disposition, Disposition::Excluded);
        assert_eq!(non_utf8.role, "unknown_binary_source");
    }

    #[test]
    fn review_ledgers_are_parsed_not_candidates() {
        let review = classify(
            "05_contenido_tecnico",
            Path::new("Causal_AI/verificacion/ledger.jsonl"),
            10,
            Some(true),
        );
        assert_eq!(review.parse_kind, Some(ParseKind::JsonLines));
        assert!(!review.candidate_eligible);
    }
}
