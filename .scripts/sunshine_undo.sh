#!/usr/bin/env bash
# Sunshine "Undo" prep command — restore normal monitor layout.
# Must exit immediately; Sunshine times out if this blocks.
# The daemon restores the layout synchronously on startup, then keeps
# running in the background to handle future hotplug events.
python3 /home/lukas/.config/hypr/monitor-setup.py --daemon >/dev/null 2>&1 &
disown
exit 0
