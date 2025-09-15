#!/usr/bin/env bash
# ~/.config/eww/scripts/powerbutton.sh

# If /tmp/eww_powermenu_shown exists and is <= GRACE seconds old -> poweroff
# Otherwise open the menu for GRACE seconds.

FLAG=/tmp/eww_powermenu_shown
GRACE=5   # seconds the menu stays revealed (adjust if you like)
NOW=$(date +%s)

# helper: safe read timestamp (0 if missing/invalid)
read_ts() {
  if [[ -f "$FLAG" ]]; then
    cat "$FLAG" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

TS=$(read_ts)
AGE=$(( NOW - TS ))

if [[ -f "$FLAG" && $AGE -le $GRACE ]]; then
  # recent reveal -> treat click as confirmation: shutdown
  systemctl /usr/bin/hyprlock
  exit $?
else
  # not recently revealed -> reveal, write timestamp and auto-hide after GRACE
  echo "$NOW" > "$FLAG"
  eww update show_powermenu=true
  sleep "$GRACE"
  eww update show_powermenu=false
  rm -f "$FLAG"
fi
