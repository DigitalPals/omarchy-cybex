//! Header banner component

use ratatui::{
    prelude::*,
    widgets::{Block, Paragraph},
};

use crate::theme::THEME;

/// ASCII art logo
const ASCII_ART: &str = r#"                     $$a.
                      `$$$
 .a&$$$&a, a$$a..a$$a. `$$bd$$$&a,    .a&$""$&a     .a$$a..a$$a.
d#7^' `^^' `Q$$bd$$$^   1$#7^' `^Q$, d#7@Qbd@'' d$   Q$$$$$$$$P
Y$b,. .,,.    Q$$$$'   .$$$b.. .,d7' Q$&a,..,a&$P'  .d$$$PQ$$$b
 `@Q$$$P@'    d$$$'    `^@Q$$$$$@"'   `^@Q$$$P@^'   @Q$P@  @Q$P@
              @$$P"#;

const TITLE: &str = "                      C Y B E X   I N S T A L L E R";

/// Render the header banner
pub fn render_header(frame: &mut Frame, area: Rect) {
    let logo_lines: Vec<Line> = ASCII_ART
        .lines()
        .map(|line| Line::from(Span::styled(line, Style::default().fg(THEME.mauve))))
        .collect();

    let title_line = Line::from(Span::styled(
        TITLE,
        Style::default().fg(THEME.pink).add_modifier(Modifier::BOLD),
    ));

    let mut lines = logo_lines;
    lines.push(Line::default()); // Empty line
    lines.push(title_line);

    let paragraph = Paragraph::new(lines)
        .block(Block::default())
        .style(Style::default().bg(THEME.mantle));

    frame.render_widget(paragraph, area);
}
