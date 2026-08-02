// SPDX-License-Identifier: MPL-2.0
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//
//! Command implementations

pub mod apply;
pub mod aspect;
pub mod completions;
pub mod config;
pub mod edge;
pub mod export;
pub mod group;
pub mod import;
pub mod plan;
pub mod scan;
pub mod scenario;
pub mod slot;
pub mod view;
pub mod weak_links;

use anyhow::Result;
use std::path::PathBuf;

/// Resolve the data directory used to persist the graph stores.
///
/// Priority: `REPOSYSTEM_DATA_DIR` → platform data dir → `./.reposystem`.
/// Shared by `scan`, `import` and `export` so they all agree on one location.
///
/// # Errors
/// Currently infallible, but returns `Result` for forward compatibility.
pub fn data_dir() -> Result<PathBuf> {
    if let Ok(dir) = std::env::var("REPOSYSTEM_DATA_DIR") {
        return Ok(PathBuf::from(dir));
    }
    let dir = directories::ProjectDirs::from("org", "hyperpolymath", "reposystem")
        .map(|dirs| dirs.data_dir().to_path_buf())
        .unwrap_or_else(|| {
            std::env::current_dir()
                .unwrap_or_else(|_| PathBuf::from("."))
                .join(".reposystem")
        });
    Ok(dir)
}
