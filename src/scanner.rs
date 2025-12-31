// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Repository scanning

use anyhow::Result;
use std::path::Path;

pub fn scan_path(path: &Path) -> Result<Vec<crate::types::Repo>> {
    // TODO: Implement scanning
    Ok(vec![])
}
