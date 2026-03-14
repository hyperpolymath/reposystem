// SPDX-License-Identifier: PMPL-1.0-or-later
// k9.rs — Bridge to K9 Nickel components.
//
// K9 contractiles are `.k9.ncl` files evaluated by the Nickel configuration
// language. This module shells out to `nickel export` to get a JSON
// representation, then extracts the structured data (pedigree, config,
// recipes, validation) for use by the contractile CLI.
//
// The three K9 security levels ("The Leash"):
//   Kennel — pure data, no execution, no signature required
//   Yard   — Nickel evaluation with type contracts, signature recommended
//   Hunt   — full execution with Just recipes, signature REQUIRED
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

use anyhow::{bail, Context, Result};
use serde::Deserialize;
use std::path::Path;
use std::process::Command;

/// Security level for a K9 component, determining what operations are allowed.
#[derive(Debug, Clone, PartialEq, Eq, Deserialize)]
pub enum LeashLevel {
    Kennel,
    Yard,
    Hunt,
}

impl std::fmt::Display for LeashLevel {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            Self::Kennel => write!(f, "Kennel (pure data)"),
            Self::Yard => write!(f, "Yard (validated config)"),
            Self::Hunt => write!(f, "Hunt (full execution)"),
        }
    }
}

/// Parsed representation of a K9 component's pedigree metadata.
#[derive(Debug, Clone, Deserialize)]
pub struct K9Pedigree {
    pub schema_version: Option<String>,
    pub component_type: Option<String>,
    pub security: Option<K9Security>,
    pub metadata: Option<K9Metadata>,
}

/// Security configuration from a K9 component's pedigree.
#[derive(Debug, Clone, Deserialize)]
pub struct K9Security {
    /// The leash level is serialised as a Nickel enum tag string.
    /// Nickel exports enum tags like `"Kennel"`, `"Yard"`, `"Hunt"`.
    pub leash: Option<String>,
    pub trust_level: Option<String>,
    pub allow_network: Option<bool>,
    pub allow_filesystem_write: Option<bool>,
    pub allow_subprocess: Option<bool>,
    pub signature_required: Option<bool>,
}

/// Descriptive metadata from a K9 component.
#[derive(Debug, Clone, Deserialize)]
pub struct K9Metadata {
    pub name: Option<String>,
    pub version: Option<String>,
    pub description: Option<String>,
    pub author: Option<String>,
}

/// A recipe extracted from a K9 Hunt-level component.
/// These correspond to the `recipes` field in the K9 Nickel structure.
#[derive(Debug, Clone, Deserialize)]
pub struct K9Recipe {
    pub name: String,
    pub description: Option<String>,
    pub dependencies: Vec<String>,
    pub commands: Vec<String>,
}

/// The full parsed result of evaluating a K9 component via Nickel.
#[derive(Debug, Clone)]
pub struct K9Component {
    /// File path this component was loaded from.
    pub source_path: String,

    /// Pedigree metadata (schema version, security level, etc.).
    pub pedigree: Option<K9Pedigree>,

    /// The raw JSON value for the entire component, so callers can
    /// inspect arbitrary fields beyond what we extract.
    pub raw_json: serde_json::Value,

    /// Extracted recipes (only present in Hunt-level components).
    pub recipes: Vec<K9Recipe>,
}

impl K9Component {
    /// Determine the declared leash level from the pedigree security block.
    pub fn leash_level(&self) -> LeashLevel {
        self.pedigree
            .as_ref()
            .and_then(|p| p.security.as_ref())
            .and_then(|s| s.leash.as_deref())
            .map(|l| match l {
                "Hunt" => LeashLevel::Hunt,
                "Yard" => LeashLevel::Yard,
                _ => LeashLevel::Kennel,
            })
            .unwrap_or(LeashLevel::Kennel)
    }

    /// Returns true if this component requires a signature before execution.
    pub fn requires_signature(&self) -> bool {
        self.pedigree
            .as_ref()
            .and_then(|p| p.security.as_ref())
            .and_then(|s| s.signature_required)
            .unwrap_or(self.leash_level() == LeashLevel::Hunt)
    }
}

/// Evaluate a K9 `.k9.ncl` file by shelling out to `nickel export`.
/// Returns the parsed component with extracted pedigree and recipes.
///
/// Requires the `nickel` binary to be available on PATH.
pub fn evaluate(path: &Path) -> Result<K9Component> {
    let path_str = path
        .to_str()
        .context("K9 component path is not valid UTF-8")?;

    // Shell out to nickel to export the file as JSON.
    let output = Command::new("nickel")
        .args(["export", path_str])
        .output()
        .context("failed to run `nickel export` — is nickel installed?")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!(
            "nickel export failed for '{}': {}",
            path_str,
            stderr.trim()
        );
    }

    let json_str = String::from_utf8(output.stdout)
        .context("nickel export produced non-UTF-8 output")?;

    let raw_json: serde_json::Value =
        serde_json::from_str(&json_str).context("nickel export produced invalid JSON")?;

    // Extract pedigree from the JSON structure.
    let pedigree: Option<K9Pedigree> = raw_json
        .get("pedigree")
        .and_then(|v| serde_json::from_value(v.clone()).ok());

    // Extract recipes from Hunt-level components.
    let recipes = extract_recipes(&raw_json);

    Ok(K9Component {
        source_path: path_str.to_string(),
        pedigree,
        raw_json,
        recipes,
    })
}

/// Typecheck a K9 component without evaluating it.
/// Returns Ok(()) if the Nickel contracts are satisfied.
pub fn typecheck(path: &Path) -> Result<()> {
    let path_str = path
        .to_str()
        .context("K9 component path is not valid UTF-8")?;

    let output = Command::new("nickel")
        .args(["typecheck", path_str])
        .output()
        .context("failed to run `nickel typecheck` — is nickel installed?")?;

    if !output.status.success() {
        let stderr = String::from_utf8_lossy(&output.stderr);
        bail!(
            "nickel typecheck failed for '{}': {}",
            path_str,
            stderr.trim()
        );
    }

    Ok(())
}

/// Extract recipe definitions from the `recipes` field of a K9 JSON export.
/// Handles the structure: `{ recipes: { "name": { commands: [...], ... } } }`.
fn extract_recipes(json: &serde_json::Value) -> Vec<K9Recipe> {
    let mut recipes = Vec::new();

    let recipes_obj = match json.get("recipes").and_then(|v| v.as_object()) {
        Some(obj) => obj,
        None => return recipes,
    };

    for (name, value) in recipes_obj {
        // Skip the "default" entry — it just names the entry-point recipe,
        // it doesn't contain commands itself.
        if name == "default" {
            continue;
        }

        let obj = match value.as_object() {
            Some(o) => o,
            None => continue,
        };

        let description = obj
            .get("description")
            .and_then(|v| v.as_str())
            .map(String::from);

        let dependencies = obj
            .get("dependencies")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str().map(String::from))
                    .collect()
            })
            .unwrap_or_default();

        let commands = obj
            .get("commands")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str().map(String::from))
                    .collect()
            })
            .unwrap_or_default();

        recipes.push(K9Recipe {
            name: name.clone(),
            description,
            dependencies,
            commands,
        });
    }

    recipes
}
