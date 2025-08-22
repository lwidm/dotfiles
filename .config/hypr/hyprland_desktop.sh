#!/usr/bin/env bash

if [[ "$MYSYSTEM" == "DebDesktop" || "$MYSYSTEM" == "ArchDesktop" ]]; then

    MON1="DP-0.8"       # First 1440p monitor
    MON2="DP-2"         # Second 1440p monitor (to be rotated)
    MON4K="DP-4.2"      # 4K monitor
    PIKVM="DP-4.3"      # PiKVM display (1080p)

    # Calculate positions
    POS1="0x560"         # First monitor position
    POS4K="2560x560"     # 4K monitor position
    POS2="5120x0"        # Second monitor position
    POSPIKVM="6560x0"    # PiKVM monitor position
    SCALING4K=1.666666666666666

    # Configure Monitors
    hyprctl keyword monitor "${MON1},   2560x1440@120,    ${POS1},        1"
    hyprctl keyword monitor "${MON4K},  3840x2160@60,     ${POS4K},       ${SCALING4K}"
    hyprctl keyword monitor "${MON2},   2560x1440@144,    ${POS2},        1"
    hyprctl keyword monitor "${PIKVM},  1920x1080@50,     ${POSPIKVM},    1"

    # Assign Workspaces to Monitors
    hyprctl keyword workspace "1, monitor:${MON4K}, default:true"
    hyprctl keyword workspace "4, monitor:${MON4K}, default:false"
    hyprctl keyword workspace "2, monitor:${MON1}, default:true"
    hyprctl keyword workspace "5, monitor:${MON1}, default:false"
    hyprctl keyword workspace "3, monitor:${MON2}, default:true"
    hyprctl keyword workspace "6, monitor:${MON2}, default:false"

    hyprctl keyword workspace "9, monitor:${PIKVM}, default:true"
fi
