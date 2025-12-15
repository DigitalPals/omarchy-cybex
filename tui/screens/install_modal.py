"""Installation output modal dialog"""

from typing import List
from textual.screen import ModalScreen
from textual.widgets import Static, Button, RichLog
from textual.containers import Vertical, Horizontal
from textual import work
from textual.app import ComposeResult

from ..utils.installer import run_installation, build_command


class InstallModal(ModalScreen[bool]):
    """Modal dialog showing installation output in real-time"""

    BINDINGS = [
        ("escape", "cancel", "Cancel"),
    ]

    def __init__(
        self,
        script_dir: str,
        options: List[str],
        uninstall: bool = False,
    ) -> None:
        super().__init__()
        self.script_dir = script_dir
        self.options = options
        self.uninstall = uninstall
        self.success = False
        self.completed = False
        self.process_task = None

    def compose(self) -> ComposeResult:
        """Compose the modal layout"""
        action = "Uninstalling" if self.uninstall else "Installing"
        options_text = ", ".join(self.options)

        yield Vertical(
            Static(
                f"[bold magenta]{action}:[/bold magenta] [cyan]{options_text}[/cyan]",
                id="modal-header"
            ),
            RichLog(id="output-log", highlight=True, markup=True),
            Horizontal(
                Button("Close", id="close-btn", variant="primary", disabled=True),
                id="modal-footer"
            ),
            id="modal-container"
        )

    def on_mount(self) -> None:
        """Start installation when modal is mounted"""
        self.run_installation_task()

    @work(exclusive=True)
    async def run_installation_task(self) -> None:
        """Run the installation in background"""
        log = self.query_one("#output-log", RichLog)
        close_btn = self.query_one("#close-btn", Button)

        # Show command being run
        cmd = build_command(self.script_dir, self.options, self.uninstall)
        log.write(f"[dim cyan]$ {' '.join(cmd)}[/dim cyan]\n\n")

        def output_handler(line: str) -> None:
            """Handle output lines from the subprocess"""
            # Convert ANSI escape codes to Rich markup where needed
            # Most ANSI codes work directly, but we can enhance some
            line = self._convert_ansi_to_rich(line)
            log.write(line)

        try:
            exit_code = await run_installation(
                self.script_dir,
                self.options,
                self.uninstall,
                output_handler
            )

            self.success = exit_code == 0
            self.completed = True

            if self.success:
                log.write("\n[bold green]Installation completed successfully![/bold green]\n")
            else:
                log.write(f"\n[bold red]Installation failed (exit code: {exit_code})[/bold red]\n")

        except Exception as e:
            self.success = False
            self.completed = True
            log.write(f"\n[bold red]Error: {e}[/bold red]\n")

        # Enable close button
        close_btn.disabled = False
        close_btn.focus()

    def _convert_ansi_to_rich(self, text: str) -> str:
        """Convert common ANSI codes to Rich markup for better display"""
        # Most ANSI codes pass through, but we can enhance visibility
        # The bash script uses these codes:
        # RED='\033[0;31m', GREEN='\033[0;32m', YELLOW='\033[1;33m'
        # BLUE='\033[0;34m', MAGENTA='\033[0;35m', CYAN='\033[0;36m'
        # BOLD='\033[1m', NC='\033[0m'
        # Rich's RichLog handles these natively, so just return as-is
        return text

    def on_button_pressed(self, event: Button.Pressed) -> None:
        """Handle button press"""
        if event.button.id == "close-btn":
            self.dismiss(self.success)

    def action_cancel(self) -> None:
        """Handle escape key - only allow if completed"""
        if self.completed:
            self.dismiss(self.success)
        # If not completed, ignore escape (can't cancel mid-install easily)
