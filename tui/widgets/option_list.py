"""Option list widget with selectable items"""

from typing import List, Set
from textual.widgets import Static, ListView, ListItem
from textual.reactive import reactive
from textual.message import Message
from textual.containers import Horizontal

from ..data.options import InstallOption, OPTIONS


class OptionItem(ListItem):
    """A single installation option with checkbox and status"""

    class Selected(Message):
        """Message sent when selection changes"""
        def __init__(self, option_id: str, selected: bool) -> None:
            self.option_id = option_id
            self.selected = selected
            super().__init__()

    selected: reactive[bool] = reactive(False)
    status: reactive[str] = reactive("pending")  # pending, installing, installed, failed

    def __init__(self, option: InstallOption, is_installed: bool = False) -> None:
        super().__init__(classes="option-item")
        self.option = option
        self._is_installed = is_installed

    def compose(self):
        """Compose the option item layout"""
        yield Horizontal(
            Static(self._checkbox_text(), classes="checkbox"),
            Static(f"{self.option.name:<18}", classes="option-name"),
            Static(self.option.description, classes="option-desc"),
            Static(self._status_text(), classes=f"status --{self.status}"),
        )

    def _checkbox_text(self) -> str:
        """Get checkbox display text"""
        if self.selected:
            return "[green][x][/green]"
        return "[cyan][ ][/cyan]"

    def _status_text(self) -> str:
        """Get status indicator text"""
        if self.status == "installed" or self._is_installed:
            return "[green]OK[/green]"
        elif self.status == "installing":
            return "[yellow]...[/yellow]"
        elif self.status == "failed":
            return "[red]FAIL[/red]"
        return ""

    def watch_selected(self, selected: bool) -> None:
        """Update display when selection changes"""
        if not self.is_mounted:
            return
        try:
            checkbox = self.query_one(".checkbox", Static)
            checkbox.update(self._checkbox_text())
            if selected:
                self.add_class("--highlight")
            else:
                self.remove_class("--highlight")
        except Exception:
            pass  # Widget not ready yet

    def watch_status(self, status: str) -> None:
        """Update display when status changes"""
        if not self.is_mounted:
            return
        try:
            status_widget = self.query_one(".status", Static)
            status_widget.update(self._status_text())
            # Update status class
            status_widget.remove_class("--pending", "--installing", "--installed", "--failed")
            status_widget.add_class(f"--{status}")
        except Exception:
            pass  # Widget not ready yet

    def toggle_selection(self) -> None:
        """Toggle the selection state"""
        self.selected = not self.selected
        self.post_message(self.Selected(self.option.id, self.selected))

    def set_installed(self, installed: bool) -> None:
        """Mark as installed"""
        self._is_installed = installed
        if installed:
            self.status = "installed"
        else:
            self.status = "pending"


class OptionList(ListView):
    """List of installation options"""

    def __init__(self, installed: Set[str] = None) -> None:
        super().__init__(id="option-list")
        self.installed = installed or set()
        self._options_map: dict[str, OptionItem] = {}

    def compose(self):
        """Compose the option list"""
        for option in OPTIONS:
            is_installed = option.id in self.installed
            item = OptionItem(option, is_installed)
            self._options_map[option.id] = item
            yield item

    def get_selected_options(self) -> List[str]:
        """Get list of selected option IDs"""
        return [
            opt_id for opt_id, item in self._options_map.items()
            if item.selected
        ]

    def select_all(self, exclude_special: bool = True) -> None:
        """Select all options, optionally excluding special ones"""
        for opt_id, item in self._options_map.items():
            if exclude_special and item.option.excluded_from_all:
                continue
            if not item.selected:
                item.toggle_selection()

    def deselect_all(self) -> None:
        """Deselect all options"""
        for item in self._options_map.values():
            if item.selected:
                item.toggle_selection()

    def set_option_status(self, option_id: str, status: str) -> None:
        """Set status for a specific option"""
        if option_id in self._options_map:
            self._options_map[option_id].status = status

    def mark_option_installed(self, option_id: str) -> None:
        """Mark an option as installed"""
        if option_id in self._options_map:
            self._options_map[option_id].set_installed(True)
            self._options_map[option_id].selected = False

    def mark_option_uninstalled(self, option_id: str) -> None:
        """Mark an option as uninstalled"""
        if option_id in self._options_map:
            self._options_map[option_id].set_installed(False)

    def on_list_item_selected(self, event: ListView.Selected) -> None:
        """Handle item selection via Enter key"""
        if isinstance(event.item, OptionItem):
            event.item.toggle_selection()
