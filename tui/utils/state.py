"""Track installation state between runs"""

import json
from pathlib import Path
from typing import Dict, Set

STATE_FILE = Path.home() / ".config" / "omarchy-cybex" / "installer-state.json"


def load_state() -> Dict:
    """Load installation state from file"""
    if STATE_FILE.exists():
        try:
            return json.loads(STATE_FILE.read_text())
        except (json.JSONDecodeError, IOError):
            return {"installed": []}
    return {"installed": []}


def save_state(state: Dict) -> None:
    """Save installation state to file"""
    STATE_FILE.parent.mkdir(parents=True, exist_ok=True)
    STATE_FILE.write_text(json.dumps(state, indent=2))


def mark_installed(option_id: str) -> None:
    """Mark an option as installed"""
    state = load_state()
    if option_id not in state.get("installed", []):
        state.setdefault("installed", []).append(option_id)
        save_state(state)


def mark_uninstalled(option_id: str) -> None:
    """Mark an option as uninstalled"""
    state = load_state()
    if option_id in state.get("installed", []):
        state["installed"].remove(option_id)
        save_state(state)


def get_installed() -> Set[str]:
    """Get set of installed option IDs"""
    return set(load_state().get("installed", []))


def clear_state() -> None:
    """Clear all installation state"""
    if STATE_FILE.exists():
        STATE_FILE.unlink()
