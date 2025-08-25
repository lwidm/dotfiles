#!/usr/bin/env bash

if [[ "$MYSYSTEM" == "DebLaptop" || "$MYSYSTEM" == "DebianLaptop" || "$MYSYSTEM" == "ArchLaptop" ]]; then
	hyprctl keyword input:kb_options caps:swapescape
fi
