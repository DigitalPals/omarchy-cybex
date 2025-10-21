#!/bin/bash

################################################################################
# Omarchy Linux Post-Installation Setup Script
# https://omarchy.org
#
# This script sets up personal preferences after a fresh Omarchy installation.
# It is designed to be idempotent - safe to run multiple times.
#
# Usage:
#   ./install.sh                - Show help and available options
#   ./install.sh all            - Install everything except mainline kernel
#   ./install.sh claude ssh     - Install specific components
#   ./install.sh mainline       - Install mainline kernel only
#
# Run without arguments to see all available options.
################################################################################

set -e  # Exit on error

# Trap handler for cleanup on failure
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        echo -e "\n${RED}✗${NC} Installation failed with exit code $exit_code"
        echo -e "${YELLOW}Some changes may have been made. Please review and potentially rollback manually.${NC}"
    fi
}
trap cleanup EXIT

# Color codes for pretty output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

################################################################################
# Helper Functions
################################################################################

print_header() {
    echo -e "\n${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${MAGENTA}  $1${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_step() {
    echo -e "${BLUE}▶${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_skip() {
    echo -e "${YELLOW}⊙${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

package_installed() {
    pacman -Q "$1" >/dev/null 2>&1
}

# Create a timestamped backup of a file
create_backup() {
    local file="$1"
    if [ -f "$file" ]; then
        local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
        cp "$file" "$backup"
        echo "$backup"
        return 0
    fi
    return 1
}

# Remove lines added by this script from a file
remove_script_lines() {
    local file="$1"
    local marker="$2"  # Comment marker to identify our additions (e.g., "Added by Omarchy")

    if [ ! -f "$file" ]; then
        return 0
    fi

    # Create temp file without our additions
    local temp_file=$(mktemp)
    local skip_next_non_empty=false

    while IFS= read -r line; do
        # If we found the marker in the previous iteration, skip non-empty lines
        if [ "$skip_next_non_empty" = true ]; then
            if [ -n "$line" ]; then
                # Skip this non-empty line (the actual command/export)
                skip_next_non_empty=false
                continue
            else
                # Skip empty lines between marker and command
                continue
            fi
        fi

        # Check if this line contains our marker
        if echo "$line" | grep -q "$marker"; then
            # Skip the marker line and set flag to skip next non-empty line
            skip_next_non_empty=true
            continue
        fi

        # Keep this line
        echo "$line" >> "$temp_file"
    done < "$file"

    # Replace original with cleaned version
    mv "$temp_file" "$file"
}

show_usage() {
    echo -e "${BOLD}${CYAN}Omarchy Linux Post-Installation Setup Script${NC}"
    echo -e "${CYAN}https://omarchy.org${NC}"
    echo ""
    echo -e "${BOLD}USAGE:${NC}"
    echo -e "  $0 [OPTION]..."
    echo -e "  $0 uninstall [OPTION]..."
    echo ""
    echo -e "${BOLD}DESCRIPTION:${NC}"
    echo -e "  Configure and install various components for your Omarchy Linux system."
    echo -e "  This script is idempotent - safe to run multiple times."
    echo ""
    echo -e "${BOLD}OPTIONS:${NC}"
    echo -e "  ${GREEN}all${NC}              Install all components (except mainline kernel)"
    echo -e "  ${GREEN}packages${NC}         Install system packages (npm, nano)"
    echo -e "  ${GREEN}claude${NC}           Install Claude Code CLI"
    echo -e "  ${GREEN}codex${NC}            Install OpenAI Codex CLI"
    echo -e "  ${GREEN}screensaver${NC}      Configure custom screensaver"
    echo -e "  ${GREEN}plymouth${NC}         Install Cybex Plymouth boot theme"
    echo -e "  ${GREEN}prompt${NC}           Configure Starship prompt, Fish-like tab completion, and autosuggestions (alias: starship)"
    echo -e "  ${GREEN}macos-keys${NC}       Configure macOS-style shortcuts (keyd + Alacritty)"
    echo -e "  ${GREEN}hyprland${NC}         Configure Hyprland bindings (alias: hyprland-bindings)"
    echo -e "  ${GREEN}auto-tile${NC}        Install Hyprland auto-tiling helper"
    echo -e "  ${GREEN}waycorner${NC}        Install and configure hot corners for Hyprland"
    echo -e "  ${GREEN}waybar${NC}           Configure Waybar idle toggle indicator"
    echo -e "  ${GREEN}ssh${NC}              Generate SSH key for GitHub (alias: ssh-key)"
    echo -e "  ${GREEN}mainline${NC}         Install and configure mainline kernel (Chaotic-AUR)"
    echo ""
    echo -e "${BOLD}UNINSTALL:${NC}"
    echo -e "  ${YELLOW}uninstall${NC} all              Remove all installed components"
    echo -e "  ${YELLOW}uninstall${NC} [option]         Remove specific component (e.g., auto-tile)"
    echo ""
    echo -e "${BOLD}EXAMPLES:${NC}"
    echo -e "  $0 all                    # Install everything except mainline kernel"
    echo -e "  $0 claude ssh             # Install Claude Code and generate SSH key"
    echo -e "  $0 mainline               # Only configure mainline kernel"
    echo -e "  $0 prompt codex           # Configure Starship prompt and install Codex CLI"
    echo -e "  $0 uninstall auto-tile    # Remove auto-tile helper"
    echo -e "  $0 uninstall all          # Remove all installed components"
    echo ""
    echo -e "${BOLD}NOTES:${NC}"
    echo -e "  • Multiple options can be combined in a single command"
    echo -e "  • The script will request sudo privileges when needed"
    echo -e "  • Some components require a reboot to take effect (kernel, Plymouth theme)"
    echo -e "  • Uninstall creates backups and restores original configurations when possible"
    echo -e "  • SSH keys cannot be uninstalled for safety reasons"
    echo -e "  • Run without arguments to show this help message"
    echo ""
}

################################################################################
# Command Line Arguments
################################################################################

# Initialize mode and flags
UNINSTALL_MODE=false
INSTALL_ALL=false
INSTALL_PACKAGES=false
INSTALL_CLAUDE=false
INSTALL_CODEX=false
INSTALL_SCREENSAVER=false
INSTALL_PLYMOUTH=false
INSTALL_PROMPT=false
INSTALL_MACOS_KEYS=false
INSTALL_HYPRLAND_BINDINGS=false
INSTALL_AUTO_TILE=false
INSTALL_WAYCORNER=false
INSTALL_WAYBAR=false
INSTALL_SSH=false
INSTALL_MAINLINE=false

# Show help if no arguments provided
if [ $# -eq 0 ]; then
    show_usage
    exit 0
fi

# Check if first argument is "uninstall"
if [ "$1" = "uninstall" ]; then
    UNINSTALL_MODE=true
    shift  # Remove "uninstall" from arguments

    # Show help if no uninstall target specified
    if [ $# -eq 0 ]; then
        print_error "Please specify what to uninstall (e.g., 'uninstall all' or 'uninstall auto-tile')"
        echo ""
        show_usage
        exit 1
    fi
fi

# Parse all command line arguments
for arg in "$@"; do
    case "$arg" in
        all)
            INSTALL_ALL=true
            ;;
        packages)
            INSTALL_PACKAGES=true
            ;;
        claude)
            INSTALL_CLAUDE=true
            ;;
        codex)
            INSTALL_CODEX=true
            ;;
        screensaver)
            INSTALL_SCREENSAVER=true
            ;;
        plymouth)
            INSTALL_PLYMOUTH=true
            ;;
        prompt|starship)
            INSTALL_PROMPT=true
            ;;
        macos-keys)
            INSTALL_MACOS_KEYS=true
            ;;
        hyprland|hyprland-bindings)
            INSTALL_HYPRLAND_BINDINGS=true
            ;;
        auto-tile)
            INSTALL_AUTO_TILE=true
            ;;
        waycorner)
            INSTALL_WAYCORNER=true
            ;;
        waybar)
            INSTALL_WAYBAR=true
            ;;
        ssh|ssh-key)
            if [ "$UNINSTALL_MODE" = true ]; then
                print_error "SSH keys cannot be uninstalled for safety reasons"
                exit 1
            fi
            INSTALL_SSH=true
            ;;
        mainline)
            INSTALL_MAINLINE=true
            ;;
        *)
            print_error "Unknown parameter: $arg"
            echo ""
            show_usage
            exit 1
            ;;
    esac
done

# If 'all' is specified, enable everything except mainline
if [ "$INSTALL_ALL" = true ]; then
    INSTALL_PACKAGES=true
    INSTALL_CLAUDE=true
    INSTALL_CODEX=true
    INSTALL_SCREENSAVER=true
    INSTALL_PLYMOUTH=true
    INSTALL_PROMPT=true
    # INSTALL_MACOS_KEYS=true  # Omarchy now includes macOS-key functionality by default
    INSTALL_HYPRLAND_BINDINGS=true
    INSTALL_AUTO_TILE=true
    INSTALL_WAYCORNER=true
    INSTALL_WAYBAR=true
    INSTALL_SSH=true
fi

################################################################################
# Uninstall Functions
################################################################################

if [ "$UNINSTALL_MODE" = true ]; then
    print_header "Starting Omarchy Component Uninstall"

    # Check if running as root
    if [ "$EUID" -eq 0 ]; then
        print_error "Please do not run this script as root or with sudo."
        print_error "The script will request sudo when needed."
        exit 1
    fi

    # Uninstall packages
    if [ "$INSTALL_PACKAGES" = true ]; then
        print_header "Uninstalling System Packages"

        PACKAGES=("npm" "nano")

        echo -e "${YELLOW}Warning: This will remove npm and nano packages.${NC}"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            for pkg in "${PACKAGES[@]}"; do
                if package_installed "$pkg"; then
                    print_step "Removing $pkg..."
                    sudo pacman -R --noconfirm "$pkg"
                    print_success "$pkg removed"
                else
                    print_skip "$pkg is not installed"
                fi
            done
        else
            print_skip "Skipping package removal"
        fi
    fi

    # Uninstall Claude Code
    if [ "$INSTALL_CLAUDE" = true ]; then
        print_header "Uninstalling Claude Code"

        if command_exists claude; then
            print_step "Removing Claude Code..."
            npm uninstall -g @anthropic-ai/claude-code --prefix "$HOME/.local"
            print_success "Claude Code removed"
        else
            print_skip "Claude Code is not installed"
        fi

        # Remove PATH entry from .bashrc only if Codex is also not installed
        if [ -f "$HOME/.bashrc" ]; then
            if ! command_exists codex; then
                print_step "Cleaning PATH from .bashrc..."
                remove_script_lines "$HOME/.bashrc" "Added by Omarchy"
                print_success "PATH entries cleaned from .bashrc"
            else
                print_skip "Keeping PATH entry (Codex is still installed)"
            fi
        fi
    fi

    # Uninstall Codex CLI
    if [ "$INSTALL_CODEX" = true ]; then
        print_header "Uninstalling Codex CLI"

        if command_exists codex; then
            print_step "Removing Codex CLI..."
            npm uninstall -g @openai/codex --prefix "$HOME/.local"
            print_success "Codex CLI removed"
        else
            print_skip "Codex CLI is not installed"
        fi

        # Remove PATH entry from .bashrc only if Claude is also not installed
        if [ -f "$HOME/.bashrc" ]; then
            if ! command_exists claude; then
                print_step "Cleaning PATH from .bashrc..."
                remove_script_lines "$HOME/.bashrc" "Added by Omarchy"
                print_success "PATH entries cleaned from .bashrc"
            else
                print_skip "Keeping PATH entry (Claude Code is still installed)"
            fi
        fi
    fi

    # Uninstall screensaver
    if [ "$INSTALL_SCREENSAVER" = true ]; then
        print_header "Removing Custom Screensaver"

        SCREENSAVER_DEST="$HOME/.config/omarchy/branding/screensaver.txt"

        if [ -f "$SCREENSAVER_DEST" ]; then
            # Find most recent backup
            BACKUP=$(ls -t "${SCREENSAVER_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring backup from $BACKUP..."
                cp "$BACKUP" "$SCREENSAVER_DEST"
                print_success "Screensaver backup restored"
            else
                print_step "Removing custom screensaver..."
                rm "$SCREENSAVER_DEST"
                print_success "Custom screensaver removed"
            fi
        else
            print_skip "Custom screensaver not found"
        fi
    fi

    # Uninstall Plymouth theme
    if [ "$INSTALL_PLYMOUTH" = true ]; then
        print_header "Uninstalling Plymouth Theme"

        if command_exists plymouth-set-default-theme; then
            CURRENT_THEME=$(sudo plymouth-set-default-theme)

            if [ "$CURRENT_THEME" = "cybex" ]; then
                print_step "Resetting Plymouth theme to default..."
                sudo plymouth-set-default-theme -R spinner
                print_success "Plymouth theme reset to spinner"

                print_step "Rebuilding initramfs..."
                sudo mkinitcpio -P
                print_success "Initramfs rebuilt"
            else
                print_skip "Plymouth theme is not set to cybex"
            fi

            # Remove theme directory
            if sudo test -d "/usr/share/plymouth/themes/cybex"; then
                print_step "Removing cybex theme directory..."
                sudo rm -rf "/usr/share/plymouth/themes/cybex"
                print_success "Cybex theme directory removed"
            fi
        else
            print_skip "Plymouth not installed"
        fi
    fi

    # Uninstall Starship prompt
    if [ "$INSTALL_PROMPT" = true ]; then
        print_header "Removing Starship Configuration"

        STARSHIP_DEST="$HOME/.config/starship.toml"

        if [ -f "$STARSHIP_DEST" ]; then
            # Find most recent backup
            BACKUP=$(ls -t "${STARSHIP_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring backup from $BACKUP..."
                cp "$BACKUP" "$STARSHIP_DEST"
                print_success "Starship configuration backup restored"
            else
                print_step "Removing Starship configuration..."
                rm "$STARSHIP_DEST"
                print_success "Starship configuration removed"
            fi
        else
            print_skip "Starship configuration not found"
        fi

        # Uninstall Fish-like tab completion
        COMPLETION_DEST="$HOME/.inputrc"

        if [ -f "$COMPLETION_DEST" ]; then
            # Find most recent backup
            BACKUP=$(ls -t "${COMPLETION_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring .inputrc backup from $BACKUP..."
                cp "$BACKUP" "$COMPLETION_DEST"
                print_success "Tab completion configuration backup restored"
            else
                print_step "Removing Fish-like tab completion configuration..."
                rm "$COMPLETION_DEST"
                print_success "Tab completion configuration removed"
            fi
        else
            print_skip "Tab completion configuration not found"
        fi

        # Uninstall ble.sh
        BLERC_DEST="$HOME/.blerc"
        BASHRC="$HOME/.bashrc"

        # Remove ble.sh configuration
        if [ -f "$BLERC_DEST" ]; then
            BACKUP=$(ls -t "${BLERC_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring .blerc backup from $BACKUP..."
                cp "$BACKUP" "$BLERC_DEST"
                print_success "ble.sh configuration backup restored"
            else
                print_step "Removing ble.sh configuration..."
                rm "$BLERC_DEST"
                print_success "ble.sh configuration removed"
            fi
        else
            print_skip "ble.sh configuration not found"
        fi

        # Remove ble.sh from .bashrc
        if [ -f "$BASHRC" ] && grep -q "blesh/ble.sh" "$BASHRC" 2>/dev/null; then
            print_step "Removing ble.sh from .bashrc..."

            # Find the most recent backup before ble.sh was added
            BACKUP=$(ls -t "${BASHRC}.bak."* 2>/dev/null | grep -v "$(date +%Y%m%d)" | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring .bashrc backup from $BACKUP..."
                cp "$BACKUP" "$BASHRC"
                print_success ".bashrc restored"
            else
                # Remove ble.sh lines manually
                TEMP_BASHRC=$(mktemp)
                grep -v "ble.sh" "$BASHRC" | grep -v "ble-attach" | grep -v "Bash Line Editor" > "$TEMP_BASHRC"
                cp "$TEMP_BASHRC" "$BASHRC"
                rm "$TEMP_BASHRC"
                print_success "ble.sh references removed from .bashrc"
            fi
        else
            print_skip "ble.sh not configured in .bashrc"
        fi

        # Optionally remove ble.sh package (ask user)
        if [ -f "$HOME/.local/share/blesh/ble.sh" ]; then
            echo -e "${YELLOW}ble.sh package is still installed.${NC}"
            read -p "Remove ble.sh package? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                AUR_HELPER=""
                if command_exists yay; then
                    AUR_HELPER="yay"
                elif command_exists paru; then
                    AUR_HELPER="paru"
                elif command_exists pacaur; then
                    AUR_HELPER="pacaur"
                fi

                if [ -n "$AUR_HELPER" ]; then
                    print_step "Removing ble.sh package..."
                    $AUR_HELPER -R --noconfirm blesh-git
                    print_success "ble.sh package removed"
                else
                    print_step "Removing ble.sh manually..."
                    rm -rf "$HOME/.local/share/blesh"
                    print_success "ble.sh removed"
                fi
            else
                print_skip "Keeping ble.sh package installed"
            fi
        fi
    fi

    # Uninstall macOS-style shortcuts
    if [ "$INSTALL_MACOS_KEYS" = true ]; then
        print_header "Removing macOS-style Shortcuts"

        # Stop and disable keyd service
        if sudo systemctl is-active --quiet keyd; then
            print_step "Stopping keyd service..."
            sudo systemctl stop keyd
            print_success "keyd service stopped"
        fi

        if sudo systemctl is-enabled --quiet keyd 2>/dev/null; then
            print_step "Disabling keyd service..."
            sudo systemctl disable keyd
            print_success "keyd service disabled"
        fi

        # Remove keyd configuration
        if sudo test -f "/etc/keyd/default.conf"; then
            print_step "Removing keyd configuration..."
            sudo rm "/etc/keyd/default.conf"
            print_success "keyd configuration removed"
        fi

        # Restore Alacritty configuration
        ALACRITTY_DEST="$HOME/.config/alacritty/alacritty.toml"
        if [ -f "$ALACRITTY_DEST" ]; then
            BACKUP=$(ls -t "${ALACRITTY_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring Alacritty backup from $BACKUP..."
                cp "$BACKUP" "$ALACRITTY_DEST"
                print_success "Alacritty configuration restored"
            else
                print_skip "No Alacritty backup found"
            fi
        fi
    fi

    # Uninstall Hyprland bindings
    if [ "$INSTALL_HYPRLAND_BINDINGS" = true ]; then
        print_header "Removing Hyprland Configuration"

        HYPRLAND_BINDINGS_DEST="$HOME/.config/hypr/bindings.conf"
        HYPRLAND_INPUT_DEST="$HOME/.config/hypr/input.conf"

        # Restore bindings.conf
        if [ -f "$HYPRLAND_BINDINGS_DEST" ]; then
            BACKUP=$(ls -t "${HYPRLAND_BINDINGS_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring bindings.conf backup from $BACKUP..."
                cp "$BACKUP" "$HYPRLAND_BINDINGS_DEST"
                print_success "Hyprland bindings restored"
            else
                print_step "Removing bindings.conf..."
                rm "$HYPRLAND_BINDINGS_DEST"
                print_success "Hyprland bindings removed"
            fi
        fi

        # Restore input.conf
        if [ -f "$HYPRLAND_INPUT_DEST" ]; then
            BACKUP=$(ls -t "${HYPRLAND_INPUT_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring input.conf backup from $BACKUP..."
                cp "$BACKUP" "$HYPRLAND_INPUT_DEST"
                print_success "Hyprland input configuration restored"
            else
                print_step "Removing input.conf..."
                rm "$HYPRLAND_INPUT_DEST"
                print_success "Hyprland input configuration removed"
            fi
        fi
    fi

    # Uninstall auto-tile
    if [ "$INSTALL_AUTO_TILE" = true ]; then
        print_header "Uninstalling Auto-Tile Helper"

        AUTO_TILE_DEST="$HOME/.local/bin/auto-tile"

        # Kill running process
        if pgrep -f "$AUTO_TILE_DEST" >/dev/null 2>&1; then
            print_step "Stopping auto-tile helper..."
            pkill -f "$AUTO_TILE_DEST"
            print_success "auto-tile helper stopped"
        fi

        # Remove script
        if [ -f "$AUTO_TILE_DEST" ]; then
            print_step "Removing auto-tile script..."
            rm "$AUTO_TILE_DEST"
            print_success "auto-tile script removed"
        fi

        # Remove from autostart.conf
        HYPRLAND_AUTOSTART="$HOME/.config/hypr/autostart.conf"
        if [ -f "$HYPRLAND_AUTOSTART" ]; then
            print_step "Removing auto-tile from Hyprland autostart..."
            remove_script_lines "$HYPRLAND_AUTOSTART" "Auto-tile first window"
            print_success "auto-tile removed from autostart"
        fi
    fi

    # Uninstall waycorner
    if [ "$INSTALL_WAYCORNER" = true ]; then
        print_header "Uninstalling Waycorner"

        # Kill running process
        if pgrep -x waycorner >/dev/null 2>&1; then
            print_step "Stopping waycorner..."
            pkill -x waycorner
            print_success "waycorner stopped"
        fi

        # Remove binary
        if [ -f "$HOME/.cargo/bin/waycorner" ]; then
            print_step "Removing waycorner binary..."
            rm "$HOME/.cargo/bin/waycorner"
            print_success "waycorner binary removed"
        fi

        # Restore or remove configuration
        WAYCORNER_DEST="$HOME/.config/waycorner/config.toml"
        if [ -f "$WAYCORNER_DEST" ]; then
            BACKUP=$(ls -t "${WAYCORNER_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring waycorner backup from $BACKUP..."
                cp "$BACKUP" "$WAYCORNER_DEST"
                print_success "waycorner configuration restored"
            else
                print_step "Removing waycorner configuration..."
                rm -rf "$HOME/.config/waycorner"
                print_success "waycorner configuration removed"
            fi
        fi

        # Remove from autostart.conf
        HYPRLAND_AUTOSTART="$HOME/.config/hypr/autostart.conf"
        if [ -f "$HYPRLAND_AUTOSTART" ]; then
            print_step "Removing waycorner from Hyprland autostart..."
            remove_script_lines "$HYPRLAND_AUTOSTART" "Hot corners"
            print_success "waycorner removed from autostart"
        fi
    fi

    # Uninstall Waybar configuration
    if [ "$INSTALL_WAYBAR" = true ]; then
        print_header "Removing Waybar Configuration"

        WAYBAR_CONFIG_DEST="$HOME/.config/waybar/config.jsonc"
        WAYBAR_STYLE_DEST="$HOME/.config/waybar/style.css"
        INDICATOR_DEST="$HOME/.local/share/omarchy/default/waybar/indicators/idle-toggle.sh"

        # Restore config.jsonc
        if [ -f "$WAYBAR_CONFIG_DEST" ]; then
            BACKUP=$(ls -t "${WAYBAR_CONFIG_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring waybar config backup from $BACKUP..."
                cp "$BACKUP" "$WAYBAR_CONFIG_DEST"
                print_success "Waybar configuration restored"
            else
                print_skip "No waybar config backup found"
            fi
        fi

        # Restore style.css
        if [ -f "$WAYBAR_STYLE_DEST" ]; then
            BACKUP=$(ls -t "${WAYBAR_STYLE_DEST}.bak."* 2>/dev/null | head -1)

            if [ -n "$BACKUP" ]; then
                print_step "Restoring waybar style backup from $BACKUP..."
                cp "$BACKUP" "$WAYBAR_STYLE_DEST"
                print_success "Waybar style restored"
            else
                print_skip "No waybar style backup found"
            fi
        fi

        # Remove indicator script
        if [ -f "$INDICATOR_DEST" ]; then
            print_step "Removing idle toggle indicator..."
            rm "$INDICATOR_DEST"
            print_success "Idle toggle indicator removed"
        fi

        # Restart waybar
        print_step "Restarting Waybar..."
        if command_exists omarchy-restart-waybar; then
            omarchy-restart-waybar &>/dev/null
            print_success "Waybar restarted"
        else
            if pgrep -x waybar >/dev/null 2>&1; then
                pkill -x waybar
                sleep 0.5
                waybar &>/dev/null &
                print_success "Waybar restarted"
            else
                print_skip "Waybar is not running"
            fi
        fi
    fi

    # Uninstall mainline kernel
    if [ "$INSTALL_MAINLINE" = true ]; then
        print_header "Uninstalling Mainline Kernel"

        echo -e "${YELLOW}Warning: This will remove the mainline kernel and reset bootloader.${NC}"
        read -p "Are you sure you want to continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if package_installed "linux-mainline"; then
                print_step "Removing linux-mainline kernel..."
                sudo pacman -R --noconfirm linux-mainline
                print_success "linux-mainline kernel removed"

                # Reset bootloader to default kernel
                print_step "Resetting bootloader to default kernel..."
                if [ -f /boot/limine.conf ]; then
                    sudo sed -i 's/^default_entry:.*/default_entry: 0/' /boot/limine.conf
                    print_success "Limine bootloader reset to first entry"
                elif command_exists grub-mkconfig; then
                    sudo grub-mkconfig -o /boot/grub/grub.cfg
                    print_success "GRUB configuration updated"
                elif command_exists bootctl; then
                    # Reset to first available entry
                    FIRST_ENTRY=$(ls /boot/loader/entries/*.conf 2>/dev/null | head -1 | xargs basename 2>/dev/null)
                    if [ -n "$FIRST_ENTRY" ]; then
                        echo "default $FIRST_ENTRY" | sudo tee /boot/loader/loader.conf >/dev/null
                        print_success "systemd-boot reset to $FIRST_ENTRY"
                    fi
                fi
            else
                print_skip "linux-mainline kernel is not installed"
            fi
        else
            print_skip "Skipping mainline kernel removal"
        fi
    fi

    print_header "Uninstall Complete!"
    echo -e "${GREEN}Selected components have been uninstalled.${NC}\n"

    exit 0
fi

################################################################################
# Main Installation Steps
################################################################################

print_header "Starting Omarchy Post-Installation Setup"

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    print_error "Please do not run this script as root or with sudo."
    print_error "The script will request sudo when needed."
    exit 1
fi

################################################################################
# System Validation Checks
################################################################################

# Determine what validation checks are needed based on selected components
NEED_SUDO=false
NEED_INTERNET=false
NEED_DISK_SPACE=false

# Components that require sudo
if [ "$INSTALL_PACKAGES" = true ] || [ "$INSTALL_MAINLINE" = true ] || [ "$INSTALL_PLYMOUTH" = true ] || [ "$INSTALL_MACOS_KEYS" = true ] || [ "$INSTALL_AUTO_TILE" = true ]; then
    NEED_SUDO=true
fi

# Components that require internet
if [ "$INSTALL_PACKAGES" = true ] || [ "$INSTALL_CLAUDE" = true ] || [ "$INSTALL_CODEX" = true ] || [ "$INSTALL_MAINLINE" = true ] || [ "$INSTALL_MACOS_KEYS" = true ] || [ "$INSTALL_AUTO_TILE" = true ] || [ "$INSTALL_WAYCORNER" = true ]; then
    NEED_INTERNET=true
fi

# Components that require significant disk space
if [ "$INSTALL_MAINLINE" = true ] || [ "$INSTALL_PLYMOUTH" = true ]; then
    NEED_DISK_SPACE=true
fi

# Only run validation checks if needed
if [ "$NEED_SUDO" = true ] || [ "$NEED_INTERNET" = true ] || [ "$NEED_DISK_SPACE" = true ]; then
    print_header "System Validation Checks"

    # Check for sudo availability (if needed)
    if [ "$NEED_SUDO" = true ]; then
        print_step "Checking sudo availability..."
        if ! command_exists sudo; then
            print_error "sudo is not installed. Please install sudo first: pacman -S sudo"
            exit 1
        fi

        if ! sudo -v &>/dev/null; then
            print_error "You don't have sudo privileges. Please ensure you're in the sudoers group."
            exit 1
        fi
        print_success "sudo is available and configured"
    fi

    # Check internet connectivity (if needed)
    if [ "$NEED_INTERNET" = true ]; then
        print_step "Checking internet connectivity..."
        if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null && ! ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
            print_error "No internet connection detected. This script requires internet access."
            print_error "Please check your network connection and try again."
            exit 1
        fi
        print_success "Internet connection verified"
    fi

    # Check disk space (if needed)
    if [ "$NEED_DISK_SPACE" = true ]; then
        print_step "Checking available disk space..."
        AVAILABLE_ROOT=$(df / | awk 'NR==2 {print int($4/1024)}')  # Available space in MB
        if [ "$AVAILABLE_ROOT" -lt 1024 ]; then
            print_error "Insufficient disk space. At least 1GB free space is required."
            print_error "Available: ${AVAILABLE_ROOT}MB"
            exit 1
        fi

        # Check /boot separately if it's a separate partition
        if mountpoint -q /boot; then
            AVAILABLE_BOOT=$(df /boot | awk 'NR==2 {print int($4/1024)}')  # Available space in MB
            if [ "$AVAILABLE_BOOT" -lt 100 ]; then
                print_error "Insufficient disk space in /boot. At least 100MB free space is required."
                print_error "Available: ${AVAILABLE_BOOT}MB"
                exit 1
            fi
        fi
        print_success "Sufficient disk space available (${AVAILABLE_ROOT}MB on /)"
    fi
fi

################################################################################
# 0. Install Mainline Kernel (Optional)
################################################################################

if [ "$INSTALL_MAINLINE" = true ]; then
    print_header "Installing Mainline Kernel"

    # Check if Chaotic-AUR is already fully configured
    CHAOTIC_CONFIGURED=false
    if grep -q "\[chaotic-aur\]" /etc/pacman.conf 2>/dev/null && \
       grep -q "Include = /etc/pacman.d/chaotic-mirrorlist" /etc/pacman.conf 2>/dev/null; then
        CHAOTIC_CONFIGURED=true
        print_skip "Chaotic-AUR repository already fully configured"
    fi

    if [ "$CHAOTIC_CONFIGURED" = false ]; then
        # Import GPG key
        print_step "Importing Chaotic-AUR GPG key..."
        if sudo pacman-key --list-keys 3056513887B78AEB &>/dev/null; then
            print_skip "Chaotic-AUR GPG key already imported"
        else
            sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
            sudo pacman-key --lsign-key 3056513887B78AEB
            print_success "Chaotic-AUR GPG key imported"
        fi

        # Install mirrorlist
        if ! package_installed "chaotic-mirrorlist"; then
            print_step "Installing Chaotic-AUR mirrorlist..."
            sudo pacman -U https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst --noconfirm
            print_success "Chaotic-AUR mirrorlist installed"
        else
            print_skip "Chaotic-AUR mirrorlist already installed"
        fi

        # Install keyring (contains all trusted keys for Chaotic-AUR packages)
        if ! package_installed "chaotic-keyring"; then
            print_step "Installing Chaotic-AUR keyring..."
            sudo pacman -U https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst --noconfirm
            print_success "Chaotic-AUR keyring installed"
        else
            print_skip "Chaotic-AUR keyring already installed"
        fi

        # Add repository to pacman.conf if not already present
        if ! grep -q "\[chaotic-aur\]" /etc/pacman.conf 2>/dev/null; then
            print_step "Adding Chaotic-AUR repository to pacman.conf..."
            echo '
[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist' | sudo tee -a /etc/pacman.conf >/dev/null
            print_success "Chaotic-AUR repository added"
        else
            # Header exists but maybe not the Include line
            if ! grep -q "Include = /etc/pacman.d/chaotic-mirrorlist" /etc/pacman.conf 2>/dev/null; then
                print_error "Chaotic-AUR header found but Include line missing in pacman.conf"
                print_error "Please manually fix /etc/pacman.conf"
                exit 1
            fi
        fi
    fi

    print_step "Updating package database..."
    sudo pacman -Syy --noconfirm
    print_success "Package database updated"

    # Refresh keyring to ensure all package signing keys are trusted
    print_step "Refreshing package signing keys..."
    sudo pacman -S --noconfirm chaotic-keyring
    print_success "Package signing keys refreshed"

    if package_installed "linux-mainline"; then
        print_skip "linux-mainline kernel already installed"
    else
        print_step "Installing linux-mainline kernel..."
        sudo pacman -S --noconfirm linux-mainline
        print_success "linux-mainline kernel installed"
    fi

    # Update bootloader configuration
    print_step "Updating bootloader configuration..."
    if [ -f /boot/limine.conf ]; then
        print_step "Setting mainline kernel as default for Limine..."
        # Find the index of the linux-mainline entry
        MAINLINE_INDEX=$(grep -n "//linux-mainline" /boot/limine.conf | head -1 | cut -d: -f1)
        if [ -n "$MAINLINE_INDEX" ]; then
            # Count how many boot entries exist before the mainline entry
            # Entries start with "//" (2 slashes) but not "///" (3 slashes which are submenus)
            ENTRY_INDEX=$(awk -v line="$MAINLINE_INDEX" 'NR < line && /^  \/\/[^\/]/ {count++} END {print count}' /boot/limine.conf)

            # Update default_entry in limine.conf
            sudo sed -i "s/^default_entry:.*/default_entry: $ENTRY_INDEX/" /boot/limine.conf
            print_success "Mainline kernel (entry $ENTRY_INDEX) set as default in Limine"
        else
            print_error "Could not find linux-mainline entry in limine.conf"
        fi
    elif command_exists grub-mkconfig; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        print_success "GRUB configuration updated"

        # Set mainline as default in GRUB
        print_step "Setting mainline kernel as default..."
        sudo grub-set-default "Advanced options for Arch Linux>Arch Linux, with Linux linux-mainline" 2>/dev/null || \
        print_error "Could not set default - please set manually in GRUB menu"
    elif command_exists bootctl; then
        print_step "Setting mainline kernel as default for systemd-boot..."
        # Find the mainline boot entry
        MAINLINE_ENTRY=$(ls /boot/loader/entries/*linux-mainline.conf 2>/dev/null | head -1 | xargs basename 2>/dev/null)
        if [ -n "$MAINLINE_ENTRY" ]; then
            echo "default $MAINLINE_ENTRY" | sudo tee /boot/loader/loader.conf >/dev/null
            print_success "Mainline kernel set as default"
        else
            print_error "Could not find mainline boot entry - please set manually"
        fi
    else
        print_error "Unknown bootloader - please update manually"
    fi

    echo -e "${YELLOW}⚠${NC}  ${BOLD}Reboot required to use the mainline kernel${NC}\n"
fi

################################################################################
# 1. Install System Packages
################################################################################

if [ "$INSTALL_PACKAGES" = true ]; then
    print_header "Installing System Packages"

    PACKAGES=("npm" "nano")

    for pkg in "${PACKAGES[@]}"; do
        if package_installed "$pkg"; then
            print_skip "$pkg is already installed"
        else
            print_step "Installing $pkg..."
            sudo pacman -S --noconfirm "$pkg"
            print_success "$pkg installed"
        fi
    done
fi

################################################################################
# 2. Install Claude Code
################################################################################

if [ "$INSTALL_CLAUDE" = true ]; then
    print_header "Installing Claude Code"

    # Check Node.js is available and version
    print_step "Checking Node.js version..."
    if ! command_exists node; then
        print_error "Node.js is not installed but should be available with npm package"
        print_error "Please ensure Node.js is installed"
        exit 1
    fi

    NODE_VERSION=$(node --version 2>/dev/null | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$NODE_MAJOR" -lt 14 ]; then
        print_error "Node.js version $NODE_VERSION is too old. Minimum required: v14.0.0"
        exit 1
    fi
    print_success "Node.js $NODE_VERSION detected"

    # Ensure ~/.local/bin exists
    mkdir -p "$HOME/.local/bin"

    if command_exists claude; then
        print_step "Updating Claude Code to latest version..."
        npm install -g @anthropic-ai/claude-code --prefix "$HOME/.local"
        print_success "Claude Code updated"
    else
        print_step "Installing Claude Code globally..."
        npm install -g @anthropic-ai/claude-code --prefix "$HOME/.local"
        print_success "Claude Code installed"
    fi

    # Add ~/.local/bin to PATH if not already present in .bashrc
    # More flexible pattern matching for existing PATH entries
    if ! grep -qE '(\.local/bin|HOME/.local/bin)' "$HOME/.bashrc" 2>/dev/null; then
        print_step "Adding ~/.local/bin to PATH in .bashrc..."
        echo '' >> "$HOME/.bashrc"
        echo '# Added by Omarchy post-install script' >> "$HOME/.bashrc"
        echo 'export PATH=$HOME/.local/bin:$PATH' >> "$HOME/.bashrc"
        print_success "PATH updated in .bashrc"

        # Update current PATH if not already present
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            export PATH="$HOME/.local/bin:$PATH"
            print_step "PATH updated for current session"
        fi
    else
        print_skip "PATH already configured in .bashrc"
    fi
fi

################################################################################
# 3. Install Codex CLI
################################################################################

if [ "$INSTALL_CODEX" = true ]; then
    print_header "Installing Codex CLI"

    # Check Node.js is available and version
    print_step "Checking Node.js version..."
    if ! command_exists node; then
        print_error "Node.js is not installed but should be available with npm package"
        print_error "Please ensure Node.js is installed or run: ./install.sh packages codex"
        exit 1
    fi

    NODE_VERSION=$(node --version 2>/dev/null | sed 's/v//')
    NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
    if [ "$NODE_MAJOR" -lt 14 ]; then
        print_error "Node.js version $NODE_VERSION is too old. Minimum required: v14.0.0"
        exit 1
    fi
    print_success "Node.js $NODE_VERSION detected"

    # Ensure ~/.local/bin exists
    mkdir -p "$HOME/.local/bin"

    if command_exists codex; then
        print_step "Updating Codex CLI to latest version..."
        npm install -g @openai/codex --prefix "$HOME/.local"
        print_success "Codex CLI updated"
    else
        print_step "Installing Codex CLI globally..."
        npm install -g @openai/codex --prefix "$HOME/.local"
        print_success "Codex CLI installed"
    fi

    # Add ~/.local/bin to PATH if not already present in .bashrc
    # More flexible pattern matching for existing PATH entries
    if ! grep -qE '(\.local/bin|HOME/.local/bin)' "$HOME/.bashrc" 2>/dev/null; then
        print_step "Adding ~/.local/bin to PATH in .bashrc..."
        echo '' >> "$HOME/.bashrc"
        echo '# Added by Omarchy post-install script' >> "$HOME/.bashrc"
        echo 'export PATH=$HOME/.local/bin:$PATH' >> "$HOME/.bashrc"
        print_success "PATH updated in .bashrc"

        # Update current PATH if not already present
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            export PATH="$HOME/.local/bin:$PATH"
            print_step "PATH updated for current session"
        fi
    else
        print_skip "PATH already configured in .bashrc"
    fi
fi

################################################################################
# 4. Configure Screensaver
################################################################################

if [ "$INSTALL_SCREENSAVER" = true ]; then
    print_header "Configuring Screensaver"

    SCREENSAVER_SRC="$SCRIPT_DIR/config/screensaver/screensaver.txt"
    SCREENSAVER_DEST="$HOME/.config/omarchy/branding/screensaver.txt"

    if [ ! -f "$SCREENSAVER_SRC" ]; then
        print_error "Source screensaver.txt not found at $SCREENSAVER_SRC"
        print_error "Skipping screensaver configuration..."
    else
        # Create destination directory if it doesn't exist
        mkdir -p "$(dirname "$SCREENSAVER_DEST")"

        if [ -f "$SCREENSAVER_DEST" ]; then
            # Use diff if cmp is not available
            if command_exists cmp; then
                if cmp -s "$SCREENSAVER_SRC" "$SCREENSAVER_DEST"; then
                    print_skip "Screensaver is already up to date"
                else
                    print_step "Backing up existing screensaver.txt..."
                    BACKUP_FILE=$(create_backup "$SCREENSAVER_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating screensaver.txt..."
                    cp "$SCREENSAVER_SRC" "$SCREENSAVER_DEST"
                    print_success "Screensaver updated"
                fi
            else
                # Fallback to diff if cmp is not available
                if diff -q "$SCREENSAVER_SRC" "$SCREENSAVER_DEST" >/dev/null 2>&1; then
                    print_skip "Screensaver is already up to date"
                else
                    print_step "Backing up existing screensaver.txt..."
                    BACKUP_FILE=$(create_backup "$SCREENSAVER_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating screensaver.txt..."
                    cp "$SCREENSAVER_SRC" "$SCREENSAVER_DEST"
                    print_success "Screensaver updated"
                fi
            fi
        else
            print_step "Copying screensaver.txt to $SCREENSAVER_DEST..."
            cp "$SCREENSAVER_SRC" "$SCREENSAVER_DEST"
            print_success "Screensaver configured"
        fi
    fi
fi

################################################################################
# 5. Install Plymouth Theme
################################################################################

if [ "$INSTALL_PLYMOUTH" = true ]; then
    print_header "Installing Plymouth Theme (Cybex)"

    PLYMOUTH_SRC="$SCRIPT_DIR/config/plymouth/themes/cybex"
    PLYMOUTH_DEST="/usr/share/plymouth/themes/cybex"

    if [ ! -d "$PLYMOUTH_SRC" ]; then
        print_error "Source Plymouth theme not found at $PLYMOUTH_SRC"
        print_error "Skipping Plymouth theme installation..."
    else
        # Install theme files (excluding .claude directory)
        if [ ! -d "$PLYMOUTH_DEST" ]; then
            print_step "Installing Plymouth theme to $PLYMOUTH_DEST..."
            sudo mkdir -p "$PLYMOUTH_DEST"
            # Copy all files except hidden directories like .claude
            (cd "$PLYMOUTH_SRC" && sudo find . -type f ! -path '*/\.*' -exec cp --parents {} "$PLYMOUTH_DEST/" \;)
            print_success "Plymouth theme files installed"
        else
            print_skip "Plymouth theme directory already exists"
            print_step "Updating Plymouth theme files..."
            # Copy all files except hidden directories like .claude
            (cd "$PLYMOUTH_SRC" && sudo find . -type f ! -path '*/\.*' -exec cp --parents {} "$PLYMOUTH_DEST/" \;)
            print_success "Plymouth theme files updated"
        fi

        # Check if plymouth-set-default-theme command exists
        if ! command_exists plymouth-set-default-theme; then
            print_error "plymouth-set-default-theme command not found"
            print_error "Install Plymouth first: sudo pacman -S plymouth"
        else
            # Check if theme is already set
            CURRENT_THEME=$(sudo plymouth-set-default-theme)
            if [ "$CURRENT_THEME" = "cybex" ]; then
                print_skip "Plymouth theme 'cybex' is already active"
            else
                print_step "Setting Plymouth theme to 'cybex'..."
                sudo plymouth-set-default-theme -R cybex
                print_success "Plymouth theme 'cybex' enabled"
                print_step "Rebuilding initramfs (this may take a moment)..."
                if ! sudo mkinitcpio -P; then
                    print_error "CRITICAL: Failed to rebuild initramfs!"
                    print_error "Your system may not boot properly with the new theme."
                    print_error "Please try running 'sudo mkinitcpio -P' manually and check for errors."
                    print_error "Common issues: insufficient /boot space, missing kernel modules, or hook errors."
                    exit 1
                fi
                print_success "Initramfs rebuilt successfully"
            fi
        fi
    fi
fi

################################################################################
# 6. Configure Starship Prompt
################################################################################

if [ "$INSTALL_PROMPT" = true ]; then
    print_header "Configuring Starship Prompt"

    STARSHIP_SRC="$SCRIPT_DIR/config/starship/starship.toml"
    STARSHIP_DEST="$HOME/.config/starship.toml"

    if [ ! -f "$STARSHIP_SRC" ]; then
        print_error "Source starship.toml not found at $STARSHIP_SRC"
        print_error "Skipping Starship configuration..."
    else
        # Create destination directory if it doesn't exist
        mkdir -p "$(dirname "$STARSHIP_DEST")"

        if [ -f "$STARSHIP_DEST" ]; then
            # Use diff if cmp is not available
            if command_exists cmp; then
                if cmp -s "$STARSHIP_SRC" "$STARSHIP_DEST"; then
                    print_skip "Starship configuration is already up to date"
                else
                    print_step "Backing up existing starship.toml..."
                    BACKUP_FILE=$(create_backup "$STARSHIP_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating starship.toml..."
                    cp "$STARSHIP_SRC" "$STARSHIP_DEST"
                    print_success "Starship configuration updated"
                fi
            else
                # Fallback to diff if cmp is not available
                if diff -q "$STARSHIP_SRC" "$STARSHIP_DEST" >/dev/null 2>&1; then
                    print_skip "Starship configuration is already up to date"
                else
                    print_step "Backing up existing starship.toml..."
                    BACKUP_FILE=$(create_backup "$STARSHIP_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating starship.toml..."
                    cp "$STARSHIP_SRC" "$STARSHIP_DEST"
                    print_success "Starship configuration updated"
                fi
            fi
        else
            print_step "Copying starship.toml to $STARSHIP_DEST..."
            cp "$STARSHIP_SRC" "$STARSHIP_DEST"
            print_success "Starship prompt configured"
        fi
    fi

    # Configure Fish-like tab completion
    COMPLETION_SRC="$SCRIPT_DIR/config/bash/completion.inputrc"
    COMPLETION_DEST="$HOME/.inputrc"

    if [ ! -f "$COMPLETION_SRC" ]; then
        print_error "Source completion.inputrc not found at $COMPLETION_SRC"
        print_error "Skipping Fish-like tab completion configuration..."
    else
        if [ -f "$COMPLETION_DEST" ]; then
            # Use diff if cmp is not available
            if command_exists cmp; then
                if cmp -s "$COMPLETION_SRC" "$COMPLETION_DEST"; then
                    print_skip "Fish-like tab completion is already up to date"
                else
                    print_step "Backing up existing .inputrc..."
                    BACKUP_FILE=$(create_backup "$COMPLETION_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating .inputrc with Fish-like tab completion..."
                    cp "$COMPLETION_SRC" "$COMPLETION_DEST"
                    print_success "Fish-like tab completion configured"
                fi
            else
                # Fallback to diff if cmp is not available
                if diff -q "$COMPLETION_SRC" "$COMPLETION_DEST" >/dev/null 2>&1; then
                    print_skip "Fish-like tab completion is already up to date"
                else
                    print_step "Backing up existing .inputrc..."
                    BACKUP_FILE=$(create_backup "$COMPLETION_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating .inputrc with Fish-like tab completion..."
                    cp "$COMPLETION_SRC" "$COMPLETION_DEST"
                    print_success "Fish-like tab completion configured"
                fi
            fi
        else
            print_step "Installing Fish-like tab completion to $COMPLETION_DEST..."
            cp "$COMPLETION_SRC" "$COMPLETION_DEST"
            print_success "Fish-like tab completion configured"
        fi
    fi

    # Install and configure ble.sh for Fish-like autosuggestions
    print_step "Checking for ble.sh (Fish-like autosuggestions)..."

    # Check if ble.sh is already installed (check both system and local locations)
    BLE_SH_PATH=""
    if [ -f "/usr/share/blesh/ble.sh" ]; then
        BLE_SH_PATH="/usr/share/blesh/ble.sh"
        print_skip "ble.sh is already installed at $BLE_SH_PATH"
    elif [ -f "$HOME/.local/share/blesh/ble.sh" ]; then
        BLE_SH_PATH="$HOME/.local/share/blesh/ble.sh"
        print_skip "ble.sh is already installed at $BLE_SH_PATH"
    else
        # Check for AUR helper
        AUR_HELPER=""
        if command_exists yay; then
            AUR_HELPER="yay"
        elif command_exists paru; then
            AUR_HELPER="paru"
        elif command_exists pacaur; then
            AUR_HELPER="pacaur"
        fi

        if [ -z "$AUR_HELPER" ]; then
            print_error "No AUR helper found (yay, paru, or pacaur required)"
            print_error "Please install an AUR helper first to enable Fish-like autosuggestions"
            print_error "Example: sudo pacman -S --needed git base-devel && git clone https://aur.archlinux.org/yay.git && cd yay && makepkg -si"
        else
            print_step "Installing ble.sh from AUR using $AUR_HELPER..."
            $AUR_HELPER -S --noconfirm blesh-git
            print_success "ble.sh installed"

            # Set the path after installation
            if [ -f "/usr/share/blesh/ble.sh" ]; then
                BLE_SH_PATH="/usr/share/blesh/ble.sh"
            elif [ -f "$HOME/.local/share/blesh/ble.sh" ]; then
                BLE_SH_PATH="$HOME/.local/share/blesh/ble.sh"
            fi
        fi
    fi

    # Configure ble.sh
    BLERC_SRC="$SCRIPT_DIR/config/bash/blerc"
    BLERC_DEST="$HOME/.blerc"

    if [ ! -f "$BLERC_SRC" ]; then
        print_error "Source blerc not found at $BLERC_SRC"
        print_error "Skipping ble.sh configuration..."
    else
        if [ -f "$BLERC_DEST" ]; then
            if command_exists cmp; then
                if cmp -s "$BLERC_SRC" "$BLERC_DEST"; then
                    print_skip "ble.sh configuration is already up to date"
                else
                    print_step "Backing up existing .blerc..."
                    BACKUP_FILE=$(create_backup "$BLERC_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating .blerc..."
                    cp "$BLERC_SRC" "$BLERC_DEST"
                    print_success "ble.sh configuration updated"
                fi
            else
                if diff -q "$BLERC_SRC" "$BLERC_DEST" >/dev/null 2>&1; then
                    print_skip "ble.sh configuration is already up to date"
                else
                    print_step "Backing up existing .blerc..."
                    BACKUP_FILE=$(create_backup "$BLERC_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating .blerc..."
                    cp "$BLERC_SRC" "$BLERC_DEST"
                    print_success "ble.sh configuration updated"
                fi
            fi
        else
            print_step "Installing ble.sh configuration to $BLERC_DEST..."
            cp "$BLERC_SRC" "$BLERC_DEST"
            print_success "ble.sh configuration installed"
        fi
    fi

    # Add ble.sh initialization to .bashrc
    if [ -n "$BLE_SH_PATH" ]; then
        BASHRC="$HOME/.bashrc"

        # Check if ble.sh is already sourced
        if grep -q "blesh/ble.sh" "$BASHRC" 2>/dev/null; then
            print_skip "ble.sh already configured in .bashrc"
        else
            print_step "Adding ble.sh to .bashrc..."

            # Create a temporary file with the new content
            TEMP_BASHRC=$(mktemp)

            # Add ble.sh source at the beginning with the detected path
            cat > "$TEMP_BASHRC" << EOF
# ble.sh - Bash Line Editor for Fish-like autosuggestions (Added by Omarchy)
[[ \$- == *i* ]] && source $BLE_SH_PATH --attach=none

EOF

            # Append original .bashrc content
            cat "$BASHRC" >> "$TEMP_BASHRC"

            # Add ble-attach at the end
            cat >> "$TEMP_BASHRC" << 'EOF'

# Attach ble.sh (Added by Omarchy)
[[ ! ${BLE_VERSION-} ]] || ble-attach
EOF

            # Backup and replace
            BACKUP_FILE=$(create_backup "$BASHRC")
            print_success "Backup created at $BACKUP_FILE"
            mv "$TEMP_BASHRC" "$BASHRC"
            print_success "ble.sh enabled in .bashrc"
        fi
    fi
fi

################################################################################
# 7. Configure macOS-style Shortcuts
################################################################################

if [ "$INSTALL_MACOS_KEYS" = true ]; then
    print_header "Configuring macOS-style Shortcuts"

    # Ensure keyd package is installed
    if package_installed "keyd"; then
        print_skip "keyd package already installed"
    else
        print_step "Installing keyd..."
        sudo pacman -S --noconfirm keyd
        print_success "keyd installed"
    fi

    KEYD_CONFIG_SRC="$SCRIPT_DIR/config/keyd/macos_shortcuts.conf"
    KEYD_CONFIG_DEST="/etc/keyd/default.conf"

    if [ ! -f "$KEYD_CONFIG_SRC" ]; then
        print_error "keyd config not found at $KEYD_CONFIG_SRC"
    else
        if sudo test -f "$KEYD_CONFIG_DEST"; then
            if command_exists cmp; then
                if sudo cmp -s "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DEST"; then
                    print_skip "keyd configuration already up to date"
                else
                    print_step "Updating keyd configuration..."
                    sudo install -D "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DEST"
                    print_success "keyd configuration updated"
                fi
            else
                if sudo diff -q "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DEST" >/dev/null 2>&1; then
                    print_skip "keyd configuration already up to date"
                else
                    print_step "Updating keyd configuration..."
                    sudo install -D "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DEST"
                    print_success "keyd configuration updated"
                fi
            fi
        else
            print_step "Installing keyd configuration..."
            sudo install -D "$KEYD_CONFIG_SRC" "$KEYD_CONFIG_DEST"
            print_success "keyd configuration installed"
        fi
    fi

    # Enable and start keyd service
    print_step "Enabling and starting keyd service..."
    if sudo systemctl enable --now keyd >/dev/null 2>&1; then
        print_success "keyd service enabled and running"
    else
        print_error "Failed to enable/start keyd - please verify 'sudo systemctl status keyd'"
    fi

    if sudo systemctl is-active --quiet keyd; then
        print_step "Reloading keyd to apply configuration..."
        if sudo keyd reload >/dev/null 2>&1; then
            print_success "keyd reloaded"
        else
            print_error "Failed to reload keyd - run 'sudo keyd reload' manually"
        fi
    fi

    # Ensure Alacritty bindings are present
    ALACRITTY_SRC="$SCRIPT_DIR/config/alacritty/alacritty.toml"
    ALACRITTY_DEST="$HOME/.config/alacritty/alacritty.toml"

    if [ ! -f "$ALACRITTY_SRC" ]; then
        print_error "Alacritty config not found at $ALACRITTY_SRC"
    else
        mkdir -p "$(dirname "$ALACRITTY_DEST")"

        if [ -f "$ALACRITTY_DEST" ]; then
            if command_exists cmp; then
                if cmp -s "$ALACRITTY_SRC" "$ALACRITTY_DEST"; then
                    print_skip "Alacritty configuration already up to date"
                else
                    BACKUP_PATH="${ALACRITTY_DEST}.bak.$(date +%Y%m%d%H%M%S)"
                    print_step "Backing up existing Alacritty config to $BACKUP_PATH..."
                    cp "$ALACRITTY_DEST" "$BACKUP_PATH"
                    print_step "Updating Alacritty configuration..."
                    cp "$ALACRITTY_SRC" "$ALACRITTY_DEST"
                    print_success "Alacritty configuration updated"
                fi
            else
                if diff -q "$ALACRITTY_SRC" "$ALACRITTY_DEST" >/dev/null 2>&1; then
                    print_skip "Alacritty configuration already up to date"
                else
                    BACKUP_PATH="${ALACRITTY_DEST}.bak.$(date +%Y%m%d%H%M%S)"
                    print_step "Backing up existing Alacritty config to $BACKUP_PATH..."
                    cp "$ALACRITTY_DEST" "$BACKUP_PATH"
                    print_step "Updating Alacritty configuration..."
                    cp "$ALACRITTY_SRC" "$ALACRITTY_DEST"
                    print_success "Alacritty configuration updated"
                fi
            fi
        else
            print_step "Installing Alacritty configuration..."
            cp "$ALACRITTY_SRC" "$ALACRITTY_DEST"
            print_success "Alacritty configuration installed"
        fi
    fi
fi

################################################################################
# 8. Generate SSH Key for GitHub
################################################################################

if [ "$INSTALL_SSH" = true ]; then
    print_header "Generating SSH Key for GitHub"

    SSH_KEY_PATH="$HOME/.ssh/id_ed25519"
    SSH_PUB_KEY="$SSH_KEY_PATH.pub"

    # Ensure .ssh directory exists with correct permissions
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    if [ -f "$SSH_KEY_PATH" ]; then
        print_skip "SSH key already exists at $SSH_KEY_PATH"
    else
        print_step "Generating new ED25519 SSH key..."
        ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f "$SSH_KEY_PATH" -N ""
        print_success "SSH key generated"
    fi

    # Check for ssh-agent configuration
    print_step "Checking SSH agent configuration..."

    # Check if ssh-agent is already configured to start automatically
    SSH_AGENT_CONFIGURED=false
    if grep -q "SSH_AUTH_SOCK" "$HOME/.bashrc" 2>/dev/null || grep -q "ssh-agent" "$HOME/.bashrc" 2>/dev/null; then
        SSH_AGENT_CONFIGURED=true
        print_skip "SSH agent startup already configured in .bashrc"
    fi

    # If not configured, add ssh-agent startup to .bashrc
    if [ "$SSH_AGENT_CONFIGURED" = false ]; then
        print_step "Adding SSH agent configuration to .bashrc..."
        cat >> "$HOME/.bashrc" << 'EOF'

# SSH Agent configuration (added by Omarchy post-install script)
if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" >/dev/null 2>&1
fi
EOF
        print_success "SSH agent configuration added to .bashrc"
    fi

    # Try to add key to current agent if running, or start a new one
    set +e  # Temporarily disable exit on error
    ssh-add -l &>/dev/null
    SSH_AGENT_STATUS=$?

    if [ "$SSH_AGENT_STATUS" -eq 0 ] || [ "$SSH_AGENT_STATUS" -eq 1 ]; then
        # Agent is running (0 = has keys, 1 = no keys)
        if ssh-add -l 2>/dev/null | grep -q "$SSH_KEY_PATH"; then
            print_skip "SSH key already loaded in current ssh-agent"
        else
            print_step "Adding SSH key to current ssh-agent..."
            ssh-add "$SSH_KEY_PATH" 2>/dev/null
            if [ $? -eq 0 ]; then
                print_success "SSH key added to ssh-agent"
            else
                print_error "Failed to add key to ssh-agent (may need manual 'ssh-add ~/.ssh/id_ed25519')"
            fi
        fi
    elif [ "$SSH_AGENT_STATUS" -eq 2 ]; then
        # No agent running, start one for this session
        print_step "Starting ssh-agent for current session..."
        eval "$(ssh-agent -s)" >/dev/null 2>&1
        ssh-add "$SSH_KEY_PATH" 2>/dev/null
        if [ $? -eq 0 ]; then
            print_success "SSH agent started and key added for current session"
            print_skip "Note: This agent is temporary. A persistent one will start on next login."
        else
            print_error "Failed to add key to ssh-agent (may need manual 'ssh-add ~/.ssh/id_ed25519')"
        fi
    fi
    set -e  # Re-enable exit on error
fi

################################################################################
# 9. Configure Hyprland Bindings
################################################################################

if [ "$INSTALL_HYPRLAND_BINDINGS" = true ]; then
    print_header "Configuring Hyprland Bindings"

    HYPRLAND_BINDINGS_SRC="$SCRIPT_DIR/config/hyprland/bindings.conf"
    HYPRLAND_BINDINGS_DEST="$HOME/.config/hypr/bindings.conf"

    if [ ! -f "$HYPRLAND_BINDINGS_SRC" ]; then
        print_error "Source bindings.conf not found at $HYPRLAND_BINDINGS_SRC"
        print_error "Skipping Hyprland bindings configuration..."
    else
        # Create destination directory if it doesn't exist
        mkdir -p "$(dirname "$HYPRLAND_BINDINGS_DEST")"

        if [ -f "$HYPRLAND_BINDINGS_DEST" ]; then
            print_step "Backing up existing bindings.conf..."
            BACKUP_FILE=$(create_backup "$HYPRLAND_BINDINGS_DEST")
            print_success "Backup created at $BACKUP_FILE"
            print_step "Updating Hyprland bindings.conf..."
            cp "$HYPRLAND_BINDINGS_SRC" "$HYPRLAND_BINDINGS_DEST"
            print_success "Hyprland bindings updated"
        else
            print_step "Copying bindings.conf to $HYPRLAND_BINDINGS_DEST..."
            cp "$HYPRLAND_BINDINGS_SRC" "$HYPRLAND_BINDINGS_DEST"
            print_success "Hyprland bindings configured"
        fi
    fi

    HYPRLAND_INPUT_SRC="$SCRIPT_DIR/config/hyprland/input.conf"
    HYPRLAND_INPUT_DEST="$HOME/.config/hypr/input.conf"

    if [ ! -f "$HYPRLAND_INPUT_SRC" ]; then
        print_error "Source input.conf not found at $HYPRLAND_INPUT_SRC"
        print_error "Skipping Hyprland input configuration..."
    else
        # Create destination directory if it doesn't exist
        mkdir -p "$(dirname "$HYPRLAND_INPUT_DEST")"

        if [ -f "$HYPRLAND_INPUT_DEST" ]; then
            print_step "Backing up existing input.conf..."
            BACKUP_FILE=$(create_backup "$HYPRLAND_INPUT_DEST")
            print_success "Backup created at $BACKUP_FILE"
            print_step "Updating Hyprland input.conf..."
            cp "$HYPRLAND_INPUT_SRC" "$HYPRLAND_INPUT_DEST"
            print_success "Hyprland input configuration updated"
        else
            print_step "Copying input.conf to $HYPRLAND_INPUT_DEST..."
            cp "$HYPRLAND_INPUT_SRC" "$HYPRLAND_INPUT_DEST"
            print_success "Hyprland input configuration configured"
        fi
    fi
fi

################################################################################
# 10. Install Hyprland Auto-Tile Helper
################################################################################

if [ "$INSTALL_AUTO_TILE" = true ]; then
    print_header "Installing Hyprland Auto-Tile Helper"

    AUTO_TILE_SRC="$SCRIPT_DIR/scripts/auto-tile"
    AUTO_TILE_DEST="$HOME/.local/bin/auto-tile"

    AUTO_TILE_DEPS=(jq socat)
    AUTO_TILE_MISSING_PACKAGES=()

    for dep in "${AUTO_TILE_DEPS[@]}"; do
        if ! command_exists "$dep"; then
            AUTO_TILE_MISSING_PACKAGES+=("$dep")
        fi
    done

    if [ ${#AUTO_TILE_MISSING_PACKAGES[@]} -gt 0 ]; then
        print_step "Installing auto-tile dependencies: ${AUTO_TILE_MISSING_PACKAGES[*]}..."
        sudo pacman -S --needed --noconfirm "${AUTO_TILE_MISSING_PACKAGES[@]}"
        print_success "auto-tile dependencies installed"
    fi

    AUTO_TILE_DEP_FAILURE=false
    for dep in "${AUTO_TILE_DEPS[@]}"; do
        if ! command_exists "$dep"; then
            print_error "Dependency '$dep' is required for auto-tile but is still missing."
            AUTO_TILE_DEP_FAILURE=true
        fi
    done

    if [ "$AUTO_TILE_DEP_FAILURE" = true ]; then
        print_error "Skipping auto-tile installation until dependencies are resolved."
    elif [ ! -f "$AUTO_TILE_SRC" ]; then
        print_error "Source auto-tile script not found at $AUTO_TILE_SRC"
    else
        mkdir -p "$HOME/.local/bin"

        AUTO_TILE_UPDATED=false
        if [ -f "$AUTO_TILE_DEST" ] && command_exists cmp && cmp -s "$AUTO_TILE_SRC" "$AUTO_TILE_DEST"; then
            print_skip "auto-tile script already up to date"
        else
            print_step "Installing auto-tile helper to $AUTO_TILE_DEST..."
            cp "$AUTO_TILE_SRC" "$AUTO_TILE_DEST"
            chmod +x "$AUTO_TILE_DEST"
            AUTO_TILE_UPDATED=true
            print_success "auto-tile helper installed"
        fi

        HYPRLAND_AUTOSTART="$HOME/.config/hypr/autostart.conf"

        if [ -f "$HYPRLAND_AUTOSTART" ]; then
            if grep -q "exec-once = ~/.local/bin/auto-tile" "$HYPRLAND_AUTOSTART"; then
                print_skip "auto-tile already in Hyprland autostart"
            else
                print_step "Adding auto-tile to Hyprland autostart..."
                echo "" >> "$HYPRLAND_AUTOSTART"
                echo "# Auto-tile first window per workspace" >> "$HYPRLAND_AUTOSTART"
                echo "exec-once = ~/.local/bin/auto-tile" >> "$HYPRLAND_AUTOSTART"
                print_success "auto-tile added to Hyprland autostart"
            fi
        else
            print_error "Hyprland autostart.conf not found at $HYPRLAND_AUTOSTART"
            print_error "Add 'exec-once = ~/.local/bin/auto-tile' manually to enable the helper"
        fi

        if [ -f "$AUTO_TILE_DEST" ]; then
            print_step "Starting auto-tile helper for current session..."
            if pgrep -f "$AUTO_TILE_DEST" >/dev/null 2>&1; then
                if [ "$AUTO_TILE_UPDATED" = true ]; then
                    print_step "Restarting auto-tile helper with updated script..."
                    pkill -f "$AUTO_TILE_DEST" || true
                    sleep 0.5
                    "$AUTO_TILE_DEST" >/dev/null 2>&1 &
                    print_success "auto-tile helper restarted"
                else
                    print_skip "auto-tile helper is already running"
                fi
            else
                "$AUTO_TILE_DEST" >/dev/null 2>&1 &
                print_success "auto-tile helper started"
            fi
        fi
    fi
fi

################################################################################
# 11. Install and Configure Waycorner (Hot Corners)
################################################################################

if [ "$INSTALL_WAYCORNER" = true ]; then
    print_header "Installing Waycorner (Hot Corners)"

    # Ensure cargo is available
    if ! command_exists cargo; then
        print_error "Rust/Cargo is not installed. Waycorner requires Rust to compile."
        print_error "Install Rust first: curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh"
        exit 1
    fi

    # Check if waycorner is already installed
    if command_exists waycorner || [ -f "$HOME/.cargo/bin/waycorner" ]; then
        print_skip "Waycorner is already installed"
    else
        print_step "Installing waycorner via cargo (this may take a few minutes)..."
        cargo install waycorner --locked
        print_success "Waycorner installed"
    fi

    # Configure waycorner
    WAYCORNER_SRC="$SCRIPT_DIR/config/waycorner/config.toml"
    WAYCORNER_DEST="$HOME/.config/waycorner/config.toml"

    if [ ! -f "$WAYCORNER_SRC" ]; then
        print_error "Source config.toml not found at $WAYCORNER_SRC"
        print_error "Skipping waycorner configuration..."
    else
        # Create destination directory if it doesn't exist
        mkdir -p "$(dirname "$WAYCORNER_DEST")"

        if [ -f "$WAYCORNER_DEST" ]; then
            # Use diff if cmp is not available
            if command_exists cmp; then
                if cmp -s "$WAYCORNER_SRC" "$WAYCORNER_DEST"; then
                    print_skip "Waycorner configuration is already up to date"
                else
                    print_step "Backing up existing config.toml..."
                    BACKUP_FILE=$(create_backup "$WAYCORNER_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating waycorner config.toml..."
                    cp "$WAYCORNER_SRC" "$WAYCORNER_DEST"
                    print_success "Waycorner configuration updated"
                fi
            else
                # Fallback to diff if cmp is not available
                if diff -q "$WAYCORNER_SRC" "$WAYCORNER_DEST" >/dev/null 2>&1; then
                    print_skip "Waycorner configuration is already up to date"
                else
                    print_step "Backing up existing config.toml..."
                    BACKUP_FILE=$(create_backup "$WAYCORNER_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating waycorner config.toml..."
                    cp "$WAYCORNER_SRC" "$WAYCORNER_DEST"
                    print_success "Waycorner configuration updated"
                fi
            fi
        else
            print_step "Copying config.toml to $WAYCORNER_DEST..."
            cp "$WAYCORNER_SRC" "$WAYCORNER_DEST"
            print_success "Waycorner configured"
        fi
    fi

    # Add waycorner to Hyprland autostart
    HYPRLAND_AUTOSTART="$HOME/.config/hypr/autostart.conf"

    if [ -f "$HYPRLAND_AUTOSTART" ]; then
        if grep -q "waycorner" "$HYPRLAND_AUTOSTART"; then
            print_skip "Waycorner already in Hyprland autostart"
        else
            print_step "Adding waycorner to Hyprland autostart..."
            echo "" >> "$HYPRLAND_AUTOSTART"
            echo "# Hot corners" >> "$HYPRLAND_AUTOSTART"
            echo "exec-once = ~/.cargo/bin/waycorner" >> "$HYPRLAND_AUTOSTART"
            print_success "Waycorner added to Hyprland autostart"
        fi
    else
        print_error "Hyprland autostart.conf not found at $HYPRLAND_AUTOSTART"
        print_error "You'll need to manually add 'exec-once = ~/.cargo/bin/waycorner' to your Hyprland config"
    fi

    print_step "Starting waycorner for current session..."
    if pgrep -x waycorner >/dev/null 2>&1; then
        print_skip "Waycorner is already running"
    else
        "$HOME/.cargo/bin/waycorner" &>/dev/null &
        print_success "Waycorner started"
    fi
fi

################################################################################
# 12. Configure Waybar Idle Toggle
################################################################################

if [ "$INSTALL_WAYBAR" = true ]; then
    print_header "Configuring Waybar Idle Toggle"

    WAYBAR_CONFIG_SRC="$SCRIPT_DIR/config/waybar/config.jsonc"
    WAYBAR_CONFIG_DEST="$HOME/.config/waybar/config.jsonc"
    WAYBAR_STYLE_SRC="$SCRIPT_DIR/config/waybar/style.css"
    WAYBAR_STYLE_DEST="$HOME/.config/waybar/style.css"
    INDICATOR_SRC="$SCRIPT_DIR/config/waybar/indicators/idle-toggle.sh"
    INDICATOR_DEST="$HOME/.local/share/omarchy/default/waybar/indicators/idle-toggle.sh"

    # Install waybar configuration
    if [ ! -f "$WAYBAR_CONFIG_SRC" ]; then
        print_error "Source config.jsonc not found at $WAYBAR_CONFIG_SRC"
        print_error "Skipping waybar configuration..."
    else
        mkdir -p "$(dirname "$WAYBAR_CONFIG_DEST")"

        if [ -f "$WAYBAR_CONFIG_DEST" ]; then
            # Use diff if cmp is not available
            if command_exists cmp; then
                if cmp -s "$WAYBAR_CONFIG_SRC" "$WAYBAR_CONFIG_DEST"; then
                    print_skip "Waybar configuration already up to date"
                else
                    print_step "Backing up existing config.jsonc..."
                    BACKUP_FILE=$(create_backup "$WAYBAR_CONFIG_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating waybar config.jsonc..."
                    cp "$WAYBAR_CONFIG_SRC" "$WAYBAR_CONFIG_DEST"
                    print_success "Waybar configuration updated"
                fi
            else
                # Fallback to diff if cmp is not available
                if diff -q "$WAYBAR_CONFIG_SRC" "$WAYBAR_CONFIG_DEST" >/dev/null 2>&1; then
                    print_skip "Waybar configuration already up to date"
                else
                    print_step "Backing up existing config.jsonc..."
                    BACKUP_FILE=$(create_backup "$WAYBAR_CONFIG_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating waybar config.jsonc..."
                    cp "$WAYBAR_CONFIG_SRC" "$WAYBAR_CONFIG_DEST"
                    print_success "Waybar configuration updated"
                fi
            fi
        else
            print_step "Installing waybar config.jsonc to $WAYBAR_CONFIG_DEST..."
            cp "$WAYBAR_CONFIG_SRC" "$WAYBAR_CONFIG_DEST"
            print_success "Waybar configuration installed"
        fi
    fi

    # Install waybar style
    if [ ! -f "$WAYBAR_STYLE_SRC" ]; then
        print_error "Source style.css not found at $WAYBAR_STYLE_SRC"
        print_error "Skipping waybar style..."
    else
        mkdir -p "$(dirname "$WAYBAR_STYLE_DEST")"

        if [ -f "$WAYBAR_STYLE_DEST" ]; then
            # Use diff if cmp is not available
            if command_exists cmp; then
                if cmp -s "$WAYBAR_STYLE_SRC" "$WAYBAR_STYLE_DEST"; then
                    print_skip "Waybar style already up to date"
                else
                    print_step "Backing up existing style.css..."
                    BACKUP_FILE=$(create_backup "$WAYBAR_STYLE_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating waybar style.css..."
                    cp "$WAYBAR_STYLE_SRC" "$WAYBAR_STYLE_DEST"
                    print_success "Waybar style updated"
                fi
            else
                # Fallback to diff if cmp is not available
                if diff -q "$WAYBAR_STYLE_SRC" "$WAYBAR_STYLE_DEST" >/dev/null 2>&1; then
                    print_skip "Waybar style already up to date"
                else
                    print_step "Backing up existing style.css..."
                    BACKUP_FILE=$(create_backup "$WAYBAR_STYLE_DEST")
                    print_success "Backup created at $BACKUP_FILE"
                    print_step "Updating waybar style.css..."
                    cp "$WAYBAR_STYLE_SRC" "$WAYBAR_STYLE_DEST"
                    print_success "Waybar style updated"
                fi
            fi
        else
            print_step "Installing waybar style.css to $WAYBAR_STYLE_DEST..."
            cp "$WAYBAR_STYLE_SRC" "$WAYBAR_STYLE_DEST"
            print_success "Waybar style installed"
        fi
    fi

    # Install indicator script
    if [ ! -f "$INDICATOR_SRC" ]; then
        print_error "Source idle-toggle.sh not found at $INDICATOR_SRC"
        print_error "Skipping waybar idle toggle indicator..."
    else
        # Create destination directory if it doesn't exist
        mkdir -p "$(dirname "$INDICATOR_DEST")"

        if [ -f "$INDICATOR_DEST" ]; then
            # Use diff if cmp is not available
            if command_exists cmp; then
                if cmp -s "$INDICATOR_SRC" "$INDICATOR_DEST"; then
                    print_skip "Waybar idle toggle indicator already up to date"
                else
                    print_step "Updating idle-toggle.sh..."
                    cp "$INDICATOR_SRC" "$INDICATOR_DEST"
                    chmod +x "$INDICATOR_DEST"
                    print_success "Waybar idle toggle indicator updated"
                fi
            else
                # Fallback to diff if cmp is not available
                if diff -q "$INDICATOR_SRC" "$INDICATOR_DEST" >/dev/null 2>&1; then
                    print_skip "Waybar idle toggle indicator already up to date"
                else
                    print_step "Updating idle-toggle.sh..."
                    cp "$INDICATOR_SRC" "$INDICATOR_DEST"
                    chmod +x "$INDICATOR_DEST"
                    print_success "Waybar idle toggle indicator updated"
                fi
            fi
        else
            print_step "Installing idle-toggle.sh to $INDICATOR_DEST..."
            cp "$INDICATOR_SRC" "$INDICATOR_DEST"
            chmod +x "$INDICATOR_DEST"
            print_success "Waybar idle toggle indicator installed"
        fi

        print_step "Restarting Waybar to apply changes..."
        if command_exists omarchy-restart-waybar; then
            omarchy-restart-waybar &>/dev/null
            print_success "Waybar restarted"
        else
            if pgrep -x waybar >/dev/null 2>&1; then
                pkill -x waybar
                sleep 0.5
                waybar &>/dev/null &
                print_success "Waybar restarted"
            else
                print_skip "Waybar is not running"
            fi
        fi
    fi
fi

################################################################################
# Installation Complete
################################################################################

print_header "Installation Complete!"

echo -e "${GREEN}All tasks completed successfully!${NC}\n"

# Only show installed components summary if something was actually installed
if [ "$INSTALL_MAINLINE" = true ] || [ "$INSTALL_PACKAGES" = true ] || \
   [ "$INSTALL_CLAUDE" = true ] || [ "$INSTALL_CODEX" = true ] || \
   [ "$INSTALL_SCREENSAVER" = true ] || [ "$INSTALL_PLYMOUTH" = true ] || \
   [ "$INSTALL_PROMPT" = true ] || [ "$INSTALL_MACOS_KEYS" = true ] || \
   [ "$INSTALL_HYPRLAND_BINDINGS" = true ] || [ "$INSTALL_AUTO_TILE" = true ] || \
   [ "$INSTALL_WAYCORNER" = true ] || [ "$INSTALL_WAYBAR" = true ] || \
   [ "$INSTALL_SSH" = true ]; then

    echo -e "${BOLD}Installed/configured components:${NC}"

    if [ "$INSTALL_MAINLINE" = true ]; then
        echo -e "  • ${CYAN}linux-mainline${NC} kernel (Chaotic-AUR)"
    fi

    if [ "$INSTALL_PACKAGES" = true ]; then
        echo -e "  • System packages (npm, nano)"
    fi

    if [ "$INSTALL_CLAUDE" = true ]; then
        echo -e "  • Claude Code (${CYAN}claude${NC} command)"
    fi

    if [ "$INSTALL_CODEX" = true ]; then
        echo -e "  • Codex CLI (${CYAN}codex${NC} command)"
    fi

    if [ "$INSTALL_SCREENSAVER" = true ]; then
        echo -e "  • Custom screensaver"
    fi

    if [ "$INSTALL_PLYMOUTH" = true ]; then
        echo -e "  • Cybex Plymouth theme"
    fi

    if [ "$INSTALL_PROMPT" = true ]; then
        echo -e "  • Starship prompt configuration"
        echo -e "  • Fish-like tab completion (menu-complete)"
        echo -e "  • Fish-like autosuggestions (ble.sh)"
    fi

    if [ "$INSTALL_MACOS_KEYS" = true ]; then
        echo -e "  • macOS-style shortcuts (keyd + Alacritty)"
    fi

    if [ "$INSTALL_HYPRLAND_BINDINGS" = true ]; then
        echo -e "  • Hyprland bindings configuration"
    fi

    if [ "$INSTALL_AUTO_TILE" = true ]; then
        echo -e "  • Hyprland auto-tile helper"
    fi

    if [ "$INSTALL_WAYCORNER" = true ]; then
        echo -e "  • Waycorner hot corners for Hyprland"
    fi

    if [ "$INSTALL_WAYBAR" = true ]; then
        echo -e "  • Waybar idle toggle indicator"
    fi

    if [ "$INSTALL_SSH" = true ]; then
        echo -e "  • SSH key for GitHub"
    fi

    echo ""
fi

# Show SSH setup instructions only if SSH key was configured
if [ "$INSTALL_SSH" = true ]; then
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${MAGENTA}  GitHub SSH Setup${NC}"
    echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

    if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
        echo -e "${BOLD}Your SSH public key:${NC}\n"
        cat "$HOME/.ssh/id_ed25519.pub"
        echo -e "\n${BOLD}To add this key to GitHub:${NC}"
    else
        echo -e "${RED}SSH public key not found!${NC}\n"
        echo -e "${BOLD}To add your key to GitHub:${NC}"
    fi
    echo -e "  1. Copy the key above (entire line)"
    echo -e "  2. Go to ${CYAN}https://github.com/settings/ssh/new${NC}"
    echo -e "  3. Paste the key and give it a title (e.g., 'Omarchy Linux')"
    echo -e "  4. Click 'Add SSH key'\n"

    echo -e "${BOLD}To test the connection:${NC}"
    echo -e "  ${CYAN}ssh -T git@github.com${NC}\n"
fi

# Next steps section - only show if there are actual next steps
if [ "$INSTALL_CLAUDE" = true ] || [ "$INSTALL_CODEX" = true ] || \
   [ "$INSTALL_MAINLINE" = true ] || [ "$INSTALL_PLYMOUTH" = true ] || \
   [ "$INSTALL_MACOS_KEYS" = true ] || [ "$INSTALL_AUTO_TILE" = true ]; then

    echo -e "${BOLD}Next steps:${NC}"

    # PATH update reminder - show only if Claude or Codex were installed
    if [ "$INSTALL_CLAUDE" = true ] || [ "$INSTALL_CODEX" = true ]; then
        echo -e "  • Run ${CYAN}source ~/.bashrc${NC} or restart your shell to update PATH"
    fi

    # Fish-like tab completion and autosuggestions reminder
    if [ "$INSTALL_PROMPT" = true ]; then
        echo -e "  • ${BOLD}Restart your shell${NC} to enable Fish-like tab completion and autosuggestions"
        echo -e "    Or run: ${CYAN}exec bash${NC}"
    fi

    # Mainline kernel reboot reminder
    if [ "$INSTALL_MAINLINE" = true ]; then
        echo -e "  • ${BOLD}${YELLOW}Reboot to use the mainline kernel${NC}"
    fi

    # Plymouth theme reboot reminder
    if [ "$INSTALL_PLYMOUTH" = true ]; then
        echo -e "  • Reboot to see the new Plymouth boot splash"
    fi

    if [ "$INSTALL_MACOS_KEYS" = true ]; then
        echo -e "  • Reload Hyprland (${CYAN}hyprctl reload${NC}) and restart Alacritty to pick up the new shortcuts"
    fi

    if [ "$INSTALL_AUTO_TILE" = true ]; then
        echo -e "  • Reload Hyprland (${CYAN}hyprctl reload${NC}) if the auto-tile helper does not engage immediately"
    fi

    echo ""
fi
