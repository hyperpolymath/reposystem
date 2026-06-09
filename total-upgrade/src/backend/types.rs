// SPDX-License-Identifier: MPL-2.0
// Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

#[allow(dead_code)]
pub enum Platform {
    Windows,
    Mac,
    Linux,
    Minix,
    Android,
    Ios,
}

impl Platform {
    #[allow(dead_code)]
    pub fn icon(&self) -> &'static str {
        match self {
            Platform::Windows => "🪟",
            Platform::Mac => "🍎",
            Platform::Linux => "🐧",
            Platform::Minix => "Ⓜ️",
            Platform::Android => "🤖",
            Platform::Ios => "🍏",
        }
    }
}

pub struct Tool {
    pub name: String,
    pub version: Option<String>,
    pub installed: bool,
    #[allow(dead_code)]
    pub category: ToolCategory,
    #[allow(dead_code)]
    pub platforms: Vec<Platform>,
}

#[allow(dead_code)]
pub enum ToolCategory {
    Editor,
    IDE,
    Runtime,
    SystemPM,
}

pub struct AppState {
    pub opsm: Tool,
    pub asdf: Tool,
    pub mise: Tool,
    pub system_pm: Tool,
    pub managed_tools: Vec<ManagedTool>,
    pub discovery_items: Vec<DiscoveryItem>,
    pub associations: Vec<Association>, // New for Stage 6
    pub last_scan: Option<chrono::DateTime<chrono::Local>>,
}

pub struct Association {
    pub extension: String,
    pub tools: Vec<String>,
    pub detected_type: String,
    pub certainty: f32, // 0.0 to 1.0
}

pub struct DiscoveryItem {
    pub name: String,
    pub description: String,
    pub status: DiscoveryStatus,
    #[allow(dead_code)]
    pub category: ToolCategory,
}

pub enum DiscoveryStatus {
    Installed,
    MissingButSuggested, // e.g. Ruby is here but Gem is missing
    Available,
}

pub struct ManagedTool {
    pub name: String,
    pub version: String,
    pub manager: String, // "asdf", "mise", or "opsm"
    pub selected: bool,
}
