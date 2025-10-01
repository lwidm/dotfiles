#!/usr/bin/env bash

if [[ "$MYSYSTEM" == "DebLaptop" || "$MYSYSTEM" == "DebianLaptop" || "$MYSYSTEM" == "ArchLaptop" ]]; then

    if ! hyprctl monitors | grep -q "HDMI-A-1"; then
        echo "HDMI-A-1 not detected. Exiting."
        exit 0
    fi

    MON_LAPTOP="eDP-1"    # Laptop display
    MON1="HDMI-A-1"       # First external monitor
    MON2=""               # Second external monitor

    # Resolutions and refresh rates based on your actual setup
    RES_LAPTOP="2880x1800@60.00Hz"
    # RES_LAPTOP="2880x1800@120.00Hz"
    RES1="1920x1080@60.00Hz"
    RES2="1920x1080@60.00Hz"

    # Positions based on your actual setup - USE COMMAS, not 'x'
    POS_LAPTOP="0x0"    # Laptop display position
    POS1="-260x-1080"               # First external monitor position
    # POS2="2919,0"          # Second external monitor position

    # Scaling factors
    SCALE_LAPTOP=2
    SCALE1=1
    SCALE2=1

    # Configure Monitors
    hyprctl keyword monitor "${MON_LAPTOP},${RES_LAPTOP},${POS_LAPTOP},${SCALE_LAPTOP}"
    if hyprctl monitors | grep -q "HDMI-A-2"; then
	hyprctl keyword monitor "${MON2},${RES2},${POS2},${SCALE2}"
    fi
    hyprctl keyword monitor "${MON1},${RES1},${POS1},${SCALE1}"

    # Assign Workspaces to Monitors
    hyprctl keyword workspace "0,monitor:${MON1}"
    hyprctl keyword workspace "9,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "8,monitor:${MON1}"
    hyprctl keyword workspace "7,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "6,monitor:${MON1}"
    hyprctl keyword workspace "5,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "4,monitor:${MON1}"
    hyprctl keyword workspace "3,monitor:${MON_LAPTOP}"
    hyprctl keyword workspace "2,monitor:${MON1}"
    hyprctl keyword workspace "1,monitor:${MON_LAPTOP},default:true"

    xrandr --output ${MON_LAPTOP} --primary

    hyprctl dispatch focusmonitor 0
fi
