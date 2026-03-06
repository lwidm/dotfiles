# My dotfiles

This directory contains the dotfiles for my system.

## Quick Start

```zsh
git clone git@github.com:lwidm/dotfiles.git ~/dotfiles
```

Then follow in order:
1. Install dependencies (see [Requirements](#requirements))
2. Install oh-my-zsh (see [Zsh](#zsh))
3. Run pre-stow setup (see [Setup](#setup))
4. Run `stow .`
5. Install remaining tools: tmux plugins, zoxide, zsh-autosuggestions

---

## Requirements

### Arch
```zsh
sudo pacman -S git wl-clipboard ttf-hack ttf-hack-nerd ttf-font-awesome wofi polybar hyprpaper hyprlock hypridle hyprshot flameshot wireplumber python-gobject mpd mpc playerctl zoxide
```

### Debian
```zsh
sudo apt install git wl-clipboard fonts-hack ttf-font-awesome wofi polybar hyprpaper hyprlock hypridle flameshot wireplumber python3-gi mpd mpc playerctl
```
- `networkmanager-dmenu`: included in `network-manager`
- `hyprshot`: install manually (not in apt)
- `oh-my-zsh`: install via script (see [Zsh](#zsh))
- `zoxide`: install via script (see [zoxide](#zoxide))
- nerd font: install manually (see [fonts](#fonts))

### OpenSUSE Tumbleweed
```bash
sudo zypper in git wl-clipboard hack-fonts wofi polybar hyprpaper hyprlock hypridle hyprshot flameshot wireplumber python-gobject-common-devel mpd mpclient playerctl NetworkManager-applet zoxide mako
```
- `oh-my-zsh`: install via script (see [Zsh](#zsh))
- nerd font: install manually (see [fonts](#fonts))

### fonts
- ttf-hack is installed via the distro sections above
- Install a nerd font: Download Hack from the [nerd fonts GitHub page](https://github.com/ryanoasis/nerd-fonts/releases) and extract to `~/.local/share/fonts/`:
```zsh
mkdir -p ~/.local/share/fonts/HackNerdFont
unzip Hack.zip -d ~/.local/share/fonts/HackNerdFont/
fc-cache -fv
```

---

## Zsh

Make zsh the default shell:
```zsh
sudo chsh -s /bin/zsh
```

In case of MSYS2 on Windows:
1. Locate MSYS2 installation folder (e.g. `C:\msys64`)
2. Open `msys2_shell.cmd`
3. Change `set "LOGINSHELL=bash"` to `set "LOGINSHELL=zsh"`

### oh-my-zsh
**Install oh-my-zsh before running stow.**
Run the following in `$HOME/Downloads`:
```zsh
rm -r $HOME/.oh-my-zsh
sh -c "$(wget https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -O -)"
```

### zsh-autosuggestions
```zsh
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
```

---

## Setup

### **!!! Do this before running stow!!!**
```zsh
rm ~/.zshrc ~/.bashrc
mkdir -p ~/.local/bin ~/.local/share/applications ~/.local/state ~/.local/include
mkdir -p ~/.config
mkdir -p ~/.config/rclone
```

### Main stow command
Run in the `dotfiles` directory:
```zsh
cd ~/dotfiles
stow .
```

> **If you just installed oh-my-zsh**, re-run `stow .` after the install script — it will have overwritten `.zshrc`.

---

## tmux
Install TPM (tmux plugin manager):
```zsh
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
```
In tmux run `<prefix> I` to install all plugins. (prefix usually is `<ctrl>-b`)

---

## zoxide
- Arch:
```zsh
sudo pacman -S zoxide
```
- Debian (or recommended cross-distro method):
```zsh
curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh
```
Full guide: [github.com/ajeetdsouza/zoxide](https://github.com/ajeetdsouza/zoxide)

- OpenSUSE:
```zsh
sudo zypper in zoxide
```

---

## MYSYSTEM environment variable
Create file `~/.MYSYSTEM` and add:
```
export MYSYSTEM=SystemName
```
Valid values:
- `ArchDesktop` / `ArchLaptop`
- `DebianDesktop` / `DebianLaptop`
- `OpenSuseDesktop` / `OpenSuseLaptop`
- `wslDebianDesktop` / `wslDebianLaptop`

---

## Make eww work with music (Spotify and Audible)
Make sure `mpd` and `playerctl` are running:
```zsh
systemctl --user enable --now mpd
```

---

# Possible Bugs

- **zoxide not found**: Usually caused by `.zshrc`/`.bashrc` not being overwritten by `stow .`. Delete the file and run `stow .` again.
