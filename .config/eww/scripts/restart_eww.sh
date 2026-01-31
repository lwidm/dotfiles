#!/usr/bin/env bash

# ~/.config/eww/scripts/restart_eww.sh
# Detached, safe restart of eww daemon and re-open bar0.

# Run in background so this script is not killed by pkill eww
(
  sleep 0.08
  pkill -x eww >/dev/null 2>&1 || true
  sleep 0.08
  setsid eww daemon >/dev/null 2>&1 &
  for i in {1..12}; do
    sleep 0.08
    pgrep -x eww >/dev/null && break
  done
  eww open bar0 >/dev/null 2>&1 || true
  eww open bar1 >/dev/null 2>&1 || true
  eww open bar2 >/dev/null 2>&1 || true
) & disown
