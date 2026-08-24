-- Extra autostart processes
hl.on("hyprland.start", function()
  hl.exec_cmd("pkill hypridle || true")
  hl.exec_cmd("omarchy-touchpad-gestures || true")
  hl.exec_cmd("hyprsunset || true")
end)
