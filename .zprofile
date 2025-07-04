#
# ~/.zprofile
#
export XDG_CONFIG_HOME=$HOME/.config
VIM="nvim"
export CC="clang-12"
export CXX="clang++-12"
export PYTHONBREAKPOINT="pudb.set_trace"
export GIT_EDITOR=$VIM
export LIBVIRT_DEFAULT_URI='qemu:///system'

export PATH=$PATH:$HOME/.local/bin
export PATH=$PATH:$HOME/.cargo/bin
export PATH=$PATH:$HOME/go/bin/
export PATH=$PATH:/snap/bin
