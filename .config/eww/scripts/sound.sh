#!/usr/bin/env bash

# Volume status script with icon and percentage output options
# Usage: volume-status.sh [--icon|--percent]

get_volume_info() {
    # Check if default sink is muted
    local muted=$(pactl get-sink-mute @DEFAULT_SINK@ | grep -o 'yes\|no')
    local volume=$(pactl get-sink-volume @DEFAULT_SINK@ | grep -oE '[0-9]+%' | head -1 | tr -d '%')
    
    echo "$muted:$volume"
}

main() {
    local option="${1:---percent}"
    IFS=':' read -r muted volume <<< "$(get_volume_info)"
    
    case "$option" in
        --icon)
            if [ "$muted" = "yes" ] || [ "$volume" -eq 0 ]; then
                echo "󰖁"  # Muted icon
            elif [ "$volume" -lt 50 ]; then
                echo ""  # Low volume icon
            else
                echo ""  # High volume icon
            fi
            ;;
        --percent)
            if [ "$muted" = "yes" ]; then
                echo "0"
            else
                printf "%02d" "$volume"  # Two-digit format
            fi
            ;;
        *)
            echo "Usage: $0 [--icon|--percent]"
            exit 1
            ;;
    esac
}

main "$@"
