// SPDX-License-Identifier: MPL-2.0
// Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

use std::collections::HashMap;
use std::fs;
use std::path::Path;

pub struct Manifest {
    #[allow(dead_code)]
    pub source: String,
    pub tools: HashMap<String, String>,
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

    pub fn parse_mise_toml<P: AsRef<Path>>(path: P) -> Option<Manifest> {
        if let Ok(content) = fs::read_to_string(&path) {
            let value: toml::Value = toml::from_str(&content).ok()?;
            let mut tools = HashMap::new();
            
            if let Some(tools_table) = value.get("tools").and_then(|v| v.as_table()) {
                for (name, version_val) in tools_table {
                    let version = match version_val {
                        toml::Value::String(s) => s.clone(),
                        toml::Value::Integer(i) => i.to_string(),
                        _ => "latest".to_string(),
                    };
                    tools.insert(name.clone(), version);
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

    pub fn write_tool_versions<P: AsRef<Path>>(path: P, manifest: &Manifest) -> std::io::Result<()> {
        let mut content = String::new();
        let mut tools: Vec<_> = manifest.tools.iter().collect();
        tools.sort_by(|a, b| a.0.cmp(b.0)); // Deterministic order

        for (name, version) in tools {
            content.push_str(&format!("{} {}\n", name, version));
        }
        fs::write(path, content)
    }
}
