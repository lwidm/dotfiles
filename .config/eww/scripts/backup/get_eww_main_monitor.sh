#!/usr/bin/env sh

msystem="${MYSYSTEM:-}"
# lowercase for forgiving matching
ms_lc=$(printf '%s' "$msystem" | tr '[:upper:]' '[:lower:]')

case "$ms_lc" in
  archdesktop|debiandesktop|debdesktop)
    printf '2'
    ;;
  *)
    printf '0'
    ;;
esac
