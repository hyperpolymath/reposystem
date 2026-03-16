// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Template expansion engine for inflate operations.
//!
//! During inflation, inherited files are generated from a template (default:
//! rsr-template-repo). This module resolves templates and substitutes variables.

use anyhow::{Context, Result};
use std::collections::HashMap;
use std::path::{Path, PathBuf};

/// Default template repository name.
pub const DEFAULT_TEMPLATE: &str = "rsr-template-repo";

/// Well-known template search paths (in priority order).
const TEMPLATE_SEARCH_PATHS: &[&str] = &[
    // Relative to the hyperpolymath repos directory
    "../rsr-template-repo",
    // Standard canonical location
    "~/Documents/hyperpolymath-repos/rsr-template-repo",
];

/// Placeholder delimiters used in template files.
const PLACEHOLDER_OPEN: &str = "{{";
const PLACEHOLDER_CLOSE: &str = "}}";

/// A resolved template ready for expansion.
#[derive(Debug)]
pub struct Template {
    /// Name of the template.
    pub name: String,
    /// Root directory of the template.
    pub root: PathBuf,
}

/// Resolve a template by name, searching known paths.
pub fn resolve(name: &str, search_from: &Path) -> Result<Template> {
    // First, try relative to the search_from directory
    for pattern in TEMPLATE_SEARCH_PATHS {
        let candidate = if pattern.starts_with("~/") {
            if let Some(home) = dirs_home() {
                home.join(&pattern[2..])
            } else {
                continue;
            }
        } else {
            search_from.join(pattern)
        };

        if candidate.is_dir() {
            return Ok(Template {
                name: name.to_string(),
                root: candidate,
            });
        }
    }

    // Try the name as an absolute or relative path
    let direct = PathBuf::from(name);
    if direct.is_dir() {
        return Ok(Template {
            name: name.to_string(),
            root: direct,
        });
    }

    anyhow::bail!(
        "Template '{}' not found. Searched from {} and standard paths.",
        name,
        search_from.display()
    )
}

/// Expand a template file's content by substituting `{{VAR}}` placeholders.
pub fn expand(content: &str, vars: &HashMap<String, String>) -> String {
    let mut result = content.to_string();
    for (key, value) in vars {
        let placeholder = format!("{}{}{}", PLACEHOLDER_OPEN, key, PLACEHOLDER_CLOSE);
        result = result.replace(&placeholder, value);
    }
    result
}

/// Build a default variable map from component metadata.
pub fn default_vars(
    component_name: &str,
    description: Option<&str>,
) -> HashMap<String, String> {
    let mut vars = HashMap::new();
    vars.insert("REPO".to_string(), component_name.to_string());
    vars.insert("repo_name".to_string(), component_name.to_string());
    vars.insert("OWNER".to_string(), "hyperpolymath".to_string());
    vars.insert("FORGE".to_string(), "github.com".to_string());
    vars.insert(
        "AUTHOR".to_string(),
        "Jonathan D.A. Jewell".to_string(),
    );
    vars.insert(
        "EMAIL".to_string(),
        "j.d.a.jewell@open.ac.uk".to_string(),
    );
    vars.insert(
        "LICENSE".to_string(),
        "PMPL-1.0-or-later".to_string(),
    );
    if let Some(desc) = description {
        vars.insert("description".to_string(), desc.to_string());
    }
    vars
}

/// Copy inherited files from a template directory, expanding placeholders.
pub fn apply_inherited(
    template: &Template,
    inherited_patterns: &[String],
    output_dir: &Path,
    vars: &HashMap<String, String>,
    dry_run: bool,
) -> Result<Vec<PathBuf>> {
    let mut copied = Vec::new();
    let glob_set = build_glob_set(inherited_patterns)?;

    for entry in walkdir::WalkDir::new(&template.root)
        .follow_links(false)
        .into_iter()
        .flatten()
    {
        if !entry.file_type().is_file() {
            continue;
        }
        let relative = entry
            .path()
            .strip_prefix(&template.root)
            .unwrap_or(entry.path());

        // Skip .git and template-internal files
        if relative
            .components()
            .any(|c| c.as_os_str() == ".git")
        {
            continue;
        }

        let relative_str = relative.to_string_lossy();
        if !glob_set.is_match(relative_str.as_ref()) {
            continue;
        }

        let dest = output_dir.join(relative);

        if dry_run {
            println!("  [template] {}", relative.display());
            copied.push(relative.to_path_buf());
            continue;
        }

        if let Some(parent) = dest.parent() {
            std::fs::create_dir_all(parent)
                .with_context(|| format!("Failed to create {}", parent.display()))?;
        }

        // Read, expand placeholders, write
        let content = std::fs::read_to_string(entry.path())
            .with_context(|| format!("Failed to read template file: {}", entry.path().display()))?;
        let expanded = expand(&content, vars);
        std::fs::write(&dest, expanded)
            .with_context(|| format!("Failed to write: {}", dest.display()))?;

        copied.push(relative.to_path_buf());
    }

    Ok(copied)
}

/// Build a glob set from pattern strings.
fn build_glob_set(patterns: &[String]) -> Result<globset::GlobSet> {
    let mut builder = globset::GlobSetBuilder::new();
    for pattern in patterns {
        builder.add(
            globset::Glob::new(pattern)
                .with_context(|| format!("Invalid glob: {pattern}"))?,
        );
    }
    builder
        .build()
        .context("Failed to build glob set")
}

/// Get the user's home directory.
fn dirs_home() -> Option<PathBuf> {
    std::env::var_os("HOME").map(PathBuf::from)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn expand_replaces_placeholders() {
        let mut vars = HashMap::new();
        vars.insert("REPO".to_string(), "my-tool".to_string());
        vars.insert("OWNER".to_string(), "hyperpolymath".to_string());

        let input = "name = \"reposystem\"\nowner = \"hyperpolymath\"";
        let result = expand(input, &vars);
        assert_eq!(result, "name = \"my-tool\"\nowner = \"hyperpolymath\"");
    }

    #[test]
    fn expand_leaves_unknown_placeholders() {
        let vars = HashMap::new();
        let input = "{{UNKNOWN}} stays as-is";
        let result = expand(input, &vars);
        assert_eq!(result, "{{UNKNOWN}} stays as-is");
    }

    #[test]
    fn default_vars_includes_essentials() {
        let vars = default_vars("my-tool", Some("A cool tool"));
        assert_eq!(vars.get("REPO").unwrap(), "my-tool");
        assert_eq!(vars.get("OWNER").unwrap(), "hyperpolymath");
        assert_eq!(vars.get("description").unwrap(), "A cool tool");
    }
}
