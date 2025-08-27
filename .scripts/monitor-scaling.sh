#!/bin/bash

# NVIDIA Multi-Monitor Scaling Script
#
if [[ "$MYSYSTEM" == "DebianDesktop" || "$MYSYSTEM" == "DebDesktop" ]]; then

    # Monitor identifiers
    MON1="DP-0.8"       # First 1440p monitor
    MON2="DP-2"         # Second 1440p monitor (to be rotated)
    MON4K="DP-4.2"      # 4K monitor
    PIKVM="DP-4.3"      # PiKVM display (1080p)

    # Calculate positions
    POS1="0x560"         # First monitor position
    NVIDIA_POS1="+0+560"
    POS4K="2560x560"     # 4K monitor position
    NVIDIA_POS4K="+2560+560"
    POS2="5120x0"        # Second monitor position
    NVIDIA_POS2="+5120+0"
    POSPIKVM="6560x740"        # Second monitor position
    NVIDIA_POSPIKVM="+6560+740"
    SCALING4K=0.666666666666666

    # Enable NVIDIA composition pipeline
    nvidia-settings --assign CurrentMetaMode="\
        $MON1:  2560x1440_60 $NVIDIA_POS1  {ForceFullCompositionPipeline=On}, \
        $MON2:  2560x1440_60 $NVIDIA_POS2  {ForceFullCompositionPipeline=On,Rotation=270}, \
        $MON4K: 3840x2160_60 $NVIDIA_POS4K {ForceFullCompositionPipeline=On} \
        $PIKVM: 1920x1080_30 $NVIDIA_POSPIKVM {ForceFullCompositionPipeline=On}"

    # Apply scaling configuration
    xrandr --fb 6560x2560
    xrandr --output $MON4K --mode 3840x2160 --rate 60 --scale ${SCALING4K}x${SCALING4K} --pos $POS4K
    xrandr --output $MON1 --mode 2560x1440 --rate 60 --auto --pos $POS1
    xrandr --output $MON2 --mode 2560x1440 --rate 60 --rotate right --pos $POS2
    xrandr --output $MONPIKVM --mode 1920x1080 --rate 30--pos $POSPIKVM

    # Mirror 4K display to PiKVM (1080p)
    # xrandr --output $PIKVM --mode 1920x1080 --scale-from 2560x1440 --same-as $MON4K


    # Set global DPI
    xrandr --dpi 96

    # Notify user
    echo "Monitor scaling applied: 150% to 4K display, MON2 rotated right"
fi
