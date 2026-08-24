-- Personal input overrides and gestures

hl.config({
  input = {
    kb_layout = "us,ru",
    kb_options = "compose:right_alt,caps:backspace",
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

-- 3-finger horizontal workspace swipe
hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })
