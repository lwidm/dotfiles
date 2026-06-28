#!/usr/bin/env bash
# Sunshine "Do" prep command — switch to remote-desktop mode.
# Sunshine sets SUNSHINE_CLIENT_WIDTH / HEIGHT / FPS as environment variables
# before running this script, so they are available directly.
set -euo pipefail

W="${SUNSHINE_CLIENT_WIDTH:-}"
H="${SUNSHINE_CLIENT_HEIGHT:-}"
FPS="${SUNSHINE_CLIENT_FPS:-}"

if [[ -n "$W" && -n "$H" && -n "$FPS" ]]; then
    RES="${W}x${H}@${FPS}"
else
    RES="preferred"
fi

exec python3 /home/lukas/.config/hypr/monitor-setup.py --remote-desktop "$RES"
