#!/usr/bin/env bash

# Virtual display configuration
VIRTUAL_PORT="HDMI-0"
VIRTUAL_RES="2880x1800"
VIRTUAL_MODE="2880x1800_60.00"

# Generate modeline using cvt
MODELINE=$(cvt 2880 1800 60 | tail -n 1 | sed 's/Modeline //')
if [ -z "$MODELINE" ]; then
    MODELINE="\"2880x1800_60.00\"  312.25  2880 3104 3416 3952  1800 1803 1809 1852 -hsync +vsync"
fi

# Create and assign virtual mode
xrandr --newmode $MODELINE
xrandr --addmode $VIRTUAL_PORT "$VIRTUAL_MODE"

# Disable physical monitors
xrandr --output DP-0.8 --off
xrandr --output DP-2 --off
xrandr --output DP-4.2 --off
xrandr --output DP-4.3 --off

# Enable virtual display
xrandr --output $VIRTUAL_PORT --mode "$VIRTUAL_MODE" --primary

# Configure Sunshine for virtual display
sunshine stop
sed -i 's/^\(capture\s*=\s*\).*$/\1virtual/' /etc/sunshine/sunshine.conf
sed -i 's/^\(output_name\s*=\s*\).*$/\1HDMI-0/' /etc/sunshine/sunshine.conf
sunshine start

echo "Virtual display enabled: $VIRTUAL_RES on $VIRTUAL_PORT"
