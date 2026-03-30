# Default file explorer
if command -v pcmanfm >/dev/null 2>&1; then
  xdg-mime default pcmanfm.desktop inode/directory
fi

# Autostart ssh-agent
if [[ "$MYSYSTEM" = "DebianDesktop" || "$MYSYSTEM" = "DebianLaptop" || "$MYSYSTEM" = "DebDesktop" || "$MYSYSTEM" = "DebLaptop" || "$MYSYSTEM" = "ArchDesktop" || "$MYSYSTEM" = "ArchLaptop" || "$MYSYSTEM" = "OpenSuseDesktop" || "$MYSYSTEM" = "OpenSuseLaptop" || "$MYSYSTEM" = "wslDebianDesktop" || "$MYSYSTEM" = "wslDebianLaptop" ]]; then
  # if [[ -z "$DISPLAY" ]] && [[ "$(tty)" = "/dev/tty1" ]]; then
  #   eval "$(ssh-agent -s)" > /dev/null
  # fi
  # if [[ -n $SSH_CONNECTION ]] && [[ -t 1 ]]; then
  #   eval "$(ssh-agent -s)" > /dev/null
  # fi
  if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
  fi
fi


if [[ "$MYSYSTEM" = "DebianDesktop" ]]; then
  export LIBVA_DRIVER_NAME=nvidia
  export GBM_BACKEND=nvidia-drm
  export __GLX_VENDOR_LIBRARY_NAME=nvidia
  export WLR_NO_HARDWARE_CURSORS=1
  #
  # export GTK_SCALE=2
  # export GDK_DPI_SCALE=0.5
  # export QT_AUTO_SCREEN_SCALE_FACTOR=1
  # export QT_SCALE_FACTOR=2
fi

if [[ "$MYSYSTEM" = "ArchDesktop" ]]; then
  export LIBVA_DRIVER_NAME=nvidia
  export GBM_BACKEND=nvidia-drm
  export __GLX_VENDOR_LIBRARY_NAME=nvidia
  export WLR_NO_HARDWARE_CURSORS=1

  # export GTK_SCALE=2
  # export GDK_DPI_SCALE=0.5
  # export QT_AUTO_SCREEN_SCALE_FACTOR=1
  # export QT_SCALE_FACTOR=2
  if [[ -z "$DISPLAY" ]] && [[ "$(tty)" = "/dev/tty1" ]]; then
    start-hyprland
  fi
fi

if [[ "$MYSYSTEM" = "ArchLaptop" ]]; then
  if [[ -z "$DISPLAY" ]] && [[ "$(tty)" = "/dev/tty1" ]]; then
    start-hyprland
  fi
fi

if [[ "$MYSYSTEM" = "OpenSuseDesktop" ]]; then
  export LIBVA_DRIVER_NAME=nvidia
  export GBM_BACKEND=nvidia-drm
  export __GLX_VENDOR_LIBRARY_NAME=nvidia
  export WLR_NO_HARDWARE_CURSORS=1

  if [[ -z "$DISPLAY" ]] && [[ "$(tty)" = "/dev/tty1" ]]; then
    start-hyprland
  fi
fi

if [[ "$MYSYSTEM" = "OpenSuseLaptop" ]]; then
  find "$HOME/.hyprshot" -type f -delete 2>/dev/null
  if [[ -z "$DISPLAY" ]] && [[ "$(tty)" = "/dev/tty1" ]]; then
    start-hyprland
  fi
fi

if [[ "$MYSYSTEM" = "wslDebianDesktop" || "$MYSYSTEM" = "wslDebianLaptop" ]]; then
  export PATH="$PATH:/usr/nvim-linux-x86_64/bin"

  FIX_MARKER="/tmp/.wslg_fix_done"
  if [[ "$MYSYSTEM" = "wslDebianLaptop" ]] && [[ ! -f "$FIX_MARKER" ]]; then
    echo "fix wslg"
    sudo ~/wslg_fix.sh
    touch "$FIX_MARKER"
  fi
fi


