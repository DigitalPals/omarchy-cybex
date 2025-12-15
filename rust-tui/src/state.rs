//! Application state management

use std::collections::HashSet;

/// Application mode
#[derive(Debug, Clone, PartialEq)]
pub enum AppMode {
    /// Normal mode - browsing options
    Normal,
    /// Showing action popup for installed item
    ConfirmAction,
    /// Installing/uninstalling - running subprocess
    Installing,
    /// Completed - showing results
    Completed,
}

/// Action choice in the confirmation popup
#[derive(Debug, Clone, Copy, PartialEq)]
pub enum ActionChoice {
    Reinstall,
    Uninstall,
}

/// Main application state
#[derive(Debug)]
pub struct AppState {
    /// Current UI mode
    pub mode: AppMode,
    /// Currently selected option index
    pub selected_index: usize,
    /// Set of installed option IDs
    pub installed: HashSet<String>,
    /// Scroll offset for output panel
    pub output_scroll: usize,
    /// Output lines from installation
    pub output_lines: Vec<String>,
    /// Current action description (e.g., "Installing Claude Code")
    pub current_action: Option<String>,
    /// Last subprocess exit code
    pub last_exit_code: Option<i32>,
    /// Flag to quit the application
    pub should_quit: bool,
    /// Status message for the status bar
    pub status_message: String,
    /// Whether to show output panel
    pub show_output: bool,
    /// Selected action in confirmation popup
    pub popup_choice: ActionChoice,
    /// Whether current action is an uninstall (used for completion handling)
    pub is_uninstalling: bool,
}

impl AppState {
    /// Create a new AppState with the given installed options
    pub fn new(installed: HashSet<String>) -> Self {
        Self {
            mode: AppMode::Normal,
            selected_index: 0,
            installed,
            output_scroll: 0,
            output_lines: Vec::new(),
            current_action: None,
            last_exit_code: None,
            should_quit: false,
            status_message: "Ready - Press Enter to install/uninstall".into(),
            show_output: false,
            popup_choice: ActionChoice::Reinstall,
            is_uninstalling: false,
        }
    }

    /// Move selection up (with wrap-around)
    pub fn move_up(&mut self, total_options: usize) {
        if total_options == 0 {
            return;
        }
        if self.selected_index > 0 {
            self.selected_index -= 1;
        } else {
            self.selected_index = total_options - 1;
        }
    }

    /// Move selection down (with wrap-around)
    pub fn move_down(&mut self, total_options: usize) {
        if total_options == 0 {
            return;
        }
        if self.selected_index < total_options - 1 {
            self.selected_index += 1;
        } else {
            self.selected_index = 0;
        }
    }

    /// Check if an option is installed
    pub fn is_installed(&self, option_id: &str) -> bool {
        self.installed.contains(option_id)
    }

    /// Clear output and reset for new operation
    pub fn clear_output(&mut self) {
        self.output_lines.clear();
        self.output_scroll = 0;
        self.last_exit_code = None;
    }

    /// Add an output line
    pub fn add_output_line(&mut self, line: String) {
        self.output_lines.push(line);
    }

    /// Scroll output up
    pub fn scroll_output_up(&mut self) {
        if self.output_scroll > 0 {
            self.output_scroll -= 1;
        }
    }

    /// Scroll output down
    pub fn scroll_output_down(&mut self, visible_lines: usize) {
        let max_scroll = self.output_lines.len().saturating_sub(visible_lines);
        if self.output_scroll < max_scroll {
            self.output_scroll += 1;
        }
    }
}
