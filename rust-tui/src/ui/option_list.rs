//! Option list component

use ratatui::{
    prelude::*,
    widgets::{Block, BorderType, Borders, List, ListItem, ListState},
};

use crate::options::OPTIONS;
use crate::state::AppState;
use crate::theme::THEME;

/// Render the option list
pub fn render_option_list(frame: &mut Frame, area: Rect, state: &AppState) {
    let items: Vec<ListItem> = OPTIONS
        .iter()
        .map(|opt| {
            let is_installed = state.is_installed(opt.id);

            // Status indicator [OK] or [ ]
            let status = if is_installed {
                Span::styled("[OK]", Style::default().fg(THEME.green))
            } else {
                Span::styled("[ ]", Style::default().fg(THEME.overlay0))
            };

            // Option name (padded for alignment)
            let name = Span::styled(
                format!(" {:<22}", opt.name),
                Style::default().fg(THEME.text),
            );

            // Description
            let desc = Span::styled(opt.description, Style::default().fg(THEME.subtext0));

            // Reboot indicator
            let reboot = if opt.requires_reboot {
                Span::styled(" [reboot]", Style::default().fg(THEME.yellow))
            } else {
                Span::raw("")
            };

            let line = Line::from(vec![status, name, desc, reboot]);
            ListItem::new(line)
        })
        .collect();

    let list = List::new(items)
        .block(
            Block::default()
                .borders(Borders::ALL)
                .border_style(Style::default().fg(THEME.mauve))
                .border_type(BorderType::Rounded)
                .title(" Options ")
                .title_style(Style::default().fg(THEME.pink))
                .style(Style::default().bg(THEME.mantle)),
        )
        .highlight_style(
            Style::default()
                .bg(THEME.surface0)
                .add_modifier(Modifier::BOLD),
        )
        .highlight_symbol("> ");

    let mut list_state = ListState::default();
    list_state.select(Some(state.selected_index));

    frame.render_stateful_widget(list, area, &mut list_state);
}
