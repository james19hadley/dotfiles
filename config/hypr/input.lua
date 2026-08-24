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
      drag_3fg = 0,
    },
  },
})

-- Touchpad Workspace & Window Gestures (3 & 4 fingers)
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })

-- 3-finger vertical gestures
hl.gesture({ fingers = 3, direction = "up", action = function() hl.dispatch(hl.dsp.fullscreen()) end })
hl.gesture({ fingers = 3, direction = "down", action = function() hl.dispatch(hl.dsp.togglefloating()) end })

-- 4-finger vertical gestures
hl.gesture({ fingers = 4, direction = "up", action = function() hl.exec_cmd("omarchy-menu toggle") end })
hl.gesture({ fingers = 4, direction = "down", action = function() hl.exec_cmd("omarchy-shell -q io.github.spencerbull.omapilot toggle") end })
