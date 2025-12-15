//! Footer component with key bindings

use ratatui::{
    prelude::*,
    widgets::Paragraph,
};

use crate::state::{AppMode, AppState};
use crate::theme::THEME;

/// Render the footer with key bindings
pub fn render_footer(frame: &mut Frame, area: Rect, state: &AppState) {
    let keys = match state.mode {
        AppMode::Installing => vec![
            ("", "Installing..."),
        ],
        AppMode::ConfirmAction => vec![
            ("↑/↓", "Select"),
            ("Enter", "Confirm"),
            ("Esc", "Cancel"),
        ],
        AppMode::Normal | AppMode::Completed => {
            if state.show_output {
                vec![
                    ("q", "Quit"),
                    ("↑/↓", "Navigate"),
                    ("Enter", "Install/Uninstall"),
                    ("Esc", "Hide Output"),
                ]
            } else {
                vec![
                    ("q", "Quit"),
                    ("↑/↓", "Navigate"),
                    ("Enter", "Install/Uninstall"),
                ]
            }
        }
    };

    let spans: Vec<Span> = keys
        .iter()
        .enumerate()
        .flat_map(|(i, (key, desc))| {
            let mut spans = vec![];
            if i > 0 {
                spans.push(Span::styled(" │ ", Style::default().fg(THEME.overlay0)));
            }
            if !key.is_empty() {
                spans.push(Span::styled(*key, Style::default().fg(THEME.mauve)));
                spans.push(Span::styled(": ", Style::default().fg(THEME.overlay0)));
            }
            spans.push(Span::styled(*desc, Style::default().fg(THEME.text)));
            spans
        })
        .collect();

    let paragraph = Paragraph::new(Line::from(spans))
        .style(Style::default().bg(THEME.mantle))
        .alignment(Alignment::Center);

    frame.render_widget(paragraph, area);
}
