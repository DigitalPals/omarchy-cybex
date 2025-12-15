//! UI components for the TUI

mod footer;
mod header;
mod layout;
mod option_list;
mod output_panel;
mod popup;
mod status_bar;

pub use footer::render_footer;
pub use header::render_header;
pub use layout::render_layout;
pub use option_list::render_option_list;
pub use output_panel::render_output_panel;
pub use popup::render_popup;
pub use status_bar::render_status_bar;
