#!/bin/sh

# If all your bars have ipc enabled, you can use
polybar-msg cmd quit
# Otherwise you can use the nuclear option:
# killall -q polybar

# Luanch bar1 and bar2
echo "---" | tee /tmp/polybarCustom.log 
polybar custom 2>&1 | tee -a /tmp/polybarCustom.log & disown

echo "Bars launched..."
