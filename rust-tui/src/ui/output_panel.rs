//! Output panel component for showing installation output

use ratatui::{
    prelude::*,
    widgets::{Block, BorderType, Borders, Paragraph, Scrollbar, ScrollbarOrientation, ScrollbarState},
};

use crate::state::{AppMode, AppState};
use crate::theme::THEME;

/// Render the output panel
pub fn render_output_panel(frame: &mut Frame, area: Rect, state: &AppState) {
    // Panel title based on mode
    let title = match &state.current_action {
        Some(action) => format!(" {} ", action),
        None => " Output ".to_string(),
    };

    // Status indicator in title
    let title_style = match state.mode {
        AppMode::Installing => Style::default().fg(THEME.yellow),
        AppMode::Completed => {
            if state.last_exit_code == Some(0) {
                Style::default().fg(THEME.green)
            } else {
                Style::default().fg(THEME.red)
            }
        }
        _ => Style::default().fg(THEME.pink),
    };

    // Calculate visible area (account for borders)
    let inner_height = area.height.saturating_sub(2) as usize;

    // Create paragraph from output lines
    let visible_lines: Vec<Line> = state
        .output_lines
        .iter()
        .skip(state.output_scroll)
        .take(inner_height)
        .map(|line| {
            // Strip ANSI codes for display (ratatui doesn't handle them)
            let clean_line = strip_ansi_codes(line);
            Line::from(Span::styled(clean_line, Style::default().fg(THEME.text)))
        })
        .collect();

    let paragraph = Paragraph::new(visible_lines).block(
        Block::default()
            .borders(Borders::ALL)
            .border_style(Style::default().fg(THEME.mauve))
            .border_type(BorderType::Rounded)
            .title(title)
            .title_style(title_style)
            .style(Style::default().bg(THEME.crust)),
    );

    frame.render_widget(paragraph, area);

    // Render scrollbar if needed
    if state.output_lines.len() > inner_height {
        let scrollbar = Scrollbar::new(ScrollbarOrientation::VerticalRight)
            .begin_symbol(Some("▲"))
            .end_symbol(Some("▼"))
            .track_symbol(Some("│"))
            .thumb_symbol("█");

        let mut scrollbar_state = ScrollbarState::new(state.output_lines.len())
            .position(state.output_scroll);

        // Render scrollbar in the right border area
        let scrollbar_area = Rect {
            x: area.x + area.width - 1,
            y: area.y + 1,
            width: 1,
            height: area.height.saturating_sub(2),
        };

        frame.render_stateful_widget(scrollbar, scrollbar_area, &mut scrollbar_state);
    }
}

/// Strip ANSI escape codes from a string
fn strip_ansi_codes(s: &str) -> String {
    let mut result = String::new();
    let mut in_escape = false;

    for c in s.chars() {
        if in_escape {
            if c.is_ascii_alphabetic() {
                in_escape = false;
            }
        } else if c == '\x1b' {
            in_escape = true;
        } else {
            result.push(c);
        }
    }

    result
}
