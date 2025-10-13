#!/usr/bin/env bash

set -euo pipefail

THRESHOLDS=(30 20 15 10 5)

declare -A NOTIFIED

BAT_PATH="/sys/class/power_supply/BAT0/capacity"
STATUS_PATH="/sys/class/power_supply/BAT0/status"

while true; do
    if [[ ! -f "$BAT_PATH" ]]; then
        echo "Battery info not found at $BAT_PATH"
        exit 1
    fi

    CAP=$(cat "$BAT_PATH")
    STATUS=$(cat "$STATUS_PATH") # "Charging", "Discharging", or "Full"

    # Only notify if discharging
    if [[ "$STATUS" == "Discharging" ]]; then
        for T in "${THRESHOLDS[@]}"; do
            if (( CAP <= T )) && [[ -z "${NOTIFIED[$T]:-}" ]]; then
                # Determine urgency
                if (( T <= 15 )); then
                    URGENCY="critical"
                else
                    URGENCY="normal"
                fi

                notify-send "Battery Low" "Battery at ${CAP}%" --urgency="$URGENCY" --hint=string:type:battery
                NOTIFIED[$T]=1
            fi
        done
    fi

    if [[ "$STATUS" == "Charging" ]] && (( CAP > 30 )); then
        unset NOTIFIED
        declare -A NOTIFIED
    fi

    sleep 60
done
