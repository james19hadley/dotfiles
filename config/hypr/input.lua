-- Keep only your personal input overrides here.
hl.config({
  input = {
    kb_layout = "us,ru",
    kb_options = "compose:right_alt,grp:win_space_toggle,caps:backspace",
    repeat_rate = 40,
    repeat_delay = 200,
    numlock_by_default = true,
    sensitivity = 0.35,
    touchpad = {
      natural_scroll = true,
      scroll_factor = 0.4,
    },
  },
})

-- App-specific touchpad scroll speeds
o.window("(Alacritty|kitty|foot)", { scroll_touchpad = 1.5 })
o.window("com.mitchellh.ghostty", { scroll_touchpad = 0.2 })
