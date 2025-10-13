#!/usr/bin/env bash
# music_info - unified music info for MPD (mpc) and MPRIS players (playerctl)
# Usage: music_info --song|--artist|--status|--time|--ctime|--ttime|--cover|--toggle|--next|--prev

set -euo pipefail

COVER="/tmp/.music_cover.png"
MUSIC_DIR="$HOME/Music"   # used only for mpd fallback

# helper: prefer playerctl (MPRIS) if available
has_playerctl() {
  command -v playerctl >/dev/null 2>&1
}

# choose active player
# returns player name on stdout or empty if none
choose_player() {
  if ! has_playerctl; then
    echo ""
    return
  fi

  # list players
  players=$(playerctl -l 2>/dev/null || true)
  if [[ -z "$players" ]]; then
    echo ""
    return
  fi

  # prefer player with "Playing" status, else first player
  for p in $players; do
    if playerctl -p "$p" status 2>/dev/null | grep -iq '^Playing$'; then
      echo "$p"
      return
    fi
  done

  # no playing player, return first available
  # (choose the first that responds)
  for p in $players; do
    if playerctl -p "$p" status >/dev/null 2>&1; then
      echo "$p"
      return
    fi
  done

  echo ""
}

# ---------------- MPRIS (playerctl) helpers ----------------
mpris_status() {
  playerctl -p "$PLAYER" status 2>/dev/null || echo "Stopped"
}

mpris_song() {
  playerctl -p "$PLAYER" metadata xesam:title 2>/dev/null || \
    playerctl -p "$PLAYER" metadata title 2>/dev/null || echo ""
}

mpris_artist() {
  # xesam:artist can be an array, playerctl prints it joined by ", "
  playerctl -p "$PLAYER" metadata xesam:artist 2>/dev/null || \
    playerctl -p "$PLAYER" metadata artist 2>/dev/null || echo ""
}

# position in seconds (with decimals)
mpris_position() {
  playerctl -p "$PLAYER" position 2>/dev/null || echo "0"
}

# duration in seconds (playerctl exposes length via mpris:length in microseconds)
mpris_length() {
  # some playerctl versions support 'metadata mpris:length'
  len=$(playerctl -p "$PLAYER" metadata mpris:length 2>/dev/null || true)
  if [[ -n "$len" ]]; then
    # mpris:length is in microseconds
    awk "BEGIN { printf \"%.0f\", $len/1000000 }"
  else
    # fallback: try metadata xesam:contentCreated or duration not available
    echo "0"
  fi
}

mpris_cover() {
  # try to fetch art URL
  arturl=$(playerctl -p "$PLAYER" metadata mpris:artUrl 2>/dev/null || true)
  arturl=${arturl:-$(playerctl -p "$PLAYER" metadata xesam:artUrl 2>/dev/null || true)}
  arturl=${arturl:-""}
  if [[ -z "$arturl" ]]; then
    echo ""
    return
  fi

  # if file:// local file, strip prefix and copy
  if [[ "$arturl" =~ ^file:// ]]; then
    path=${arturl#file://}
    if [[ -f "$path" ]]; then
      cp -f "$path" "$COVER" 2>/dev/null || true
      echo "$COVER"
      return
    fi
  fi

  # if http(s) use curl to download
  if [[ "$arturl" =~ ^https?:// ]]; then
    # try curl, fallback to wget
    if command -v curl >/dev/null 2>&1; then
      curl -sSfL "$arturl" -o "$COVER" || rm -f "$COVER"
    elif command -v wget >/dev/null 2>&1; then
      wget -qO "$COVER" "$arturl" || rm -f "$COVER"
    fi
    if [[ -f "$COVER" ]]; then
      echo "$COVER"
      return
    fi
  fi

  # nothing found
  echo ""
}

# ---------------- MPD (mpc) helpers ----------------
mpd_song() {
  mpc -f %title% current 2>/dev/null || echo ""
}
mpd_artist() {
  mpc -f %artist% current 2>/dev/null || echo ""
}
mpd_status() {
  STATUS_RAW=$(mpc status 2>/dev/null || true)
  if [[ $STATUS_RAW == *"[playing]"* ]]; then
    echo "Playing"
  elif [[ $STATUS_RAW == *"[paused]"* ]]; then
    echo "Paused"
  else
    echo "Stopped"
  fi
}
mpd_position_seconds() {
  # parse "xx:yy (NN%)" format from mpc status
  pos=$(mpc status 2>/dev/null | awk '/%/ {print $3}' | tr -d '()%')
  echo "${pos:-0}"
}
mpd_ctime() {
  # current time like "1:23"
  mpc status 2>/dev/null | awk '/%/ {print $1}' | tr -d '()' || echo "0:00"
}
mpd_ttime() {
  mpc -f %time% current 2>/dev/null || echo "0:00"
}
mpd_cover() {
  # try ffmpeg as before
  file=$(mpc current -f %file% 2>/dev/null || true)
  if [[ -n "$file" ]]; then
    ffmpeg -i "${MUSIC_DIR}/${file}" "${COVER}" -y &>/dev/null || rm -f "$COVER"
    if [[ -f "$COVER" ]]; then
      echo "$COVER"
      return
    fi
  fi
  echo ""
}

# ---------------- choose backend ----------------
PLAYER=""
if has_playerctl; then
  PLAYER=$(choose_player)
fi

USE_MPRIS=false
if [[ -n "$PLAYER" ]]; then
  # ensure player responds
  if playerctl -p "$PLAYER" status >/dev/null 2>&1; then
    USE_MPRIS=true
  fi
fi

# ---------------- public API functions ----------------
get_status() {
  if $USE_MPRIS; then
    s=$(mpris_status)
    # normalize to single words like "Playing"/"Paused"
    if [[ -z "$s" ]]; then s="Stopped"; fi
    echo "$s"
  else
    mpd_status
  fi
}

get_song() {
  if $USE_MPRIS; then
    mpris_song
  else
    mpd_song
  fi
}

get_artist() {
  if $USE_MPRIS; then
    mpris_artist
  else
    mpd_artist
  fi
}

# return percentage elapsed (0-100)
get_time() {
  if $USE_MPRIS; then
    pos=$(mpris_position)
    # mpris position may be float seconds
    pos=${pos:-0}
    len=$(mpris_length)
    if [[ -z "$len" || "$len" -le 0 ]]; then
      echo "0"
      return
    fi
    # integer percent
    awk "BEGIN { printf \"%d\", ($pos / $len) * 100 }"
  else
    # mpd provides percent via mpc status in format "xx:yy (NN%)"
    perc=$(mpc status 2>/dev/null | awk '/%/ {gsub(/\(|\)/,\"\",$3); sub(/%/,\"\",$3); print $3; exit}')
    echo "${perc:-0}"
  fi
}

get_ctime() {
  if $USE_MPRIS; then
    pos=$(mpris_position)
    # format seconds to M:SS
    awk "BEGIN {sec=$pos; m=int(sec/60); s=int(sec%60); printf \"%d:%02d\", m, s }"
  else
    mpd_ctime
  fi
}

get_ttime() {
  if $USE_MPRIS; then
    len=$(mpris_length)
    awk "BEGIN {sec=$len; m=int(sec/60); s=int(sec%60); printf \"%d:%02d\", m, s }"
  else
    mpd_ttime
  fi
}

get_cover() {
  if $USE_MPRIS; then
    art=$(mpris_cover)
    if [[ -n "$art" ]]; then
      echo "$art"
      return
    fi
    # fallback to mpd cover extraction
    mpd_cover
  else
    mpd_cover
  fi
}

# control commands (toggle/next/prev) - operate on chosen player or mpd
do_toggle() {
  if $USE_MPRIS; then
    playerctl -p "$PLAYER" play-pause
  else
    mpc -q toggle
  fi
}
do_next() {
  if $USE_MPRIS; then
    playerctl -p "$PLAYER" next
  else
    { mpc -q next; get_cover; }
  fi
}
do_prev() {
  if $USE_MPRIS; then
    playerctl -p "$PLAYER" previous
  else
    { mpc -q prev; get_cover; }
  fi
}

# ---------------- main CLI dispatch ----------------
case "${1:-}" in
  --song)   get_song ;;
  --artist) get_artist ;;
  --status) get_status ;;
  --time)   get_time ;;
  --ctime)  get_ctime ;;
  --ttime)  get_ttime ;;
  --cover)  get_cover ;;
  --toggle) do_toggle ;;
  --next)   do_next ;;
  --prev)   do_prev ;;
  *) 
    echo "Usage: $0 [--song|--artist|--status|--time|--ctime|--ttime|--cover|--toggle|--next|--prev]"
    exit 1
    ;;
esac
