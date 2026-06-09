// SPDX-License-Identifier: MPL-2.0
// Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
use std::collections::HashMap;
use std::fs;
use std::path::Path;

pub struct Manifest {
    pub source: String, // e.g., ".tool-versions", "mise.toml"
    pub tools: HashMap<String, String>, // Name -> Version
}

pub struct ManifestParser;

impl ManifestParser {
    pub fn parse_tool_versions<P: AsRef<Path>>(path: P) -> Option<Manifest> {
        if let Ok(content) = fs::read_to_string(&path) {
            let mut tools = HashMap::new();
            for line in content.lines() {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.len() >= 2 {
                    tools.insert(parts[0].to_string(), parts[1].to_string());
                }
            }
            Some(Manifest {
                source: path.as_ref().to_string_lossy().to_string(),
                tools,
            })
        } else {
            None
        }
    }

    // TODO: Implement mise.toml (TOML) parsing in next turn
}
