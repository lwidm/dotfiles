# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

# Set name of the theme to load --- if set to "random", it will
# load a random theme each time oh-my-zsh is loaded, in which case,
# to know which specific one was loaded, run: echo $RANDOM_THEME
# See https://github.com/ohmyzsh/ohmyzsh/wiki/Themes
ZSH_THEME="robbyrussell"


# Set list of themes to pick from when loading at random
# Setting this variable when ZSH_THEME=random will cause zsh to load
# a theme from this variable instead of looking in $ZSH/themes/
# If set to an empty array, this variable will have no effect.
# ZSH_THEME_RANDOM_CANDIDATES=( "robbyrussell" "agnoster" )

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion.
# Case-sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment one of the following lines to change the auto-update behavior
# zstyle ':omz:update' mode disabled  # disable automatic updates
# zstyle ':omz:update' mode auto      # update automatically without asking
# zstyle ':omz:update' mode reminder  # just remind me to update when it's time

# Uncomment the following line to change how often to auto-update (in days).
# zstyle ':omz:update' frequency 13

# Uncomment the following line if pasting URLs and other text is messed up.
# DISABLE_MAGIC_FUNCTIONS="true"

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# You can also set it to another string to have that shown instead of the default red dots.
# e.g. COMPLETION_WAITING_DOTS="%F{yellow}waiting...%f"
# Caution: this setting can cause issues with multiline prompts in zsh < 5.7.1 (see #5765)
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# You can set one of the optional three formats:
# "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# or set a custom format using the strftime function format specifications,
# see 'man strftime' for details.
# HIST_STAMPS="mm/dd/yyyy"

# Would you like to use another custom folder than $ZSH/custom?
# ZSH_CUSTOM=/path/to/new-custom-folder

# Which plugins would you like to load?
# Standard plugins can be found in $ZSH/plugins/
# Custom plugins may be added to $ZSH_CUSTOM/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git zsh-autosuggestions)

source $ZSH/oh-my-zsh.sh

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
# if [[ -n $SSH_CONNECTION ]]; then
#   export EDITOR='vim'
# else
#   export EDITOR='mvim'
# fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.
#
# Example aliases
# alias zshconfig="mate ~/.zshrc"
# alias ohmyzsh="mate ~/.oh-my-zsh"
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

# Conda

# Environment variables
if [ -f ~/.MYSYSTEM ]; then
  source ~/.MYSYSTEM
fi

# Autostart ssh-agent
if [[ "$MYSYSTEM" == "DebianDesktop" || "$MYSYSTEM" == "DebianLaptop" || "$MYSYSTEM" == "DebDesktop" || "$MYSYSTEM" == "DebLaptop" || "$MYSYSTEM" == "ArchDesktop" || "$MYSYSTEM" == "ArchLaptop" ]]; then
  if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    eval "$(ssh-agent -s)" > /dev/null
  fi
fi


if [[ "$MYSYSTEM" == "DebianDesktop" ]]; then
  # export LIBVA_DRIVER_NAME=nvidia
  # export GBM_BACKEND=nvidia-drm
  # export __GLX_VENDOR_LIBRARY_NAME=nvidia
  # export WLR_NO_HARDWARE_CURSORS=1
  #
  # export GTK_SCALE=2
  # export GDK_DPI_SCALE=0.5
  # export QT_AUTO_SCREEN_SCALE_FACTOR=1
  # export QT_SCALE_FACTOR=2
  if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    hyprland &
  fi
fi

if [[ "$MYSYSTEM" == "ArchDesktop" ]]; then
  export LIBVA_DRIVER_NAME=nvidia
  export GBM_BACKEND=nvidia-drm
  export __GLX_VENDOR_LIBRARY_NAME=nvidia
  export WLR_NO_HARDWARE_CURSORS=1

  export GTK_SCALE=2
  export GDK_DPI_SCALE=0.5
  export QT_AUTO_SCREEN_SCALE_FACTOR=1
  export QT_SCALE_FACTOR=2
  if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    hyprland &
  fi
fi

if [[ "$MYSYSTEM" == "ArchLaptop" ]]; then
  if [[ -z $DISPLAY ]] && [[ $(tty) = /dev/tty1 ]]; then
    hyprland &
  fi
fi

if [[ "$MYSYSTEM" == "wslDebianDesktop" || "$MYSYSTEM" == "wslDebianLaptop" ]]; then
  export PATH="$PATH:/usr/nvim-linux-x86_64/bin"
  # Start SSH Agent and add key
  if [ -z "$SSH_AUTH_SOCK" ]; then
    eval "$(ssh-agent -s)" > /dev/null
    # ssh-add ~/.ssh/id_ed25519 2>/dev/null
    # ssh-add ~/.ssh/id_ed25519_euler 2>/dev/null
    if [[ "$MYSYSTEM" == "wslDebianLaptop" ]]; then
      echo "fix wslg"
      sudo ~/wslg_fix.sh
    fi
  fi
fi

# CC anc CCX compilers
CC=clang
CXX=clang++

# zoxide
eval "$(zoxide init zsh)"


# Function to check if we're in a nix-shell
function in_nix_shell {
  [[ -n "$IN_NIX_SHELL" ]]
}

# Backup current theme
export ORIGINAL_ZSH_THEME=$ZSH_THEME

# Change theme if in nix-shell
if in_nix_shell; then
  export ZSH_THEME="simple"
else
  export ZSH_THEME="$ORIGINAL_ZSH_THEME"
fi

# Load oh-my-zsh
source $ZSH/oh-my-zsh.sh


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

