//! Main application with event loop

use std::io::Stdout;
use std::path::PathBuf;
use std::sync::mpsc::{self, Receiver, TryRecvError};
use std::time::Duration;

use color_eyre::Result;
use crossterm::event::{self, Event, KeyCode, KeyEvent, KeyModifiers};
use ratatui::prelude::*;

use crate::config::{mark_installed, mark_uninstalled};
use crate::installer::{run_install_command, InstallerEvent};
use crate::options::OPTIONS;
use crate::state::{ActionChoice, AppMode, AppState};
use crate::ui::render_layout;

/// Main application
pub struct App {
    /// Application state
    state: AppState,
    /// Path to the script directory containing install
    script_dir: PathBuf,
    /// Channel receiver for installer events
    installer_rx: Option<Receiver<InstallerEvent>>,
}

impl App {
    /// Create a new App
    pub fn new(state: AppState, script_dir: PathBuf) -> Self {
        Self {
            state,
            script_dir,
            installer_rx: None,
        }
    }

    /// Run the application event loop
    pub fn run(&mut self, terminal: &mut Terminal<CrosstermBackend<Stdout>>) -> Result<()> {
        loop {
            // Render UI
            terminal.draw(|frame| render_layout(frame, &self.state))?;

            // Handle installer events
            self.handle_installer_events();

            // Handle keyboard events with timeout
            if event::poll(Duration::from_millis(50))? {
                if let Event::Key(key) = event::read()? {
                    self.handle_key_event(key);
                }
            }

            // Check if we should quit
            if self.state.should_quit {
                break;
            }
        }

        Ok(())
    }

    /// Handle keyboard events
    fn handle_key_event(&mut self, key: KeyEvent) {
        // Ctrl+C always quits
        if key.modifiers.contains(KeyModifiers::CONTROL) && key.code == KeyCode::Char('c') {
            self.state.should_quit = true;
            return;
        }

        match self.state.mode {
            AppMode::Normal => self.handle_normal_mode_key(key),
            AppMode::ConfirmAction => self.handle_popup_key(key),
            AppMode::Installing => {
                // Ignore keys during installation (except Ctrl+C handled above)
            }
            AppMode::Completed => self.handle_completed_mode_key(key),
        }
    }

    /// Handle keys in normal mode
    fn handle_normal_mode_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Char('q') => {
                self.state.should_quit = true;
            }
            KeyCode::Up | KeyCode::Char('k') => {
                self.state.move_up(OPTIONS.len());
                self.update_status_for_selection();
            }
            KeyCode::Down | KeyCode::Char('j') => {
                self.state.move_down(OPTIONS.len());
                self.update_status_for_selection();
            }
            KeyCode::Enter => {
                self.trigger_action();
            }
            KeyCode::Esc => {
                // Clear output panel
                self.state.clear_output();
                self.state.show_output = false;
            }
            _ => {}
        }
    }

    /// Handle keys in completed mode - now same as normal but returns to normal immediately
    fn handle_completed_mode_key(&mut self, key: KeyEvent) {
        // Completed mode now behaves like normal mode - focus stays on option list
        self.handle_normal_mode_key(key);
    }

    /// Handle keys in popup mode
    fn handle_popup_key(&mut self, key: KeyEvent) {
        match key.code {
            KeyCode::Up | KeyCode::Char('k') => {
                self.state.popup_choice = ActionChoice::Reinstall;
            }
            KeyCode::Down | KeyCode::Char('j') => {
                self.state.popup_choice = ActionChoice::Uninstall;
            }
            KeyCode::Enter => {
                let uninstall = self.state.popup_choice == ActionChoice::Uninstall;
                self.state.mode = AppMode::Normal;
                self.run_action(uninstall);
            }
            KeyCode::Esc => {
                self.state.mode = AppMode::Normal;
                self.update_status_for_selection();
            }
            _ => {}
        }
    }

    /// Trigger install or uninstall for the selected option
    fn trigger_action(&mut self) {
        if self.state.selected_index >= OPTIONS.len() {
            return;
        }

        let option = &OPTIONS[self.state.selected_index];
        let is_installed = self.state.is_installed(option.id);

        if is_installed {
            // Show popup to choose action
            self.state.popup_choice = ActionChoice::Reinstall;
            self.state.mode = AppMode::ConfirmAction;
            self.state.status_message = format!("{} is installed - choose action", option.name);
        } else {
            // Directly install
            self.run_action(false);
        }
    }

    /// Run the install/uninstall action
    fn run_action(&mut self, uninstall: bool) {
        if self.state.selected_index >= OPTIONS.len() {
            return;
        }

        let option = &OPTIONS[self.state.selected_index];

        // Set up the action
        let action = if uninstall {
            format!("Uninstalling {}", option.name)
        } else {
            format!("Installing {}", option.name)
        };

        self.state.clear_output();
        self.state.current_action = Some(action.clone());
        self.state.status_message = action;
        self.state.mode = AppMode::Installing;
        self.state.show_output = true;
        self.state.is_uninstalling = uninstall;

        // Create channel for installer events
        let (tx, rx) = mpsc::channel();
        self.installer_rx = Some(rx);

        // Start the installer in a background thread
        run_install_command(&self.script_dir, option.id, uninstall, tx);
    }

    /// Handle events from the installer subprocess
    fn handle_installer_events(&mut self) {
        if let Some(rx) = &self.installer_rx {
            loop {
                match rx.try_recv() {
                    Ok(event) => match event {
                        InstallerEvent::OutputLine(line) => {
                            self.state.add_output_line(line);
                            // Auto-scroll to bottom
                            let lines = self.state.output_lines.len();
                            if lines > 20 {
                                self.state.output_scroll = lines - 20;
                            }
                        }
                        InstallerEvent::Completed(exit_code) => {
                            self.state.last_exit_code = Some(exit_code);
                            self.state.mode = AppMode::Normal;

                            // Update installed state based on the action we performed
                            if let Some(option) = OPTIONS.get(self.state.selected_index) {
                                if exit_code == 0 {
                                    if self.state.is_uninstalling {
                                        // Uninstall succeeded
                                        mark_uninstalled(option.id);
                                        self.state.installed.remove(option.id);
                                        self.state.status_message =
                                            format!("Uninstalled {} - Press Enter on another option", option.name);
                                    } else {
                                        // Install/update succeeded - mark as installed
                                        mark_installed(option.id);
                                        self.state.installed.insert(option.id.to_string());
                                        self.state.status_message =
                                            format!("Installed {} - Press Enter on another option", option.name);
                                    }
                                } else {
                                    self.state.status_message = format!(
                                        "Failed with exit code {} - Esc to close output",
                                        exit_code
                                    );
                                }
                            }

                            self.installer_rx = None;
                            break;
                        }
                        InstallerEvent::Error(err) => {
                            self.state.add_output_line(format!("Error: {}", err));
                            self.state.last_exit_code = Some(-1);
                            self.state.mode = AppMode::Normal;
                            self.state.status_message = "Error occurred - Esc to close output".to_string();
                            self.installer_rx = None;
                            break;
                        }
                    },
                    Err(TryRecvError::Empty) => break,
                    Err(TryRecvError::Disconnected) => {
                        self.installer_rx = None;
                        break;
                    }
                }
            }
        }
    }

    /// Update status bar based on current selection
    fn update_status_for_selection(&mut self) {
        if let Some(option) = OPTIONS.get(self.state.selected_index) {
            let action = if self.state.is_installed(option.id) {
                "uninstall"
            } else {
                "install"
            };
            self.state.status_message = format!(
                "Press Enter to {} {}",
                action, option.name
            );
        }
    }
}
