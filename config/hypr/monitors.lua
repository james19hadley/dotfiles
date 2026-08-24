-- Monitor setup & scaling
local omarchy_gdk_scale = 1
local omarchy_monitor_scale = 1.25

hl.env("GDK_SCALE", tostring(omarchy_gdk_scale))
hl.monitor({ output = "eDP-1", mode = "preferred", position = "0x0", scale = omarchy_monitor_scale })
hl.monitor({ output = "", mode = "preferred", position = "auto-right", scale = 1 })
