// SPDX-License-Identifier: MPL-2.0
// Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>
mod backend;
#[cfg(test)]
mod tests;

use anyhow::Result;
use crossterm::{
    event::{self, Event, KeyCode},
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
    ExecutableCommand,
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Tabs},
    Terminal,
};
use std::io::stdout;
use crate::backend::manifest::ManifestParser;
use crate::backend::types::{AppState, ToolCategory, ManagedTool, Association};
use crate::backend::detector::Detector;
use crate::backend::scanner::Scanner;
use crate::backend::daemon_setup::render_daemon_setup;

use clap::Parser;
use std::env;

#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Cli {
    /// Run the background daemon
    #[arg(short, long)]
    daemon: bool,
}

#[derive(Copy, Clone, PartialEq)]
enum Screen {
    MainMenu,
    Detection,
    ManagerSetup,
    SyncTransfer,
    Discovery,
    DaemonSetup, // New screen for daemon settings
}

struct App {
    current_screen: Screen,
    menu_state: ListState,
    manager_list_state: ListState,
    daemon_settings_state: ListState, // For navigating the complex daemon settings
    items: Vec<&'static str>,
    state: AppState,
}

impl App {
    fn new() -> App {
        let mut menu_state = ListState::default();
        menu_state.select(Some(0));
        let mut manager_list_state = ListState::default();
        manager_list_state.select(Some(0));
        let mut daemon_settings_state = ListState::default();
        daemon_settings_state.select(Some(0));

        // REAL DETECTION (Stage 3)
        let opsm = Detector::check_tool("opsm", ToolCategory::SystemPM);
        let asdf = Detector::check_tool("asdf", ToolCategory::SystemPM);
        let mise = Detector::check_tool("mise", ToolCategory::SystemPM);
        let system_pm = Detector::check_tool("nala", ToolCategory::SystemPM);

        // MANIFEST PARSING (Stage 4)
        let mut managed_tools = Vec::new();
        let home = std::env::var("HOME").unwrap_or_default();
        let global_tv = std::path::Path::new(&home).join(".tool-versions");
        
        if let Some(m) = ManifestParser::parse_tool_versions(&global_tv) {
            for (name, version) in m.tools {
                managed_tools.push(ManagedTool {
                    name,
                    version,
                    manager: "global".to_string(),
                    selected: false,
                });
            }
        }

        // ECOSYSTEM DISCOVERY (Stage 5)
        let discovery_items = Detector::discover_ecosystems();

        // ASSOCIATION SCAN (Stage 6)
        let associations = Scanner::scan_associations();

        App {
            current_screen: Screen::MainMenu,
            menu_state,
            manager_list_state,
            daemon_settings_state,
            items: vec![
                "1. Check Tool Status",
                "2. Manage asdf/mise/opsm",
                "3. Sync & Transfer",
                "4. Search & Discovery",
                "5. Background Daemon Settings",
                "Q. Quit",
            ],
            state: AppState {
                opsm,
                asdf,
                mise,
                system_pm,
                managed_tools,
                discovery_items,
                associations,
                last_scan: Some(chrono::Local::now()),
            },
        }
    }

    fn next(&mut self) {
        match self.current_screen {
            Screen::MainMenu => {
                let i = match self.menu_state.selected() {
                    Some(i) => if i >= self.items.len() - 1 { 0 } else { i + 1 },
                    None => 0,
                };
                self.menu_state.select(Some(i));
            }
            Screen::ManagerSetup => {
                let i = match self.manager_list_state.selected() {
                    Some(i) => if i >= self.state.managed_tools.len() - 1 { 0 } else { i + 1 },
                    None => 0,
                };
                self.manager_list_state.select(Some(i));
            }
            _ => {}
        }
    }

    fn previous(&mut self) {
        match self.current_screen {
            Screen::MainMenu => {
                let i = match self.menu_state.selected() {
                    Some(i) => if i == 0 { self.items.len() - 1 } else { i - 1 },
                    None => 0,
                };
                self.menu_state.select(Some(i));
            }
            Screen::ManagerSetup => {
                let i = match self.manager_list_state.selected() {
                    Some(i) => if i == 0 { self.state.managed_tools.len() - 1 } else { i - 1 },
                    None => 0,
                };
                self.manager_list_state.select(Some(i));
            }
            _ => {}
        }
    }

    fn toggle_selected(&mut self) {
        if let Some(i) = self.manager_list_state.selected() {
            if let Some(tool) = self.state.managed_tools.get_mut(i) {
                tool.selected = !tool.selected;
            }
        }
    }
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    if cli.daemon {
        // Run silent background daemon
        println!("Starting total-upgrade daemon in background...");
        loop {
            // Check for updates (stub logic)
            // Log to state dir
            std::thread::sleep(std::time::Duration::from_secs(3600));
        }
    }

    // Interactive TUI starts here
    enable_raw_mode()?;
    stdout().execute(EnterAlternateScreen)?;
    let mut terminal = Terminal::new(CrosstermBackend::new(stdout()))?;

    let mut app = App::new();

    loop {
        terminal.draw(|f| {
            let chunks = Layout::default()
                .direction(Direction::Vertical)
                .margin(1)
                .constraints([
                    Constraint::Length(3), // Header
                    Constraint::Min(0),    // Content
                    Constraint::Length(3), // Footer
                ])
                .split(f.area());

            let titles = vec!["Main", "Detection", "Managers", "Sync", "Search"];
            let index = match app.current_screen {
                Screen::MainMenu => 0,
                Screen::Detection => 1,
                Screen::ManagerSetup => 2,
                Screen::SyncTransfer => 3,
                Screen::Discovery => 4,
                Screen::DaemonSetup => 5,
            };
            let tabs = Tabs::new(titles)
                .block(Block::default().borders(Borders::ALL).title(" total-upgrade "))
                .select(if index < 5 { index } else { 0 }) // Tab index out of bounds fallback
                .highlight_style(Style::default().fg(Color::Yellow));
            f.render_widget(tabs, chunks[0]);

            match app.current_screen {
                Screen::MainMenu => render_main_menu(f, chunks[1], &mut app),
                Screen::Detection => render_detection(f, chunks[1], &app),
                Screen::ManagerSetup => render_managers(f, chunks[1], &mut app),
                Screen::SyncTransfer => render_sync(f, chunks[1]),
                Screen::Discovery => render_discovery(f, chunks[1], &app),
                Screen::DaemonSetup => render_daemon_setup(f, chunks[1], &mut app),
            }

            let footer_text = match app.current_screen {
                Screen::MainMenu => "Up/Down: Navigate | Enter: Select | Q: Quit",
                Screen::ManagerSetup => "Up/Down: Navigate | Space: Toggle | Esc: Back",
                Screen::Discovery => "Esc: Back | F: Report to feedback-o-tron",
                _ => "Press 'Esc' to return to Main Menu.",
            };
            let footer = Paragraph::new(footer_text)
                .block(Block::default().borders(Borders::ALL));
            f.render_widget(footer, chunks[2]);
        })?;

        if event::poll(std::time::Duration::from_millis(16))? {
            if let Event::Key(key) = event::read()? {
                if key.code == KeyCode::Char('q') && app.current_screen == Screen::MainMenu {
                    break;
                }
                if key.code == KeyCode::Esc {
                    app.current_screen = Screen::MainMenu;
                }

                match app.current_screen {
                    Screen::MainMenu => match key.code {
                        KeyCode::Up => app.previous(),
                        KeyCode::Down => app.next(),
                        KeyCode::Enter => match app.menu_state.selected() {
                            Some(0) => app.current_screen = Screen::Detection,
                            Some(1) => app.current_screen = Screen::ManagerSetup,
                            Some(2) => app.current_screen = Screen::SyncTransfer,
                            Some(3) => app.current_screen = Screen::Discovery,
                            Some(4) => app.current_screen = Screen::DaemonSetup,
                            Some(5) => break,
                            _ => {}
                        },
                        _ => {}
                    },
                    Screen::ManagerSetup => match key.code {
                        KeyCode::Up => app.previous(),
                        KeyCode::Down => app.next(),
                        KeyCode::Char(' ') => app.toggle_selected(),
                        _ => {}
                    },
                    _ => {}
                }
            }
        }
    }

    disable_raw_mode()?;
    stdout().execute(LeaveAlternateScreen)?;
    Ok(())
}

fn render_main_menu(f: &mut ratatui::Frame, area: Rect, app: &mut App) {
    let items: Vec<ListItem> = app
        .items
        .iter()
        .map(|i| ListItem::new(*i).style(Style::default().fg(Color::White)))
        .collect();
    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL).title(" Select Operation "))
        .highlight_style(Style::default().bg(Color::Blue).add_modifier(Modifier::BOLD))
        .highlight_symbol(">> ");
    f.render_stateful_widget(list, area, &mut app.menu_state);
}

fn render_detection(f: &mut ratatui::Frame, area: Rect, app: &App) {
    let mut lines = Vec::new();
    for tool in &[&app.state.opsm, &app.state.asdf, &app.state.mise, &app.state.system_pm] {
        let status = if tool.installed {
            format!("INSTALLED ({})", tool.version.as_ref().unwrap_or(&"unknown".to_string()))
        } else {
            "MISSING".to_string()
        };
        let color = if tool.installed { Color::Green } else { Color::Red };
        lines.push(Line::from(vec![
            Span::raw(format!("{:<10}: ", tool.name)),
            Span::styled(status, Style::default().fg(color)),
        ]));
    }
    lines.push(Line::from(""));
    lines.push(Line::from(vec![
        Span::raw("Last Scan: "),
        Span::styled(format!("{}", app.state.last_scan.unwrap().format("%Y-%m-%d %H:%M:%S")), Style::default().fg(Color::DarkGray)),
    ]));
    let p = Paragraph::new(lines).block(Block::default().borders(Borders::ALL).title(" Real-time Detection "));
    f.render_widget(p, area);
}

fn render_managers(f: &mut ratatui::Frame, area: Rect, app: &mut App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([Constraint::Length(8), Constraint::Min(0)])
        .split(area);
    let info_text = vec![
        Line::from("Manager Management Screen"),
        Line::from("--------------------------"),
        Line::from("[ ] Attach existing manifests"),
        Line::from("[ ] Detach unused managers"),
        Line::from(vec![Span::raw("Primary Manager: "), Span::styled("opsm", Style::default().fg(Color::Yellow))]),
    ];
    let info = Paragraph::new(info_text).block(Block::default().borders(Borders::ALL).title(" Actions "));
    f.render_widget(info, chunks[0]);
    let tool_items: Vec<ListItem> = app.state.managed_tools.iter()
        .map(|t| {
            let symbol = if t.selected { "[X]" } else { "[ ]" };
            ListItem::new(format!("{} {:<15} v{:<10} ({})", symbol, t.name, t.version, t.manager))
        })
        .collect();
    let tools_list = List::new(tool_items)
        .block(Block::default().borders(Borders::ALL).title(" Managed Tools (Space to Toggle) "))
        .highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
        .highlight_symbol("> ");
    f.render_stateful_widget(tools_list, chunks[1], &mut app.manager_list_state);
}

fn render_sync(f: &mut ratatui::Frame, area: Rect) {
    let text = vec![
        Line::from("Sync & Transfer Screen"),
        Line::from("----------------------"),
        Line::from("-> Move tools from asdf to mise"),
        Line::from("-> Sync opsm with system PM"),
        Line::from("-> Export current manifest to all"),
    ];
    let p = Paragraph::new(text).block(Block::default().borders(Borders::ALL).title(" Transfer Operations "));
    f.render_widget(p, area);
}

fn render_discovery(f: &mut ratatui::Frame, area: Rect, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(area);

    // Left column: Ecosystems (Stage 5)
    let mut ecosystem_lines = Vec::new();
    for item in &app.state.discovery_items {
        use crate::backend::types::DiscoveryStatus;
        let (status_str, color) = match item.status {
            DiscoveryStatus::Installed => ("INSTALLED", Color::Green),
            DiscoveryStatus::MissingButSuggested => ("SUGGESTED", Color::Yellow),
            DiscoveryStatus::Available => ("AVAILABLE", Color::DarkGray),
        };
        ecosystem_lines.push(ListItem::new(vec![
            Line::from(vec![
                Span::styled(format!("{:<10} ", item.name), Style::default().add_modifier(Modifier::BOLD)),
                Span::styled(status_str, Style::default().fg(color)),
            ]),
            Line::from(format!("  └─ {}", item.description)),
        ]));
    }
    let eco_list = List::new(ecosystem_lines).block(Block::default().borders(Borders::ALL).title(" Ecosystems "));
    f.render_widget(eco_list, chunks[0]);

    // Right column: File Associations (Stage 6)
    let mut assoc_lines = Vec::new();
    for assoc in &app.state.associations {
        let certainty_color = if assoc.certainty > 0.8 { Color::Green } else { Color::Yellow };
        assoc_lines.push(ListItem::new(vec![
            Line::from(vec![
                Span::styled(format!("{:<5} ", assoc.extension), Style::default().fg(Color::Cyan).add_modifier(Modifier::BOLD)),
                Span::raw("-> "),
                Span::styled(&assoc.detected_type, Style::default().fg(certainty_color)),
            ]),
            Line::from(format!("  Tools: {}", assoc.tools.join(", "))),
        ]));
    }
    let assoc_list = List::new(assoc_lines).block(Block::default().borders(Borders::ALL).title(" File Associations "));
    f.render_widget(assoc_list, chunks[1]);
}
