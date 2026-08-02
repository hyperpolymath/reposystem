// SPDX-License-Identifier: MPL-2.0
// Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
use std::process::Command;
use crate::backend::types::{Tool, ToolCategory, Platform};

pub struct Detector;

impl Detector {
    pub fn check_tool(name: &str, category: ToolCategory) -> Tool {
        let output = Command::new("which")
            .arg(name)
            .output();

        let installed = output.is_ok() && output.unwrap().status.success();
        
        let version = if installed {
            let v_out = Command::new(name)
                .arg("--version")
                .output();
            
            match v_out {
                Ok(o) => Some(String::from_utf8_lossy(&o.stdout).trim().to_string()),
                Err(_) => None,
            }
        } else {
            None
        };

        Tool {
            name: name.to_string(),
            version,
            installed,
            category,
            platforms: vec![Platform::Linux, Platform::Windows],
        }
    }

    pub fn discover_ecosystems() -> Vec<crate::backend::types::DiscoveryItem> {
        use crate::backend::types::{DiscoveryItem, DiscoveryStatus, ToolCategory};
        let mut items = Vec::new();

        // 1. Standard PATH checks
        let checks = vec![
            ("python", "pip", "Python Ecosystem"),
            ("ruby", "gem", "Ruby Ecosystem"),
            ("node", "npm", "Node.js Ecosystem"),
            ("cargo", "rustup", "Rust Ecosystem"),
            ("elixir", "mix", "Elixir/Hex Ecosystem"),
        ];

        for (runtime, pm, desc) in checks {
            let runtime_exists = Command::new("which").arg(runtime).output().is_ok_and(|o| o.status.success());
            let pm_exists = Command::new("which").arg(pm).output().is_ok_and(|o| o.status.success());

            let status = match (runtime_exists, pm_exists) {
                (true, true) => DiscoveryStatus::Installed,
                (true, false) => DiscoveryStatus::MissingButSuggested,
                (false, _) => DiscoveryStatus::Available,
            };

            items.push(DiscoveryItem {
                name: pm.to_string(),
                description: format!("{} for {}", pm, desc),
                status,
                category: ToolCategory::Runtime,
            });
        }

        // 2. Deep Scan of /developer/tools (v0.4.0 preview)
        let tools_root = "/home/hyperpolymath/developer/tools";
        let prover_dirs = vec!["provers", "languages", "solvers"];
        
        for subdir in prover_dirs {
            let path = std::path::Path::new(tools_root).join(subdir);
            if let Ok(entries) = std::fs::read_dir(path) {
                for entry in entries.flatten() {
                    if entry.path().is_dir() {
                        let name = entry.file_name().to_string_lossy().to_string();
                        items.push(DiscoveryItem {
                            name,
                            description: format!("Found in {}/{}", tools_root, subdir),
                            status: DiscoveryStatus::Available,
                            category: ToolCategory::IDE, // General category for provers for now
                        });
                    }
                }
            }
        }

        items
    }
}
