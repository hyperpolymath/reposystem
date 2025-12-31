// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

use anyhow::Result;

pub fn run(action: &str, name: &str, base: Option<String>) -> Result<()> {
    tracing::info!("Scenario action: {} {}", action, name);
    // TODO: Implement scenarios
    Ok(())
}
