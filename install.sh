#!/bin/bash

################################################################################
# Omarchy Linux Post-Installation Setup Script
# https://omarchy.org
#
# This script sets up personal preferences after a fresh Omarchy installation.
# It is designed to be idempotent - safe to run multiple times.
#
# Usage:
#   ./install.sh          - Standard installation
#   ./install.sh mainline - Install with latest mainline kernel
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

################################################################################
# Command Line Arguments
################################################################################

INSTALL_MAINLINE=false

# Parse command line arguments
if [ "$1" = "mainline" ]; then
    INSTALL_MAINLINE=true
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

print_header "System Validation Checks"

# Check for sudo availability
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

# Check internet connectivity
print_step "Checking internet connectivity..."
if ! ping -c 1 -W 3 8.8.8.8 &>/dev/null && ! ping -c 1 -W 3 1.1.1.1 &>/dev/null; then
    print_error "No internet connection detected. This script requires internet access."
    print_error "Please check your network connection and try again."
    exit 1
fi
print_success "Internet connection verified"

# Check disk space (need at least 1GB free on root)
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

    if package_installed "linux-mainline"; then
        print_skip "linux-mainline kernel already installed"
    else
        print_step "Installing linux-mainline kernel..."
        sudo pacman -S --noconfirm linux-mainline
        print_success "linux-mainline kernel installed"
    fi

    # Update bootloader configuration
    print_step "Updating bootloader configuration..."
    if command_exists grub-mkconfig; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
        print_success "GRUB configuration updated"
    elif command_exists bootctl; then
        print_skip "systemd-boot detected - no configuration needed"
    else
        print_error "Unknown bootloader - please update manually"
    fi

    echo -e "${YELLOW}⚠${NC}  ${BOLD}Reboot required to use the mainline kernel${NC}\n"
fi

################################################################################
# 1. Install System Packages
################################################################################

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

################################################################################
# 2. Install Claude Code
################################################################################

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
    print_skip "Claude Code is already installed"
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

################################################################################
# 3. Install Codex CLI
################################################################################

print_header "Installing Codex CLI"

if command_exists codex; then
    print_skip "Codex CLI is already installed"
else
    print_step "Installing Codex CLI globally..."
    npm install -g @openai/codex --prefix "$HOME/.local"
    print_success "Codex CLI installed"
fi

################################################################################
# 4. Configure Screensaver
################################################################################

print_header "Configuring Screensaver"

SCREENSAVER_SRC="$SCRIPT_DIR/screensaver.txt"
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
                print_step "Updating screensaver.txt..."
                cp "$SCREENSAVER_SRC" "$SCREENSAVER_DEST"
                print_success "Screensaver updated"
            fi
        else
            # Fallback to diff if cmp is not available
            if diff -q "$SCREENSAVER_SRC" "$SCREENSAVER_DEST" >/dev/null 2>&1; then
                print_skip "Screensaver is already up to date"
            else
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

################################################################################
# 5. Install Plymouth Theme
################################################################################

print_header "Installing Plymouth Theme (Cybex)"

PLYMOUTH_SRC="$SCRIPT_DIR/plymouth/themes/cybex"
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
        cd "$PLYMOUTH_SRC"
        sudo find . -type f ! -path '*/\.*' -exec cp --parents {} "$PLYMOUTH_DEST/" \;
        cd - >/dev/null
        print_success "Plymouth theme files installed"
    else
        print_skip "Plymouth theme directory already exists"
        print_step "Updating Plymouth theme files..."
        # Copy all files except hidden directories like .claude
        cd "$PLYMOUTH_SRC"
        sudo find . -type f ! -path '*/\.*' -exec cp --parents {} "$PLYMOUTH_DEST/" \;
        cd - >/dev/null
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

################################################################################
# 6. Generate SSH Key for GitHub
################################################################################

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

################################################################################
# Installation Complete
################################################################################

print_header "Installation Complete!"

echo -e "${GREEN}All tasks completed successfully!${NC}\n"
echo -e "${BOLD}Installed tools:${NC}"
if [ "$INSTALL_MAINLINE" = true ]; then
    echo -e "  • ${CYAN}linux-mainline${NC} kernel (Chaotic-AUR)"
fi
echo -e "  • npm, nano"
echo -e "  • Claude Code (${CYAN}claude${NC} command)"
echo -e "  • Codex CLI (${CYAN}codex${NC} command)"
echo -e "  • Custom screensaver"
echo -e "  • Cybex Plymouth theme"
echo -e "  • SSH key for GitHub\n"

echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}${MAGENTA}  GitHub SSH Setup${NC}"
echo -e "${BOLD}${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

if [ -f "$SSH_PUB_KEY" ]; then
    echo -e "${BOLD}Your SSH public key:${NC}\n"
    cat "$SSH_PUB_KEY"
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

echo -e "${BOLD}Other next steps:${NC}"
echo -e "  • Run ${CYAN}source ~/.bashrc${NC} or restart your shell to update PATH"
if [ "$INSTALL_MAINLINE" = true ]; then
    echo -e "  • ${BOLD}${YELLOW}Reboot to use the mainline kernel${NC}"
fi
echo -e "  • Reboot to see the new Plymouth boot splash\n"
