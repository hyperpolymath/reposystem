// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell

use anyhow::Result;

pub fn run(key: &str, value: Option<String>) -> Result<()> {
    match value {
        Some(v) => tracing::info!("Setting {} = {}", key, v),
        None => tracing::info!("Getting {}", key),
    }
    // TODO: Implement config
    Ok(())
}
