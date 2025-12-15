"""Main installation screen with option list"""

from textual.screen import Screen
from textual.widgets import Static, Footer
from textual.containers import Vertical, Container
from textual.app import ComposeResult
from textual.binding import Binding

from ..widgets.header_banner import HeaderBanner
from ..widgets.option_list import OptionList, OptionItem
from ..utils.state import get_installed, mark_installed, mark_uninstalled
from .install_modal import InstallModal


class MainScreen(Screen):
    """Main screen with installation options"""

    BINDINGS = [
        Binding("q", "quit", "Quit"),
        Binding("i", "install", "Install"),
        Binding("u", "uninstall", "Uninstall"),
        Binding("a", "select_all", "Select All"),
        Binding("d", "deselect_all", "Deselect All"),
        Binding("space", "toggle", "Toggle", show=False),
        Binding("enter", "toggle", "Toggle", show=False),
    ]

    def __init__(self, script_dir: str) -> None:
        super().__init__()
        self.script_dir = script_dir

    def compose(self) -> ComposeResult:
        """Compose the main screen layout"""
        installed = get_installed()

        yield HeaderBanner()
        yield Container(
            OptionList(installed),
            id="option-container"
        )
        yield Static(
            "[cyan]Ready[/cyan] - Select options to install",
            id="status-bar"
        )
        yield Footer()

    def action_quit(self) -> None:
        """Quit the application"""
        self.app.exit()

    def action_toggle(self) -> None:
        """Toggle current selection"""
        option_list = self.query_one(OptionList)
        if option_list.highlighted_child:
            item = option_list.highlighted_child
            if isinstance(item, OptionItem):
                item.toggle_selection()

    def action_select_all(self) -> None:
        """Select all options (except special ones)"""
        option_list = self.query_one(OptionList)
        option_list.select_all(exclude_special=True)
        self._update_status()

    def action_deselect_all(self) -> None:
        """Deselect all options"""
        option_list = self.query_one(OptionList)
        option_list.deselect_all()
        self._update_status()

    def action_install(self) -> None:
        """Install selected options"""
        option_list = self.query_one(OptionList)
        selected = option_list.get_selected_options()

        if not selected:
            self._set_status("[yellow]No options selected[/yellow]")
            return

        self._set_status(f"[cyan]Installing {len(selected)} option(s)...[/cyan]")

        # Show installation modal
        def on_complete(success: bool) -> None:
            if success:
                # Mark options as installed
                for opt_id in selected:
                    mark_installed(opt_id)
                    option_list.mark_option_installed(opt_id)
                self._set_status(f"[green]Installed {len(selected)} option(s)[/green]")
            else:
                self._set_status("[red]Installation failed[/red]")

        self.app.push_screen(
            InstallModal(self.script_dir, selected, uninstall=False),
            on_complete
        )

    def action_uninstall(self) -> None:
        """Uninstall selected options"""
        option_list = self.query_one(OptionList)
        selected = option_list.get_selected_options()

        if not selected:
            self._set_status("[yellow]No options selected[/yellow]")
            return

        self._set_status(f"[cyan]Uninstalling {len(selected)} option(s)...[/cyan]")

        # Show uninstall modal
        def on_complete(success: bool) -> None:
            if success:
                # Mark options as uninstalled
                for opt_id in selected:
                    mark_uninstalled(opt_id)
                    option_list.mark_option_uninstalled(opt_id)
                self._set_status(f"[green]Uninstalled {len(selected)} option(s)[/green]")
            else:
                self._set_status("[red]Uninstall failed[/red]")

        self.app.push_screen(
            InstallModal(self.script_dir, selected, uninstall=True),
            on_complete
        )

    def on_option_item_selected(self, message: OptionItem.Selected) -> None:
        """Handle option selection changes"""
        self._update_status()

    def _update_status(self) -> None:
        """Update status bar with selection count"""
        option_list = self.query_one(OptionList)
        selected = option_list.get_selected_options()
        if selected:
            self._set_status(f"[cyan]{len(selected)} option(s) selected[/cyan]")
        else:
            self._set_status("[cyan]Ready[/cyan] - Select options to install")

    def _set_status(self, text: str) -> None:
        """Set status bar text"""
        status = self.query_one("#status-bar", Static)
        status.update(text)
