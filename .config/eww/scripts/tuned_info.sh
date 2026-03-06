#!/bin/bash

profile=$(cat /etc/tuned/active_profile 2>/dev/null || echo "unknown")

case "$profile" in
  "desktop")                icon="󰍹" ;;
  "powersave")              icon="󰌪" ;;
  "balanced-battery")       icon="󰾆" ;;
  "balanced")               icon="󰾅" ;;
  "throughput-performance") icon="󰓅" ;;
  *)                        icon="󰘚" ;;
esac

echo "{\"profile\": \"$profile\", \"icon\": \"$icon\"}"
