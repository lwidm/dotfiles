#!/usr/bin/env bash

export XDG_CURRENT_DESKTOP=Hyprland
export WAYLAND_DISPLAY=wayland-1  # Confirm with `echo $WAYLAND_DISPLAY`
export HYPRLAND_INSTANCE_SIGNATURE=$(ls /tmp/hypr/ | grep -o "hyprland-.*")
/usr/bin/hyprlock
