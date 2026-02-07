#!/usr/bin/env bash

# ~/.config/eww/scripts/restart_eww.sh
# Detached, safe restart of eww daemon and re-open dynamic bars.

DYNAMIC_BARS="$HOME/.config/eww/dynamic_bars.yuck"

# Run in background so this script is not killed by pkill eww
(
  sleep 0.08
  pkill -x eww >/dev/null 2>&1 || true
  sleep 0.08

  # Regenerate bar definitions from current monitor state
  python3 ~/.config/hypr/monitor-setup.py --eww-only >/dev/null 2>&1

  setsid eww daemon >/dev/null 2>&1 &
  for i in {1..12}; do
    sleep 0.08
    pgrep -x eww >/dev/null && break
  done

  # Open all dynamically defined bars
  if [ -f "$DYNAMIC_BARS" ]; then
    grep -oP '(?<=\(defwindow )\S+' "$DYNAMIC_BARS" | while read -r bar; do
      eww open "$bar" >/dev/null 2>&1 || true
    done
  fi
) & disown
