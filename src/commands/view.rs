// SPDX-License-Identifier: AGPL-3.0-or-later
// SPDX-FileCopyrightText: 2025 Jonathan D.A. Jewell
//! Interactive TUI view for exploring the ecosystem graph

use crate::graph::EcosystemGraph;
use anyhow::{Context, Result};
use crossterm::{
    event::{self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::{
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout, Rect},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, ListState, Paragraph, Tabs},
    Frame, Terminal,
};
use std::io;
use std::path::PathBuf;

/// Tab selection
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum Tab {
    Repos,
    Edges,
    Groups,
    Aspects,
}

impl Tab {
    fn titles() -> Vec<&'static str> {
        vec!["Repos", "Edges", "Groups", "Aspects"]
    }

    fn index(&self) -> usize {
        match self {
            Tab::Repos => 0,
            Tab::Edges => 1,
            Tab::Groups => 2,
            Tab::Aspects => 3,
        }
    }

    fn from_index(i: usize) -> Self {
        match i % 4 {
            0 => Tab::Repos,
            1 => Tab::Edges,
            2 => Tab::Groups,
            _ => Tab::Aspects,
        }
    }
}

/// Application state
struct App {
    graph: EcosystemGraph,
    current_tab: Tab,
    list_state: ListState,
    should_quit: bool,
}

impl App {
    fn new(graph: EcosystemGraph) -> Self {
        let mut list_state = ListState::default();
        list_state.select(Some(0));
        Self {
            graph,
            current_tab: Tab::Repos,
            list_state,
            should_quit: false,
        }
    }

    fn next_tab(&mut self) {
        self.current_tab = Tab::from_index(self.current_tab.index() + 1);
        self.list_state.select(Some(0));
    }

    fn prev_tab(&mut self) {
        self.current_tab = Tab::from_index(self.current_tab.index().wrapping_sub(1).min(3));
        self.list_state.select(Some(0));
    }

    fn next_item(&mut self) {
        let len = self.current_list_len();
        if len == 0 {
            return;
        }
        let i = match self.list_state.selected() {
            Some(i) => (i + 1) % len,
            None => 0,
        };
        self.list_state.select(Some(i));
    }

    fn prev_item(&mut self) {
        let len = self.current_list_len();
        if len == 0 {
            return;
        }
        let i = match self.list_state.selected() {
            Some(i) => (i + len - 1) % len,
            None => 0,
        };
        self.list_state.select(Some(i));
    }

    fn current_list_len(&self) -> usize {
        match self.current_tab {
            Tab::Repos => self.graph.store.repos.len(),
            Tab::Edges => self.graph.store.edges.len(),
            Tab::Groups => self.graph.store.groups.len(),
            Tab::Aspects => self.graph.aspects.annotations.len(),
        }
    }
}

/// Launch the interactive TUI viewer
pub fn run() -> Result<()> {
    let data_dir = get_data_dir()?;
    let graph = EcosystemGraph::load(&data_dir)
        .with_context(|| format!("Failed to load graph from {}", data_dir.display()))?;

    if graph.store.repos.is_empty() {
        println!("No repositories in graph. Run 'reposystem scan' first.");
        return Ok(());
    }

    // Setup terminal
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Create app and run
    let mut app = App::new(graph);
    let res = run_app(&mut terminal, &mut app);

    // Restore terminal
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture
    )?;
    terminal.show_cursor()?;

    if let Err(err) = res {
        eprintln!("Error: {err:?}");
    }

    Ok(())
}

fn run_app<B: ratatui::backend::Backend>(
    terminal: &mut Terminal<B>,
    app: &mut App,
) -> io::Result<()> {
    loop {
        terminal.draw(|f| ui(f, app))?;

        if let Event::Key(key) = event::read()? {
            if key.kind == KeyEventKind::Press {
                match key.code {
                    KeyCode::Char('q') | KeyCode::Esc => app.should_quit = true,
                    KeyCode::Tab | KeyCode::Right => app.next_tab(),
                    KeyCode::BackTab | KeyCode::Left => app.prev_tab(),
                    KeyCode::Down | KeyCode::Char('j') => app.next_item(),
                    KeyCode::Up | KeyCode::Char('k') => app.prev_item(),
                    _ => {}
                }
            }
        }

        if app.should_quit {
            return Ok(());
        }
    }
}

fn ui(f: &mut Frame, app: &App) {
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(3), // Tabs
            Constraint::Min(0),    // Content
            Constraint::Length(3), // Help
        ])
        .split(f.size());

    // Tabs
    let titles: Vec<Line> = Tab::titles()
        .iter()
        .map(|t| Line::from(Span::styled(*t, Style::default().fg(Color::White))))
        .collect();
    let tabs = Tabs::new(titles)
        .block(Block::default().borders(Borders::ALL).title("Reposystem"))
        .select(app.current_tab.index())
        .style(Style::default().fg(Color::White))
        .highlight_style(
            Style::default()
                .fg(Color::Yellow)
                .add_modifier(Modifier::BOLD),
        );
    f.render_widget(tabs, chunks[0]);

    // Content
    let content_chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(40), Constraint::Percentage(60)])
        .split(chunks[1]);

    render_list(f, app, content_chunks[0]);
    render_detail(f, app, content_chunks[1]);

    // Help
    let help = Paragraph::new(Line::from(vec![
        Span::styled("←/→", Style::default().fg(Color::Yellow)),
        Span::raw(" tabs  "),
        Span::styled("↑/↓", Style::default().fg(Color::Yellow)),
        Span::raw(" navigate  "),
        Span::styled("q", Style::default().fg(Color::Yellow)),
        Span::raw(" quit"),
    ]))
    .block(Block::default().borders(Borders::ALL));
    f.render_widget(help, chunks[2]);
}

fn render_list(f: &mut Frame, app: &App, area: Rect) {
    let items: Vec<ListItem> = match app.current_tab {
        Tab::Repos => app
            .graph
            .store
            .repos
            .iter()
            .map(|r| {
                ListItem::new(Line::from(vec![
                    Span::styled(&r.name, Style::default().fg(Color::Cyan)),
                ]))
            })
            .collect(),
        Tab::Edges => app
            .graph
            .store
            .edges
            .iter()
            .map(|e| {
                let from = app
                    .graph
                    .get_repo(&e.from)
                    .map(|r| r.name.as_str())
                    .unwrap_or(&e.from);
                let to = app
                    .graph
                    .get_repo(&e.to)
                    .map(|r| r.name.as_str())
                    .unwrap_or(&e.to);
                ListItem::new(Line::from(vec![
                    Span::styled(from, Style::default().fg(Color::Cyan)),
                    Span::raw(" → "),
                    Span::styled(to, Style::default().fg(Color::Green)),
                ]))
            })
            .collect(),
        Tab::Groups => app
            .graph
            .store
            .groups
            .iter()
            .map(|g| {
                ListItem::new(Line::from(vec![
                    Span::styled(&g.name, Style::default().fg(Color::Magenta)),
                    Span::raw(format!(" ({} members)", g.members.len())),
                ]))
            })
            .collect(),
        Tab::Aspects => app
            .graph
            .aspects
            .annotations
            .iter()
            .map(|a| {
                let target = if a.target.starts_with("repo:") {
                    app.graph
                        .get_repo(&a.target)
                        .map(|r| r.name.as_str())
                        .unwrap_or(&a.target)
                } else {
                    &a.target
                };
                let aspect = a.aspect_id.replace("aspect:", "");
                ListItem::new(Line::from(vec![
                    Span::styled(target, Style::default().fg(Color::Cyan)),
                    Span::raw(" - "),
                    Span::styled(aspect, Style::default().fg(Color::Yellow)),
                ]))
            })
            .collect(),
    };

    let title = match app.current_tab {
        Tab::Repos => format!("Repositories ({})", app.graph.store.repos.len()),
        Tab::Edges => format!("Edges ({})", app.graph.store.edges.len()),
        Tab::Groups => format!("Groups ({})", app.graph.store.groups.len()),
        Tab::Aspects => format!("Annotations ({})", app.graph.aspects.annotations.len()),
    };

    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL).title(title))
        .highlight_style(
            Style::default()
                .bg(Color::DarkGray)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("▶ ");

    f.render_stateful_widget(list, area, &mut app.list_state.clone());
}

fn render_detail(f: &mut Frame, app: &App, area: Rect) {
    let selected = app.list_state.selected().unwrap_or(0);

    let detail_text: Vec<Line> = match app.current_tab {
        Tab::Repos => {
            if let Some(repo) = app.graph.store.repos.get(selected) {
                vec![
                    Line::from(vec![
                        Span::styled("Name: ", Style::default().fg(Color::Yellow)),
                        Span::raw(&repo.name),
                    ]),
                    Line::from(vec![
                        Span::styled("ID: ", Style::default().fg(Color::Yellow)),
                        Span::raw(&repo.id),
                    ]),
                    Line::from(vec![
                        Span::styled("Forge: ", Style::default().fg(Color::Yellow)),
                        Span::raw(format!("{:?}", repo.forge)),
                    ]),
                    Line::from(vec![
                        Span::styled("Owner: ", Style::default().fg(Color::Yellow)),
                        Span::raw(&repo.owner),
                    ]),
                    Line::from(vec![
                        Span::styled("Branch: ", Style::default().fg(Color::Yellow)),
                        Span::raw(&repo.default_branch),
                    ]),
                    Line::from(vec![
                        Span::styled("Visibility: ", Style::default().fg(Color::Yellow)),
                        Span::raw(format!("{:?}", repo.visibility)),
                    ]),
                    Line::from(""),
                    Line::from(vec![
                        Span::styled("Tags: ", Style::default().fg(Color::Yellow)),
                        Span::raw(if repo.tags.is_empty() {
                            "(none)".to_string()
                        } else {
                            repo.tags.join(", ")
                        }),
                    ]),
                ]
            } else {
                vec![Line::from("No repository selected")]
            }
        }
        Tab::Edges => {
            if let Some(edge) = app.graph.store.edges.get(selected) {
                let from = app
                    .graph
                    .get_repo(&edge.from)
                    .map(|r| r.name.as_str())
                    .unwrap_or(&edge.from);
                let to = app
                    .graph
                    .get_repo(&edge.to)
                    .map(|r| r.name.as_str())
                    .unwrap_or(&edge.to);
                vec![
                    Line::from(vec![
                        Span::styled("From: ", Style::default().fg(Color::Yellow)),
                        Span::raw(from),
                    ]),
                    Line::from(vec![
                        Span::styled("To: ", Style::default().fg(Color::Yellow)),
                        Span::raw(to),
                    ]),
                    Line::from(vec![
                        Span::styled("Relation: ", Style::default().fg(Color::Yellow)),
                        Span::raw(format!("{:?}", edge.rel)),
                    ]),
                    Line::from(vec![
                        Span::styled("Channel: ", Style::default().fg(Color::Yellow)),
                        Span::raw(format!("{:?}", edge.channel)),
                    ]),
                    Line::from(vec![
                        Span::styled("Label: ", Style::default().fg(Color::Yellow)),
                        Span::raw(edge.label.as_deref().unwrap_or("(none)")),
                    ]),
                    Line::from(vec![
                        Span::styled("ID: ", Style::default().fg(Color::Yellow)),
                        Span::raw(&edge.id),
                    ]),
                ]
            } else {
                vec![Line::from("No edge selected")]
            }
        }
        Tab::Groups => {
            if let Some(group) = app.graph.store.groups.get(selected) {
                let mut lines = vec![
                    Line::from(vec![
                        Span::styled("Name: ", Style::default().fg(Color::Yellow)),
                        Span::raw(&group.name),
                    ]),
                    Line::from(vec![
                        Span::styled("ID: ", Style::default().fg(Color::Yellow)),
                        Span::raw(&group.id),
                    ]),
                    Line::from(""),
                    Line::from(vec![Span::styled(
                        format!("Members ({}):", group.members.len()),
                        Style::default().fg(Color::Yellow),
                    )]),
                ];
                for member in &group.members {
                    let name = app
                        .graph
                        .get_repo(member)
                        .map(|r| r.name.as_str())
                        .unwrap_or(member);
                    lines.push(Line::from(format!("  - {}", name)));
                }
                lines
            } else {
                vec![Line::from("No group selected")]
            }
        }
        Tab::Aspects => {
            if let Some(ann) = app.graph.aspects.annotations.get(selected) {
                let target = if ann.target.starts_with("repo:") {
                    app.graph
                        .get_repo(&ann.target)
                        .map(|r| r.name.as_str())
                        .unwrap_or(&ann.target)
                } else {
                    &ann.target
                };
                let aspect = app
                    .graph
                    .aspects
                    .aspects
                    .iter()
                    .find(|a| a.id == ann.aspect_id)
                    .map(|a| a.name.as_str())
                    .unwrap_or(&ann.aspect_id);
                vec![
                    Line::from(vec![
                        Span::styled("Target: ", Style::default().fg(Color::Yellow)),
                        Span::raw(target),
                    ]),
                    Line::from(vec![
                        Span::styled("Aspect: ", Style::default().fg(Color::Yellow)),
                        Span::raw(aspect),
                    ]),
                    Line::from(vec![
                        Span::styled("Weight: ", Style::default().fg(Color::Yellow)),
                        Span::raw(format!("{}/3", ann.weight)),
                    ]),
                    Line::from(vec![
                        Span::styled("Polarity: ", Style::default().fg(Color::Yellow)),
                        Span::raw(format!("{:?}", ann.polarity)),
                    ]),
                    Line::from(""),
                    Line::from(vec![
                        Span::styled("Reason: ", Style::default().fg(Color::Yellow)),
                        Span::raw(&ann.reason),
                    ]),
                ]
            } else {
                vec![Line::from("No annotation selected")]
            }
        }
    };

    let detail = Paragraph::new(detail_text)
        .block(Block::default().borders(Borders::ALL).title("Details"));
    f.render_widget(detail, area);
}

/// Get the data directory
fn get_data_dir() -> Result<PathBuf> {
    if let Ok(dir) = std::env::var("REPOSYSTEM_DATA_DIR") {
        return Ok(PathBuf::from(dir));
    }

    let data_dir = directories::ProjectDirs::from("org", "hyperpolymath", "reposystem")
        .map(|dirs| dirs.data_dir().to_path_buf())
        .unwrap_or_else(|| {
            std::env::current_dir()
                .unwrap_or_else(|_| PathBuf::from("."))
                .join(".reposystem")
        });

    Ok(data_dir)
}
