#!/usr/bin/env bash

# Virtual display cleanup
VIRTUAL_PORT="HDMI-0"
VIRTUAL_MODE="2880x1800_60.00"

# Disable virtual display
xrandr --output $VIRTUAL_PORT --off
xrandr --delmode $VIRTUAL_PORT "$VIRTUAL_MODE"
xrandr --rmmode "$VIRTUAL_MODE"

# Restore physical monitors using your existing script
/home/lukas/.scripts/monitor-scaling.sh

# Reset Sunshine to physical display capture
sunshine stop
sed -i 's/^\(capture\s*=\s*\).*$/\1auto/' /etc/sunshine/sunshine.conf
sunshine start

echo "Original monitor configuration restored"
