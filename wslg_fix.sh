#!/usr/bin/env sh

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root. Use sudo or switch to root."
    exit 1
fi

rm -rf /tmp/.X11-unix
ln -s /mnt/wslg/.X11-unix /tmp/.X11-unix

echo "X11 Unix socket link updated successfully"
