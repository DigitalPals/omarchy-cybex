//! Main layout composition

use ratatui::prelude::*;

use super::{render_footer, render_header, render_option_list, render_output_panel, render_popup, render_status_bar};
use crate::state::{AppMode, AppState};
use crate::theme::THEME;

/// Render the main layout
pub fn render_layout(frame: &mut Frame, state: &AppState) {
    // Clear with base background
    frame.render_widget(
        ratatui::widgets::Block::default().style(Style::default().bg(THEME.base)),
        frame.area(),
    );

    // Main vertical layout
    let chunks = Layout::default()
        .direction(Direction::Vertical)
        .constraints([
            Constraint::Length(9),  // Header banner
            Constraint::Min(10),    // Main content area
            Constraint::Length(1),  // Status bar
            Constraint::Length(1),  // Footer
        ])
        .split(frame.area());

    // Render header banner
    render_header(frame, chunks[0]);

    // Main content: option list, or split with output panel
    if state.show_output || state.mode == AppMode::Installing {
        // Split horizontally: list on left, output on right
        let content_chunks = Layout::default()
            .direction(Direction::Horizontal)
            .constraints([
                Constraint::Percentage(40),
                Constraint::Percentage(60),
            ])
            .split(chunks[1]);

        render_option_list(frame, content_chunks[0], state);
        render_output_panel(frame, content_chunks[1], state);
    } else {
        // Full width option list
        render_option_list(frame, chunks[1], state);
    }

    // Status bar
    render_status_bar(frame, chunks[2], state);

    // Footer with key bindings
    render_footer(frame, chunks[3], state);

    // Render popup overlay if in confirm action mode
    if state.mode == AppMode::ConfirmAction {
        render_popup(frame, state);
    }
}
