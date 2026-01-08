// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Repository scanning - discovers git repositories in a directory tree

use crate::types::{Forge, ImportMeta, Repo, Visibility};
use anyhow::{Context, Result};
use chrono::Utc;
use std::path::{Path, PathBuf};
use tracing::{debug, info, warn};
use walkdir::WalkDir;

/// Configuration for scanning
#[derive(Debug, Clone)]
pub struct ScanConfig {
    /// Maximum depth to traverse (0 = unlimited)
    pub max_depth: usize,
    /// Whether to follow symlinks
    pub follow_symlinks: bool,
    /// Whether to extract full metadata
    pub deep: bool,
    /// Directories to skip
    pub skip_dirs: Vec<String>,
}

impl Default for ScanConfig {
    fn default() -> Self {
        Self {
            max_depth: 0,
            follow_symlinks: false,
            deep: false,
            skip_dirs: vec![
                "node_modules".into(),
                ".git".into(),
                "target".into(),
                "vendor".into(),
                "__pycache__".into(),
                ".cache".into(),
                "dist".into(),
                "build".into(),
            ],
        }
    }
}

/// Result of scanning a single repository
#[derive(Debug)]
pub struct ScanResult {
    /// The discovered repository
    pub repo: Repo,
    /// Warnings encountered during scan
    pub warnings: Vec<String>,
}

/// Scan a path for git repositories
pub fn scan_path(path: &Path, config: &ScanConfig) -> Result<Vec<ScanResult>> {
    let path = path
        .canonicalize()
        .with_context(|| format!("Failed to canonicalize path: {}", path.display()))?;

    info!("Scanning {} for git repositories", path.display());

    let mut results = Vec::new();
    let mut walker = WalkDir::new(&path).follow_links(config.follow_symlinks);

    if config.max_depth > 0 {
        walker = walker.max_depth(config.max_depth);
    }

    for entry in walker
        .into_iter()
        .filter_entry(|e| !should_skip(e, &config.skip_dirs))
    {
        let entry = match entry {
            Ok(e) => e,
            Err(err) => {
                warn!("Error walking directory: {}", err);
                continue;
            }
        };

        // Check if this is a git repository
        let git_dir = entry.path().join(".git");
        if git_dir.exists() && git_dir.is_dir() {
            debug!("Found git repository: {}", entry.path().display());

            match scan_repo(entry.path(), config) {
                Ok(result) => results.push(result),
                Err(err) => {
                    warn!(
                        "Failed to scan repository {}: {}",
                        entry.path().display(),
                        err
                    );
                }
            }
        }
    }

    info!("Found {} repositories", results.len());
    Ok(results)
}

/// Check if a directory entry should be skipped
fn should_skip(entry: &walkdir::DirEntry, skip_dirs: &[String]) -> bool {
    if !entry.file_type().is_dir() {
        return false;
    }

    let name = entry.file_name().to_string_lossy();

    // Skip hidden directories (except .git which we handle separately)
    if name.starts_with('.') && name != ".git" {
        return true;
    }

    skip_dirs.iter().any(|s| s == &*name)
}

/// Scan a single git repository
fn scan_repo(path: &Path, config: &ScanConfig) -> Result<ScanResult> {
    let mut warnings = Vec::new();

    // Try to open the repository with gix
    let repo = gix::open(path).with_context(|| format!("Failed to open git repo: {}", path.display()))?;

    // Extract remote origin URL
    let (forge, owner, name, visibility) = extract_remote_info(&repo, path, &mut warnings);

    // Get default branch
    let default_branch = get_default_branch(&repo).unwrap_or_else(|| "main".into());

    // Extract tags if doing deep scan
    let tags = if config.deep {
        extract_tags(path, &mut warnings)
    } else {
        vec![]
    };

    // Generate ID
    let id = if forge == Forge::Local {
        Repo::local_id(path)
    } else {
        Repo::forge_id(forge, &owner, &name)
    };

    let repo_data = Repo {
        kind: "Repo".into(),
        id,
        forge,
        owner,
        name,
        default_branch,
        visibility,
        tags,
        imports: ImportMeta {
            source: "local-scan".into(),
            path_hint: Some(path.to_path_buf()),
            imported_at: Utc::now(),
        },
        local_path: Some(path.to_path_buf()),
    };

    Ok(ScanResult {
        repo: repo_data,
        warnings,
    })
}

/// Extract remote origin information
fn extract_remote_info(
    repo: &gix::Repository,
    path: &Path,
    warnings: &mut Vec<String>,
) -> (Forge, String, String, Visibility) {
    // Try to get the origin remote
    let remote_url = repo
        .find_remote("origin")
        .ok()
        .and_then(|remote| remote.url(gix::remote::Direction::Fetch).map(|u| u.to_bstring().to_string()));

    match remote_url {
        Some(url) => parse_remote_url(&url, path, warnings),
        None => {
            warnings.push("No origin remote found".into());
            local_fallback(path)
        }
    }
}

/// Parse a remote URL to extract forge, owner, and name
fn parse_remote_url(
    url: &str,
    path: &Path,
    warnings: &mut Vec<String>,
) -> (Forge, String, String, Visibility) {
    // Try to detect the forge
    let forge = Forge::from_url(url);

    if let Some(forge) = forge {
        // Parse owner/name from URL
        if let Some((owner, name)) = parse_owner_name(url) {
            return (forge, owner, name, Visibility::Public);
        }
    }

    warnings.push(format!("Could not parse remote URL: {}", url));
    local_fallback(path)
}

/// Parse owner and name from a git URL
fn parse_owner_name(url: &str) -> Option<(String, String)> {
    // Handle SSH URLs: git@github.com:owner/name.git
    if url.starts_with("git@") {
        let parts: Vec<&str> = url.splitn(2, ':').collect();
        if parts.len() == 2 {
            return extract_from_path(parts[1]);
        }
    }

    // Handle HTTPS URLs: https://github.com/owner/name.git
    if url.starts_with("http://") || url.starts_with("https://") {
        // Find the path portion after the domain
        if let Some(path_start) = url.find("://").map(|i| i + 3) {
            let rest = &url[path_start..];
            if let Some(slash) = rest.find('/') {
                return extract_from_path(&rest[slash + 1..]);
            }
        }
    }

    None
}

/// Extract owner/name from a path like "owner/name.git" or "owner/name"
fn extract_from_path(path: &str) -> Option<(String, String)> {
    let path = path.trim_end_matches(".git").trim_matches('/');
    let parts: Vec<&str> = path.split('/').collect();

    if parts.len() >= 2 {
        Some((parts[0].to_string(), parts[1].to_string()))
    } else {
        None
    }
}

/// Create a local-only fallback identity
fn local_fallback(path: &Path) -> (Forge, String, String, Visibility) {
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_else(|| "unknown".into());

    (Forge::Local, "local".into(), name, Visibility::Private)
}

/// Get the default branch name
fn get_default_branch(repo: &gix::Repository) -> Option<String> {
    // Try to get HEAD reference
    repo.head_ref()
        .ok()
        .flatten()
        .map(|r| r.name().shorten().to_string())
}

/// Extract tags from repository (e.g., from topics, languages, etc.)
fn extract_tags(path: &Path, warnings: &mut Vec<String>) -> Vec<String> {
    let mut tags = Vec::new();

    // Detect language/framework from files
    if path.join("Cargo.toml").exists() {
        tags.push("rust".into());
    }
    if path.join("package.json").exists() {
        tags.push("javascript".into());
    }
    if path.join("deno.json").exists() || path.join("deno.jsonc").exists() {
        tags.push("deno".into());
    }
    if path.join("rescript.json").exists() || path.join("bsconfig.json").exists() {
        tags.push("rescript".into());
    }
    if path.join("go.mod").exists() {
        tags.push("go".into());
    }
    if path.join("pyproject.toml").exists() || path.join("setup.py").exists() {
        tags.push("python".into());
    }
    if path.join("Gemfile").exists() {
        tags.push("ruby".into());
    }
    if path.join("mix.exs").exists() {
        tags.push("elixir".into());
    }
    if path.join("gleam.toml").exists() {
        tags.push("gleam".into());
    }
    if path.join("dune-project").exists() {
        tags.push("ocaml".into());
    }

    // Detect project type from special files
    if path.join("Containerfile").exists() || path.join("Dockerfile").exists() {
        tags.push("container".into());
    }
    if path.join(".github").exists() {
        tags.push("github-actions".into());
    }
    if path.join(".gitlab-ci.yml").exists() {
        tags.push("gitlab-ci".into());
    }

    // Try to read topics from GitHub's .github/TOPICS file or similar
    let topics_path = path.join(".github/topics.txt");
    if topics_path.exists() {
        match std::fs::read_to_string(&topics_path) {
            Ok(content) => {
                for line in content.lines() {
                    let topic = line.trim();
                    if !topic.is_empty() && !tags.contains(&topic.to_string()) {
                        tags.push(topic.to_string());
                    }
                }
            }
            Err(err) => {
                warnings.push(format!("Failed to read topics file: {}", err));
            }
        }
    }

    tags
}

/// Simplified scan function for the command module
pub fn scan_path_simple(path: &Path) -> Result<Vec<Repo>> {
    let config = ScanConfig::default();
    let results = scan_path(path, &config)?;
    Ok(results.into_iter().map(|r| r.repo).collect())
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    #[test]
    fn test_parse_github_https_url() {
        let (owner, name) = parse_owner_name("https://github.com/hyperpolymath/reposystem.git").unwrap();
        assert_eq!(owner, "hyperpolymath");
        assert_eq!(name, "reposystem");
    }

    #[test]
    fn test_parse_github_ssh_url() {
        let (owner, name) = parse_owner_name("git@github.com:hyperpolymath/reposystem.git").unwrap();
        assert_eq!(owner, "hyperpolymath");
        assert_eq!(name, "reposystem");
    }

    #[test]
    fn test_forge_detection() {
        assert_eq!(Forge::from_url("https://github.com/foo/bar"), Some(Forge::GitHub));
        assert_eq!(Forge::from_url("git@gitlab.com:foo/bar.git"), Some(Forge::GitLab));
        assert_eq!(Forge::from_url("https://bitbucket.org/foo/bar"), Some(Forge::Bitbucket));
        assert_eq!(Forge::from_url("https://codeberg.org/foo/bar"), Some(Forge::Codeberg));
        assert_eq!(Forge::from_url("https://git.sr.ht/~foo/bar"), Some(Forge::Sourcehut));
        assert_eq!(Forge::from_url("https://example.com/foo/bar"), None);
    }

    #[test]
    fn test_local_id_determinism() {
        let temp = TempDir::new().unwrap();
        let path = temp.path();

        let id1 = Repo::local_id(path);
        let id2 = Repo::local_id(path);

        assert_eq!(id1, id2);
        assert!(id1.starts_with("repo:local:"));
    }

    #[test]
    fn test_scan_empty_dir() {
        let temp = TempDir::new().unwrap();
        let config = ScanConfig::default();

        let results = scan_path(temp.path(), &config).unwrap();
        assert!(results.is_empty());
    }
}
