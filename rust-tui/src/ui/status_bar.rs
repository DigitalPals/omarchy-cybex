//! Status bar component

use ratatui::{
    prelude::*,
    widgets::Paragraph,
};

use crate::state::AppState;
use crate::theme::THEME;

/// Render the status bar
pub fn render_status_bar(frame: &mut Frame, area: Rect, state: &AppState) {
    let style = Style::default().fg(THEME.yellow).bg(THEME.mantle);

    let paragraph = Paragraph::new(state.status_message.as_str()).style(style);

    frame.render_widget(paragraph, area);
}
