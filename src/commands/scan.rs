// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

use anyhow::Result;
use std::path::PathBuf;

pub fn run(path: PathBuf, deep: bool, shallow: bool, metadata: bool, detect_workspaces: bool) -> Result<()> {
    tracing::info!("Scanning: {:?}", path);
    // TODO: Implement scanning
    Ok(())
}
