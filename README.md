# Personal Omarchy Dotfiles

My personal configurations and custom tools for Omarchy (Arch Linux + Hyprland).

## Structure

* `config/hypr/` — Hyprland monitor setups, input rules, custom keybindings.
* `config/waybar/` — Top status bar modules and styling.
* `config/omarchy/` — Omarchy theme overrides, hooks, and weather settings.
* `bin/` — Custom utility scripts (e.g. `omarchy-menu-display` for `Super + P`).

## Sync Changes

To pull latest config changes from your system into this repo:
```bash
./sync.sh
git add .
git commit -m "Update configs"
git push
```

## Push to Remote

```bash
git remote add origin git@github.com:YOUR_USERNAME/dotfiles.git
git branch -M main
git push -u origin main
```
