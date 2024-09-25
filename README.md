# My dotfiles

This directory contains the dotfiles for my system

## Requirements
- git
- wl-clipboard
- ttf-hack
- virtualbox-guest-utils
- waybar
- sway
- ttf-font-awesome
- wofi
- oh-my-zsh
- tmux
- zsh
- eza

### fonts
install ttf-hack
install a nerd font

### .zshrc and .xinitrc
manually remove these two files from home directory before running
```zsh
stow .
```
in the `dotfiles` directory

## Virtuabox
sudo systemctl enable vboxservice.service
sudo systemctl start vboxservice.serivce

## Zsh
make zsh the default console <\br>
```zsh
sudo chsh -s /bin/zsh
```
in case of msys you need to do the following
1. Locate MSYS2 installation folder in windows. In my case, it's in C:\msys64.
2. Open msys2_shell.cmd.
3. Locate line set "LOGINSHELL=bash" and change it to set "LOGINSHELL=zsh"


### oh my zsh
**install oh my zsh:** 
Run the following command in the `$HOME/Downloads` folder
```zsh
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
```

### zsh-autosuggestions
WARNING: in case of msys terminal you need to replace the `~` with `/c/msys64/home/<user>`
Run the following command to install zsh-autosuggestions
```zsh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```


## tmux
WARNING: in case of msys terminal you need to replace the `~` with `/c/msys64/home/<user>`
install tpm (tmux package manager)
```zsh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

in tmux run `<prefix> I` to install all the packages

## zoxide
WARNING: this step will not work on msys. Use the msys packages instead
an online guide can be found in the [github repo](https://github.com/ajeetdsouza/zoxide)

The recommended way to install zoxide is via the install script:
```zsh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
```

