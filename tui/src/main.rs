// SPDX-License-Identifier: PMPL-1.0-or-later
// SPDX-FileCopyrightText: 2026 Jonathan D.A. Jewell
//
//! Reposystem TUI — terminal user interface entry point.
//!
//! Migrated from Ada/SPARK (`legacy-ada/reposystem_tui-main.adb`).
//! Uses ratatui + crossterm for rendering, with SPARK-style contracts
//! preserved in `reposystem_tui::AppState`.

#![forbid(unsafe_code)]

use std::io;
use std::time::Duration;

use clap::Parser;
use crossterm::{
    event::{self, Event, KeyCode, KeyEvent, KeyModifiers},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    layout::{Constraint, Direction, Layout},
    prelude::CrosstermBackend,
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, Paragraph},
    Frame, Terminal,
};

use reposystem_tui::{AppState, PanLLPanel, PanLLStatus, ViewMode};

// =============================================================================
// CLI arguments — mirrors Ada command-line parsing in reposystem_tui-main.adb
// =============================================================================

/// Reposystem TUI — Railway yard for your repository ecosystem.
///
/// Terminal-based viewer for repository dependency graphs, aspect annotations,
/// slot/provider bindings, and PanLL panel integration.
#[derive(Parser, Debug)]
#[command(name = "reposystem-tui", version, about)]
struct Cli {
    /// Terminal width override (1-1000, default: auto-detect).
    #[arg(short = 'W', long, value_parser = clap::value_parser!(u16).range(1..=1000))]
    width: Option<u16>,

    /// Terminal height override (1-500, default: auto-detect).
    #[arg(short = 'H', long, value_parser = clap::value_parser!(u16).range(1..=500))]
    height: Option<u16>,
}

// =============================================================================
// Rendering — mirrors Ada `Render` procedure
// =============================================================================

/// Render the current application state to the terminal frame.
///
/// Mirrors Ada `Render`:
/// ```ada
/// procedure Render (State : App_State)
///   with Pre => State.Running;
/// ```
///
/// The `Pre => State.Running` contract is enforced by the caller (main loop
/// only calls render while `state.is_running()` is true).
fn render(frame: &mut Frame, state: &AppState) {
    // SPARK Pre-condition check
    debug_assert!(state.is_running(), "SPARK pre: Render requires State.Running");

    let area = frame.area();

    // Layout: header + status + content + footer
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3),  // Header
            Constraint::Length(3),  // Status bar (mode + filter + PanLL)
            Constraint::Min(5),    // Content area
            Constraint::Length(2), // Footer / help
        ])
        .split(area);

    // -- Header -----------------------------------------------------------
    let header = Paragraph::new(Line::from(vec![
        Span::styled(
            " REPOSYSTEM ",
            Style::default()
                .fg(Color::White)
                .bg(Color::Blue)
                .add_modifier(Modifier::BOLD),
        ),
        Span::raw(" Railway Yard for Your Repository Ecosystem"),
    ]))
    .block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(Color::Cyan)),
    );
    frame.render_widget(header, chunks[0]);

    // -- Status bar -------------------------------------------------------
    let mode_style = Style::default()
        .fg(Color::Yellow)
        .add_modifier(Modifier::BOLD);
    let filter_style = Style::default().fg(Color::Green);
    let panll_style = match state.panll_status() {
        PanLLStatus::Connected => Style::default().fg(Color::Green),
        PanLLStatus::Connecting => Style::default().fg(Color::Yellow),
        PanLLStatus::Error => Style::default().fg(Color::Red),
        PanLLStatus::Disconnected => Style::default().fg(Color::DarkGray),
    };

    let status_line = Line::from(vec![
        Span::raw(" Mode: "),
        Span::styled(format!("[{}]", state.mode()), mode_style),
        Span::raw("  Filter: "),
        Span::styled(format!("[{}]", state.filter()), filter_style),
        Span::raw("  PanLL: "),
        Span::styled(format!("{}", state.panll_status()), panll_style),
        Span::raw("  Panel: "),
        Span::styled(
            format!("[{}]", state.active_panel()),
            Style::default().fg(Color::Magenta),
        ),
    ]);

    let status = Paragraph::new(status_line).block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(Color::DarkGray)),
    );
    frame.render_widget(status, chunks[1]);

    // -- Content area -----------------------------------------------------
    let content_lines = build_content_lines(state);
    let content = Paragraph::new(content_lines).block(
        Block::default()
            .title(format!(
                " Repos: {}  Edges: {}  Selected: {} ",
                state.repo_count(),
                state.edge_count(),
                state.selected()
            ))
            .borders(Borders::ALL)
            .border_style(Style::default().fg(Color::Cyan)),
    );
    frame.render_widget(content, chunks[2]);

    // -- Footer / keybindings help ----------------------------------------
    let help = Paragraph::new(Line::from(vec![
        Span::styled(" [1-5]", Style::default().fg(Color::Yellow)),
        Span::raw(" View  "),
        Span::styled("[a/s/r/p]", Style::default().fg(Color::Yellow)),
        Span::raw(" Filter  "),
        Span::styled("[hjkl]", Style::default().fg(Color::Yellow)),
        Span::raw(" Navigate  "),
        Span::styled("[n/N]", Style::default().fg(Color::Yellow)),
        Span::raw(" Select  "),
        Span::styled("[c]", Style::default().fg(Color::Yellow)),
        Span::raw(" PanLL  "),
        Span::styled("[L/M/W]", Style::default().fg(Color::Yellow)),
        Span::raw(" Panel  "),
        Span::styled("[q]", Style::default().fg(Color::Red)),
        Span::raw(" Quit"),
    ]));
    frame.render_widget(help, chunks[3]);
}

/// Build content lines based on the current view mode and panel.
///
/// Mirrors the Ada `Render` procedure's mode-specific content sections.
fn build_content_lines(state: &AppState) -> Vec<Line<'static>> {
    match state.mode() {
        ViewMode::Graph => vec![
            Line::from("  Dependency graph visualization"),
            Line::from(format!(
                "  Cursor: ({}, {})",
                state.cursor_x(),
                state.cursor_y()
            )),
            Line::from(""),
            Line::from("  (Graph rendering area — use hjkl to navigate)"),
        ],
        ViewMode::List => vec![
            Line::from("  Repository list"),
            Line::from("  (Use n/N to select repositories)"),
        ],
        ViewMode::Detail => vec![
            Line::from("  Repository detail view"),
            Line::from(format!("  Selected index: {}", state.selected())),
        ],
        ViewMode::Scenario => vec![
            Line::from("  What-if scenario analysis"),
            Line::from("  (Scenario simulation area)"),
        ],
        ViewMode::PanLL => build_panll_content(state),
    }
}

/// Build PanLL view content based on the active panel.
///
/// Mirrors the Ada `PanLL_View` branch in `Render`, which shows different
/// content for Panel_L, Panel_N, and Panel_W.
fn build_panll_content(state: &AppState) -> Vec<Line<'static>> {
    let panel_header_style = Style::default()
        .fg(Color::Magenta)
        .add_modifier(Modifier::BOLD);

    match state.active_panel() {
        PanLLPanel::L => vec![
            Line::from(Span::styled(
                "  Panel-L: Ecosystem Constraints",
                panel_header_style,
            )),
            Line::from("  - Slot policies       - Edge cardinality limits"),
            Line::from("  - Aspect rules        - Governance invariants"),
        ],
        PanLLPanel::N => vec![
            Line::from(Span::styled(
                "  Panel-N: Ecosystem Health Reasoning",
                panel_header_style,
            )),
            Line::from("  - Dependency analysis    - Vulnerability propagation"),
            Line::from("  - Slot coverage gaps     - Orphan detection"),
        ],
        PanLLPanel::W => vec![
            Line::from(Span::styled(
                "  Panel-W: Ecosystem Barycentre",
                panel_header_style,
            )),
            Line::from("  - Graph snapshot      - Health dashboard"),
            Line::from("  - Scan results        - Scenario output"),
        ],
    }
}

// =============================================================================
// Terminal setup/teardown
// =============================================================================

/// Set up raw mode and alternate screen for the terminal.
fn setup_terminal() -> io::Result<Terminal<CrosstermBackend<io::Stdout>>> {
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    Terminal::new(backend)
}

/// Restore the terminal to its original state.
fn restore_terminal(terminal: &mut Terminal<CrosstermBackend<io::Stdout>>) -> io::Result<()> {
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;
    Ok(())
}

// =============================================================================
// Main event loop — mirrors Ada `Run` procedure
// =============================================================================

/// Main entry point.
///
/// Mirrors Ada `Run`:
/// ```ada
/// procedure Run (Width : Screen_Width; Height : Screen_Height)
///   with No_Return => False;
/// ```
fn main() -> io::Result<()> {
    let cli = Cli::parse();

    // Auto-detect terminal size, with CLI overrides
    // (mirrors Ada defaulting to 80x24 then parsing args)
    let (term_width, term_height) = crossterm::terminal::size().unwrap_or((80, 24));
    let width = cli.width.unwrap_or(term_width);
    let height = cli.height.unwrap_or(term_height);

    let mut state = AppState::new(width, height);
    let mut terminal = setup_terminal()?;

    // Main event loop — mirrors Ada `while State.Running loop`
    while state.is_running() {
        // Render — mirrors Ada `Render (State)`
        terminal.draw(|frame| render(frame, &state))?;

        // Poll for input with 100ms timeout to allow responsive rendering
        if event::poll(Duration::from_millis(100))? {
            match event::read()? {
                // Keyboard input — mirrors Ada `Get_Immediate`
                Event::Key(KeyEvent {
                    code, modifiers, ..
                }) => {
                    let key = match code {
                        // Map key codes to characters matching the Ada key mapping
                        KeyCode::Char(c) => {
                            if modifiers.contains(KeyModifiers::SHIFT) {
                                c.to_uppercase().next().unwrap_or(c)
                            } else {
                                c
                            }
                        }
                        KeyCode::Left => 'h',
                        KeyCode::Right => 'l',
                        KeyCode::Up => 'k',
                        KeyCode::Down => 'j',
                        KeyCode::Esc => 'q',
                        _ => continue,
                    };
                    state.handle_input(key);
                }

                // Terminal resize — update state dimensions
                Event::Resize(w, h) => {
                    state.resize(w, h);
                }

                _ => {}
            }
        }
    }

    // Clean exit — mirrors Ada screen clear on exit
    restore_terminal(&mut terminal)?;
    Ok(())
}
