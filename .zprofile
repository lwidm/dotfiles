#
# ~/.zprofile
#
export XDG_CONFIG_HOME=$HOME/.config
[[ -f ~/.MYSYSTEM ]] && source ~/.MYSYSTEM
VIM="nvim"
export EDITOR="nvim"
export VISUAL="nvim"
export CC="clang"
export CXX="clang++"
export PYTHONBREAKPOINT="pudb.set_trace"
export GIT_EDITOR=$VIM
export LIBVIRT_DEFAULT_URI='qemu:///system'

# Force NVIDIA EGL vendor — bypasses Mesa DRI2 failures on NVIDIA+Wayland (desktop only)
[[ "$MYSYSTEM" == "OpenSuseDesktop" ]] && export __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/10_nvidia.json

export PATH=$PATH:/var/lib/flatpak/exports/share
export PATH=$PATH:/home/lukas/.local/share/flatpak/exports/share
export PATH=$PATH:$HOME/.local/bin
export PATH=$PATH:$HOME/.cargo/bin
export PATH=$PATH:$HOME/go/bin/
export PATH=$PATH:/snap/bin
export PATH=$PATH:/home/lukas/ParaView-5.10.1-MPI-Linux-Python3.9-x86_64/bin
export PATH=$PATH:/var/lib/snapd/snap/bin

[[ -f ~/vulkansdk/default/setup-env.sh ]] && source ~/vulkansdk/default/setup-env.sh
