//! refs_seed — refs.yml (Hayagriva, subconjunto) -> JSONL
//!
//! Solo std; parser tolerante del formato real de este repositorio:
//!   clave:                       (col 0)
//!     campo: valor               (2 espacios)
//!     campo:                     (mapa anidado)
//!       sub: valor               (4 espacios; parent.title, url.value)
//! Autores: `author: Nombre` o `author: ["A, X", "B, Y"]`.
//! Uso: refs_seed <refs.yml> <out.jsonl>

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::io::{self, Write};

#[derive(Default)]
struct Rec {
    key: String,
    fields: BTreeMap<String, String>,
}

fn dequote(s: &str) -> String {
    let s = s.trim();
    if s.len() >= 2 {
        let (a, b) = (s.as_bytes()[0] as char, s.as_bytes()[s.len() - 1] as char);
        if (a == '"' && b == '"') || (a == '\'' && b == '\'') {
            return s[1..s.len() - 1].replace("\\\"", "\"").replace("''", "'");
        }
    }
    s.to_string()
}

fn parse_inline_list(raw: &str) -> Vec<String> {
    let inner = raw.trim().trim_start_matches('[').trim_end_matches(']');
    let mut out = Vec::new();
    let mut cur = String::new();
    let mut in_q = false;
    let mut q = '"';
    for c in inner.chars() {
        match c {
            '"' | '\'' => {
                if in_q && c == q { in_q = false; } else if !in_q { in_q = true; q = c; }
            }
            ',' if !in_q => {
                let t = dequote(cur.trim());
                if !t.is_empty() { out.push(t); }
                cur.clear();
            }
            _ => cur.push(c),
        }
    }
    let t = dequote(cur.trim());
    if !t.is_empty() { out.push(t); }
    out
}

fn json_escape(s: &str) -> String {
    let mut r = String::with_capacity(s.len() + 8);
    for c in s.chars() {
        match c {
            '"' => r.push_str("\\\""),
            '\\' => r.push_str("\\\\"),
            '\n' => r.push_str("\\n"),
            '\r' => r.push_str("\\r"),
            '\t' => r.push_str("\\t"),
            c if (c as u32) < 0x20 => r.push_str(&format!("\\u{:04x}", c as u32)),
            _ => r.push(c),
        }
    }
    r
}

fn json_str(s: &str) -> String { format!("\"{}\"", json_escape(s)) }

fn year_of(date: &str) -> String {
    let d: Vec<char> = date.chars().collect();
    for w in d.windows(4) {
        if w.iter().all(|c| c.is_ascii_digit()) {
            let y: String = w.iter().collect();
            if let Ok(n) = y.parse::<u32>() { if (1400..=2100).contains(&n) { return y; } }
        }
    }
    String::new()
}

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() != 3 {
        eprintln!("uso: refs_seed <refs.yml> <out.jsonl>");
        std::process::exit(2);
    }
    let text = fs::read_to_string(&args[1])?;
    let mut recs: Vec<Rec> = Vec::new();
    let mut cur: Option<Rec> = None;
    let mut nested: Option<String> = None;

    for raw_line in text.lines() {
        if raw_line.trim().is_empty() || raw_line.trim_start().starts_with('#') { continue; }
        let indent = raw_line.chars().take_while(|c| *c == ' ').count();

        if indent == 0 {
            if let Some(r) = cur.take() { recs.push(r); }
            nested = None;
            let line = raw_line.trim_end();
            if let Some(pos) = line.find(':') {
                let key = line[..pos].trim().to_string();
                if !key.is_empty() && key.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-') {
                    cur = Some(Rec { key, ..Default::default() });
                    continue;
                }
            }
            continue;
        }

        let line = raw_line[indent..].trim_end();
        let Some(colon) = line.find(':') else { continue; };
        let field = line[..colon].trim().to_string();
        let value = line[colon + 1..].trim().to_string();

        match indent {
            2 => {
                if value.is_empty() {
                    nested = Some(field);
                } else if let Some(r) = cur.as_mut() {
                    r.fields.insert(field, value);
                    nested = None;
                }
            }
            4 => {
                if let (Some(parent_field), Some(r)) = (nested.clone(), cur.as_mut()) {
                    r.fields.insert(format!("{}.{}", parent_field, field), dequote(&value));
                }
            }
            _ => {}
        }
    }
    if let Some(r) = cur.take() { recs.push(r); }

    let mut out = String::new();
    let mut n_doi = 0usize;
    let mut n_url = 0usize;
    let mut n_book = 0usize;
    for r in &recs {
        let f = &r.fields;
        let get = |k: &str| f.get(k).cloned().unwrap_or_default();
        let doi = get("doi");
        if !doi.is_empty() { n_doi += 1; }
        if f.contains_key("url.value") { n_url += 1; }
        let ty = get("type");
        if ty == "book" { n_book += 1; }
        let authors_raw = get("author");
        let authors: Vec<String> = if authors_raw.trim_start().starts_with('[') {
            parse_inline_list(&authors_raw)
        } else if !authors_raw.is_empty() {
            vec![dequote(&authors_raw)]
        } else { vec![] };
        let authors_json = authors.iter().map(|a| json_str(a)).collect::<Vec<_>>().join(",");
        let source = {
            let p = get("parent.title");
            if !p.is_empty() { p } else { get("publisher") }
        };
        let url = get("url.value");
        let year = year_of(&get("date"));
        out.push_str(&format!(
            "{{\"key\":{},\"type\":{},\"title\":{},\"authors\":[{}],\"year\":{},\"source\":{},\"volume\":{},\"issue\":{},\"pages\":{},\"edition\":{},\"doi\":{},\"url\":{}}}\n",
            json_str(&r.key),
            json_str(&ty),
            json_str(&dequote(&get("title"))),
            authors_json,
            json_str(&year),
            json_str(&dequote(&source)),
            json_str(&dequote(&get("volume"))),
            json_str(&dequote(&get("issue"))),
            json_str(&dequote(&get("page-range"))),
            json_str(&dequote(&get("edition"))),
            json_str(&dequote(&doi)),
            json_str(&url),
        ));
    }
    fs::write(&args[2], out)?;
    writeln!(io::stderr(), "refs_seed: {} entradas | books={} | con_doi={} | con_url={}", recs.len(), n_book, n_doi, n_url)?;
    Ok(())
}
