#!/usr/bin/env bash

set -euo pipefail

if [ ! -d /sys/class/power_supply/BAT0 ]; then
    echo '{"percent": "0", "icon": "󰚥", "capacity": "0"}'
    exit 0
fi

# Your existing battery logic here...

# usage: battery_info.sh [percent|icon|both|json]
mode=${1:-icon}

# find first battery capacity
CAP=""
for b in /sys/class/power_supply/*; do
  if [[ -f "$b/capacity" ]]; then
    CAP=$(cat "$b/capacity" 2>/dev/null || echo "")
    break
  fi
done

# sanitize / defaults
CAP=${CAP%%[^0-9]*}   # strip anything after non-digit
[ -z "$CAP" ] && CAP=0
# clamp
if (( CAP < 0 )); then CAP=0; fi
if (( CAP > 100 )); then CAP=100; fi

# icon mapping exactly as you requested
if   (( CAP >= 95 )); then ICON="󰁹"
elif (( CAP >= 90 )); then ICON="󰂂"
elif (( CAP >= 80 )); then ICON="󰂁"
elif (( CAP >= 70 )); then ICON="󰂀"
elif (( CAP >= 60 )); then ICON="󰁿"
elif (( CAP >= 50 )); then ICON="󰁾"
elif (( CAP >= 40 )); then ICON="󰁽"
elif (( CAP >= 30 )); then ICON="󰁼"
elif (( CAP >= 20 )); then ICON="󰁻"
elif (( CAP >= 10 )); then ICON="󰁺"
elif (( CAP >= 5  )); then ICON="󰂎"
else                    ICON="󱃍"
fi

case "$mode" in
  percent) printf '%s\n' "$CAP" ;;
  icon)    printf '%s\n' "$ICON" ;;
  both)    printf '%s\n%s\n' "$CAP" "$ICON" ;;
  json)    printf '{"percent":%s,"icon":"%s"}\n' "$CAP" "$ICON" ;;
  *)       printf '%s\n' "$ICON" ;;
esac
