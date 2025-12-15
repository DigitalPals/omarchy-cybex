"""Installation options with metadata extracted from README.md"""

from dataclasses import dataclass, field
from typing import Optional, List


@dataclass
class InstallOption:
    """Represents a single installation option"""
    id: str
    name: str
    description: str
    category: str
    requires_reboot: bool = False
    excluded_from_all: bool = False
    aliases: List[str] = field(default_factory=list)


# All available installation options
OPTIONS: List[InstallOption] = [
    InstallOption(
        id="claude",
        name="Claude Code",
        description="Anthropic's AI coding assistant CLI",
        category="AI Tools"
    ),
    InstallOption(
        id="codex",
        name="Codex CLI",
        description="OpenAI's Codex command-line interface",
        category="AI Tools"
    ),
    InstallOption(
        id="screensaver",
        name="Custom Screensaver",
        description="Personalized ASCII art screensaver",
        category="Customization"
    ),
    InstallOption(
        id="plymouth",
        name="Plymouth Theme",
        description="Cybex boot splash theme",
        category="System",
        requires_reboot=True
    ),
    InstallOption(
        id="fish",
        name="Fish Shell",
        description="Modern shell with Starship prompt",
        category="Shell"
    ),
    InstallOption(
        id="hyprland",
        name="Hyprland Bindings",
        description="Custom key bindings and input config",
        category="Desktop",
        aliases=["hyprland-bindings"]
    ),
    InstallOption(
        id="waycorner",
        name="Hot Corners",
        description="macOS-style hot corners for Hyprland",
        category="Desktop"
    ),
    InstallOption(
        id="waybar",
        name="Waybar Idle Toggle",
        description="Click to toggle idle lock indicator",
        category="Desktop"
    ),
    InstallOption(
        id="ssh",
        name="SSH Key",
        description="Generate SSH key for GitHub",
        category="Security",
        aliases=["ssh-key"]
    ),
    InstallOption(
        id="passwordless-sudo",
        name="Passwordless Sudo",
        description="Enable passwordless sudo for user",
        category="Security",
        excluded_from_all=True
    ),
    InstallOption(
        id="brave",
        name="Brave Browser",
        description="Privacy-focused browser as default",
        category="Applications"
    ),
    InstallOption(
        id="mainline",
        name="Mainline Kernel",
        description="Latest mainline Linux kernel",
        category="System",
        requires_reboot=True,
        excluded_from_all=True
    ),
    InstallOption(
        id="noctalia",
        name="Noctalia Shell",
        description="Modern desktop shell (replaces Waybar)",
        category="Desktop",
        aliases=["noctalia-shell"]
    ),
    InstallOption(
        id="looknfeel",
        name="Animations",
        description="Improved Hyprland window animations",
        category="Customization"
    ),
]

# Category display order
CATEGORIES: List[str] = [
    "System",
    "AI Tools",
    "Shell",
    "Desktop",
    "Applications",
    "Security",
    "Customization"
]


def get_option_by_id(option_id: str) -> Optional[InstallOption]:
    """Get an option by its ID"""
    for opt in OPTIONS:
        if opt.id == option_id:
            return opt
    return None


def get_options_for_all() -> List[InstallOption]:
    """Get options that are included in 'all' selection"""
    return [opt for opt in OPTIONS if not opt.excluded_from_all]
