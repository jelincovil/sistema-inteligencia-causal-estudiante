//! refs_apply — inserta `doi:` en entradas de refs.yml sin tocar nada más.
//!
//! Uso: refs_apply <refs.yml> <dois_fix.jsonl> [--write]
//! Sin --write: dry-run (informa). Con --write: reescribe refs.yml en sitio.
//! dois_fix.jsonl: una línea {"key":"clave","doi":"10...."} por línea.

use std::collections::BTreeMap;
use std::env;
use std::fs;
use std::io;
use std::path::Path;

fn main() -> io::Result<()> {
    let args: Vec<String> = env::args().collect();
    if args.len() < 3 {
        eprintln!("uso: refs_apply <refs.yml> <dois_fix.jsonl> [--write]");
        std::process::exit(2);
    }
    let write_mode = args.iter().any(|a| a == "--write");
    let refs_path = &args[1];
    let fixes_path = &args[2];

    let text = fs::read_to_string(refs_path)?;
    let fixes_text = fs::read_to_string(fixes_path)?;

    let mut fixes: BTreeMap<String, String> = BTreeMap::new();
    for (ln, line) in fixes_text.lines().enumerate() {
        let line = line.trim();
        if line.is_empty() { continue; }
        let key = extract_json_str(line, "key")
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, format!("línea {}: falta key", ln + 1)))?;
        let doi = extract_json_str(line, "doi")
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, format!("línea {}: falta doi", ln + 1)))?;
        fixes.insert(key, doi);
    }

    let mut lines: Vec<String> = text.lines().map(|l| l.to_string()).collect();
    let mut blocks: Vec<(usize, usize, String)> = Vec::new();
    let mut cur_start: Option<usize> = None;
    let mut cur_key = String::new();
    for (i, l) in lines.iter().enumerate() {
        if is_toplevel_key(l) {
            if let Some(s) = cur_start.take() {
                blocks.push((s, i, cur_key.clone()));
            }
            cur_start = Some(i);
            cur_key = l[..l.find(':').unwrap()].trim().to_string();
        }
    }
    if let Some(s) = cur_start.take() {
        blocks.push((s, lines.len(), cur_key));
    }

    let mut inserted = 0usize;
    let mut already = Vec::new();
    for (start, end, key) in blocks.iter().rev() {
        let Some(doi) = fixes.get(key) else { continue; };
        let block = &lines[*start..*end];
        if block.iter().any(|l| l.trim_start().starts_with("doi:")) {
            already.push(key.clone());
            continue;
        }
        let mut insert_at = *end;
        while insert_at > *start && lines[insert_at - 1].trim().is_empty() {
            insert_at -= 1;
        }
        lines.insert(insert_at, format!("  doi: \"{}\"", doi));
        inserted += 1;
    }

    let known: std::collections::BTreeSet<&String> = blocks.iter().map(|(_, _, k)| k).collect();
    let unknown: Vec<String> = fixes.keys().filter(|k| !known.contains(k)).cloned().collect();

    eprintln!("refs_apply: {inserted} dois insertados | ya tenían doi: {} | claves desconocidas: {}", already.len(), unknown.len());
    if !unknown.is_empty() { eprintln!("desconocidas: {}", unknown.join(", ")); }
    if !already.is_empty() { eprintln!("omitidas por doi existente: {}", already.join(", ")); }

    if write_mode {
        let out = lines.join("\n") + if text.ends_with('\n') { "\n" } else { "" };
        let bak = format!("{}.pre-doi-backup", refs_path);
        if !Path::new(&bak).exists() { fs::write(&bak, &text)?; }
        fs::write(refs_path, out)?;
        eprintln!("refs_apply: refs.yml reescrito (backup: {bak})");
    } else {
        eprintln!("refs_apply: dry-run (usa --write para aplicar)");
    }
    Ok(())
}

fn is_toplevel_key(l: &str) -> bool {
    if l.starts_with(' ') || l.starts_with('#') || l.trim().is_empty() { return false; }
    match l.find(':') {
        Some(pos) => {
            let k = l[..pos].trim();
            !k.is_empty() && k.chars().all(|c| c.is_ascii_alphanumeric() || c == '_' || c == '-')
        }
        None => false,
    }
}

fn extract_json_str(line: &str, field: &str) -> Option<String> {
    let needle = format!("\"{}\":", field);
    let start = line.find(&needle)? + needle.len();
    let rest = line[start..].trim_start();
    if !rest.starts_with('"') { return None; }
    let inner = &rest[1..];
    let mut out = String::new();
    let mut escaped = false;
    for c in inner.chars() {
        if escaped {
            match c { 'n' => out.push('\n'), 't' => out.push('\t'), 'r' => out.push('\r'), o => out.push(o) }
            escaped = false;
        } else if c == '\\' { escaped = true; } else if c == '"' { return Some(out); } else { out.push(c); }
    }
    None
}
