// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Manifest parsing for `.morph.a2ml` files.
//!
//! The manifest declares which files are owned by a component (unique to it)
//! and which are inherited from the monorepo root (stripped on deflate,
//! generated on inflate).

use anyhow::{Context, Result};
use serde::Deserialize;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

/// The well-known manifest filename.
pub const MANIFEST_FILENAME: &str = ".morph.a2ml";

/// Top-level manifest structure.
#[derive(Debug, Clone, Deserialize)]
pub struct Manifest {
    pub component: ComponentSection,
    pub files: FilesSection,
    pub template: Option<TemplateSection>,
    pub dependencies: Option<DependenciesSection>,
    pub registry: Option<RegistrySection>,
}

/// Identifies the component.
#[derive(Debug, Clone, Deserialize)]
pub struct ComponentSection {
    pub name: String,
    pub path: PathBuf,
}

/// File classification patterns.
#[derive(Debug, Clone, Deserialize)]
pub struct FilesSection {
    /// Glob patterns for files unique to this component.
    pub owned: Vec<String>,
    /// Glob patterns for files inherited from the monorepo root.
    pub inherited: Vec<String>,
}

/// Template configuration for inflation.
#[derive(Debug, Clone, Deserialize)]
pub struct TemplateSection {
    pub name: String,
    #[serde(default)]
    pub vars: HashMap<String, String>,
}

/// Dependencies on other components (informational).
#[derive(Debug, Clone, Deserialize)]
pub struct DependenciesSection {
    #[serde(default)]
    pub components: Vec<String>,
}

/// Package registry information.
#[derive(Debug, Clone, Deserialize)]
pub struct RegistrySection {
    #[serde(rename = "type")]
    pub registry_type: String,
}

/// Parse a manifest from a file path.
pub fn parse(path: &Path) -> Result<Manifest> {
    let content = std::fs::read_to_string(path)
        .with_context(|| format!("Failed to read manifest: {}", path.display()))?;
    let manifest: Manifest = toml::from_str(&content)
        .with_context(|| format!("Failed to parse manifest: {}", path.display()))?;
    Ok(manifest)
}

/// Parse a manifest from the component directory (looks for `.morph.a2ml`).
pub fn parse_from_dir(dir: &Path) -> Result<Manifest> {
    let manifest_path = dir.join(MANIFEST_FILENAME);
    parse(&manifest_path)
}

/// Find all `.morph.a2ml` manifests under a directory.
pub fn find_manifests(dir: &Path, recursive: bool) -> Result<Vec<Manifest>> {
    let mut manifests = Vec::new();

    if recursive {
        for entry in WalkDir::new(dir)
            .follow_links(false)
            .into_iter()
            .filter_entry(|e| {
                // Skip hidden dirs, build dirs, .git
                let name = e.file_name().to_string_lossy();
                !name.starts_with('.')
                    && name != "target"
                    && name != "node_modules"
                    && name != "_build"
            })
        {
            let entry = entry?;
            if entry.file_name() == MANIFEST_FILENAME {
                match parse(entry.path()) {
                    Ok(m) => manifests.push(m),
                    Err(e) => {
                        tracing::warn!("Skipping {}: {e}", entry.path().display());
                    }
                }
            }
        }
    } else {
        // Non-recursive: only check immediate subdirectories
        let read_dir = std::fs::read_dir(dir)
            .with_context(|| format!("Failed to read directory: {}", dir.display()))?;

        for entry in read_dir {
            let entry = entry?;
            let candidate = entry.path().join(MANIFEST_FILENAME);
            if candidate.exists() {
                match parse(&candidate) {
                    Ok(m) => manifests.push(m),
                    Err(e) => {
                        tracing::warn!("Skipping {}: {e}", candidate.display());
                    }
                }
            }
        }
    }

    Ok(manifests)
}

/// Validate a manifest for completeness.
pub fn validate(manifest: &Manifest) -> Result<()> {
    if manifest.component.name.is_empty() {
        anyhow::bail!("Manifest component.name is empty");
    }
    if manifest.files.owned.is_empty() {
        anyhow::bail!(
            "Manifest for '{}' has no owned file patterns",
            manifest.component.name
        );
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn parse_minimal_manifest() {
        let toml = r#"
[component]
name = "test-component"
path = "src/test/"

[files]
owned = ["src/**"]
inherited = ["LICENSE"]
"#;
        let manifest: Manifest = toml::from_str(toml).unwrap();
        assert_eq!(manifest.component.name, "test-component");
        assert_eq!(manifest.files.owned, vec!["src/**"]);
        assert_eq!(manifest.files.inherited, vec!["LICENSE"]);
        assert!(manifest.template.is_none());
    }

    #[test]
    fn parse_full_manifest() {
        let toml = r#"
[component]
name = "libgit2-ffi"
path = "ffi/libgit2/"

[files]
owned = ["ffi/**", "build.zig"]
inherited = ["LICENSE", "SECURITY.md"]

[template]
name = "rsr-template-repo"
vars = { repo_name = "libgit2-ffi", description = "Zig FFI" }

[dependencies]
components = ["core"]

[registry]
type = "none"
"#;
        let manifest: Manifest = toml::from_str(toml).unwrap();
        assert_eq!(manifest.component.name, "libgit2-ffi");
        assert_eq!(manifest.files.owned.len(), 2);
        let tmpl = manifest.template.unwrap();
        assert_eq!(tmpl.name, "rsr-template-repo");
        assert_eq!(tmpl.vars.get("repo_name").unwrap(), "libgit2-ffi");
    }

    #[test]
    fn validate_empty_name_fails() {
        let manifest = Manifest {
            component: ComponentSection {
                name: String::new(),
                path: PathBuf::from("test/"),
            },
            files: FilesSection {
                owned: vec!["src/**".into()],
                inherited: vec![],
            },
            template: None,
            dependencies: None,
            registry: None,
        };
        assert!(validate(&manifest).is_err());
    }
}
