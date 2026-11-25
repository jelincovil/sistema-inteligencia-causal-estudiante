use std::collections::HashSet;

use crate::error::ContractError;
use crate::limits::{MAX_DOCUMENT_BYTES, MAX_JSON_DEPTH, MAX_JSON_NODES};

/// Reject duplicate keys inside any JSON object.
///
/// `serde_json` keeps the last key and does not report the collision. The
/// kernel contract forbids that, because a silent overwrite can hide a
/// contradictory claim.
///
/// The pre-parser is bounded: [`MAX_DOCUMENT_BYTES`] bytes,
/// [`MAX_JSON_DEPTH`] nesting levels, and [`MAX_JSON_NODES`] values. A deep
/// or wide document fails with a typed error instead of overflowing the
/// stack or running forever.
pub fn reject_duplicate_keys(input: &str) -> Result<(), ContractError> {
    if input.len() as u64 > MAX_DOCUMENT_BYTES {
        return Err(ContractError::InputTooLarge {
            limit: MAX_DOCUMENT_BYTES,
            actual: input.len() as u64,
        });
    }
    let mut parser = Parser {
        bytes: input.as_bytes(),
        index: 0,
        nodes: 0,
    };
    parser.skip_ws();
    parser.parse_value("$", 0)?;
    parser.skip_ws();
    if parser.index != parser.bytes.len() {
        return Err(ContractError::Json(
            "trailing data after the JSON value".to_string(),
        ));
    }
    Ok(())
}

struct Parser<'a> {
    bytes: &'a [u8],
    index: usize,
    nodes: usize,
}

impl<'a> Parser<'a> {
    fn skip_ws(&mut self) {
        while self.index < self.bytes.len() && self.bytes[self.index].is_ascii_whitespace() {
            self.index += 1;
        }
    }

    fn note_node(&mut self) -> Result<(), ContractError> {
        self.nodes += 1;
        if self.nodes > MAX_JSON_NODES {
            return Err(ContractError::JsonTooManyNodes {
                limit: MAX_JSON_NODES,
            });
        }
        Ok(())
    }

    fn peek(&self) -> Result<u8, ContractError> {
        self.bytes
            .get(self.index)
            .copied()
            .ok_or_else(|| ContractError::Json("unexpected end of JSON".to_string()))
    }

    fn bump(&mut self) -> Result<u8, ContractError> {
        let byte = self.peek()?;
        self.index += 1;
        Ok(byte)
    }

    fn parse_value(&mut self, path: &str, depth: usize) -> Result<(), ContractError> {
        if depth > MAX_JSON_DEPTH {
            return Err(ContractError::JsonTooDeep {
                limit: MAX_JSON_DEPTH,
            });
        }
        self.note_node()?;
        match self.peek()? {
            b'{' => self.parse_object(path, depth),
            b'[' => self.parse_array(path, depth),
            b'"' => {
                let _ = self.parse_string()?;
                Ok(())
            }
            b't' => self.consume_literal(b"true"),
            b'f' => self.consume_literal(b"false"),
            b'n' => self.consume_literal(b"null"),
            b'-' | b'0'..=b'9' => self.skip_number(),
            other => Err(ContractError::Json(format!(
                "unexpected byte {other} at {path}"
            ))),
        }
    }

    fn parse_object(&mut self, path: &str, depth: usize) -> Result<(), ContractError> {
        self.expect(b'{')?;
        self.skip_ws();
        let mut keys = HashSet::new();
        if self.peek()? == b'}' {
            self.index += 1;
            return Ok(());
        }
        loop {
            self.skip_ws();
            if self.peek()? != b'"' {
                return Err(ContractError::Json(format!(
                    "object key must be a string at {path}"
                )));
            }
            let key = self.parse_string()?;
            if !keys.insert(key.clone()) {
                return Err(ContractError::DuplicateKey {
                    path: path.to_string(),
                    key,
                });
            }
            self.skip_ws();
            self.expect(b':')?;
            self.skip_ws();
            let child = format!("{path}.{key}");
            self.parse_value(&child, depth + 1)?;
            self.skip_ws();
            match self.bump()? {
                b',' => continue,
                b'}' => return Ok(()),
                other => {
                    return Err(ContractError::Json(format!(
                        "expected comma or closing brace, found {other} at {path}"
                    )));
                }
            }
        }
    }

    fn parse_array(&mut self, path: &str, depth: usize) -> Result<(), ContractError> {
        self.expect(b'[')?;
        self.skip_ws();
        if self.peek()? == b']' {
            self.index += 1;
            return Ok(());
        }
        let mut item = 0_usize;
        loop {
            self.skip_ws();
            let child = format!("{path}[{item}]");
            self.parse_value(&child, depth + 1)?;
            item += 1;
            self.skip_ws();
            match self.bump()? {
                b',' => continue,
                b']' => return Ok(()),
                other => {
                    return Err(ContractError::Json(format!(
                        "expected comma or closing bracket, found {other} at {path}"
                    )));
                }
            }
        }
    }

    fn parse_string(&mut self) -> Result<String, ContractError> {
        self.expect(b'"')?;
        let mut out = String::new();
        loop {
            let byte = self.bump()?;
            match byte {
                b'"' => return Ok(out),
                b'\\' => {
                    let escaped = self.bump()?;
                    match escaped {
                        b'"' | b'\\' | b'/' => out.push(escaped as char),
                        b'b' => out.push('\u{0008}'),
                        b'f' => out.push('\u{000c}'),
                        b'n' => out.push('\n'),
                        b'r' => out.push('\r'),
                        b't' => out.push('\t'),
                        b'u' => out.push(self.parse_unicode_escape()?),
                        other => {
                            return Err(ContractError::Json(format!("invalid escape {other}")));
                        }
                    }
                }
                b if b < 0x20 => {
                    return Err(ContractError::Json(
                        "raw control character in string".to_string(),
                    ));
                }
                b => {
                    if b < 0x80 {
                        out.push(b as char);
                    } else {
                        self.index -= 1;
                        let rest = &self.bytes[self.index..];
                        let text = std::str::from_utf8(rest).map_err(|_| ContractError::Utf8)?;
                        let ch = text.chars().next().ok_or(ContractError::Utf8)?;
                        out.push(ch);
                        self.index += ch.len_utf8();
                    }
                }
            }
        }
    }

    fn parse_unicode_escape(&mut self) -> Result<char, ContractError> {
        let unit = self.read_hex4()?;
        if (0xD800..=0xDBFF).contains(&unit) {
            if self.bump()? != b'\\' || self.bump()? != b'u' {
                return Err(ContractError::Json(
                    "lonely UTF-16 surrogate in JSON string".to_string(),
                ));
            }
            let low = self.read_hex4()?;
            if !(0xDC00..=0xDFFF).contains(&low) {
                return Err(ContractError::Json(
                    "invalid UTF-16 surrogate pair".to_string(),
                ));
            }
            let code = 0x10000 + (((unit - 0xD800) as u32) << 10) + (low - 0xDC00) as u32;
            return char::from_u32(code).ok_or_else(|| {
                ContractError::Json("invalid Unicode scalar from surrogate pair".to_string())
            });
        }
        char::from_u32(unit as u32)
            .ok_or_else(|| ContractError::Json("invalid Unicode escape".to_string()))
    }

    fn read_hex4(&mut self) -> Result<u16, ContractError> {
        let mut value = 0_u16;
        for _ in 0..4 {
            let byte = self.bump()?;
            let digit = match byte {
                b'0'..=b'9' => byte - b'0',
                b'a'..=b'f' => byte - b'a' + 10,
                b'A'..=b'F' => byte - b'A' + 10,
                _ => {
                    return Err(ContractError::Json(
                        "invalid hex digit in \\u escape".to_string(),
                    ));
                }
            };
            value = (value << 4) | u16::from(digit);
        }
        Ok(value)
    }

    fn skip_number(&mut self) -> Result<(), ContractError> {
        if self.peek()? == b'-' {
            self.index += 1;
        }
        if self.peek()? == b'0' {
            self.index += 1;
            if self.index < self.bytes.len() && self.bytes[self.index].is_ascii_digit() {
                return Err(ContractError::Json(
                    "leading zeros are not valid JSON".to_string(),
                ));
            }
        } else if self.peek()?.is_ascii_digit() {
            while self.index < self.bytes.len() && self.bytes[self.index].is_ascii_digit() {
                self.index += 1;
            }
        } else {
            return Err(ContractError::Json("invalid number".to_string()));
        }
        if self.index < self.bytes.len() && self.bytes[self.index] == b'.' {
            self.index += 1;
            if !self.peek()?.is_ascii_digit() {
                return Err(ContractError::Json("invalid fraction".to_string()));
            }
            while self.index < self.bytes.len() && self.bytes[self.index].is_ascii_digit() {
                self.index += 1;
            }
        }
        if self.index < self.bytes.len() && matches!(self.bytes[self.index], b'e' | b'E') {
            self.index += 1;
            if self.index < self.bytes.len() && matches!(self.bytes[self.index], b'+' | b'-') {
                self.index += 1;
            }
            if !self.peek()?.is_ascii_digit() {
                return Err(ContractError::Json("invalid exponent".to_string()));
            }
            while self.index < self.bytes.len() && self.bytes[self.index].is_ascii_digit() {
                self.index += 1;
            }
        }
        Ok(())
    }

    fn consume_literal(&mut self, literal: &[u8]) -> Result<(), ContractError> {
        if self.bytes[self.index..].starts_with(literal) {
            self.index += literal.len();
            Ok(())
        } else {
            Err(ContractError::Json(format!(
                "expected {}",
                String::from_utf8_lossy(literal)
            )))
        }
    }

    fn expect(&mut self, byte: u8) -> Result<(), ContractError> {
        let found = self.bump()?;
        if found == byte {
            Ok(())
        } else {
            Err(ContractError::Json(format!(
                "expected byte {byte}, found {found}"
            )))
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn deep_nesting_fails_closed() {
        let mut deep = String::new();
        for _ in 0..(MAX_JSON_DEPTH + 10) {
            deep.push('[');
        }
        for _ in 0..(MAX_JSON_DEPTH + 10) {
            deep.push(']');
        }
        assert!(matches!(
            reject_duplicate_keys(&deep),
            Err(ContractError::JsonTooDeep { .. })
        ));
    }

    #[test]
    fn wide_document_fails_closed() {
        let mut wide = String::from("[");
        for index in 0..(MAX_JSON_NODES + 10) {
            if index > 0 {
                wide.push(',');
            }
            wide.push_str("null");
        }
        wide.push(']');
        assert!(matches!(
            reject_duplicate_keys(&wide),
            Err(ContractError::JsonTooManyNodes { .. })
        ));
    }

    #[test]
    fn too_many_keys_in_one_object_still_rejects_duplicates() {
        let mut text = String::from("{");
        for index in 0..1000 {
            if index > 0 {
                text.push(',');
            }
            text.push_str(&format!("\"k{index}\":null"));
        }
        text.push_str(",\"k0\":null}");
        assert!(matches!(
            reject_duplicate_keys(&text),
            Err(ContractError::DuplicateKey { .. })
        ));
    }
}
