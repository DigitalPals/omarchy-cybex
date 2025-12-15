//! Omarchy Cybex TUI Installer
//!
//! A terminal user interface for installing Omarchy Cybex customizations.

mod app;
mod config;
mod installer;
mod options;
mod state;
mod theme;
mod ui;

use std::env;
use std::io::stdout;
use std::path::PathBuf;

use color_eyre::Result;
use crossterm::{
    execute,
    terminal::{disable_raw_mode, enable_raw_mode, EnterAlternateScreen, LeaveAlternateScreen},
};
use ratatui::prelude::*;

use app::App;
use config::load_installed;
use state::AppState;

fn main() -> Result<()> {
    // Install color-eyre panic handler
    color_eyre::install()?;

    // Get script directory from args or use current directory
    let script_dir = env::args()
        .nth(1)
        .map(PathBuf::from)
        .unwrap_or_else(|| env::current_dir().expect("Failed to get current directory"));

    // Verify install.sh exists
    let install_script = script_dir.join("install.sh");
    if !install_script.exists() {
        eprintln!("Error: install.sh not found in {:?}", script_dir);
        eprintln!("Usage: {} [script_dir]", env::args().next().unwrap_or_default());
        std::process::exit(1);
    }

    // Load installed state
    let installed = load_installed();
    let state = AppState::new(installed);

    // Initialize terminal
    enable_raw_mode()?;
    let mut stdout = stdout();
    execute!(stdout, EnterAlternateScreen)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;

    // Clear terminal and hide cursor
    terminal.clear()?;

    // Create and run app
    let mut app = App::new(state, script_dir);
    let result = app.run(&mut terminal);

    // Restore terminal
    disable_raw_mode()?;
    execute!(terminal.backend_mut(), LeaveAlternateScreen)?;
    terminal.show_cursor()?;

    result
}
