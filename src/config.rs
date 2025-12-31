// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Configuration management

use anyhow::Result;
use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub data_dir: std::path::PathBuf,
    pub cache_dir: std::path::PathBuf,
    pub log_level: String,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            data_dir: directories::ProjectDirs::from("com", "hyperpolymath", "reposystem")
                .map(|d| d.data_dir().to_path_buf())
                .unwrap_or_else(|| std::path::PathBuf::from("~/.local/share/reposystem")),
            cache_dir: directories::ProjectDirs::from("com", "hyperpolymath", "reposystem")
                .map(|d| d.cache_dir().to_path_buf())
                .unwrap_or_else(|| std::path::PathBuf::from("~/.cache/reposystem")),
            log_level: "info".to_string(),
        }
    }
}

pub fn load() -> Result<Config> {
    Ok(Config::default())
}
