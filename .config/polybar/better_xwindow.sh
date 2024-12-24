#!/usr/bin/env bash

# Get the current active monitor (e.g., from `xrandr`)
active_monitor=$(xrandr --listactivemonitors | grep '*' | awk '{print $4}')

# Ensure the monitor name is correctly formatted (strip extra spaces)
active_monitor=$(echo $active_monitor | tr -d '[:space:]')

# Get the dimensions and position of the active monitor (e.g., from `xrandr --verbose`)
monitor_geometry=$(xrandr --verbose | grep -A 1 "$active_monitor" | grep -E '^\s*[^ ]' | awk '{print $3}')

# If monitor_geometry is "primary", we need to get the correct geometry using another method
if [[ "$monitor_geometry" == "primary" ]]; then
    # Fallback to getting the geometry of the primary monitor
    monitor_geometry=$(xrandr --verbose | grep -A 1 "primary" | grep -E '^\s*[^ ]' | awk '{print $4}')
fi

# Extract width and height of the monitor (geometry format: widthxheight+X+Y)
monitor_width=$(echo $monitor_geometry | cut -d 'x' -f 1)
monitor_height_and_position=$(echo $monitor_geometry | cut -d 'x' -f 2)

# Extract position (X and Y) from monitor geometry string
monitor_height=$(echo $monitor_height_and_position | cut -d '+' -f 1)
monitor_x=$(echo $monitor_height_and_position | cut -d '+' -f 2)
monitor_y=$(echo $monitor_height_and_position | cut -d '+' -f 3)

# Debugging output: print the monitor width, height, and position
# echo "Monitor: $active_monitor"
# echo "Monitor Width: $monitor_width, Monitor Height: $monitor_height"
# echo "Monitor Position: X: $monitor_x, Y: $monitor_y"

# Get the list of windows and their positions using `wmctrl`
windows=$(wmctrl -lG)

# Filter windows based on their position matching the active monitor
filtered_windows=""
echo "$windows" | while read -r window; do
    # Extract window geometry (position and size)
    window_id=$(echo $window | awk '{print $1}')
    window_x=$(echo $window | awk '{print $2}')
    window_y=$(echo $window | awk '{print $3}')
    window_width=$(echo $window | awk '{print $4}')
    window_height=$(echo $window | awk '{print $5}')
    
    # Debugging output: print the window x, y, width, height
    echo "Window ID: $window_id, X: $window_x, Y: $window_y, Width: $window_width, Height: $window_height"

    # Check if the window's x and y coordinates are within the active monitor's geometry
    if [ "$window_x" -ge "$monitor_x" ] && [ "$window_x" -lt "$((monitor_x + monitor_width))" ] && \
       [ "$window_y" -ge "$monitor_y" ] && [ "$window_y" -lt "$((monitor_y + monitor_height))" ]; then
        filtered_windows+=$(echo $window | awk '{print $1, $5, $6}')"\n"
    fi
done

# Output the filtered windows (you can format this as needed for Polybar)
echo -e "$filtered_windows"
