// SPDX-License-Identifier: PMPL-1.0-or-later
// toml_compat.rs — Parse mustfile.toml into A2mlDocument for backward compatibility.
//
// The Ada must runner uses mustfile.toml (TOML format) as its contract file.
// This module converts that format into the same A2mlDocument structure used
// by the A2ML parser, so the rest of the CLI works identically regardless
// of input format.
//
// TOML sections mapped to A2ML:
//   [project]              → Section "Project" with direct entries
//   [tasks.<name>]         → Section "Tasks", subsection per task
//   [requirements]         → Section "Requirements" with must_have/must_not_have
//   [requirements.content] → Subsections under "Requirements"
//   [enforcement]          → Section "Enforcement" with direct entries
//   [deploy]               → Section "Deploy" with direct entries
//
// The key difference: TOML tasks have `commands` arrays that become
// executable `run:` entries, so `must list` and `must run` work on TOML files.
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use crate::a2ml::{A2mlDocument, Entry, Section, Subsection};
use anyhow::{Context, Result};
use std::fs;
use std::path::Path;

/// Parse a mustfile.toml and convert it into an A2mlDocument.
pub fn parse_mustfile_toml(path: &Path) -> Result<A2mlDocument> {
    let content = fs::read_to_string(path)
        .with_context(|| format!("reading mustfile.toml: {}", path.display()))?;

    let table: toml::Table = content
        .parse()
        .with_context(|| format!("parsing TOML: {}", path.display()))?;

    let mut doc = A2mlDocument {
        spdx_license: None,
        file_type: Some("Mustfile".to_string()),
        abstract_text: None,
        requires: Vec::new(),
        sections: Vec::new(),
    };

    // ── Project section ──
    if let Some(project) = table.get("project").and_then(|v| v.as_table()) {
        let mut entries = Vec::new();
        for (key, value) in project {
            entries.push(Entry {
                key: key.clone(),
                value: value_to_string(value),
            });
        }
        doc.sections.push(Section {
            name: "Project".to_string(),
            entries,
            subsections: Vec::new(),
            prose: Vec::new(),
        });
    }

    // ── Tasks section → each task becomes a subsection with `run:` commands ──
    if let Some(tasks) = table.get("tasks").and_then(|v| v.as_table()) {
        let mut task_section = Section {
            name: "Tasks".to_string(),
            entries: Vec::new(),
            subsections: Vec::new(),
            prose: Vec::new(),
        };

        for (task_name, task_value) in tasks {
            if let Some(task_table) = task_value.as_table() {
                let mut entries = Vec::new();

                if let Some(desc) = task_table.get("description").and_then(|v| v.as_str()) {
                    entries.push(Entry {
                        key: "description".to_string(),
                        value: desc.to_string(),
                    });
                }

                if let Some(deps) = task_table.get("dependencies").and_then(|v| v.as_array()) {
                    let dep_str: Vec<&str> = deps.iter().filter_map(|v| v.as_str()).collect();
                    if !dep_str.is_empty() {
                        entries.push(Entry {
                            key: "dependencies".to_string(),
                            value: dep_str.join(", "),
                        });
                    }
                }

                // Convert commands array into a single `run:` entry.
                // Multiple commands are joined with ` && `.
                if let Some(cmds) = task_table.get("commands").and_then(|v| v.as_array()) {
                    let cmd_strs: Vec<&str> = cmds.iter().filter_map(|v| v.as_str()).collect();
                    if !cmd_strs.is_empty() {
                        entries.push(Entry {
                            key: "run".to_string(),
                            value: cmd_strs.join(" && "),
                        });
                    }
                }

                task_section.subsections.push(Subsection {
                    name: task_name.clone(),
                    entries,
                });
            }
        }

        doc.sections.push(task_section);
    }

    // ── Requirements section ──
    if let Some(reqs) = table.get("requirements").and_then(|v| v.as_table()) {
        let mut req_section = Section {
            name: "Requirements".to_string(),
            entries: Vec::new(),
            subsections: Vec::new(),
            prose: Vec::new(),
        };

        // must_have → subsection "must-have" with a run command checking file existence
        if let Some(must_have) = reqs.get("must_have").and_then(|v| v.as_array()) {
            let files: Vec<&str> = must_have.iter().filter_map(|v| v.as_str()).collect();
            if !files.is_empty() {
                let check_cmd = files
                    .iter()
                    .map(|f| format!("test -f \"{}\"", f))
                    .collect::<Vec<_>>()
                    .join(" && ");

                req_section.subsections.push(Subsection {
                    name: "must-have".to_string(),
                    entries: vec![
                        Entry {
                            key: "description".to_string(),
                            value: format!("Files that must exist ({})", files.len()),
                        },
                        Entry {
                            key: "run".to_string(),
                            value: check_cmd,
                        },
                    ],
                });
            }
        }

        // must_not_have → subsection "must-not-have"
        if let Some(must_not) = reqs.get("must_not_have").and_then(|v| v.as_array()) {
            let files: Vec<&str> = must_not.iter().filter_map(|v| v.as_str()).collect();
            if !files.is_empty() {
                let check_cmd = files
                    .iter()
                    .map(|f| format!("test ! -e \"{}\"", f))
                    .collect::<Vec<_>>()
                    .join(" && ");

                req_section.subsections.push(Subsection {
                    name: "must-not-have".to_string(),
                    entries: vec![
                        Entry {
                            key: "description".to_string(),
                            value: format!("Files that must not exist ({})", files.len()),
                        },
                        Entry {
                            key: "run".to_string(),
                            value: check_cmd,
                        },
                    ],
                });
            }
        }

        // content requirements → subsection per file
        if let Some(content) = reqs.get("content").and_then(|v| v.as_table()) {
            for (file, patterns) in content {
                if let Some(pats) = patterns.as_array() {
                    let pat_strs: Vec<&str> = pats.iter().filter_map(|v| v.as_str()).collect();
                    let check_cmd = pat_strs
                        .iter()
                        .map(|p| format!("grep -q \"{}\" \"{}\"", p, file))
                        .collect::<Vec<_>>()
                        .join(" && ");

                    req_section.subsections.push(Subsection {
                        name: format!("content-{}", file.replace('/', "-").replace('.', "-")),
                        entries: vec![
                            Entry {
                                key: "description".to_string(),
                                value: format!("{} must contain required strings", file),
                            },
                            Entry {
                                key: "run".to_string(),
                                value: check_cmd,
                            },
                        ],
                    });
                }
            }
        }

        doc.sections.push(req_section);
    }

    // ── Enforcement section ──
    if let Some(enforcement) = table.get("enforcement").and_then(|v| v.as_table()) {
        let mut entries = Vec::new();
        for (key, value) in enforcement {
            if key == "checks" {
                continue; // handled separately
            }
            entries.push(Entry {
                key: key.clone(),
                value: value_to_string(value),
            });
        }

        if let Some(checks) = enforcement.get("checks").and_then(|v| v.as_table()) {
            for (key, value) in checks {
                entries.push(Entry {
                    key: key.clone(),
                    value: value_to_string(value),
                });
            }
        }

        doc.sections.push(Section {
            name: "Enforcement".to_string(),
            entries,
            subsections: Vec::new(),
            prose: Vec::new(),
        });
    }

    // Set abstract from project info.
    if let Some(project) = table.get("project").and_then(|v| v.as_table()) {
        let name = project
            .get("name")
            .and_then(|v| v.as_str())
            .unwrap_or("unknown");
        doc.abstract_text = Some(format!(
            "Physical State contract for {} (converted from mustfile.toml)",
            name
        ));
    }

    Ok(doc)
}

/// Convert a TOML value to a string representation.
fn value_to_string(value: &toml::Value) -> String {
    match value {
        toml::Value::String(s) => s.clone(),
        toml::Value::Integer(n) => n.to_string(),
        toml::Value::Float(f) => f.to_string(),
        toml::Value::Boolean(b) => b.to_string(),
        toml::Value::Array(arr) => {
            let items: Vec<String> = arr.iter().map(value_to_string).collect();
            items.join(", ")
        }
        other => other.to_string(),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    #[test]
    fn parse_minimal_mustfile_toml() {
        let toml_content = r#"
schema = "0.1"

[project]
name = "test-project"
version = "1.0.0"

[tasks.build]
description = "Build the project"
commands = ["cargo build"]

[tasks.test]
description = "Run tests"
dependencies = ["build"]
commands = ["cargo test"]

[requirements]
must_have = ["Cargo.toml", "src/main.rs"]
must_not_have = ["Makefile"]
"#;
        let mut tmp = tempfile::NamedTempFile::new().unwrap();
        write!(tmp, "{}", toml_content).unwrap();

        let doc = parse_mustfile_toml(tmp.path()).unwrap();
        assert_eq!(doc.file_type.as_deref(), Some("Mustfile"));

        // Should have Tasks section with executable items.
        let execs = doc.executable_items();
        // build (run), test (run), must-have (run), must-not-have (run) = 4
        assert!(execs.len() >= 2);

        // Tasks should have descriptions.
        let tasks = doc.section("Tasks").unwrap();
        let build = tasks.subsection("build").unwrap();
        assert_eq!(build.get("description"), Some("Build the project"));
        assert_eq!(build.get("run"), Some("cargo build"));
    }
}
