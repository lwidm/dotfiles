#!/usr/bin/env bash

if [[ "$MYSYSTEM" == "DebLaptop" || "$MYSYSTEM" == "DebianLaptop" || "$MYSYSTEM" == "ArchLaptop" ]]; then
	hyprctl keyword input:kb_options caps:swapescape
	hyprctl keyword input:touchpad:scroll_factor 0.5

	# Configure laptop monitor with proper resolution and scaling
	hyprctl keyword monitor "eDP-1,2880x1800@120.00Hz,0x0,2"
fi
