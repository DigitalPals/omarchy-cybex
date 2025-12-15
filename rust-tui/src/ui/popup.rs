//! Action confirmation popup

use ratatui::{
    prelude::*,
    widgets::{Block, BorderType, Borders, Clear, Paragraph},
};

use crate::options::OPTIONS;
use crate::state::{ActionChoice, AppState};
use crate::theme::THEME;

/// Render the action confirmation popup
pub fn render_popup(frame: &mut Frame, state: &AppState) {
    let option_name = OPTIONS
        .get(state.selected_index)
        .map(|o| o.name)
        .unwrap_or("Unknown");

    // Calculate popup size and position (centered)
    let popup_width = 40;
    let popup_height = 7;
    let area = frame.area();
    let popup_area = Rect {
        x: area.width.saturating_sub(popup_width) / 2,
        y: area.height.saturating_sub(popup_height) / 2,
        width: popup_width.min(area.width),
        height: popup_height.min(area.height),
    };

    // Clear the area behind the popup
    frame.render_widget(Clear, popup_area);

    // Render popup background
    let block = Block::default()
        .borders(Borders::ALL)
        .border_type(BorderType::Rounded)
        .border_style(Style::default().fg(THEME.mauve))
        .title(format!(" {} ", option_name))
        .title_style(Style::default().fg(THEME.pink).add_modifier(Modifier::BOLD))
        .style(Style::default().bg(THEME.base));

    frame.render_widget(block, popup_area);

    // Render options inside the popup
    let inner_area = Rect {
        x: popup_area.x + 2,
        y: popup_area.y + 2,
        width: popup_area.width.saturating_sub(4),
        height: popup_area.height.saturating_sub(3),
    };

    // Reinstall option
    let reinstall_style = if state.popup_choice == ActionChoice::Reinstall {
        Style::default().fg(THEME.green).add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(THEME.text)
    };
    let reinstall_prefix = if state.popup_choice == ActionChoice::Reinstall {
        "> "
    } else {
        "  "
    };

    // Uninstall option
    let uninstall_style = if state.popup_choice == ActionChoice::Uninstall {
        Style::default().fg(THEME.red).add_modifier(Modifier::BOLD)
    } else {
        Style::default().fg(THEME.text)
    };
    let uninstall_prefix = if state.popup_choice == ActionChoice::Uninstall {
        "> "
    } else {
        "  "
    };

    let lines = vec![
        Line::from(Span::styled(
            format!("{}Install / Update", reinstall_prefix),
            reinstall_style,
        )),
        Line::from(Span::styled(
            format!("{}Uninstall", uninstall_prefix),
            uninstall_style,
        )),
        Line::default(),
        Line::from(Span::styled(
            "↑/↓: Select  Enter: Confirm  Esc: Cancel",
            Style::default().fg(THEME.overlay0),
        )),
    ];

    let paragraph = Paragraph::new(lines);
    frame.render_widget(paragraph, inner_area);
}
