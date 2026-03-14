// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Auto-detection heuristics for file classification.
//!
//! When deflating a repo that lacks a `.morph.a2ml` manifest, these heuristics
//! classify files as owned (component-specific) or inherited (monorepo root).

use std::path::Path;

/// Classification result for a single file.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum FileClass {
    /// File is unique to this component — always copied.
    Owned,
    /// File is provided by the monorepo root — stripped on deflate.
    Inherited,
    /// File should be skipped entirely (build artefacts, VCS dirs).
    Ignored,
}

/// Classify a file path using convention-based heuristics.
///
/// This is the fallback when no manifest is available. The classification
/// follows RSR (Rhodium Standard Repository) conventions.
pub fn classify(path: &Path) -> FileClass {
    let name = path
        .file_name()
        .map(|n| n.to_string_lossy().to_string())
        .unwrap_or_default();
    let name_lower = name.to_lowercase();

    // Check directory components for ignored patterns
    for component in path.components() {
        let c = component.as_os_str().to_string_lossy();
        if matches!(
            c.as_ref(),
            ".git"
                | "target"
                | "node_modules"
                | "_build"
                | ".lake"
                | "__pycache__"
                | ".mypy_cache"
                | ".pytest_cache"
                | "dist"
                | ".next"
        ) {
            return FileClass::Ignored;
        }
    }

    // Ignored by extension
    if let Some(ext) = path.extension().and_then(|e| e.to_str()) {
        if matches!(ext, "o" | "so" | "dylib" | "exe" | "dll" | "a" | "lib") {
            return FileClass::Ignored;
        }
    }

    // Inherited files — monorepo root provides these
    if matches!(
        name_lower.as_str(),
        "license"
            | "license.txt"
            | "license.md"
            | "license-mpl-2.0"
            | "license-mpl-2.0.txt"
            | "security.md"
            | "code_of_conduct.md"
            | "contributing.md"
            | "contributing.adoc"
            | ".editorconfig"
    ) {
        return FileClass::Inherited;
    }

    // Standard RSR workflows are inherited
    if path.starts_with(".github/workflows/") {
        let workflow = name_lower.as_str();
        if matches!(
            workflow,
            "hypatia-scan.yml"
                | "codeql.yml"
                | "scorecard.yml"
                | "quality.yml"
                | "mirror.yml"
                | "instant-sync.yml"
                | "guix-nix-policy.yml"
                | "rsr-antipattern.yml"
                | "security-policy.yml"
                | "wellknown-enforcement.yml"
                | "workflow-linter.yml"
                | "npm-bun-blocker.yml"
                | "ts-blocker.yml"
                | "scorecard-enforcer.yml"
                | "secret-scanner.yml"
        ) {
            return FileClass::Inherited;
        }
    }

    // AI manifest is regenerated per component
    if name == "0-AI-MANIFEST.a2ml" || name == "AI.a2ml" {
        return FileClass::Inherited;
    }

    // Everything else is owned
    FileClass::Owned
}

/// Classify all files in a directory, returning (path, classification) pairs.
pub fn classify_directory(dir: &Path) -> Vec<(std::path::PathBuf, FileClass)> {
    let mut results = Vec::new();

    let walker = walkdir::WalkDir::new(dir)
        .follow_links(false)
        .into_iter()
        .filter_entry(|e| {
            let name = e.file_name().to_string_lossy();
            // Skip .git at walk level for efficiency
            name != ".git"
        });

    for entry in walker.flatten() {
        if !entry.file_type().is_file() {
            continue;
        }
        if let Ok(relative) = entry.path().strip_prefix(dir) {
            let class = classify(relative);
            results.push((relative.to_path_buf(), class));
        }
    }

    results
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::path::PathBuf;

    #[test]
    fn source_files_are_owned() {
        assert_eq!(classify(Path::new("src/main.rs")), FileClass::Owned);
        assert_eq!(classify(Path::new("lib/core.zig")), FileClass::Owned);
        assert_eq!(classify(Path::new("build.zig")), FileClass::Owned);
    }

    #[test]
    fn license_is_inherited() {
        assert_eq!(classify(Path::new("LICENSE")), FileClass::Inherited);
        assert_eq!(classify(Path::new("LICENSE.txt")), FileClass::Inherited);
        assert_eq!(classify(Path::new("SECURITY.md")), FileClass::Inherited);
    }

    #[test]
    fn build_artefacts_are_ignored() {
        assert_eq!(classify(Path::new("target/debug/bin")), FileClass::Ignored);
        assert_eq!(
            classify(Path::new("node_modules/foo/index.js")),
            FileClass::Ignored
        );
        assert_eq!(classify(Path::new("lib.so")), FileClass::Ignored);
    }

    #[test]
    fn rsr_workflows_are_inherited() {
        assert_eq!(
            classify(Path::new(".github/workflows/hypatia-scan.yml")),
            FileClass::Inherited
        );
        assert_eq!(
            classify(Path::new(".github/workflows/mirror.yml")),
            FileClass::Inherited
        );
    }

    #[test]
    fn custom_workflows_are_owned() {
        assert_eq!(
            classify(Path::new(".github/workflows/ci.yml")),
            FileClass::Owned
        );
        assert_eq!(
            classify(Path::new(".github/workflows/release.yml")),
            FileClass::Owned
        );
    }

    #[test]
    fn readme_is_owned() {
        assert_eq!(classify(Path::new("README.adoc")), FileClass::Owned);
        assert_eq!(classify(Path::new("README.md")), FileClass::Owned);
    }

    #[test]
    fn manifest_files_are_owned() {
        assert_eq!(classify(Path::new("Cargo.toml")), FileClass::Owned);
        assert_eq!(classify(Path::new("deno.json")), FileClass::Owned);
        assert_eq!(
            classify(&PathBuf::from("rescript.json")),
            FileClass::Owned
        );
    }
}
