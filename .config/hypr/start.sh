#!/usr/bin/env bash

# initialize wallpaper daemon
swww init &
# set wallpaper
swww img ~/.bg/nixos-wallpaper-catppuccin-latte.svg &

waybar &
dunst
