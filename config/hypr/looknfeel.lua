-- Change the default Omarchy look'n'feel

local active_border_purple = "rgb(8f00ff)"
local inactive_border_color = "rgba(595959aa)"

hl.config({
  general = {
    col = {
      active_border = active_border_purple,
      inactive_border = inactive_border_color,
    },
    gaps_in = 0,
    gaps_out = 0,
    border_size = 1,
    layout = "master",
  },
  decoration = {
    rounding = 1,
    active_opacity = 1.0,
    inactive_opacity = 0.8,
  },
  group = {
    col = {
      border_active = active_border_purple,
      border_inactive = inactive_border_color,
    },
  },
})
