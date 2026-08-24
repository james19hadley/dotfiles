#!/bin/bash

# Sync current system configs into dotfiles repo

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Syncing Hyprland configs..."
mkdir -p "$DOTFILES_DIR/config/hypr"
cp -a ~/.config/hypr/*.conf ~/.config/hypr/*.lua "$DOTFILES_DIR/config/hypr/" 2>/dev/null || true

echo "==> Syncing Waybar configs..."
mkdir -p "$DOTFILES_DIR/config/waybar"
cp -a ~/.config/waybar/config.jsonc ~/.config/waybar/style.css "$DOTFILES_DIR/config/waybar/" 2>/dev/null || true

echo "==> Syncing Omarchy configs..."
mkdir -p "$DOTFILES_DIR/config/omarchy"
cp -r ~/.config/omarchy/* "$DOTFILES_DIR/config/omarchy/" 2>/dev/null || true

echo "==> Syncing custom scripts..."
mkdir -p "$DOTFILES_DIR/bin"
cp -a ~/.local/bin/omarchy-* ~/.local/bin/display-menu "$DOTFILES_DIR/bin/" 2>/dev/null || true

# Clean nested git, bak files, and compiled binaries
find "$DOTFILES_DIR" -name "*.bak.*" -delete 2>/dev/null || true
find "$DOTFILES_DIR/config/omarchy/themes" -name ".git" -exec rm -rf {} + 2>/dev/null || true
rm -f "$DOTFILES_DIR/bin/uv" "$DOTFILES_DIR/bin/uvx" "$DOTFILES_DIR/bin/lore"* "$DOTFILES_DIR/bin/antigravity" "$DOTFILES_DIR/bin/zed" 2>/dev/null || true

echo "==> Dotfiles synced successfully!"
echo "Run 'git status' and 'git commit' in $DOTFILES_DIR to save changes."
