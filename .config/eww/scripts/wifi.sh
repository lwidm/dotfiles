#!/usr/bin/env bash

status=$(nmcli g | grep -oE "disconnected")
essid=$(nmcli c | grep wlp0s20f3 | awk '{print ($1)}')

if [ $status ] ; then
    icon="󰤫"
    text=""
    col="#ab0000"

else
    icon="󰤨"
    text="${essid}"
    col="#a1bdce"
fi



if [[ "$1" == "--COL" ]]; then
    echo $col	
elif [[ "$1" == "--ESSID" ]]; then
	echo $text
elif [[ "$1" == "--ICON" ]]; then
	echo $icon
fi
