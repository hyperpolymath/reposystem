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

pub mod a2ml;
pub mod just_emitter;
pub mod k9;

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
}

/// Search order for locating a contractile file. The CLI tools check these
/// directories in order, taking the first match:
///   1. `./contractiles/<type>/`  (portable contract set)
///   2. `./<type>/`               (top-level legacy location)
///   3. `./`                      (repo root)
pub fn find_contractile(filename: &str) -> Option<std::path::PathBuf> {
    // Derive the type subdirectory from the filename.
    // "Mustfile.a2ml" → "must", "Trustfile.a2ml" → "trust", etc.
    let type_dir = filename
        .split('.')
        .next()
        .unwrap_or("")
        .to_lowercase()
        .replace("file", "");

    let candidates = [
        format!("contractiles/{}/{}", type_dir, filename),
        format!("{}/{}", type_dir, filename),
        filename.to_string(),
    ];

    for candidate in &candidates {
        let path = std::path::PathBuf::from(candidate);
        if path.exists() {
            return Some(path);
        }
    }

    None
}
