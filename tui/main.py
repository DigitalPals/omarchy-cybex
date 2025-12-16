#!/usr/bin/env python3
"""Omarchy Cybex TUI Installer - Main Entry Point"""

import sys
from pathlib import Path

from textual.app import App

from .screens.main_screen import MainScreen


class OmarchyInstaller(App):
    """Omarchy Cybex TUI Installer Application"""

    TITLE = "Omarchy Cybex Installer"
    CSS_PATH = "styles/omarchy.tcss"

    def __init__(self, script_dir: str) -> None:
        super().__init__()
        self.script_dir = script_dir

    def on_mount(self) -> None:
        """Mount the main screen on app start"""
        self.push_screen(MainScreen(self.script_dir))


def main() -> None:
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: python main.py <script_dir>")
        print("This is typically invoked by ./install")
        sys.exit(1)

    script_dir = sys.argv[1]

    # Verify script directory exists
    if not Path(script_dir).is_dir():
        print(f"Error: Script directory not found: {script_dir}")
        sys.exit(1)

    # Verify install script exists
    install_script = Path(script_dir) / "install"
    if not install_script.is_file():
        print(f"Error: install not found in {script_dir}")
        sys.exit(1)

    # Run the TUI
    app = OmarchyInstaller(script_dir)
    app.run()


if __name__ == "__main__":
    main()
