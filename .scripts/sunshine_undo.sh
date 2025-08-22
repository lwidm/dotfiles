#!/usr/bin/env bash
#~/.scripts/sunshine_undo.sh
set -euo pipefail

BACKUP_DIR="${HOME}/.cache/sunshine"
SUN_CONF="/etc/sunshine/sunshine.conf"
timestamp=$(ls -1t ${BACKUP_DIR}/monitors-*.txt 2>/dev/null | head -n1 || true)

if [ -z "$timestamp" ]; then
  echo "No backup found in ${BACKUP_DIR} — manual restore may be required."
else
  echo "Restoring xrandr state from $timestamp (best-effort)..."
  # We can't perfectly restore arbitrary xrandr states, but we will attempt to bring back outputs mentioned
  grep -Eo '([A-Za-z0-9-]+) connected' "$timestamp" | awk '{print $1}' | while read -r out; do
    echo "Attempting to re-enable $out (mode autodetect)"
    xrandr --output "$out" --auto || true
  done
fi

# remove the virtual mode we added previously -- attempt to find a common mode name
VIRTUAL_MODE_CANDIDATES=$(ls ${BACKUP_DIR}/xrandr-full-*.txt 2>/dev/null | head -n1 || true)
# Best-effort: remove common mode names if they exist
for m in "2880x1800_60.00" "2560x1440_60.00" "2560x1440_59.95" "1920x1080_60.00"; do
  echo "Attempting to remove mode $m from all outputs"
  for out in $(xrandr | awk '/ connected| disconnected/ {print $1}'); do
    xrandr --output "$out" --off || true
    xrandr --delmode "$out" "$m" 2>/dev/null || true
  done
done

# restore sunshine.conf backup if it exists
if [ -f "${SUN_CONF}.bak"* ]; then
  latest_backup=$(ls -t ${SUN_CONF}.bak.* 2>/dev/null | head -n1 || true)
  if [ -n "$latest_backup" ]; then
    echo "Restoring sunshine.conf from $latest_backup (using sudo)"
    sudo cp "$latest_backup" "$SUN_CONF"
  fi
fi

# restart sunshine service
if systemctl --user status sunshine >/dev/null 2>&1; then
  systemctl --user restart sunshine || true
  sleep 1
  systemctl --user status sunshine --no-pager || true
else
  echo "systemd user service 'sunshine' not found; start manually if needed."
fi

echo "Restore script finished (best-effort)."

