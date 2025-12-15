# Omarchy Cybex

```
                     $$a.
                      `$$$
 .a&$$$&a, a$$a..a$$a. `$$bd$$$&a,    .a&$""$&a     .a$$a..a$$a.
d#7^' `^^' `Q$$bd$$$^   1$#7^' `^Q$, d#7@Qbd@'' d$   Q$$$$$$$$P
Y$b,. .,,.    Q$$$$'   .$$$b.. .,d7' Q$&a,..,a&$P'  .d$$$PQ$$$b
 `@Q$$$P@'    d$$$'    `^@Q$$$$$@"'   `^@Q$$$P@^'   @Q$P@  @Q$P@
             @$$P
```

## About

A post-installation setup script for **Omarchy Linux** (optimized for version 3.2+) to fine-tune system settings and install personalized tools for John's workflow. This script is designed to be idempotent and safe to run multiple times.

## Features

This script automates the installation and configuration of:

- 🤖 **Claude Code** - Anthropic's AI-powered coding assistant CLI
- 💻 **Codex CLI** - OpenAI's Codex command-line interface
- 🎨 **Custom Screensaver** - Personalized ASCII art screensaver
- 🚀 **Plymouth Theme** - Cybex boot splash theme
- 🐟 **Fish Shell** - Modern shell with Starship prompt, autosuggestions, and syntax highlighting (via omarchy-fish)
- 🖥️  **Hyprland Bindings** - Custom application and window manager bindings
- 🪟 **Auto-Tile Helper** - Automatically float first window per workspace, tile when second opens
- 🖱️  **Hot Corners** - macOS-style hot corners for Hyprland via waycorner
- 💤 **Waybar Idle Toggle** - Click to toggle idle lock on/off with visual indicator
- 🔑 **SSH Key** - Generate and configure SSH key for GitHub
- 🔓 **Passwordless Sudo** - Enable passwordless sudo for the current user
- 🌐 **Brave Browser** - Privacy-focused web browser set as system default
- 🐧 **Mainline Kernel** - Latest mainline Linux kernel (Chaotic-AUR)
- 🌙 **Noctalia Shell** - Modern desktop shell replacing Waybar (Quickshell-based)
- ✨ **Look'n'Feel** - Improved Hyprland animations (window slides, workspace transitions)

## Prerequisites

- **Omarchy Linux 3.2+** installation
- **sudo** privileges
- **Internet connection** (for downloading packages)
- At least **1GB free disk space** (for kernel installation)

> **Note:** Omarchy 3.2 includes several features by default that were previously provided by this script:
> - **Ghostty** is now the default terminal (with native splits and tabs support)
> - **JetBrainsMono Nerd Font** is now the default font
> - **macOS-style keyboard shortcuts** are built-in

## Quick Start

```bash
# Clone the repository
git clone https://github.com/DigitalPals/omarchy-cybex.git
cd omarchy-cybex

# Make the script executable
chmod +x install

# Launch the TUI installer
./install

# Or install specific components via CLI
./install claude ssh fish
```

## Usage

```bash
./install              # Launch interactive TUI
./install [OPTION]...  # CLI mode
```

### Available Options

| Option | Description | Alias |
|--------|-------------|-------|
| `all` | Install all components (except mainline kernel) | - |
| `claude` | Install Claude Code CLI | - |
| `codex` | Install OpenAI Codex CLI | - |
| `screensaver` | Configure custom screensaver | - |
| `plymouth` | Install Cybex Plymouth boot theme | - |
| `fish` | Install Fish shell with Starship prompt (via omarchy-fish) | - |
| `hyprland` | Configure Hyprland bindings | `hyprland-bindings` |
| `waycorner` | Install and configure hot corners for Hyprland | - |
| `waybar` | Configure Waybar idle toggle indicator | - |
| `ssh` | Generate SSH key for GitHub | `ssh-key` |
| `passwordless-sudo` | Enable passwordless sudo for current user | - |
| `brave` | Install Brave browser and set as default | - |
| `mainline` | Install and configure mainline kernel | - |
| `noctalia` | Install Noctalia Shell (replaces Waybar) | `noctalia-shell` |
| `looknfeel` | Install improved Hyprland animations | - |

### Examples

```bash
# Launch interactive TUI installer
./install

# Show help and available options
./install --help

# Install everything except mainline kernel
./install all

# Install Claude Code and generate SSH key
./install claude ssh

# Install Fish shell and Codex CLI
./install fish codex

# Install multiple specific components
./install claude codex ssh brave

# Install mainline kernel only
./install mainline
```

## Component Details

### Claude Code
Installs Anthropic's Claude Code CLI using the official installer (`curl -fsSL https://claude.ai/install.sh | bash`). The installer automatically updates your `~/.bashrc` with the necessary PATH configuration and reloads it.

### Codex CLI
Installs OpenAI's Codex command-line interface for AI-assisted coding.

### Custom Screensaver
Deploys a personalized ASCII art screensaver to `~/.config/omarchy/branding/screensaver.txt`.

### Plymouth Theme (Cybex)
Installs the Cybex boot splash theme and rebuilds the initramfs. **Requires reboot** to take effect.

### Fish Shell
Installs the Fish shell via the omarchy-fish package with:
- **Native Fish features**: Autosuggestions, syntax highlighting, and smart completions
- **Starship prompt**: Beautiful, informative prompt with git status, language versions, and custom styling
- **fzf integration**: Fast fuzzy finding with keybindings (Ctrl+R for history, Ctrl+Alt+F for directories)
- **Smart navigation**: zoxide for intelligent directory jumping, eza for enhanced file listing
- **Omarchy compatibility**: Maintains bash as login shell for system compatibility while auto-launching Fish in terminals

The configuration preserves your existing Starship prompt settings and adds Fish-specific enhancements.

### Hyprland Bindings
Deploys custom Hyprland key bindings to `~/.config/hypr/bindings.conf`. Includes application shortcuts (terminal, browser, file manager) and window management keybindings.

### Auto-Tile Helper
Installs a background helper script that provides intelligent window management for Hyprland:
- **First window** on any workspace - Automatically floats and centers at 60% screen size
- **Second window opens** - Both windows automatically switch to tiled mode
- **Window closes** - Remaining single window returns to floating/centered

Dependencies (`jq`, `socat`) are installed automatically. The helper starts immediately and is added to Hyprland autostart for persistence across reboots.

### Waycorner (Hot Corners)
Installs waycorner via cargo and configures macOS-style hot corners for Hyprland:
- **Top Right Corner** - Lock screen
- **Bottom Left Corner** - Start screensaver

Automatically adds waycorner to Hyprland autostart. Move your mouse to the corners to trigger actions!

### Waybar Idle Toggle
Adds a clickable toggle icon to Waybar that controls the idle lock (hypridle):
- **Toggle ON** (full brightness) - Idle lock disabled, computer stays active
- **Toggle OFF** (dimmed) - Computer will idle and lock when inactive
- Click the icon to toggle between states
- Updates every 3 seconds to reflect current status
- Automatically adapts to all Omarchy themes (uses theme foreground color with opacity)
- Non-destructive installation: Preserves your existing Waybar configuration

The icon appears in the upper right modules of Waybar. Installation creates backups of your config files before making any changes.

### SSH Key
Generates an ED25519 SSH key pair and configures ssh-agent for automatic key loading. Provides instructions for adding the key to GitHub.

### Passwordless Sudo
Enables passwordless sudo for the current user by creating `/etc/sudoers.d/<username>`. This allows running sudo commands without entering a password.

**Security Note:** This option is not included in `all` and must be explicitly requested. Only enable on trusted single-user systems.

### Brave Browser
Installs the Brave web browser from the AUR (brave-bin package) and sets it as the system default browser by adding `BROWSER=brave` to `~/.config/uwsm/default`. Brave is a privacy-focused browser with built-in ad blocking and tracking protection.

### Mainline Kernel
Installs the latest mainline Linux kernel from Chaotic-AUR. Automatically configures the bootloader to use the new kernel. **Requires reboot** to use the new kernel.

### Noctalia Shell
Replaces the default Omarchy desktop components (Waybar, Mako, SwayOSD, swaybg) with [Noctalia Shell](https://github.com/noctalia/noctalia-shell), a modern unified desktop shell built on Quickshell.

**Features:**
- Unified bar, notifications, OSD, and wallpaper management
- Modern design with smooth animations
- Lower resource usage than running separate daemons

**Installation:**
```bash
./install noctalia
```

The installer automatically:
- Installs the `noctalia-shell` package from AUR
- Disables conflicting Omarchy services (waybar, mako, swayosd, swaybg)
- Configures Hyprland autostart for Noctalia
- Adds compatible keybindings for volume/brightness controls
- Starts Noctalia Shell immediately

**Reverting to Waybar:**
```bash
./install uninstall noctalia
```

This restores the original Omarchy desktop components and removes Noctalia configuration.

**Note:** After Omarchy system updates, you may need to re-run `./install noctalia` to ensure proper configuration.

### Look'n'Feel (Hyprland Animations)
Replaces the default Omarchy Hyprland animations with more expressive ones. Deploys custom animation settings to `~/.config/hypr/looknfeel.conf`.

**Features:**
- **Window animations**: Windows slide in/out with subtle overshoot effect
- **Workspace transitions**: Smooth slide animation when switching workspaces
- **Border animation**: Rotating gradient border effect
- **Layer animations**: Menus and notifications slide in/out smoothly
- Custom bezier curves for natural-feeling motion

**Installation:**
```bash
./install looknfeel
```

**Reverting:**
```bash
./install uninstall looknfeel
```

## Important Notes

- ✅ **Idempotent** - Safe to run multiple times without causing issues
- 🔒 **No root required** - Do not run with sudo; the script will request privileges when needed
- 🌐 **Internet required** - Most components require downloading packages
- 🔄 **Reboot needed** - Mainline kernel and Plymouth theme require a reboot
- 📁 **PATH updates** - After installing Claude/Codex, run `source ~/.bashrc` or restart your shell

## Post-Installation

After running the script:

1. **Update PATH** (if Claude or Codex was installed):
   ```bash
   source ~/.bashrc
   ```

2. **Add SSH key to GitHub** (if SSH key was generated):
   - Copy the displayed public key
   - Go to https://github.com/settings/ssh/new
   - Paste and save

3. **Reboot** (if mainline kernel or Plymouth theme was installed):
   ```bash
   sudo reboot
   ```

## Troubleshooting

- **Permission denied**: Ensure the script is executable with `chmod +x install`
- **Command not found**: After installing CLI tools, restart your shell or run `source ~/.bashrc`
- **Boot issues**: If the mainline kernel causes problems, select the default kernel from the boot menu

## Author

**John** - Customized for personal Omarchy Linux installations

## License

This is a personal configuration repository. Feel free to fork and adapt to your needs.

---

**Omarchy Linux** - https://omarchy.org
