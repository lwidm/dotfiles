#!/usr/bin/env bash
#~/.scripts/sunshine_do.sh
set -euo pipefail

# sunshine_do.sh
# Create a virtual display, disable physical monitors, set virtual as primary,
# and reconfigure Sunshine to capture that output.
#
# Run this as the graphical user (inside your X session). If DISPLAY is empty,
# the script will try :0.

# ----- CONFIG -----
VIRTUAL_W=2560
VIRTUAL_H=1440
VIRTUAL_R=60

VIRTUAL_MODE="${VIRTUAL_W}x${VIRTUAL_H}_${VIRTUAL_R}.00"
SUN_CONF="/etc/sunshine/sunshine.conf"   # system file (we use sudo to edit)
BACKUP_DIR="${HOME}/.cache/sunshine"
# ------------------

mkdir -p "$BACKUP_DIR"
timestamp=$(date +%s)

# ensure DISPLAY is set
if [ -z "${DISPLAY:-}" ]; then
  export DISPLAY=":0"
  echo "No DISPLAY set — using $DISPLAY"
fi

# save current connected outputs (so undo can restore)
xrandr --listmonitors > "${BACKUP_DIR}/monitors-${timestamp}.txt"
xrandr | sed -n '1,120p' > "${BACKUP_DIR}/xrandr-full-${timestamp}.txt"
echo "Saved xrandr output to ${BACKUP_DIR}"

#  find a disconnected output to use as virtual (first candidate)
VIRTUAL_PORT=$(xrandr | awk '/ disconnected/{print $1; exit}')
if [ -z "$VIRTUAL_PORT" ]; then
  echo "No disconnected output found. Falling back to 'VIRTUAL1' (may fail)."
  VIRTUAL_PORT="VIRTUAL1"
else
  echo "Found disconnected output: $VIRTUAL_PORT"
fi

# Build modeline
# We try to generate a modeline with cvt; if cvt missing, fallback to a common mode
if command -v cvt >/dev/null 2>&1; then
  MODELINE=$(cvt "$VIRTUAL_W" "$VIRTUAL_H" "$VIRTUAL_R" | tail -n 1 | sed 's/Modeline //')
else
  MODELINE="\"${VIRTUAL_MODE}\"  312.25  ${VIRTUAL_W} $(($VIRTUAL_W+224)) $(($VIRTUAL_W+536)) $(($VIRTUAL_W+1072))  ${VIRTUAL_H} $(($VIRTUAL_H+3)) $(($VIRTUAL_H+9)) $(($VIRTUAL_H+52)) -hsync +vsync"
  echo "cvt not found; using fallback modeline"
fi

# Create & add the mode (ignore errors if already exists)
echo "Creating mode on $VIRTUAL_PORT: $VIRTUAL_MODE"
set +e
xrandr --newmode $MODELINE
xrandr --addmode "$VIRTUAL_PORT" "$VIRTUAL_MODE"
xrandr --output "$VIRTUAL_PORT" --mode "$VIRTUAL_MODE" --primary
set -e

# Turn off other connected physical outputs (but keep pikvm or other if needed)
echo "Turning off other connected outputs..."
while read -r line; do
  out=$(printf '%s\n' "$line" | awk '{print $1}')
  state=$(printf '%s\n' "$line" | awk '{print $2}')
  if [ "$out" != "$VIRTUAL_PORT" ] && [ "$state" = "connected" ]; then
    echo "Turning off $out"
    xrandr --output "$out" --off || true
  fi
done < <(xrandr | awk '/ connected| disconnected/')

# back up and update sunshine.conf (use sudo)
if [ -f "$SUN_CONF" ]; then
  sudo cp "$SUN_CONF" "${SUN_CONF}.bak.$timestamp"
  # set capture to auto or virtual (we will set 'capture = auto' but also set output name)
  sudo bash -c "sed -i 's/^\\s*capture\\s*=\\s*.*/capture = auto/' '$SUN_CONF' || true"
  # set output_name — Sunshine accepts numeric index or a string; if it has a device name line, update it
  # we'll write output_name to the conf as the output string (the exact required value may vary)
  sudo bash -c "grep -q '^output_name' '$SUN_CONF' || echo '' >> '$SUN_CONF'"
  sudo bash -c "sed -i 's/^\\s*output_name\\s*=.*/output_name = ${VIRTUAL_PORT}/' '$SUN_CONF' || true"
  echo "Backed up and updated $SUN_CONF -> ${SUN_CONF}.bak.$timestamp"
else
  echo "Warning: $SUN_CONF not found; skipping config edit"
fi

# restart sunshine as the graphical user service
echo "Restarting Sunshine (user service)..."
# prefer systemd --user if available
if systemctl --user status sunshine >/dev/null 2>&1; then
  systemctl --user restart sunshine || true
  sleep 1
  systemctl --user status sunshine --no-pager || true
else
  echo "systemd user service 'sunshine' not found; try starting sunshine manually in a terminal to debug"
fi

echo "Done. Virtual output: $VIRTUAL_PORT  Mode: $VIRTUAL_MODE"
echo "If Sunshine doesn't start, run: journalctl --user -u sunshine -f  (or run 'sunshine' in a terminal for debug)"

