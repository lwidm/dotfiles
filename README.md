# My dotfiles

This directory contains the dotfiles for my system

**Create the `~/.config`directory before running `stow`**. This is important otherwise this will be simlinked

## Requirements
- git
- wl-clipboard
- ttf-hack
- virtualbox-guest-utils
- sway
- ttf-font-awesome
- wofi
- oh-my-zsh
- polybar
- hyprpaper

### fonts

install ttf-hack
install a nerd font

### **!!! DO this before running stow command!!!**
```zsh
rm ~/.zshrc ~/.bashrc
mkdir -p ~/.local/bin ~/.local/share ~/.local/state ~/.local/include
mkdir -p ~/.config
mkdir -p ~/.config/rclone
```

### Main stow command
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
rm -r $HOME/.oh-my-zsh
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
cd $HOME/dotfiles
stow .
```

### zsh-autosuggestions
Run the following command to install zsh-autosuggestions

```zsh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

## MYSYSTEM environment variable
create file `~\.MYSYSTEM`and add the following line
```
export MYSYSTEM=SystemName
```

## tmux
install tpm (tmux package manager)

```zsh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```

in tmux run `<prefix> I` to install all the packages

## zoxide
an online guide can be found in the [github repo](https://github.com/ajeetdsouza/zoxide)
- On Arch i recommend using pacman
```zsh
sudo pacman -S zoxide
```
- The recommended way to install zoxide is via the install script:
```zsh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
```

# Possible Bugs

- zoxide not found
  This is usually due to the `.zshrc`/`.bashrc` file not being overwritten by the `stow .` command. This can be solved by deleting this file and running the `stow` command again.
