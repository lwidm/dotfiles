#!/usr/bin/env bash

## Get status
get_status() {
	status=$(playerctl status 2>/dev/null)
	
	if [[ "${status}" == "Playing" ]]; then
		echo ""
	elif [[ "${status}" == "Paused" ]]; then
		echo ""
	else
		# This includes Stopped state and no player found
		echo "Offline"
	fi
}

## Get song (title)
get_song() {
	song=$(playerctl metadata --format "{{ title }}" 2>/dev/null)
	if [[ -z "$song" ]]; then
		echo "Offline"
	else
		echo "$song"
	fi
}

## Get artist
get_artist() {
	artist=$(playerctl metadata --format "{{ artist }}" 2>/dev/null)
	if [[ -z "$artist" ]]; then
		echo ""
	else
		echo "$artist"
	fi
}

## Get album
get_album() {
	album=$(playerctl metadata --format "{{ album }}" 2>/dev/null)
	if [[ -z "$album" ]]; then
		echo ""
	else
		echo "$album"
	fi
}

## Get volume (0.0 to 1.0)
get_volume() {
	volume=$(playerctl volume 2>/dev/null)
	if [[ -z "$volume" ]]; then
		echo "0"
	else
		# Convert to percentage (0-100)
		echo "$volume * 100" | bc
	fi
}

## Get current position in seconds
get_ctime() {
	ctime=$(playerctl metadata --format "{{ duration(position) }}" 2>/dev/null)
	if [[ -z "$ctime" || "$ctime" == "0:00" ]]; then
		echo "0:00"
	else
		echo "$ctime"
	fi
}

## Get total track time
get_ttime() {
	ttime=$(playerctl metadata --format "{{ duration(mpris:length) }}" 2>/dev/null)
	if [[ -z "$ttime" || "$ttime" == "0:00" ]]; then
		echo "0:00"
	else
		echo "$ttime"
	fi
}

get_progress() {
    status=$(playerctl status 2>/dev/null)
    if [[ "$status" != "Playing" && "$status" != "Paused" ]]; then
        echo "0"
        return
    fi
    current_time=$(get_ctime)
    total_time=$(get_ttime)
    current_seconds=$(echo "$current_time" | awk -F: '{if (NF==2) print $1*60+$2; else if (NF==3) print $1*3600+$2*60+$3}')
    total_seconds=$(echo "$total_time" | awk -F: '{if (NF==2) print $1*60+$2; else if (NF==3) print $1*3600+$2*60+$3}')
    if [[ -z "$current_seconds" || -z "$total_seconds" || "$total_seconds" -eq 0 ]]; then
        echo "0"
    else
        awk "BEGIN {printf \"%.0f\", ($current_seconds / $total_seconds) * 100}" 2>/dev/null || echo "0"
    fi
}

## Get cover art URL/path (if available)
get_cover() {
	# Note: This depends on the player providing this metadata
	artUrl=$(playerctl metadata mpris:artUrl 2>/dev/null)
	
	if [[ -n "$artUrl" ]]; then
		# If it's a file URL, convert to path
		if [[ "$artUrl" =~ ^file:// ]]; then
			echo "${artUrl#file://}"
		else
			# For other types (http, etc.), you might want different handling
			echo "$artUrl"
		fi
	else
		# Fallback cover
		echo "images/music.png"
	fi
}

## Execute accordingly
case "$1" in
	--song)
		get_song
		;;
	--artist)
		get_artist
		;;
	--album)
		get_album
		;;
	--status)
		get_status
		;;
	--volume)
		get_volume
		;;
	--ctime)
		get_ctime
		;;
	--ttime)
		get_ttime
		;;
	--cover)
		get_cover
		;;
	--toggle)
		playerctl play-pause
		;;
	--next)
		playerctl next
		# The cover might change after skipping
		;;
	--prev)
		playerctl previous
		;;
	--progress)
		get_progress
		;;
	*)
		echo "Usage: $0 {--song|--artist|--album|--status|--volume|--ctime|--ttime|--cover|--toggle|--next|--prev|--progress}"
		exit 1
		;;
esac
