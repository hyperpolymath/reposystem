// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

use anyhow::Result;
use std::path::PathBuf;

pub fn run(format: &str, output: Option<PathBuf>, aspect: Option<String>) -> Result<()> {
    tracing::info!("Exporting to {}", format);
    // TODO: Implement export
    Ok(())
}
