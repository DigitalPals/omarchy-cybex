# Fish shell configuration for Omarchy
# Installed by: ./install.sh fish
#
# This configuration is applied after omarchy-fish sets up the Fish shell.
# User customizations can be added to this file or placed in separate files
# in ~/.config/fish/conf.d/ which are sourced automatically.

# Add ~/.local/bin to PATH if not already present (for Claude Code, Codex, etc.)
if not contains ~/.local/bin $PATH
    set -gx PATH ~/.local/bin $PATH
end

# Initialize Starship prompt
# The starship.toml configuration is located at ~/.config/starship.toml
starship init fish | source

# Initialize zoxide (smart cd - provided by omarchy-fish)
# This is typically already initialized by omarchy-fish, but including it here
# ensures it works if you copy this config elsewhere
if command -v zoxide > /dev/null
    zoxide init fish | source
end

# Optional: Add custom aliases here
# Example:
# alias ll='eza -la --icons'
# alias gs='git status'

# Optional: Add custom abbreviations (Fish's smart aliases)
# Abbreviations expand when you press space or enter
# Example:
# abbr -a gco git checkout
# abbr -a gst git status
# abbr -a dc docker-compose

# Optional: Set environment variables
# Example:
# set -gx EDITOR nano
# set -gx VISUAL nano

# Note: Fish automatically provides:
# - Syntax highlighting
# - Autosuggestions (gray text from history)
# - Tab completion with descriptions
# - Command history search with Ctrl+R (provided by omarchy-fish fzf integration)
