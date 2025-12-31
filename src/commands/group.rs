// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

use anyhow::Result;

pub fn run(action: &str, name: Option<String>, repos: Vec<String>) -> Result<()> {
    tracing::info!("Group action: {}", action);
    // TODO: Implement groups
    Ok(())
}
