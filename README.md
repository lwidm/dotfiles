# My dotfiles

This directory contains the dotfiles for my system

## Requirements
git
wl-clipboard
ttf-hack
virtualbox-guest-utils
waybar
sway
ttf-font-awesome
wofi
oh-my-zsh

### fonts
install ttf-hack
install a nerd font

## Virtuabox
sudo systemctl enable vboxservice.service
sudo systemctl start vboxservice.serivce

## Zsh
make zsh the default console <\br>
```zsh
sudo chsh -s /bin/zsh
```

### oh my zsh
**install oh my zsh:** 
Run the following command in the `$HOME/Downloads` folder
```zsh
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
```

### zsh-autosuggestions
Run the following command to install zsh-autosuggestions
```zsh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

## tmux
install tpm (tmux package manager)
```zsh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

in tmux run `<prefix> I` to install all the packages

