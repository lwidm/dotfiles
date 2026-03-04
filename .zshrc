export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions)

# User configuration
alias ls="eza -a --icons=always --colour=always"
alias ll="eza -al --icons=always --colour=always"
alias lt="eza -aT --icons=always --colour=always"
alias llt="eza -alT --icons=always --colour=always"
# alias ls="exa -a --icons --colour=always"
# alias ll="exa -al --icons --colour=always"
# alias lt="exa -aT --icons --colour=always"
# alias llt="exa -alT --icons --colour=always"
alias cisco-start="gtk-launch com.cisco.secureclient.gui"
alias openTabletDriver-start="/usr/lib/opentabletdriver/OpenTabletDriver.Daemon &"
alias opentabletdriver-start="/usr/lib/opentabletdriver/OpenTabletDriver.Daemon &"
alias opentabletGui-start="/usr/lib/opentabletdriver/OpenTabletDriver.UX.Gtk"
alias opentabletgui-start="/usr/lib/opentabletdriver/OpenTabletDriver.UX.Gtk"
alias ssh_home="ssh lukas@172.16.21.28"
alias ssh_ucsblab="ssh lukas@jfm.me.ucsb.edu"
alias ssh_anvil="ssh x-lwidmer@anvil.rcac.purdue.edu"
pycalc() {
  ~/miniconda3/bin/python3 -i -c "
for _mod, _name in [('numpy', 'np'), ('scipy', None), ('matplotlib.pyplot', 'plt'), ('h5py', None)]:
    try:
        _m = __import__(_mod)
        if '.' in _mod: _m = getattr(_m, _mod.split('.')[-1])
        globals()[_name or _mod.split('.')[-1]] = _m
    except ImportError:
        print(f'Warning: {_mod} not found')
del _mod, _name, _m
"
}


# Conda

# Environment variables
if [ -f ~/.MYSYSTEM ]; then
  source ~/.MYSYSTEM
fi



# zoxide
eval "$(zoxide init zsh)"


# Change theme if in nix-shell
if [[ -n "$IN_NIX_SHELL" ]]; then
  ZSH_THEME="simple"
fi

source $ZSH/oh-my-zsh.sh

export PATH=$HOME/Software/PARTIES_Libs/bin:$PATH

# >>> conda initialize >>>
# !! Contents within this block are managed by 'conda init' !!
__conda_setup="$('/home/lukas/miniconda3/bin/conda' 'shell.zsh' 'hook' 2> /dev/null)"
if [ $? -eq 0 ]; then
    eval "$__conda_setup"
else
    if [ -f "/home/lukas/miniconda3/etc/profile.d/conda.sh" ]; then
        . "/home/lukas/miniconda3/etc/profile.d/conda.sh"
    else
        export PATH="/home/lukas/miniconda3/bin:$PATH"
    fi
fi
unset __conda_setup
# <<< conda initialize <<<

