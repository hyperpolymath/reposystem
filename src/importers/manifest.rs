// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
//
//! Manifest importer — turns the generated `repos.toml` estate inventory (and
//! the hand-maintained `repos.groups.toml`) into a populated ecosystem graph.
//!
//! This is the bridge that connects the real ~297-repo estate to the graph and
//! visualisation engine. `repos.toml` is the *inventory*; the Rust `types`
//! module is the *schema of record*. Sibling systems named in
//! [`DEFAULT_SEAM_SYSTEMS`] (e.g. `aerie`, `ambientops`) are promoted to
//! external seams rather than repos — the strict repos-only boundary.

use crate::graph::EcosystemGraph;
use crate::scanner::parse_owner_name;
use crate::types::{
    default_estate, Estate, ExternalSeam, Forge, Group, ImportMeta, Repo, SeamDomain, Visibility,
};
use anyhow::{Context, Result};
use chrono::Utc;
use serde::Deserialize;
use std::collections::HashMap;
use std::path::PathBuf;

/// Sibling systems represented as external seams, not repos.
///
/// Reposystem points at these but models none of their internals: `aerie` is
/// networks / the wider world, `ambientops` is machines.
pub const DEFAULT_SEAM_SYSTEMS: &[(&str, SeamDomain)] = &[
    ("aerie", SeamDomain::Network),
    ("ambientops", SeamDomain::Machine),
];

#[derive(Debug, Deserialize)]
struct Manifest {
    #[serde(default)]
    repo: Vec<RepoEntry>,
}

#[derive(Debug, Deserialize)]
struct RepoEntry {
    name: String,
    #[serde(default)]
    path: Option<String>,
    #[serde(default)]
    url: Option<String>,
    #[serde(default)]
    kind: Option<String>,
}

#[derive(Debug, Default, Deserialize)]
struct GroupsFile {
    #[serde(default)]
    groups: HashMap<String, Vec<String>>,
}

/// Options for a manifest import.
pub struct ManifestImport {
    /// Path to `repos.toml`.
    pub manifest: PathBuf,
    /// Path to `repos.groups.toml` (skipped if absent).
    pub groups: Option<PathBuf>,
    /// Estate id to stamp on every imported node.
    pub estate_id: String,
    /// Estate display name.
    pub estate_name: String,
}

impl Default for ManifestImport {
    fn default() -> Self {
        Self {
            manifest: PathBuf::from("repos.toml"),
            groups: Some(PathBuf::from("repos.groups.toml")),
            estate_id: default_estate(),
            estate_name: "Hyperpolymath".to_string(),
        }
    }
}

/// Summary of an import run.
#[derive(Debug, Default, Clone, Copy)]
pub struct ImportSummary {
    /// Repositories imported.
    pub repos: usize,
    /// External seams imported.
    pub seams: usize,
    /// Groups imported.
    pub groups: usize,
}

/// Import a manifest into a fresh ecosystem graph.
///
/// # Errors
/// Returns an error if the manifest cannot be read or parsed.
pub fn import(opts: &ManifestImport) -> Result<(EcosystemGraph, ImportSummary)> {
    let text = std::fs::read_to_string(&opts.manifest)
        .with_context(|| format!("Failed to read manifest {}", opts.manifest.display()))?;
    let manifest: Manifest = toml::from_str(&text)
        .with_context(|| format!("Failed to parse manifest {}", opts.manifest.display()))?;

    let mut graph = EcosystemGraph::new();
    let now = Utc::now();
    let mut name_to_id: HashMap<String, String> = HashMap::new();
    let mut seen_forges: Vec<Forge> = Vec::new();
    let mut summary = ImportSummary::default();

    for entry in &manifest.repo {
        // Seam systems become external seams (sinks), not repos.
        if let Some((system, domain)) = seam_match(&entry.name) {
            graph.add_seam(ExternalSeam {
                kind: "ExternalSeam".into(),
                id: ExternalSeam::seam_id(system, system),
                domain,
                system: system.to_string(),
                name: system.to_string(),
                uri: entry.url.clone(),
                description: None,
                estate: opts.estate_id.clone(),
            });
            summary.seams += 1;
            continue;
        }

        let url = entry.url.clone().unwrap_or_default();
        let forge = Forge::from_url(&url).unwrap_or(Forge::Local);
        if forge != Forge::Local && !seen_forges.contains(&forge) {
            seen_forges.push(forge);
        }
        let (owner, name) = parse_owner_name(&url)
            .unwrap_or_else(|| ("hyperpolymath".to_string(), entry.name.clone()));

        let id = if forge == Forge::Local {
            format!("repo:local:{}", entry.name)
        } else {
            Repo::forge_id(forge, &owner, &name)
        };

        let mut metadata = HashMap::new();
        if let Some(k) = &entry.kind {
            metadata.insert("manifest_kind".to_string(), k.clone());
        }
        if let Some(p) = &entry.path {
            metadata.insert("manifest_path".to_string(), p.clone());
        }

        let tags = entry.kind.clone().map(|k| vec![k]).unwrap_or_default();

        graph.add_repo(Repo {
            kind: "Repo".into(),
            id: id.clone(),
            forge,
            owner,
            name: entry.name.clone(),
            default_branch: "main".into(),
            visibility: Visibility::Public,
            tags,
            estate: opts.estate_id.clone(),
            metadata,
            imports: ImportMeta {
                source: "manifest:repos.toml".into(),
                path_hint: entry.path.as_ref().map(PathBuf::from),
                imported_at: now,
            },
            local_path: None,
        });
        name_to_id.insert(entry.name.clone(), id);
        summary.repos += 1;
    }

    // Groups (optional, hand-maintained). Members are repo *names*; resolve to ids.
    if let Some(groups_path) = &opts.groups {
        if groups_path.exists() {
            let gtext = std::fs::read_to_string(groups_path)
                .with_context(|| format!("Failed to read {}", groups_path.display()))?;
            let gfile: GroupsFile = toml::from_str(&gtext)
                .with_context(|| format!("Failed to parse {}", groups_path.display()))?;
            for (gname, members) in gfile.groups {
                let member_ids: Vec<String> = members
                    .iter()
                    .filter_map(|m| name_to_id.get(m).cloned())
                    .collect();
                graph.add_group(Group {
                    kind: "Group".into(),
                    id: format!("group:{gname}"),
                    name: gname,
                    description: None,
                    members: member_ids,
                });
                summary.groups += 1;
            }
        }
    }

    // Estate identity, stamped with the forges actually observed.
    graph.store.estates = vec![Estate {
        kind: "Estate".into(),
        id: opts.estate_id.clone(),
        name: opts.estate_name.clone(),
        description: None,
        forges: seen_forges,
        root_owner: Some("hyperpolymath".into()),
    }];
    graph.store.estate = Some(opts.estate_id.clone());

    Ok((graph, summary))
}

/// Match on the basename of the manifest entry, since the manifest prefixes
/// some names with their group (e.g. `systems-ecosystem/ambientops`).
fn seam_match(name: &str) -> Option<(&'static str, SeamDomain)> {
    let base = name.rsplit('/').next().unwrap_or(name).to_lowercase();
    DEFAULT_SEAM_SYSTEMS
        .iter()
        .find(|(sys, _)| *sys == base)
        .map(|(sys, dom)| (*sys, *dom))
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Write;

    fn write_temp(name: &str, content: &str) -> PathBuf {
        let dir = std::env::temp_dir().join("reposystem-manifest-test");
        std::fs::create_dir_all(&dir).unwrap();
        let path = dir.join(name);
        let mut f = std::fs::File::create(&path).unwrap();
        f.write_all(content.as_bytes()).unwrap();
        path
    }

    #[test]
    fn imports_repos_and_promotes_seams() {
        let manifest = write_temp(
            "repos.toml",
            r#"
[meta]
count = 3

[[repo]]
name = "boj-server"
path = "boj-server"
url  = "git@github.com:hyperpolymath/boj-server.git"
kind = "repo"

[[repo]]
name = "aerie"
path = "aerie"
url  = "git@github.com:hyperpolymath/aerie.git"
kind = "repo"

[[repo]]
name = "systems-ecosystem/ambientops"
path = "systems-ecosystem/ambientops"
url  = "git@github.com:hyperpolymath/ambientops.git"
kind = "repo"
"#,
        );

        let opts = ManifestImport {
            manifest,
            groups: None,
            estate_id: default_estate(),
            estate_name: "Hyperpolymath".into(),
        };
        let (graph, summary) = import(&opts).unwrap();

        assert_eq!(summary.repos, 1, "only boj-server is a repo");
        assert_eq!(summary.seams, 2, "aerie + ambientops are seams");
        assert_eq!(graph.seams().len(), 2);
        assert_eq!(graph.repos().len(), 1);
        assert_eq!(graph.store.estate.as_deref(), Some("estate:hyperpolymath"));
        assert!(graph.store.repos.iter().all(|r| r.estate == "estate:hyperpolymath"));

        // The boj-server repo id is derived from the forge URL.
        assert!(graph.get_repo("repo:gh:hyperpolymath/boj-server").is_some());
    }
}
