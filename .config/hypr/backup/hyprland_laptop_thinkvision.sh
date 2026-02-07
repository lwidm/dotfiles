#!/usr/bin/env bash

if [[ "$MYSYSTEM" == "DebLaptop" || "$MYSYSTEM" == "DebianLaptop" || "$MYSYSTEM" == "ArchLaptop" ]]; then

    if ! hyprctl monitors | grep -q "DP-1"; then
        echo "DP-1 (ThinkVision M14t) not detected. Exiting."
        exit 0
    fi

    # Toggle: pass "left" or "right" as first argument (default: left)
    SIDE="${1:-left}"

    MON_LAPTOP="eDP-1"    # Laptop display
    MON_EXT="DP-1"        # ThinkVision M14t

    RES_LAPTOP="2880x1800@120.00Hz"
    RES_EXT="1920x1080@60.00Hz"

    SCALE_LAPTOP=2    # logical size: 1440x900
    SCALE_EXT=1       # logical size: 1920x1080

    # Vertical centering offset: (1080 - 900) / 2 = 90
    if [[ "$SIDE" == "right" ]]; then
        # ThinkVision to the right of laptop
        POS_LAPTOP="0x90"
        POS_EXT="1440x0"
    else
        # ThinkVision to the left of laptop (default)
        POS_LAPTOP="1920x90"
        POS_EXT="0x0"
    fi

    # Configure Monitors
    hyprctl keyword monitor "${MON_EXT},${RES_EXT},${POS_EXT},${SCALE_EXT}"
    hyprctl keyword monitor "${MON_LAPTOP},${RES_LAPTOP},${POS_LAPTOP},${SCALE_LAPTOP}"

    # Assign Workspaces to Monitors
    hyprctl keyword workspace "0,monitor:${MON_EXT}"
    hyprctl keyword workspace "9,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "8,monitor:${MON_EXT}"
    hyprctl keyword workspace "7,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "6,monitor:${MON_EXT}"
    hyprctl keyword workspace "5,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "4,monitor:${MON_EXT}"
    hyprctl keyword workspace "3,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "2,monitor:${MON_EXT}"
    hyprctl keyword workspace "1,monitor:${MON_LAPTOP},default:true"

    hyprctl keyword workspace "100,monitor:${MON_EXT}"
    hyprctl keyword workspace "90,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "80,monitor:${MON_EXT}"
    hyprctl keyword workspace "70,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "60,monitor:${MON_EXT}"
    hyprctl keyword workspace "50,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "40,monitor:${MON_EXT}"
    hyprctl keyword workspace "30,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "20,monitor:${MON_EXT}"
    hyprctl keyword workspace "10,monitor:${MON_LAPTOP}"

    xrandr --output ${MON_LAPTOP} --primary

    eww open bar2 >/dev/null 2>&1 || true

    hyprctl dispatch focusmonitor 0
fi
