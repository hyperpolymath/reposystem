// SPDX-License-Identifier: MPL-2.0
// Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

use serde::{Serialize, Deserialize};
use std::fs;
use std::path::PathBuf;
use anyhow::Result;

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct DaemonConfig {
    pub autostart: bool,
    pub elevated_mode: bool,
    pub notify: bool,
    pub update_mode: String,   // "Check", "Notify", "Download", "Install"
    pub version_scope: String, // "Major", "Minor", "Patch"
    pub release_channel: String, // "Stable", "LTS", "Beta", "Alpha", "RC"
    pub pins: Vec<Pin>,
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct Pin {
    pub name: String,
    pub version: String,
    pub action: String, // "Keep", "Block"
}

impl Default for DaemonConfig {
    fn default() -> Self {
        Self {
            autostart: true,
            elevated_mode: false,
            notify: true,
            update_mode: "Notify".to_string(),
            version_scope: "Minor".to_string(),
            release_channel: "Stable".to_string(),
            pins: vec![
                Pin { name: "java".to_string(), version: "8".to_string(), action: "Keep".to_string() },
                Pin { name: "vscode".to_string(), version: "alpha".to_string(), action: "Block".to_string() },
            ],
        }
    }
}

pub struct ConfigManager;

impl ConfigManager {
    fn get_path() -> PathBuf {
        let home = std::env::var("HOME").unwrap_or_default();
        std::path::Path::new(&home).join(".config/total-upgrade/daemon.toml")
    }

    pub fn load() -> DaemonConfig {
        let path = Self::get_path();
        if let Ok(content) = fs::read_to_string(path) {
            toml::from_str(&content).unwrap_or_default()
        } else {
            DaemonConfig::default()
        }
    }

    pub fn save(config: &DaemonConfig) -> Result<()> {
        let path = Self::get_path();
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent)?;
        }
        let content = toml::to_string_pretty(config)?;
        fs::write(path, content)?;
        Ok(())
    }
}
