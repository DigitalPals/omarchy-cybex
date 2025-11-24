# Archived Bash Configuration Files

These files were used by the previous `prompt` option to provide Fish-like features in bash. They have been replaced by the `fish` option which installs native Fish shell via omarchy-fish.

## Archived Files

- **blerc** - Configuration for ble.sh (Bash Line Editor) that provided Fish-like autosuggestions
- **completion.inputrc** - Readline configuration for Fish-like tab completion in bash

## Why Archived

As of the migration to omarchy-fish, these files are no longer needed because:
1. Fish shell has native autosuggestions and syntax highlighting (no need for ble.sh)
2. Fish has its own completion system (no need for .inputrc)
3. The omarchy-fish package provides better integration and performance

These files are kept for reference but are not used by the current installer.

## Migration Notes

If you previously used `./install.sh prompt`, you can migrate to Fish shell with:
```bash
./install.sh fish
```

This will:
- Install the omarchy-fish package
- Preserve your Starship prompt configuration
- Configure Fish to auto-launch from bash (maintaining Omarchy boot compatibility)
- Provide superior autosuggestions and completions natively
