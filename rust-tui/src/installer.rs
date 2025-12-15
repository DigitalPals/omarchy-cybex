//! Subprocess execution for install.sh

use std::io::{BufRead, BufReader};
use std::path::Path;
use std::process::{Command, Stdio};
use std::sync::mpsc::Sender;
use std::thread;

/// Events sent from the installer subprocess
#[derive(Debug, Clone)]
pub enum InstallerEvent {
    /// A line of output from the subprocess
    OutputLine(String),
    /// The process completed with an exit code
    Completed(i32),
    /// An error occurred
    Error(String),
}

/// Run an install/uninstall command asynchronously
///
/// Spawns the subprocess and streams output via the provided sender.
pub fn run_install_command(
    script_dir: &Path,
    option_id: &str,
    uninstall: bool,
    event_tx: Sender<InstallerEvent>,
) {
    let install_script = script_dir.join("install");
    let script_dir = script_dir.to_path_buf();
    let option_id = option_id.to_string();

    thread::spawn(move || {
        let mut cmd = Command::new(&install_script);
        cmd.current_dir(&script_dir);

        if uninstall {
            cmd.arg("uninstall");
        }
        cmd.arg(&option_id);

        // Capture stdout and stderr
        cmd.stdout(Stdio::piped());
        cmd.stderr(Stdio::piped());

        match cmd.spawn() {
            Ok(mut child) => {
                // Stream stdout
                if let Some(stdout) = child.stdout.take() {
                    let tx = event_tx.clone();
                    let reader = BufReader::new(stdout);
                    thread::spawn(move || {
                        for line in reader.lines().map_while(Result::ok) {
                            let _ = tx.send(InstallerEvent::OutputLine(line));
                        }
                    });
                }

                // Stream stderr
                if let Some(stderr) = child.stderr.take() {
                    let tx = event_tx.clone();
                    let reader = BufReader::new(stderr);
                    thread::spawn(move || {
                        for line in reader.lines().map_while(Result::ok) {
                            let _ = tx.send(InstallerEvent::OutputLine(line));
                        }
                    });
                }

                // Wait for completion
                match child.wait() {
                    Ok(status) => {
                        let exit_code = status.code().unwrap_or(-1);
                        let _ = event_tx.send(InstallerEvent::Completed(exit_code));
                    }
                    Err(e) => {
                        let _ = event_tx.send(InstallerEvent::Error(format!(
                            "Failed to wait for process: {}",
                            e
                        )));
                    }
                }
            }
            Err(e) => {
                let _ = event_tx.send(InstallerEvent::Error(format!(
                    "Failed to spawn install.sh: {}",
                    e
                )));
            }
        }
    });
}
