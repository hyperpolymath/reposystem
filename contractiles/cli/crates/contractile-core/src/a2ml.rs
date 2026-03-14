// SPDX-License-Identifier: PMPL-1.0-or-later
// a2ml.rs — Parser for A2ML (Annotated Markup with Machine Logic) contractile files.
//
// A2ML is the canonical format for all contractile types: Mustfile, Trustfile,
// Dustfile, Intentfile, and any future *file contracts. The format is deliberately
// line-oriented and human-readable, with a small set of structural elements:
//
//   # comment
//   @block-name:      ← opens a metadata block
//   @end              ← closes it
//   ## Section        ← level-2 heading (section)
//   ### Subsection    ← level-3 heading (named entry within a section)
//   - key: value      ← key-value pair within the current section/subsection
//   plain text        ← prose within @abstract or section bodies
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{Context, Result};

/// A fully parsed A2ML document, representing one contractile file.
#[derive(Debug, Clone)]
pub struct A2mlDocument {
    /// SPDX license identifier extracted from the header comment.
    pub spdx_license: Option<String>,

    /// The contractile type name parsed from the header comment
    /// (e.g. "Mustfile", "Trustfile", "Dustfile", "Intentfile").
    pub file_type: Option<String>,

    /// Contents of the `@abstract:` block — a human-readable summary of
    /// what this contractile file declares.
    pub abstract_text: Option<String>,

    /// Section names listed in the `@requires:` block. These declare which
    /// sections the document considers mandatory for completeness.
    pub requires: Vec<String>,

    /// All top-level sections (`## Heading`) and their contents.
    pub sections: Vec<Section>,
}

/// A top-level section within an A2ML document, introduced by `## Name`.
#[derive(Debug, Clone)]
pub struct Section {
    /// Section heading text (the part after `## `).
    pub name: String,

    /// Key-value entries directly within this section (not inside a subsection).
    pub entries: Vec<Entry>,

    /// Named subsections introduced by `### Name` within this section.
    pub subsections: Vec<Subsection>,

    /// Prose lines that appear before any entries or subsections.
    pub prose: Vec<String>,
}

/// A named subsection within a section, introduced by `### Name`.
/// Subsections are the typical unit of an "item" within a contractile — for
/// example, a single check in a Mustfile, a single verification in a Trustfile,
/// or a single rollback target in a Dustfile.
#[derive(Debug, Clone)]
pub struct Subsection {
    /// Subsection heading text (the part after `### `).
    pub name: String,

    /// Key-value entries within this subsection.
    pub entries: Vec<Entry>,
}

/// A single key-value pair parsed from `- key: value` lines.
#[derive(Debug, Clone)]
pub struct Entry {
    /// The key portion (trimmed, before the first `:`).
    pub key: String,

    /// The value portion (trimmed, after the first `:`).
    pub value: String,
}

/// Well-known executable field keys used across contractile types.
/// Each contractile type uses a subset of these to indicate which entries
/// contain shell commands that can be run by the corresponding CLI tool.
pub mod executable_keys {
    /// Mustfile: the command to run for a check.
    pub const RUN: &str = "run";

    /// Trustfile: the command to run for a verification step.
    pub const COMMAND: &str = "command";

    /// Dustfile: the handler command for a recovery action.
    pub const HANDLER: &str = "handler";

    /// Dustfile: the rollback command to undo a change.
    pub const ROLLBACK: &str = "rollback";

    /// Dustfile: the undo command for a deployment failure.
    pub const UNDO: &str = "undo";

    /// Dustfile: the transform command to convert logs into dust events.
    pub const TRANSFORM: &str = "transform";

    /// Returns all keys that represent executable commands, in any contractile type.
    pub fn all() -> &'static [&'static str] {
        &[RUN, COMMAND, HANDLER, ROLLBACK, UNDO, TRANSFORM]
    }
}

/// Internal parser state — which structural context we're currently inside.
#[derive(Debug, PartialEq)]
enum ParseState {
    /// Outside any block or section, at the top of the file.
    TopLevel,
    /// Inside an `@abstract:` ... `@end` block.
    AbstractBlock,
    /// Inside an `@requires:` ... `@end` block.
    RequiresBlock,
    /// Inside a `## Section`, before any `### Subsection`.
    InSection,
    /// Inside a `### Subsection` within a section.
    InSubsection,
}

/// Parse an A2ML source string into a structured document.
///
/// The parser is intentionally lenient: it ignores unknown `@block:` types,
/// treats unrecognised lines as prose, and does not require any particular
/// section ordering. This allows the format to evolve without breaking older
/// parsers.
pub fn parse(input: &str) -> Result<A2mlDocument> {
    let mut doc = A2mlDocument {
        spdx_license: None,
        file_type: None,
        abstract_text: None,
        requires: Vec::new(),
        sections: Vec::new(),
    };

    let mut state = ParseState::TopLevel;
    let mut abstract_lines: Vec<String> = Vec::new();

    for (line_num, raw_line) in input.lines().enumerate() {
        let line = raw_line.trim_end();
        let line_ctx = || format!("line {}", line_num + 1);

        // ── Blank lines ──
        if line.trim().is_empty() {
            if state == ParseState::AbstractBlock {
                abstract_lines.push(String::new());
            }
            continue;
        }

        // ── Comment lines (# ...) ──
        if line.starts_with('#') && !line.starts_with("##") {
            // Extract SPDX license from comment header.
            if let Some(rest) = line.strip_prefix("# SPDX-License-Identifier:") {
                doc.spdx_license = Some(rest.trim().to_string());
            }
            // Extract file type from comment like "# Mustfile (A2ML Canonical)".
            if line.contains("(A2ML") || line.contains("A2ML Canonical") {
                let type_part = line.trim_start_matches('#').trim();
                if let Some(name) = type_part.split_whitespace().next() {
                    doc.file_type = Some(name.to_string());
                }
            }
            continue;
        }

        // ── @block: and @end directives ──
        if line.trim() == "@end" {
            match state {
                ParseState::AbstractBlock => {
                    doc.abstract_text = Some(abstract_lines.join("\n").trim().to_string());
                    abstract_lines.clear();
                }
                ParseState::RequiresBlock => {
                    // requires entries already pushed
                }
                _ => {}
            }
            // Return to whatever context makes sense — if we had sections,
            // we'd go back to section, but @end only closes metadata blocks
            // which always appear before sections.
            state = ParseState::TopLevel;
            continue;
        }

        if line.trim() == "@abstract:" {
            state = ParseState::AbstractBlock;
            continue;
        }

        if line.trim() == "@requires:" {
            state = ParseState::RequiresBlock;
            continue;
        }

        // Skip unknown @block: directives (forward compatibility).
        if line.trim().starts_with('@') && line.trim().ends_with(':') {
            // Unknown block — consume until @end
            state = ParseState::TopLevel;
            continue;
        }

        // ── State-specific parsing ──
        match state {
            ParseState::AbstractBlock => {
                abstract_lines.push(line.to_string());
            }

            ParseState::RequiresBlock => {
                // Lines like "- section: Parameters"
                if let Some(entry) = parse_entry(line) {
                    if entry.key == "section" {
                        doc.requires.push(entry.value);
                    }
                }
            }

            ParseState::TopLevel | ParseState::InSection | ParseState::InSubsection => {
                // ── ## Section heading ──
                if let Some(heading) = line.strip_prefix("## ") {
                    let heading = heading.trim();
                    if !heading.is_empty() {
                        doc.sections.push(Section {
                            name: heading.to_string(),
                            entries: Vec::new(),
                            subsections: Vec::new(),
                            prose: Vec::new(),
                        });
                        state = ParseState::InSection;
                        continue;
                    }
                }

                // ── ### Subsection heading ──
                if let Some(heading) = line.strip_prefix("### ") {
                    let heading = heading.trim();
                    if !heading.is_empty() {
                        let section = doc.sections.last_mut().with_context(|| {
                            format!(
                                "{}: subsection '{}' found before any section",
                                line_ctx(),
                                heading
                            )
                        })?;
                        section.subsections.push(Subsection {
                            name: heading.to_string(),
                            entries: Vec::new(),
                        });
                        state = ParseState::InSubsection;
                        continue;
                    }
                }

                // ── - key: value entry ──
                if let Some(entry) = parse_entry(line) {
                    match state {
                        ParseState::InSubsection => {
                            if let Some(section) = doc.sections.last_mut() {
                                if let Some(sub) = section.subsections.last_mut() {
                                    sub.entries.push(entry);
                                }
                            }
                        }
                        ParseState::InSection => {
                            if let Some(section) = doc.sections.last_mut() {
                                section.entries.push(entry);
                            }
                        }
                        _ => {
                            // Entry at top level (unusual but tolerated)
                        }
                    }
                    continue;
                }

                // ── Prose lines (plain text within a section) ──
                if state == ParseState::InSection {
                    if let Some(section) = doc.sections.last_mut() {
                        section.prose.push(line.to_string());
                    }
                }
            }
        }
    }

    Ok(doc)
}

/// Try to parse a line as `- key: value`. Returns `None` if the line doesn't
/// match the expected format.
fn parse_entry(line: &str) -> Option<Entry> {
    let trimmed = line.trim();
    let body = trimmed.strip_prefix("- ")?;

    // Split on the first `:` only — values may contain colons (e.g. URLs,
    // sha256sum output, openssl commands).
    let colon_pos = body.find(':')?;
    let key = body[..colon_pos].trim().to_string();
    let value = body[colon_pos + 1..].trim().to_string();

    if key.is_empty() {
        return None;
    }

    Some(Entry { key, value })
}

// ── Convenience accessors ──

impl A2mlDocument {
    /// Find a section by name (case-sensitive).
    pub fn section(&self, name: &str) -> Option<&Section> {
        self.sections.iter().find(|s| s.name == name)
    }

    /// Iterate over all subsections across all sections that contain an
    /// executable command entry (run, command, handler, rollback, undo, transform).
    pub fn executable_items(&self) -> Vec<ExecutableItem<'_>> {
        let mut items = Vec::new();
        for section in &self.sections {
            for sub in &section.subsections {
                for entry in &sub.entries {
                    if executable_keys::all().contains(&entry.key.as_str()) {
                        items.push(ExecutableItem {
                            section: &section.name,
                            subsection: &sub.name,
                            key: &entry.key,
                            command: &entry.value,
                            description: sub
                                .entries
                                .iter()
                                .find(|e| e.key == "description")
                                .map(|e| e.value.as_str()),
                        });
                    }
                }
            }
        }
        items
    }
}

/// A reference to a single executable item found within an A2ML document.
/// Produced by [`A2mlDocument::executable_items`].
#[derive(Debug)]
pub struct ExecutableItem<'a> {
    /// The section this item belongs to (e.g. "Checks", "Verifications").
    pub section: &'a str,

    /// The subsection (entry name) this item belongs to (e.g. "policy-config-valid").
    pub subsection: &'a str,

    /// The key type that makes this executable (e.g. "run", "command", "rollback").
    pub key: &'a str,

    /// The shell command to execute.
    pub command: &'a str,

    /// An optional human-readable description from the same subsection.
    pub description: Option<&'a str>,
}

impl Section {
    /// Look up a direct entry by key within this section.
    pub fn get(&self, key: &str) -> Option<&str> {
        self.entries
            .iter()
            .find(|e| e.key == key)
            .map(|e| e.value.as_str())
    }

    /// Find a subsection by name.
    pub fn subsection(&self, name: &str) -> Option<&Subsection> {
        self.subsections.iter().find(|s| s.name == name)
    }
}

impl Subsection {
    /// Look up an entry by key within this subsection.
    pub fn get(&self, key: &str) -> Option<&str> {
        self.entries
            .iter()
            .find(|e| e.key == key)
            .map(|e| e.value.as_str())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// Verify the parser handles a minimal Mustfile-style A2ML document.
    #[test]
    fn parse_mustfile_style() {
        let input = r#"
# SPDX-License-Identifier: PMPL-1.0-or-later
# Mustfile (A2ML Canonical)

@abstract:
Declarative state contract describing what must be true.
@end

@requires:
- section: Parameters
- section: Checks
@end

## Parameters

- gateway_port: 8080
- schema_version: v1.0.0

## Checks

### policy-config-valid
- description: config/policy.yaml must be valid
- run: just validate-policy

### gateway-exposes-port
- description: gateway must expose the configured port
- run: ss -lnt | rg ":8080"
"#;

        let doc = parse(input).unwrap();
        assert_eq!(doc.spdx_license.as_deref(), Some("PMPL-1.0-or-later"));
        assert_eq!(doc.file_type.as_deref(), Some("Mustfile"));
        assert!(doc.abstract_text.as_ref().unwrap().contains("must be true"));
        assert_eq!(doc.requires, vec!["Parameters", "Checks"]);
        assert_eq!(doc.sections.len(), 2);

        // Parameters section has direct entries
        let params = doc.section("Parameters").unwrap();
        assert_eq!(params.get("gateway_port"), Some("8080"));

        // Checks section has subsections with executable items
        let checks = doc.section("Checks").unwrap();
        assert_eq!(checks.subsections.len(), 2);
        let policy = checks.subsection("policy-config-valid").unwrap();
        assert_eq!(policy.get("run"), Some("just validate-policy"));

        // executable_items should find 2 items (both `run` entries)
        let execs = doc.executable_items();
        assert_eq!(execs.len(), 2);
        assert_eq!(execs[0].subsection, "policy-config-valid");
        assert_eq!(execs[0].key, "run");
    }

    /// Verify the parser handles Trustfile-style `command:` entries.
    #[test]
    fn parse_trustfile_style() {
        let input = r#"
# Trustfile (A2ML Canonical)

## Verifications

### policy-hash
- description: SHA-256 of policy matches
- command: sha256sum policy/policy.ncl
"#;

        let doc = parse(input).unwrap();
        let execs = doc.executable_items();
        assert_eq!(execs.len(), 1);
        assert_eq!(execs[0].key, "command");
        assert_eq!(execs[0].command, "sha256sum policy/policy.ncl");
    }

    /// Verify the parser handles Dustfile-style multi-key executables.
    #[test]
    fn parse_dustfile_style() {
        let input = r#"
# Dustfile (A2ML Canonical)

## Policy

### policy-rollback
- path: policy/policy.ncl
- rollback: git checkout HEAD~1 -- policy/policy.ncl

## Gateway

### bad-deployment
- event: deploy.failure
- undo: gatewayctl rollback --last
"#;

        let doc = parse(input).unwrap();
        let execs = doc.executable_items();
        assert_eq!(execs.len(), 2);
        assert_eq!(execs[0].key, "rollback");
        assert_eq!(execs[1].key, "undo");
    }
}
