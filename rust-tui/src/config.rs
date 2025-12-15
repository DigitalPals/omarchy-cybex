//! State persistence for tracking installed options

use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use std::fs;
use std::path::PathBuf;

/// State file structure (compatible with Python TUI)
#[derive(Serialize, Deserialize, Default)]
struct InstallerState {
    installed: Vec<String>,
}

/// Get the path to the state file
fn state_file_path() -> PathBuf {
    dirs::config_dir()
        .unwrap_or_else(|| PathBuf::from("."))
        .join("omarchy-cybex")
        .join("installer-state.json")
}

/// Load installed option IDs from state file
pub fn load_installed() -> HashSet<String> {
    let path = state_file_path();
    if path.exists() {
        if let Ok(contents) = fs::read_to_string(&path) {
            if let Ok(state) = serde_json::from_str::<InstallerState>(&contents) {
                return state.installed.into_iter().collect();
            }
        }
    }
    HashSet::new()
}

/// Save installed option IDs to state file
pub fn save_installed(installed: &HashSet<String>) -> Result<(), std::io::Error> {
    let path = state_file_path();
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }

    let state = InstallerState {
        installed: installed.iter().cloned().collect(),
    };

    fs::write(path, serde_json::to_string_pretty(&state)?)?;
    Ok(())
}

/// Mark an option as installed
pub fn mark_installed(option_id: &str) {
    let mut installed = load_installed();
    installed.insert(option_id.to_string());
    let _ = save_installed(&installed);
}

/// Mark an option as uninstalled
pub fn mark_uninstalled(option_id: &str) {
    let mut installed = load_installed();
    installed.remove(option_id);
    let _ = save_installed(&installed);
}
