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
    RES_LAPTOP="2880x1800@120.00Hz"
    # RES_LAPTOP="1440x900@120.00Hz"   # logical size, scale=2 from 2880x1800@120
    RES1="1920x1080@60.00Hz"
    RES2="1920x1080@60.00Hz"

    # Positions based on your actual setup - USE COMMAS, not 'x'
    POS1="0x0"               # First external monitor position
    # POS2="2919,0"          # Second external monitor position
    POS_LAPTOP="240x1080"    # Laptop display position

    # Scaling factors
    SCALE_LAPTOP=2
    SCALE1=1
    SCALE2=1

    # Configure Monitors: Note: since i am using positive coordinates the screens need to be defined from top to bottom and left to right (the monitor with position "0x0" needs to be defined first)
    hyprctl keyword monitor "${MON1},${RES1},${POS1},${SCALE1}"
    hyprctl keyword monitor "${MON_LAPTOP},${RES_LAPTOP},${POS_LAPTOP},${SCALE_LAPTOP}"
    if hyprctl monitors | grep -q "HDMI-A-2"; then
	hyprctl keyword monitor "${MON2},${RES2},${POS2},${SCALE2}"
    fi

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
