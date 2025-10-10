# Omarchy MyWay

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

A post-installation setup script for **Omarchy Linux** to fine-tune system settings and install personalized tools for John's workflow. This script is designed to be idempotent and safe to run multiple times.

## Features

This script automates the installation and configuration of:

- 📦 **System Packages** - Essential tools (npm, nano)
- 🤖 **Claude Code** - Anthropic's AI-powered coding assistant CLI
- 💻 **Codex CLI** - OpenAI's Codex command-line interface
- 🎨 **Custom Screensaver** - Personalized ASCII art screensaver
- 🚀 **Plymouth Theme** - Cybex boot splash theme
- ⭐ **Starship Prompt** - Modern, customized shell prompt
- ⌨️  **macOS-style Shortcuts** - keyd remaps + Alacritty bindings for Super+C/V/A/Z
- 🖥️  **Hyprland Bindings** - Custom application and window manager bindings
- 🔑 **SSH Key** - Generate and configure SSH key for GitHub
- 🐧 **Mainline Kernel** - Latest mainline Linux kernel (Chaotic-AUR)

## Prerequisites

- **Omarchy Linux** installation
- **sudo** privileges
- **Internet connection** (for downloading packages)
- At least **1GB free disk space** (for kernel installation)

## Quick Start

```bash
# Clone the repository
git clone https://github.com/DigitalPals/omarchy-myway.git
cd omarchy-myway

# Make the script executable
chmod +x install.sh

# Install everything (except mainline kernel)
./install.sh all

# Or install specific components
./install.sh claude ssh starship
```

## Usage

```bash
./install.sh [OPTION]...
```

### Available Options

| Option | Description | Alias |
|--------|-------------|-------|
| `all` | Install all components (except mainline kernel) | - |
| `packages` | Install system packages (npm, nano) | - |
| `claude` | Install Claude Code CLI | - |
| `codex` | Install OpenAI Codex CLI | - |
| `screensaver` | Configure custom screensaver | - |
| `plymouth` | Install Cybex Plymouth boot theme | - |
| `prompt` | Configure Starship prompt | `starship` |
| `macos-keys` | Configure keyd macOS-style shortcuts and Alacritty bindings | - |
| `hyprland` | Configure Hyprland bindings | `hyprland-bindings` |
| `ssh` | Generate SSH key for GitHub | `ssh-key` |
| `mainline` | Install and configure mainline kernel | - |

### Examples

```bash
# Show help and available options
./install.sh

# Install everything except mainline kernel
./install.sh all

# Install Claude Code and generate SSH key
./install.sh claude ssh

# Configure Starship prompt and install Codex
./install.sh prompt codex

# Configure macOS-style shortcuts (keyd + Alacritty)
./install.sh macos-keys

# Install multiple specific components
./install.sh packages claude codex ssh

# Install mainline kernel only
./install.sh mainline
```

## Component Details

### System Packages
Installs essential development tools:
- **npm** - Node.js package manager
- **nano** - Text editor

### Claude Code
Installs Anthropic's Claude Code CLI globally to `~/.local/bin`. Automatically adds the directory to your PATH if needed.

### Codex CLI
Installs OpenAI's Codex command-line interface for AI-assisted coding.

### Custom Screensaver
Deploys a personalized ASCII art screensaver to `~/.config/omarchy/branding/screensaver.txt`.

### Plymouth Theme (Cybex)
Installs the Cybex boot splash theme and rebuilds the initramfs. **Requires reboot** to take effect.

### Starship Prompt
Configures a modern, informative shell prompt with:
- Git status indicators
- Language version detection (Node.js, Python, Java, PHP)
- Directory path display
- Custom styling

### macOS-style Shortcuts
Installs and configures keyd plus updated Alacritty bindings so `SUPER+C/V/A/Z` behave like macOS while all Hyprland shortcuts keep working.

### Hyprland Bindings
Deploys custom Hyprland key bindings to `~/.config/hypr/bindings.conf`. Includes application shortcuts (terminal, browser, file manager) and window management keybindings.

### SSH Key
Generates an ED25519 SSH key pair and configures ssh-agent for automatic key loading. Provides instructions for adding the key to GitHub.

### Mainline Kernel
Installs the latest mainline Linux kernel from Chaotic-AUR. Automatically configures the bootloader to use the new kernel. **Requires reboot** to use the new kernel.

## Important Notes

- ✅ **Idempotent** - Safe to run multiple times without causing issues
- 🔒 **No root required** - Do not run with sudo; the script will request privileges when needed
- 🌐 **Internet required** - Most components require downloading packages
- 🔄 **Reboot needed** - Mainline kernel and Plymouth theme require a reboot
- 📁 **PATH updates** - After installing Claude/Codex, run `source ~/.bashrc` or restart your shell

## macOS-style Shortcuts (keyd)

Get global macOS-style shortcuts (`SUPER+C/V/A/Z`) while keeping Hyprland bindings such as `SUPER+ENTER`:

```bash
./install.sh macos-keys
```

This target:
- Installs `keyd` if necessary and deploys `keyd/macos_shortcuts.conf` to `/etc/keyd/default.conf`
- Enables and reloads the `keyd` service so the remap is active immediately
- Installs the curated `alacritty/alacritty.toml`, backing up your existing file the first time so Alacritty maps `CTRL+Insert`/`Shift+Insert` to copy/paste

After the script finishes:
- Reload Hyprland (`hyprctl reload`) and relaunch Alacritty to pick up the new bindings.
- Test `SUPER+C/V/A/Z` in Chromium or another GUI app, and in Alacritty to confirm copy/paste works without sending SIGINT.
- Use `sudo keyd -m` if you want to inspect the translated key events in real time.

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

- **Permission denied**: Ensure the script is executable with `chmod +x install.sh`
- **Command not found**: After installing CLI tools, restart your shell or run `source ~/.bashrc`
- **Boot issues**: If the mainline kernel causes problems, select the default kernel from the boot menu

## Author

**John** - Customized for personal Omarchy Linux installations

## License

This is a personal configuration repository. Feel free to fork and adapt to your needs.

---

**Omarchy Linux** - https://omarchy.org
