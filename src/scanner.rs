// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Repository scanning

use anyhow::Result;
use std::path::Path;
use crate::graph::Repo;

/// Scan a path for git repositories
pub fn scan_path(path: &Path) -> Result<Vec<Repo>> {
    // TODO: Implement scanning
    let _ = path; // silence unused warning
    Ok(vec![])
}
