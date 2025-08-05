#!/bin/bash
# NVIDIA Multi-Monitor Scaling Script
# Save as ~/bin/monitor-scaling.sh
if [[ "$MYSYSTEM" == "DebianDesktop" || "$MYSYSTEM" == "DebDesktop" ]]; then

    # Monitor identifiers
    MON1="DP-4.8"       # First 1440p monitor
    MON2="DP-2"     # Second 1440p monitor (to be rotated)
    # MON4K="DP-4.8"        # 4K monitor
    MON4K="DP-0.8"        # 4K monitor

    # Calculate positions
    POS1="0x560"         # First monitor position
    POS2="5248x0"        # Second monitor position
    POS4K="2560x200"     # 4K monitor position

    # Apply scaling configuration
    # xrandr --output $MON4K --mode 3840x2160 --scale 1.5x1.5 --pos $POS4K --panning 3840x2160+2560+200 --primary
    xrandr --output $MON4K --mode 3840x2160 --scale 0.7x0.7 --pos $POS4K  --primary
    xrandr --output $MON1 --mode 2560x1440 --pos $POS1
    xrandr --output $MON2 --mode 2560x1440 --rotate right --pos $POS2

    # Enable NVIDIA composition pipeline
    # nvidia-settings --assign CurrentMetaMode="\
    # $MON1: 2560x1440_60 +0+560 {ForceFullCompositionPipeline=On}, \
    # $MON2: 2560x1440_60 +6400+0 {ForceFullCompositionPipeline=On, Rotation=90}, \
    # $MON4K: 3840x2160_60 +2560+200 { \
    #     ViewPortIn=3840x2160, \
    #     ViewPortOut=2560x1440+0+0, \
    #     ForceFullCompositionPipeline=On}"

    # Set global DPI
    xrandr --dpi 96

    # Notify user
    echo "Monitor scaling applied: 150% to 4K display, MON2 rotated right"
fi
