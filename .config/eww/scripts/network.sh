#!/usr/bin/env bash

# Each element: {"type","icon","name","color","device"}
# Consumed by the `wifi_module` widget in eww.yuck.

COL_UP="#a1bdce"
COL_DOWN="#ab0000"

icon_for() {
    case "$1" in
        ethernet) printf '\xf3\xb0\x88\x80' ;;  # 󰈀
        wifi)     printf '\xf3\xb0\xa4\xa8' ;;  # 󰤨
        *)        printf '\xf3\xb0\xa4\xab' ;;  # 󰤫
    esac
}

json_escape() {
    printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

# 1. Active ethernet/wifi connections -> "device:type:connection"
mapfile -t devices < <(
    nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device status \
        | awk -F: '$3 == "connected" && ($2 == "ethernet" || $2 == "wifi") \
                   { print $1 ":" $2 ":" $4 }'
)

# 2. Default-route metric per device (lower = higher priority)
declare -A metric
while read -r dev m; do
    [ -n "$dev" ] && metric["$dev"]="$m"
done < <(
    ip route show default | awk '{
        d=""; m=99999;
        for (i = 1; i <= NF; i++) {
            if ($i == "dev")    d = $(i + 1);
            if ($i == "metric") m = $(i + 1);
        }
        if (d != "") print d, m;
    }'
)

# 3. Sort devices by metric (devices without a default route -> 99999)
mapfile -t ordered < <(
    for line in "${devices[@]}"; do
        dev=${line%%:*}
        m=${metric[$dev]:-99999}
        printf '%s\t%s\n' "$m" "$line"
    done | sort -n -k1,1 | cut -f2-
)

# 4. Emit JSON
printf '['
if [ ${#ordered[@]} -eq 0 ]; then
    printf '{"type":"none","icon":"%s","name":"","color":"%s","device":""}' \
        "$(icon_for none)" "$COL_DOWN"
else
    first=1
    for line in "${ordered[@]}"; do
        dev=$(printf '%s' "$line" | cut -d: -f1)
        type=$(printf '%s' "$line" | cut -d: -f2)
        name=$(printf '%s' "$line" | cut -d: -f3-)
        [ $first -eq 0 ] && printf ','
        first=0
        printf '{"type":"%s","icon":"%s","name":"%s","color":"%s","device":"%s"}' \
            "$type" "$(icon_for "$type")" "$(json_escape "$name")" "$COL_UP" "$(json_escape "$dev")"
    done
fi
printf ']\n'
