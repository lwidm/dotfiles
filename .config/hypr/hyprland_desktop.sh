#!/usr/bin/env bash
















if [[ "$MYSYSTEM" == "DebDesktop" || "$MYSYSTEM" == "DebianDesktop" || "$MYSYSTEM" == "ArchDesktop" ]]; then

    export LIBVA_DRIVER_NAME=nvidia
    export XDG_SESSION_TYPE=wayland
    export GBM_BACKEND=nvidia-drm
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export WLR_NO_HARDWARE_CURSORS=1

    # MON1="DP-0.8"       # First 1440p monitor (Dell U2724D)
    # MON2="DP-2"         # Second 1440p monitor (Dell S2719DGF)
    # MON4K="DP-4.2"      # Second 4K monitor (Dell U2723QE)
    # PIKVM="DP-4.3"      # PiKVM display
    # DUMMY="HDMI-0"      # Dummy 4K monitor (BBC HDP-V105)

    MON1="DP-4"         # First 1440p monitor (Dell U2724D)
    MON2="DP-5"         # Second 1440p monitor (Dell S2719DGF)
    MON4K="DP-7"        # Second 4K monitor (Dell U2723QE)
    PIKVM="DP-8"        # PiKVM display
    DUMMY="HDMI-A-2"    # Dummy 4K monitor (BBC HDP-V105)

    # Resolutions and refresh rates based on your actual setup
    RES1="2560x1440@59.95"
    RES2="2560x1440@60"
    RES4K="3840x2160@60"
    RESPIK="1920x1080@60"
    RESDUMY="2560@1440@60"

    # Positions based on your actual setup
    # POS1="0x380"          # First monitor position
    # POS4K="2560x380"      # 4K monitor to the right of first monitor
    # POS2="5120x0"         # Second monitor to the right of 4K monitor
    # POSPIKVM="6560x0"     # PiKVM monitor to the right of second monitor
    POS1="0x560"            # First monitor position
    POS4K="2560x560"        # 4K monitor to the right of first monitor
    POS2="4960x0"	    # Second monitor to the right of 4K monitor
    POSPIKVM="6560x740"     # PiKVM monitor to the right of second monitor

    # Scaling factors
    SCALE1=1
    SCALE2=1
    SCALE4K=1.6
    SCALEPIK=1

    # Configure Monitors
    hyprctl keyword monitor "${DUMMY},disable"

    hyprctl keyword monitor "${MON1},${RES1},${POS1},${SCALE1}"
    hyprctl keyword monitor "${MON4K},${RES4K},${POS4K},${SCALE4K},preferred"
    hyprctl keyword monitor "${MON2},${RES2},${POS2},${SCALE2},transform,3"
    hyprctl keyword monitor "${PIKVM},${RESPIK},${POSPIKVM},${SCALEPIK}"

    # Assign Workspaces to Monitors
    hyprctl keyword workspace "9,monitor:${PIKVM}"

    hyprctl keyword workspace "6,monitor:${MON2}"
    hyprctl keyword workspace "5,monitor:${MON2}"
    hyprctl keyword workspace "4,monitor:${MON1}"
    hyprctl keyword workspace "3,monitor:${MON1}"
    hyprctl keyword workspace "2,monitor:${MON4K}"
    hyprctl keyword workspace "1,monitor:${MON4K},default:true"

    xrandr --output ${MON4K} --primary

    hyprctl dispatch focusmonitor 1
fi
