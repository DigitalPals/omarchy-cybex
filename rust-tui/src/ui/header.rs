//! Header banner component

use ratatui::{
    prelude::*,
    widgets::{Block, Paragraph},
};

use crate::theme::THEME;

/// ASCII art logo - all lines padded to same width for proper centering
const ASCII_ART: [&str; 7] = [
    "                     $$a.                                          ",
    "                      `$$$                                         ",
    " .a&$$$&a, a$$a..a$$a. `$$bd$$$&a,    .a&$\"\"$&a     .a$$a..a$$a. ",
    "d#7^' `^^' `Q$$bd$$$^   1$#7^' `^Q$, d#7@Qbd@'' d$   Q$$$$$$$$P  ",
    "Y$b,. .,,.    Q$$$$'   .$$$b.. .,d7' Q$&a,..,a&$P'  .d$$$PQ$$$b  ",
    " `@Q$$$P@'    d$$$'    `^@Q$$$$$@\"'   `^@Q$$$P@^'   @Q$P@  @Q$P@ ",
    "             @$$P                                                  ",
];

/// Render the header banner
pub fn render_header(frame: &mut Frame, area: Rect) {
    let lines: Vec<Line> = ASCII_ART
        .iter()
        .map(|line| Line::from(Span::styled(*line, Style::default().fg(THEME.mauve))))
        .collect();

    let paragraph = Paragraph::new(lines)
        .block(Block::default())
        .style(Style::default().bg(THEME.mantle))
        .alignment(Alignment::Center);

    frame.render_widget(paragraph, area);
}
