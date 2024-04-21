#!/usr/bin/env bash

# initialize wallpaper daemon
swww-daemon &

# set wallpaper
swww img ~/.bg/nixos-wallpaper-catppuccin-latte.png &

waybar &
dunst
