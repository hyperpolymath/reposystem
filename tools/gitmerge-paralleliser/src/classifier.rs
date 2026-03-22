// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//! File classification engine for gitmerge-paralleliser.
//!
//! Classifies changed files into semantic categories so they can be committed
//! and pushed independently. This enables granular review on GitHub — docs can
//! be approved without waiting for large data files, CI config can merge without
//! blocking on code review, etc.

#![forbid(unsafe_code)]

use std::collections::BTreeMap;
use std::path::Path;

/// Semantic file classification.
///
/// Ordered by typical review priority (CI/config first since they unblock
/// everything else, then docs, then code, then data/assets last since they
/// are large and slow to push).
#[derive(Debug, Clone, Copy, PartialEq, Eq, PartialOrd, Ord, Hash)]
pub enum FileClass {
    /// CI/CD workflows, GitHub Actions, hooks, linters
    Ci,
    /// Configuration files (Cargo.toml, deno.json, flake.nix, .editorconfig, etc.)
    Config,
    /// Documentation (README, CHANGELOG, LICENSE, .md, .adoc, .djot, .tex)
    Docs,
    /// Source code (.rs, .res, .ex, .idr, .zig, .gleam, .ml, .hs, .jl, etc.)
    Code,
    /// Test files (test/, tests/, *_test.*, *_spec.*, etc.)
    Tests,
    /// Machine-readable metadata (.a2ml, .scm, STATE, META, ECOSYSTEM)
    Meta,
    /// Data files (.json, .jsonl, .csv, .toml data, .yaml data)
    Data,
    /// Binary assets, images, fonts, archives
    Assets,
}

impl FileClass {
    /// Human-readable label for display
    pub fn label(&self) -> &'static str {
        match self {
            Self::Ci => "CI/CD & Workflows",
            Self::Config => "Configuration",
            Self::Docs => "Documentation",
            Self::Code => "Source Code",
            Self::Tests => "Tests",
            Self::Meta => "Machine-Readable Metadata",
            Self::Data => "Data Files",
            Self::Assets => "Assets & Binaries",
        }
    }

    /// Short label for compact display
    pub fn short(&self) -> &'static str {
        match self {
            Self::Ci => "ci",
            Self::Config => "config",
            Self::Docs => "docs",
            Self::Code => "code",
            Self::Tests => "tests",
            Self::Meta => "meta",
            Self::Data => "data",
            Self::Assets => "assets",
        }
    }

    /// Branch suffix (used with prefix to create branch names)
    pub fn branch_suffix(&self) -> &'static str {
        self.short()
    }

    /// Suggested commit message component
    pub fn commit_verb(&self) -> &'static str {
        match self {
            Self::Ci => "ci",
            Self::Config => "build",
            Self::Docs => "docs",
            Self::Code => "feat",
            Self::Tests => "test",
            Self::Meta => "chore",
            Self::Data => "chore",
            Self::Assets => "chore",
        }
    }
}

/// Classify a list of file paths into categories.
///
/// Returns a BTreeMap so categories are always in a stable, priority-based order.
pub fn classify_files(files: &[String]) -> BTreeMap<FileClass, Vec<String>> {
    let mut result: BTreeMap<FileClass, Vec<String>> = BTreeMap::new();

    for file in files {
        let class = classify_single(file);
        result.entry(class).or_default().push(file.clone());
    }

    result
}

/// Classify a single file path.
fn classify_single(path: &str) -> FileClass {
    let p = Path::new(path);
    let filename = p
        .file_name()
        .map(|f| f.to_string_lossy().to_string())
        .unwrap_or_default();
    let filename_lower = filename.to_lowercase();
    let ext = p
        .extension()
        .map(|e| e.to_string_lossy().to_lowercase())
        .unwrap_or_default();
    let path_lower = path.to_lowercase();

    // CI/CD — workflows, hooks, GitHub/GitLab config
    if path_lower.contains(".github/workflows/")
        || path_lower.contains(".gitlab-ci")
        || path_lower.contains("hooks/")
        || path_lower.contains(".circleci/")
        || path_lower.contains("Jenkinsfile")
        || filename_lower == ".pre-commit-config.yaml"
    {
        return FileClass::Ci;
    }

    // Machine-readable metadata (.a2ml, .scm in .machine_readable/)
    if path_lower.contains(".machine_readable/")
        || path_lower.contains("machine_read/")
        || ext == "a2ml"
        || (ext == "scm"
            && (filename_lower.contains("state")
                || filename_lower.contains("meta")
                || filename_lower.contains("ecosystem")
                || filename_lower.contains("agentic")
                || filename_lower.contains("neurosym")
                || filename_lower.contains("playbook")))
        || filename == "0-AI-MANIFEST.a2ml"
        || filename == "AI.a2ml"
    {
        return FileClass::Meta;
    }

    // Tests — test directories and test file naming conventions
    if path_lower.contains("/test/")
        || path_lower.contains("/tests/")
        || path_lower.contains("/spec/")
        || path_lower.starts_with("test/")
        || path_lower.starts_with("tests/")
        || filename_lower.contains("_test.")
        || filename_lower.contains("_spec.")
        || filename_lower.contains(".test.")
        || filename_lower.contains(".spec.")
        || filename_lower.starts_with("test_")
    {
        return FileClass::Tests;
    }

    // Documentation
    if matches!(
        ext.as_str(),
        "md" | "adoc" | "djot" | "rst" | "txt" | "tex" | "org" | "pod"
    ) || filename_lower == "license"
        || filename_lower == "licence"
        || filename_lower.starts_with("license")
        || filename_lower == "changelog"
        || filename_lower == "contributing"
        || filename_lower == "code_of_conduct"
        || filename_lower == "security"
        || filename_lower == "citation.cff"
        || filename_lower == "authors"
        || filename_lower == "notice"
        || filename_lower == "maintainers"
        || filename_lower == "topology.md"
        || path_lower.contains("/docs/")
        || path_lower.contains("/doc/")
        || path_lower.contains("/wiki/")
    {
        return FileClass::Docs;
    }

    // Configuration files
    if matches!(
        filename_lower.as_str(),
        "cargo.toml"
            | "cargo.lock"
            | "deno.json"
            | "deno.lock"
            | "package.json"
            | "bun.lockb"
            | "mix.exs"
            | "mix.lock"
            | "gleam.toml"
            | "manifest.toml"
            | "rebar.config"
            | "build.zig"
            | "build.zig.zon"
            | "justfile"
            | "makefile"
            | "gnumakefile"
            | "rakefile"
            | "gemfile"
            | "gemfile.lock"
            | "flake.nix"
            | "flake.lock"
            | "guix.scm"
            | ".editorconfig"
            | ".gitignore"
            | ".gitattributes"
            | ".gitmodules"
            | "opsm.toml"
            | "graph.toml"
            | "containerfile"
            | "dockerfile"
            | ".dockerignore"
            | ".containerignore"
            | "mustfile"
            | "trustfile"
            | "dustfile"
    ) || filename_lower.ends_with("containerfile")
        || filename_lower.ends_with("dockerfile")
        || ext == "nix"
        || ext == "lock"
        || (ext == "toml" && !path_lower.contains("/src/"))
        || filename_lower == ".rustfmt.toml"
        || filename_lower == "clippy.toml"
        || filename_lower == "rust-toolchain.toml"
        || filename_lower == ".tool-versions"
        || path_lower.contains("config/")
        || path_lower.contains("configs/")
    {
        return FileClass::Config;
    }

    // Binary assets
    if matches!(
        ext.as_str(),
        "png" | "jpg"
            | "jpeg"
            | "gif"
            | "svg"
            | "ico"
            | "webp"
            | "avif"
            | "bmp"
            | "tiff"
            | "woff"
            | "woff2"
            | "ttf"
            | "otf"
            | "eot"
            | "mp3"
            | "mp4"
            | "ogg"
            | "wav"
            | "flac"
            | "webm"
            | "zip"
            | "tar"
            | "gz"
            | "bz2"
            | "xz"
            | "zst"
            | "7z"
            | "rar"
            | "wasm"
            | "so"
            | "dylib"
            | "dll"
            | "a"
            | "lib"
            | "o"
            | "obj"
            | "exe"
            | "bin"
            | "dat"
            | "db"
            | "sqlite"
    ) {
        return FileClass::Assets;
    }

    // Data files
    if matches!(ext.as_str(), "json" | "jsonl" | "csv" | "tsv" | "yaml" | "yml" | "xml")
        || path_lower.contains("/data/")
        || path_lower.contains("verisimdb-data/")
        || path_lower.contains("/outcomes/")
        || path_lower.contains("/recipes/")
        || path_lower.contains("/patterns/")
        || path_lower.contains("/learning/")
    {
        return FileClass::Data;
    }

    // Source code — everything else with a known code extension
    if matches!(
        ext.as_str(),
        "rs" | "res"
            | "resi"
            | "ex"
            | "exs"
            | "erl"
            | "hrl"
            | "idr"
            | "ipkg"
            | "zig"
            | "gleam"
            | "ml"
            | "mli"
            | "hs"
            | "lhs"
            | "cabal"
            | "jl"
            | "rb"
            | "py"
            | "go"
            | "c"
            | "h"
            | "cpp"
            | "cxx"
            | "hpp"
            | "java"
            | "kt"
            | "scala"
            | "clj"
            | "cljs"
            | "cljc"
            | "lisp"
            | "cl"
            | "scm"
            | "rkt"
            | "lua"
            | "nim"
            | "cr"
            | "v"
            | "d"
            | "ada"
            | "adb"
            | "ads"
            | "js"
            | "mjs"
            | "cjs"
            | "ts"
            | "tsx"
            | "jsx"
            | "css"
            | "scss"
            | "less"
            | "html"
            | "htm"
            | "sh"
            | "bash"
            | "zsh"
            | "fish"
            | "ps1"
            | "bat"
            | "cmd"
            | "dats"
            | "sats"
            | "hats"
            | "lean"
            | "lean4"
            | "agda"
            | "coq"
            | "eph"
            | "as"
            | "ncl"
            | "nickel"
            | "sql"
            | "graphql"
            | "gql"
            | "proto"
            | "thrift"
            | "capnp"
            | "fbs"
    ) {
        return FileClass::Code;
    }

    // Fallback: if we can't classify it, call it code (conservative)
    FileClass::Code
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_workflow_is_ci() {
        assert_eq!(
            classify_single(".github/workflows/ci.yml"),
            FileClass::Ci
        );
    }

    #[test]
    fn test_hook_is_ci() {
        assert_eq!(
            classify_single("hooks/validate-spdx.sh"),
            FileClass::Ci
        );
    }

    #[test]
    fn test_readme_is_docs() {
        assert_eq!(classify_single("README.adoc"), FileClass::Docs);
    }

    #[test]
    fn test_license_is_docs() {
        assert_eq!(classify_single("LICENSE"), FileClass::Docs);
    }

    #[test]
    fn test_code_of_conduct_is_docs() {
        assert_eq!(
            classify_single("CODE_OF_CONDUCT.md"),
            FileClass::Docs
        );
    }

    #[test]
    fn test_rust_is_code() {
        assert_eq!(classify_single("src/main.rs"), FileClass::Code);
    }

    #[test]
    fn test_rescript_is_code() {
        assert_eq!(
            classify_single("src/app/VeriSimClient.res"),
            FileClass::Code
        );
    }

    #[test]
    fn test_idris_is_code() {
        assert_eq!(
            classify_single("src/abi/Foreign.idr"),
            FileClass::Code
        );
    }

    #[test]
    fn test_cargo_toml_is_config() {
        assert_eq!(classify_single("Cargo.toml"), FileClass::Config);
    }

    #[test]
    fn test_containerfile_is_config() {
        assert_eq!(
            classify_single("containers/burble.Containerfile"),
            FileClass::Config
        );
    }

    #[test]
    fn test_jsonl_is_data() {
        assert_eq!(
            classify_single("outcomes/2026-03.jsonl"),
            FileClass::Data
        );
    }

    #[test]
    fn test_png_is_assets() {
        assert_eq!(
            classify_single("assets/logo.png"),
            FileClass::Assets
        );
    }

    #[test]
    fn test_a2ml_is_meta() {
        assert_eq!(
            classify_single(".machine_readable/6a2/STATE.a2ml"),
            FileClass::Meta
        );
    }

    #[test]
    fn test_test_file_is_tests() {
        assert_eq!(
            classify_single("test/outcome_tracker_test.exs"),
            FileClass::Tests
        );
    }

    #[test]
    fn test_spec_file_is_tests() {
        assert_eq!(
            classify_single("tests/inflate_test.rs"),
            FileClass::Tests
        );
    }

    #[test]
    fn test_wasm_is_assets() {
        assert_eq!(classify_single("pkg/module.wasm"), FileClass::Assets);
    }

    #[test]
    fn test_containerfile_filename() {
        // Containerfile at root should be config
        assert_eq!(classify_single("Containerfile"), FileClass::Config);
    }
}
