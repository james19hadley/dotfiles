-- Personal input overrides and gestures

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
      clickfinger_behavior = true,
      tap_to_click = true,
    },
  },
})

-- Clear any stale gestures
pcall(function() hl.gesture({ fingers = 3, direction = "horizontal", action = "unset" }) end)
pcall(function() hl.gesture({ fingers = 4, direction = "horizontal", action = "unset" }) end)
pcall(function() hl.gesture({ fingers = 3, direction = "vertical", action = "unset" }) end)
pcall(function() hl.gesture({ fingers = 4, direction = "vertical", action = "unset" }) end)
pcall(function() hl.gesture({ fingers = 3, direction = "up", action = "unset" }) end)
pcall(function() hl.gesture({ fingers = 3, direction = "down", action = "unset" }) end)
pcall(function() hl.gesture({ fingers = 4, direction = "up", action = "unset" }) end)
pcall(function() hl.gesture({ fingers = 4, direction = "down", action = "unset" }) end)

-- Set 3-finger horizontal workspace swipe
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
