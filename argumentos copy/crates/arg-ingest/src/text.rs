use anyhow::{bail, Result};

use crate::classify::ParseKind;
use crate::{sha256, SourceSpan};

#[derive(Debug, Clone)]
pub(crate) struct ExtractedUnit {
    pub(crate) span: SourceSpan,
    pub(crate) raw_text: String,
    pub(crate) raw_sha256: String,
    pub(crate) heading_trail: Vec<String>,
    pub(crate) structural_kind: String,
    pub(crate) source_only_reason: String,
    pub(crate) json_pointer: Option<String>,
}

#[derive(Debug, Clone, Copy)]
struct Line<'a> {
    start: usize,
    content_end: usize,
    number: u64,
    text: &'a str,
}

#[derive(Debug, Clone)]
struct Block {
    start: usize,
    byte_end: usize,
    line_start: u64,
    line_end: u64,
    raw: String,
    forced_kind: Option<&'static str>,
    heading: Option<Heading>,
}

pub(crate) fn extract(source: &str, parse_kind: ParseKind) -> Result<Vec<ExtractedUnit>> {
    let mut units = match parse_kind {
        ParseKind::JsonDocument => json_document(source)?,
        ParseKind::JsonLines => json_lines(source)?,
        ParseKind::Text | ParseKind::Yaml => lexical_blocks(source),
    };
    if units.is_empty() && !source.is_empty() {
        units.push(fallback_unit(source));
    }
    Ok(units)
}

fn json_document(source: &str) -> Result<Vec<ExtractedUnit>> {
    let value: serde_json::Value = serde_json::from_str(source)?;
    let reason = if is_substantive_json(&value) {
        ""
    } else {
        "non_substantive_json"
    };
    Ok(vec![ExtractedUnit {
        span: SourceSpan {
            byte_start: 0,
            byte_end: source.len() as u64,
            line_start: 1,
            line_end: source.lines().count().max(1) as u64,
        },
        raw_text: source.to_owned(),
        raw_sha256: sha256(source.as_bytes()),
        heading_trail: Vec::new(),
        structural_kind: "json_document".to_owned(),
        source_only_reason: reason.to_owned(),
        json_pointer: Some("/".to_owned()),
    }])
}

fn is_substantive_json(value: &serde_json::Value) -> bool {
    match value {
        serde_json::Value::Null => false,
        serde_json::Value::Array(values) => !values.is_empty(),
        serde_json::Value::Object(values) => !values.is_empty(),
        _ => true,
    }
}

fn json_lines(source: &str) -> Result<Vec<ExtractedUnit>> {
    let mut units = Vec::new();
    for line in lines(source) {
        if line.text.trim().is_empty() {
            continue;
        }
        let value: serde_json::Value = serde_json::from_str(line.text)
            .map_err(|error| anyhow::anyhow!("invalid JSONL line {}: {error}", line.number))?;
        let raw = line.text.to_owned();
        let reason = if is_substantive_json(&value) {
            ""
        } else {
            "review_ledger_record"
        };
        units.push(ExtractedUnit {
            span: SourceSpan {
                byte_start: line.start as u64,
                byte_end: line.content_end as u64,
                line_start: line.number,
                line_end: line.number,
            },
            raw_sha256: sha256(raw.as_bytes()),
            raw_text: raw,
            heading_trail: Vec::new(),
            structural_kind: "jsonl_record".to_owned(),
            source_only_reason: reason.to_owned(),
            json_pointer: Some("/".to_owned()),
        });
    }
    Ok(units)
}

fn fallback_unit(source: &str) -> ExtractedUnit {
    ExtractedUnit {
        span: SourceSpan {
            byte_start: 0,
            byte_end: source.len() as u64,
            line_start: 1,
            line_end: source.lines().count().max(1) as u64,
        },
        raw_text: source.to_owned(),
        raw_sha256: sha256(source.as_bytes()),
        heading_trail: Vec::new(),
        structural_kind: "whitespace_only_document".to_owned(),
        source_only_reason: "no_nonempty_source_block".to_owned(),
        json_pointer: None,
    }
}

fn lexical_blocks(source: &str) -> Vec<ExtractedUnit> {
    let all_lines = lines(source);
    let mut blocks = Vec::new();
    let mut current: Option<Block> = None;
    let mut in_fence: Option<String> = None;

    for line in all_lines {
        let trimmed = line.text.trim();
        if let Some(marker) = in_fence.clone() {
            append_line(&mut current, line, source);
            if is_fence_close(trimmed, &marker) {
                if let Some(block) = current.take() {
                    blocks.push(block);
                }
                in_fence = None;
            }
            continue;
        }

        if let Some(marker) = fence_start(trimmed) {
            flush_block(&mut current, &mut blocks);
            in_fence = Some(marker);
            current = Some(Block {
                start: line.start,
                byte_end: line.content_end,
                line_start: line.number,
                line_end: line.number,
                raw: line.text.to_owned(),
                forced_kind: Some("fenced_code"),
                heading: None,
            });
            continue;
        }

        if trimmed.is_empty() {
            flush_block(&mut current, &mut blocks);
            continue;
        }

        if let Some(heading) = heading(line.text) {
            flush_block(&mut current, &mut blocks);
            blocks.push(Block {
                start: line.start,
                byte_end: line.content_end,
                line_start: line.number,
                line_end: line.number,
                raw: line.text.to_owned(),
                forced_kind: Some("heading"),
                heading: Some(heading),
            });
            continue;
        }

        append_line(&mut current, line, source);
    }
    flush_block(&mut current, &mut blocks);

    let mut units = Vec::new();
    let mut hierarchy: Vec<(u64, String)> = Vec::new();
    for block in blocks {
        if let Some(heading) = &block.heading {
            while hierarchy
                .last()
                .is_some_and(|(parent_level, _)| *parent_level >= heading.level)
            {
                hierarchy.pop();
            }
            hierarchy.push((heading.level, heading.title.clone()));
            units.push(unit_from_block(
                block,
                &hierarchy,
                Some("heading"),
                "heading_navigation",
            ));
        } else {
            units.push(unit_from_block(block, &hierarchy, None, ""));
        }
    }
    units
}

fn append_line(current: &mut Option<Block>, line: Line<'_>, full_source: &str) {
    if let Some(block) = current {
        block.byte_end = line.content_end;
        block.line_end = line.number;
        block.raw = full_source[block.start..block.byte_end].to_owned();
    } else {
        *current = Some(Block {
            start: line.start,
            byte_end: line.content_end,
            line_start: line.number,
            line_end: line.number,
            raw: line.text.to_owned(),
            forced_kind: None,
            heading: None,
        });
    }
}

fn flush_block(current: &mut Option<Block>, blocks: &mut Vec<Block>) {
    if let Some(block) = current.take() {
        if !block.raw.trim().is_empty() {
            blocks.push(block);
        }
    }
}

fn unit_from_block(
    block: Block,
    hierarchy: &[(u64, String)],
    forced_kind: Option<&str>,
    forced_reason: &str,
) -> ExtractedUnit {
    let trimmed = block.raw.trim();
    let kind = forced_kind
        .map(str::to_owned)
        .unwrap_or_else(|| classify_structural_kind(trimmed, block.forced_kind));
    let reason = if !forced_reason.is_empty() {
        forced_reason.to_owned()
    } else {
        source_only_reason(trimmed, &kind)
    };
    ExtractedUnit {
        span: SourceSpan {
            byte_start: block.start as u64,
            byte_end: block.byte_end as u64,
            line_start: block.line_start,
            line_end: block.line_end,
        },
        raw_sha256: sha256(block.raw.as_bytes()),
        raw_text: block.raw,
        heading_trail: hierarchy.iter().map(|(_, title)| title.clone()).collect(),
        structural_kind: kind,
        source_only_reason: reason,
        json_pointer: None,
    }
}

fn classify_structural_kind(trimmed: &str, forced: Option<&'static str>) -> String {
    if let Some(kind) = forced {
        return kind.to_owned();
    }
    let lowercase = trimmed.to_lowercase();
    if trimmed
        .lines()
        .all(|line| line.trim_start().starts_with("//"))
    {
        "typst_comment".to_owned()
    } else if is_typst_label(trimmed) {
        "typst_label".to_owned()
    } else if is_source_directive(&lowercase) {
        "source_directive".to_owned()
    } else if lowercase.starts_with("#theorem")
        || lowercase.starts_with("#teorema")
        || starts_with_natural(&lowercase, &["theorem", "teorema"])
    {
        "theorem".to_owned()
    } else if lowercase.starts_with("#definition")
        || lowercase.starts_with("#definicion")
        || lowercase.starts_with("#definición")
        || starts_with_natural(&lowercase, &["definition", "definición", "definicion"])
    {
        "definition".to_owned()
    } else {
        "prose_or_structured_block".to_owned()
    }
}

fn source_only_reason(trimmed: &str, kind: &str) -> String {
    match kind {
        "fenced_code" => "fenced_code".to_owned(),
        "typst_comment" => "typst_comment_block".to_owned(),
        "typst_label" => "typst_label".to_owned(),
        "source_directive" => "import_include_show_or_layout_directive".to_owned(),
        _ if !trimmed.chars().any(char::is_alphanumeric) => "no_substantive_text".to_owned(),
        _ => String::new(),
    }
}

fn is_typst_label(trimmed: &str) -> bool {
    trimmed.starts_with('<') && trimmed.ends_with('>') && !trimmed.contains('\n')
}

fn is_source_directive(lowercase: &str) -> bool {
    const DIRECTIVES: [&str; 27] = [
        "#import",
        "#include",
        "#show",
        "#set",
        "#let",
        "#context",
        "#page",
        "#place",
        "#figure",
        "#table",
        "#image",
        "#box",
        "#rect",
        "#grid",
        "#align",
        "#v(",
        "#h(",
        "#style",
        "#locate",
        "#state",
        "#counter",
        "#numbering",
        "#bibliography",
        "#outline",
        "#pagebreak",
        "#columns",
        "#rotate",
    ];
    DIRECTIVES
        .iter()
        .any(|prefix| lowercase.starts_with(prefix))
}

#[derive(Debug, Clone)]
struct Heading {
    level: u64,
    title: String,
}

fn heading(line: &str) -> Option<Heading> {
    let trimmed = line.trim();
    let markdown = trimmed.strip_prefix('#').and_then(|_| {
        let level = trimmed
            .chars()
            .take_while(|character| *character == '#')
            .count();
        if (1..=6).contains(&level)
            && trimmed[level..]
                .chars()
                .next()
                .is_some_and(char::is_whitespace)
        {
            let title = trimmed[level..]
                .trim()
                .trim_end_matches('#')
                .trim()
                .to_owned();
            Some(Heading {
                level: level as u64,
                title,
            })
        } else {
            None
        }
    });
    if markdown.is_some() {
        return markdown;
    }

    if trimmed.starts_with('=') {
        let level = trimmed
            .chars()
            .take_while(|character| *character == '=')
            .count();
        if trimmed[level..]
            .chars()
            .next()
            .is_none_or(char::is_whitespace)
        {
            return Some(Heading {
                level: level as u64,
                title: trimmed[level..].trim().to_owned(),
            });
        }
    }

    for (prefix, level) in [("#part[", 1_u64), ("#chapter[", 1), ("#appendix[", 1)] {
        if let Some(rest) = trimmed.strip_prefix(prefix) {
            if let Some(title) = rest.strip_suffix(']') {
                return Some(Heading {
                    level,
                    title: title.trim().to_owned(),
                });
            }
        }
    }
    None
}

fn starts_with_natural(text: &str, starts: &[&str]) -> bool {
    starts.iter().any(|start| {
        text.strip_prefix(start).is_some_and(|rest| {
            rest.chars()
                .next()
                .is_none_or(|character| character.is_whitespace() || character == ':')
        })
    })
}

fn fence_start(trimmed: &str) -> Option<String> {
    for marker in ["```", "~~~"] {
        if trimmed.starts_with(marker) {
            return Some(marker.to_owned());
        }
    }
    None
}

fn is_fence_close(trimmed: &str, marker: &str) -> bool {
    trimmed.starts_with(marker)
        && trimmed
            .chars()
            .all(|character| character == marker.chars().next().unwrap_or('`'))
}

fn lines(source: &str) -> Vec<Line<'_>> {
    let bytes = source.as_bytes();
    let mut result = Vec::new();
    let mut start = 0;
    let mut number = 1_u64;
    let mut index = 0;
    while index < bytes.len() {
        if bytes[index] == b'\n' {
            let content_end = if index > start && bytes[index - 1] == b'\r' {
                index - 1
            } else {
                index
            };
            result.push(Line {
                start,
                content_end,
                number,
                text: &source[start..content_end],
            });
            start = index + 1;
            number += 1;
        }
        index += 1;
    }
    if start < bytes.len() {
        let content_end = if bytes.last() == Some(&b'\r') {
            bytes.len() - 1
        } else {
            bytes.len()
        };
        result.push(Line {
            start,
            content_end,
            number,
            text: &source[start..content_end],
        });
    }
    result
}

pub(crate) fn validate_raw_unit(source: &str, unit: &ExtractedUnit) -> Result<()> {
    let start = unit.span.byte_start as usize;
    let end = unit.span.byte_end as usize;
    let Some(raw) = source.get(start..end) else {
        bail!("unit byte span is not a UTF-8 boundary inside its source");
    };
    if raw != unit.raw_text || sha256(raw.as_bytes()) != unit.raw_sha256 {
        bail!("unit raw slice, span, and digest disagree");
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn preserves_utf8_crlf_boundaries_and_lines() {
        let source = "Introducción.\r\n\r\nEl café cuesta 3 €.\r\n";
        let units = extract(source, ParseKind::Text).unwrap();
        assert_eq!(units.len(), 2);
        assert_eq!(units[0].span.byte_start, 0);
        assert_eq!(units[0].span.byte_end, "Introducción.".len() as u64);
        assert_eq!(units[1].span.line_start, 3);
        assert_eq!(units[1].span.line_end, 3);
        assert_eq!(units[1].raw_text, "El café cuesta 3 €.");
        for unit in &units {
            validate_raw_unit(source, unit).unwrap();
        }
    }

    #[test]
    fn fences_keep_blank_lines_and_ignore_fake_headings() {
        let source = "# Real\n\nParagraph.\n\n```md\n# Fake\n\nstill code\n```\n\nAfter.\n";
        let units = extract(source, ParseKind::Text).unwrap();
        assert!(!units
            .iter()
            .any(|unit| unit.heading_trail.contains(&"Fake".to_owned())));
        let code = units
            .iter()
            .find(|unit| unit.structural_kind == "fenced_code")
            .unwrap();
        assert!(code.raw_text.contains("# Fake\n\nstill code"));
        assert_eq!(code.source_only_reason, "fenced_code");
        let after = units.iter().find(|unit| unit.raw_text == "After.").unwrap();
        assert_eq!(after.heading_trail, vec!["Real"]);
    }

    #[test]
    fn comments_directives_and_chapter_headings_are_explicit_source_only() {
        let source = "#chapter[Resultados]\n\n// comentario\n\n#import \"base.typ\": *\n\n<label>\n\nHallazgo.\n";
        let units = extract(source, ParseKind::Text).unwrap();
        assert_eq!(units[0].source_only_reason, "heading_navigation");
        assert!(units
            .iter()
            .any(|unit| unit.source_only_reason == "typst_comment_block"));
        assert!(units
            .iter()
            .any(|unit| unit.source_only_reason == "import_include_show_or_layout_directive"));
        assert!(units
            .iter()
            .any(|unit| unit.source_only_reason == "typst_label"));
        assert!(units
            .iter()
            .any(|unit| unit.raw_text == "Hallazgo." && unit.source_only_reason.is_empty()));
    }

    #[test]
    fn malformed_jsonl_is_rejected() {
        assert!(extract("{bad}\n", ParseKind::JsonLines).is_err());
    }
}
