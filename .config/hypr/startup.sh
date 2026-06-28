#!/usr/bin/env bash
# ~/.config/hypr/startup.sh
# System-conditional startup launched via exec-once in hyprland.conf.
# Add per-system app launches below. MYSYSTEM should be set in /etc/environment
# or ~/.config/environment.d/ on each machine.

case "$MYSYSTEM" in
    OpenSuseDesktop|DebianDesktop)
        ~/.local/bin/sunshine.AppImage &
        ;;
esac
