// SPDX-License-Identifier: MPL-2.0
// Owner: Jonathan D.A. Jewell <j.d.a.jewell@open.ac.uk>

pub fn render_daemon_setup(f: &mut ratatui::Frame, area: ratatui::layout::Rect, app: &mut crate::App) {
    use ratatui::widgets::{Block, Borders, List, ListItem, Paragraph};
    use ratatui::layout::{Constraint, Direction, Layout};
    use ratatui::text::{Line, Span};
    use ratatui::style::{Color, Modifier, Style};

    let chunks = Layout::default()
        .direction(Direction::Horizontal)
        .constraints([Constraint::Percentage(50), Constraint::Percentage(50)])
        .split(area);

    let items = vec![
        ListItem::new("[x] Daemon Autostart Enabled"),
        ListItem::new("[ ] Elevated Mode (sudo)"),
        ListItem::new("[ ] Notify on Updates"),
        ListItem::new("Update Mode: [ Check & Notify ]"),
        ListItem::new("Version Scope: [ Minor Only ]"),
        ListItem::new("Release Channel: [ Stable ]"),
        ListItem::new("-------------------------------"),
        ListItem::new("Specific Pins (Multi-version):"),
        ListItem::new("[ ] Java: Block [26]"),
        ListItem::new("[x] Java: Keep [8] AND [26]"),
        ListItem::new("[x] VSCode: [ Stable ]"),
        ListItem::new("[ ] VSCode: [ Alpha ]"),
    ];

    let list = List::new(items)
        .block(Block::default().borders(Borders::ALL).title(" Daemon Settings "))
        .highlight_style(Style::default().bg(Color::DarkGray).add_modifier(Modifier::BOLD))
        .highlight_symbol("> ");

    f.render_stateful_widget(list, chunks[0], &mut app.daemon_settings_state);

    let info_text = vec![
        Line::from("Daemon Details"),
        Line::from("--------------"),
        Line::from("The daemon runs silently in the background."),
        Line::from("Configure settings here. They are saved to:"),
        Line::from("~/.config/total-upgrade/daemon.toml"),
        Line::from(""),
        Line::from("Channels: Alpha, Beta, RC, LTS, Stable"),
        Line::from("Scopes: Major, Minor, Patch"),
        Line::from(""),
        Line::from(vec![Span::raw("Status: "), Span::styled("Configuring...", Style::default().fg(Color::Yellow))]),
    ];
    let p = Paragraph::new(info_text).block(Block::default().borders(Borders::ALL).title(" Info "));
    f.render_widget(p, chunks[1]);
}
