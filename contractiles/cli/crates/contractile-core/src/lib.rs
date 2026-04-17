// SPDX-License-Identifier: PMPL-1.0-or-later
// contractile-core — Core library for the contractile CLI family.
//
// Provides three main capabilities:
//   1. A2ML parsing (a2ml) — reads Mustfile/Trustfile/Dustfile/Intentfile.a2ml
//   2. K9 bridge (k9) — evaluates K9 Nickel components via `nickel export`
//   3. Just emitter (just_emitter) — generates .just recipes from A2ML + K9
//
// These form the shared foundation for the `must`, `trust`, `dust`, `intend`,
// and `k9` CLI subcommands, as well as the `gen-just` integration command.
//
// Copyright (c) 2026 Jonathan D.A. Jewell (hyperpolymath)

#![forbid(unsafe_code)]
pub mod a2ml;
pub mod just_emitter;
pub mod k9;
pub mod toml_compat;

/// Canonical file names for each contractile type.
/// The CLI tools search for these (case-insensitive) when no explicit
/// path is given.
pub mod filenames {
    /// Mustfile: state/invariant contract.
    pub const MUSTFILE_A2ML: &str = "Mustfile.a2ml";
    pub const MUSTFILE_TOML: &str = "mustfile.toml";

    /// Trustfile: integrity and provenance verification.
    pub const TRUSTFILE_A2ML: &str = "Trustfile.a2ml";

    /// Dustfile: recovery and rollback semantics.
    pub const DUSTFILE_A2ML: &str = "Dustfile.a2ml";

    /// Intentfile: declared future intent / roadmap.
    pub const INTENTFILE_A2ML: &str = "Intentfile.a2ml";

    /// Adjustfile: accessibility & digital justice invariants.
    pub const ADJUSTFILE_A2ML: &str = "Adjustfile.a2ml";
    /// Adjustfile: S-expression contractile format (in .machine_readable/).
    pub const ADJUST_CONTRACTILE: &str = "ADJUST.contractile";
}

/// Search order for locating a contractile file. The CLI tools check these
/// directories in order, taking the first match:
///   1. `.machine_readable/contractiles/<type>/` (canonical estate layout — highest priority)
///   2. `./contractiles/<type>/`                 (portable contract set)
///   3. `./<type>/`                              (top-level legacy location)
///   4. `./`                                     (repo root)
pub fn find_contractile(filename: &str) -> Option<std::path::PathBuf> {
    // Derive the type subdirectory from the filename.
    // "Mustfile.a2ml" → "must", "Trustfile.a2ml" → "trust", etc.
    let type_dir = filename
        .split('.')
        .next()
        .unwrap_or("")
        .to_lowercase()
        .replace("file", "");

    // Build candidate paths. Canonical estate layout (.machine_readable/contractiles/<verb>/)
    // is searched first; legacy locations follow for backward compatibility.
    let mut candidates = vec![
        format!(".machine_readable/contractiles/{}/{}", type_dir, filename),
        format!("contractiles/{}/{}", type_dir, filename),
        format!("{}/{}", type_dir, filename),
        filename.to_string(),
    ];

    // Add legacy "lust" alias for Intentfile.
    if type_dir == "intent" {
        candidates.insert(1, format!("contractiles/lust/{}", filename));
        candidates.insert(2, format!("lust/{}", filename));
    }

    // Adjustfile also lives in .machine_readable/ as ADJUST.contractile.
    if type_dir == "adjust" {
        candidates.push(".machine_readable/ADJUST.contractile".to_string());
    }

    for candidate in &candidates {
        let path = std::path::PathBuf::from(candidate);
        if path.exists() {
            return Some(path);
        }
    }

    None
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    /// Verify that find_contractile() resolves a Mustfile.a2ml placed at the
    /// canonical estate path `.machine_readable/contractiles/must/Mustfile.a2ml`
    /// without requiring an explicit --file flag.
    #[test]
    fn find_contractile_resolves_canonical_machine_readable_path() {
        let tmp = tempfile::tempdir().expect("failed to create temp dir");
        let canonical = tmp
            .path()
            .join(".machine_readable/contractiles/must");
        fs::create_dir_all(&canonical).expect("failed to create canonical dir");
        let mustfile = canonical.join("Mustfile.a2ml");
        fs::write(&mustfile, "(must)").expect("failed to write Mustfile.a2ml");

        // Change cwd to the temp dir so relative path resolution works.
        let original_dir = std::env::current_dir().expect("no cwd");
        std::env::set_current_dir(tmp.path()).expect("failed to chdir");

        let result = find_contractile("Mustfile.a2ml");

        std::env::set_current_dir(original_dir).expect("failed to restore cwd");

        assert!(
            result.is_some(),
            "expected Mustfile.a2ml to be found in .machine_readable/contractiles/must/"
        );
        assert_eq!(
            result.unwrap(),
            std::path::PathBuf::from(".machine_readable/contractiles/must/Mustfile.a2ml")
        );
    }
}
