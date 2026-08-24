hl.unbind("SUPER + SPACE")
-- Application bindings
o.bind("SUPER + ALT + RETURN", "Tmux", "uwsm-app -- xdg-terminal-exec --dir=\"$(omarchy-cmd-terminal-cwd)\" tmux new")
o.bind("SUPER + RETURN", "Terminal", "uwsm-app -- xdg-terminal-exec --dir=\"$(omarchy-cmd-terminal-cwd)\"")
o.bind("SUPER + F", "File manager", "uwsm-app -- nautilus --new-window")
o.bind("SUPER + B", "Browser", "omarchy-launch-browser")
o.bind("SUPER + SHIFT + B", "Browser (private)", "omarchy-launch-browser --private")
o.bind("SUPER + M", "Music", "omarchy-launch-or-focus spotify")
o.bind("SUPER + N", "Editor", "omarchy-launch-editor")
o.bind("SUPER + T", "Activity", "omarchy-launch-tui btop")
o.bind("SUPER + D", "Docker", "omarchy-launch-tui lazydocker")
o.bind("SUPER + G", "Signal", "omarchy-launch-or-focus signal 'uwsm app -- signal-desktop'")
o.bind("SUPER + O", "Obsidian", "omarchy-launch-or-focus obsidian 'uwsm-app -- obsidian'")
o.bind("SUPER + slash", "Passwords", "uwsm-app -- 1password")

-- Display switcher (Super + P)
hl.unbind("SUPER + P")
o.bind("SUPER + P", "Display switcher", "/home/ging/.local/bin/omarchy-menu-display")

-- Custom Webapps & assistants
o.bind("SUPER + A", "FICSIT ADA Assistant", "/home/ging/.local/bin/ada look")
o.bind("SUPER + SHIFT + A", "Grok", "omarchy-launch-webapp 'https://grok.com'")
o.bind("SUPER + C", "Calendar", "omarchy-launch-webapp 'https://app.hey.com/calendar/weeks/'")
o.bind("SUPER + E", "Email", "omarchy-launch-webapp 'https://app.hey.com'")
o.bind("SUPER + Y", "YouTube", "omarchy-launch-or-focus-webapp YouTube 'https://youtube.com/'")
o.bind("SUPER + SHIFT + G", "WhatsApp", "omarchy-launch-or-focus-webapp WhatsApp 'https://web.whatsapp.com/'")
o.bind("SUPER + ALT + G", "Google Messages", "omarchy-launch-or-focus-webapp 'Google Messages' 'https://messages.google.com/web/conversations'")
o.bind("SUPER + X", "X", "omarchy-launch-webapp 'https://x.com/'")
o.bind("SUPER + SHIFT + X", "X Post", "omarchy-launch-webapp 'https://x.com/compose/post'")

-- Workspace switches
o.bind("SUPER + TAB", "Previous workspace", hl.dsp.focus({ workspace = "previous" }))
o.bind("SUPER + ALT + RIGHT", "Next workspace", hl.dsp.focus({ workspace = "r+1" }))
o.bind("SUPER + ALT + L", "Next workspace", hl.dsp.focus({ workspace = "r+1" }))
o.bind("SUPER + ALT + LEFT", "Previous workspace", hl.dsp.focus({ workspace = "r-1" }))
o.bind("SUPER + ALT + H", "Previous workspace", hl.dsp.focus({ workspace = "r-1" }))

o.bind("SUPER + ALT + SHIFT + RIGHT", "Move window to next workspace", hl.dsp.window.move({ workspace = "r+1" }))
o.bind("SUPER + ALT + SHIFT + L", "Move window to next workspace", hl.dsp.window.move({ workspace = "r+1" }))
o.bind("SUPER + ALT + SHIFT + LEFT", "Move window to prev workspace", hl.dsp.window.move({ workspace = "r-1" }))
o.bind("SUPER + ALT + SHIFT + H", "Move window to prev workspace", hl.dsp.window.move({ workspace = "r-1" }))

-- Scroll through workspaces with SUPER + scroll
hl.bind("SUPER", hl.dsp.focus({ workspace = "r+1" }), { mouse = "mouse_down" })
hl.bind("SUPER", hl.dsp.focus({ workspace = "r-1" }), { mouse = "mouse_up" })

-- Fullscreen screenshot directly to clipboard
o.bind("CTRL + PRINT", "Fullscreen screenshot to clipboard", "bash -c 'grim - | wl-copy && notify-send -u low \"📸 Screenshot copied to clipboard\"'")

-- Nightlight controls
o.bind("SUPER + F6", "Cooler screen", "omarchy-sunset cooler")
o.bind("SUPER + F7", "Warmer screen", "omarchy-sunset warmer")
o.bind("SUPER + F8", "Warm mode", "omarchy-sunset warm")
o.bind("SUPER + F9", "Reset color temp", "omarchy-sunset reset")

-- Mouse keyboard mod (CTRL + ALT + keys)
local mouse_speed = 15
o.bind("CTRL + ALT + L", "Mouse right", "ydotool mousemove --relative -- " .. mouse_speed .. " 0", { repeating = true })
o.bind("CTRL + ALT + H", "Mouse left", "ydotool mousemove --relative -- -" .. mouse_speed .. " 0", { repeating = true })
o.bind("CTRL + ALT + K", "Mouse up", "ydotool mousemove --relative -- 0 -" .. mouse_speed, { repeating = true })
o.bind("CTRL + ALT + J", "Mouse down", "ydotool mousemove --relative -- 0 " .. mouse_speed, { repeating = true })

o.bind("CTRL + ALT + Y", "Mouse up-left", "ydotool mousemove --relative -- -" .. mouse_speed .. " -" .. mouse_speed, { repeating = true })
o.bind("CTRL + ALT + O", "Mouse up-right", "ydotool mousemove --relative -- " .. mouse_speed .. " -" .. mouse_speed, { repeating = true })
o.bind("CTRL + ALT + B", "Mouse down-left", "ydotool mousemove --relative -- -" .. mouse_speed .. " " .. mouse_speed, { repeating = true })
o.bind("CTRL + ALT + slash", "Mouse down-right", "ydotool mousemove --relative -- " .. mouse_speed .. " " .. mouse_speed, { repeating = true })

o.bind("CTRL + ALT + N", "Mouse left click", "ydotool key 272:1 272:0")
o.bind("CTRL + ALT + M", "Mouse middle click", "ydotool key 274:1 274:0")
o.bind("CTRL + ALT + comma", "Mouse right click", "ydotool key 273:1 273:0")

o.bind("CTRL + ALT + U", "Mouse scroll up", "bash -c 'ydotool scroll -- -15 0'", { repeating = true })
o.bind("CTRL + ALT + I", "Mouse scroll down", "bash -c 'ydotool scroll -- 15 0'", { repeating = true })

-- Open Omarchy menu on single Super tap (release)
o.bind("SUPER + SUPER_L", "Omarchy Menu", "omarchy-menu toggle", { release = true })

-- OmaPilot AI Assistant bindings
o.bind("SUPER + I", "OmaPilot AI", "omarchy-shell -q io.github.spencerbull.omapilot toggle")
o.bind("SUPER + SHIFT + I", "OmaPilot Voice", "omarchy-shell -q io.github.spencerbull.omapilot voiceToggle")
o.bind("SUPER + ALT + A", "ADA Quote", "ada quote")
