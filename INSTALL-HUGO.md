# Hugo's Caelestia Setup Guide

Complete guide to reinstall Arch Linux with LUKS encryption and restore this customized Caelestia setup.

## Table of Contents
1. [Pre-Install Backup](#1-pre-install-backup)
2. [Arch Linux Installation with LUKS](#2-arch-linux-installation-with-luks)
3. [Post-Install Base Setup](#3-post-install-base-setup)
4. [Install Caelestia](#4-install-caelestia)
5. [Restore Custom Configs](#5-restore-custom-configs)
6. [System Configuration](#6-system-configuration)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Pre-Install Backup

Before reinstalling, backup these items:

```bash
# Push any uncommitted dotfile changes
cd ~/.local/share/caelestia
git add -A && git commit -m "backup before reinstall" && git push

# Backup user configs
mkdir -p ~/backup-reinstall
cp -r ~/.config/caelestia ~/backup-reinstall/
cp -r ~/.ssh ~/backup-reinstall/
cp -r ~/Pictures/Wallpapers ~/backup-reinstall/ 2>/dev/null

# Optional: backup privacy patch
sudo cp /etc/xdg/quickshell/caelestia/modules/lock/NotifGroup.qml ~/backup-reinstall/

# Copy backup to external drive or cloud
```

### Backup Checklist
- [ ] `~/.config/caelestia/` (user overrides)
- [ ] `~/.ssh/` (SSH keys)
- [ ] `~/Pictures/Wallpapers/`
- [ ] Privacy patch NotifGroup.qml (if applied)
- [ ] Any other personal files

---

## 2. Arch Linux Installation with LUKS

### Download & Prepare
1. Download the latest ISO from https://archlinux.org/download/
2. Verify the signature (optional but recommended)
3. Create bootable USB: `dd bs=4M if=archlinux.iso of=/dev/sdX status=progress oflag=sync`
4. Disable Secure Boot in BIOS
5. Boot from USB

### Connect to Internet
```bash
# WiFi
iwctl
station wlan0 connect "SSID"
# Enter password when prompted, then exit

# Verify
ping -c 3 archlinux.org
```

### Partition the Disk
```bash
# Identify your disk (usually nvme0n1 or sda)
lsblk

# Partition with gdisk
gdisk /dev/nvme0n1

# Delete all existing partitions (d, repeat until empty)
# Create new partitions:
#   n, 1, default, +1G, ef00    (EFI System Partition)
#   n, 2, default, default, 8309 (Linux LUKS)
# Write and exit: w, y
```

### Setup LUKS Encryption
```bash
# Format the root partition with LUKS (you'll set the encryption password here)
cryptsetup luksFormat /dev/nvme0n1p2

# Open the encrypted partition
cryptsetup open /dev/nvme0n1p2 cryptroot
```

### Format and Mount
```bash
# Format partitions
mkfs.fat -F32 /dev/nvme0n1p1
mkfs.ext4 /dev/mapper/cryptroot

# Mount
mount /dev/mapper/cryptroot /mnt
mount --mkdir /dev/nvme0n1p1 /mnt/boot
```

### Install Base System
```bash
pacstrap -K /mnt base linux linux-firmware intel-ucode \
    networkmanager vim git base-devel fish sudo
```

> **Note:** Replace `intel-ucode` with `amd-ucode` for AMD CPUs.

### Generate fstab
```bash
genfstab -U /mnt >> /mnt/etc/fstab
```

### Configure the System (chroot)
```bash
arch-chroot /mnt
```

Inside chroot:
```bash
# Timezone
ln -sf /usr/share/zoneinfo/Europe/Paris /etc/localtime
hwclock --systohc

# Locale
echo "en_GB.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_GB.UTF-8" > /etc/locale.conf

# Hostname
echo "archbox" > /etc/hostname

# Create user
useradd -m -G wheel -s /usr/bin/fish hugo
passwd hugo

# Enable sudo for wheel group
EDITOR=vim visudo
# Uncomment: %wheel ALL=(ALL:ALL) ALL

# Configure mkinitcpio for LUKS
vim /etc/mkinitcpio.conf
# Change HOOKS to:
# HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block encrypt filesystems fsck)

# Regenerate initramfs
mkinitcpio -P
```

### Setup Bootloader (systemd-boot)
```bash
# Install bootloader
bootctl install

# Get UUID of encrypted partition
blkid /dev/nvme0n1p2
# Note the UUID (not PARTUUID)

# Create boot entry
cat > /boot/loader/entries/arch.conf << 'EOF'
title   Arch Linux
linux   /vmlinuz-linux
initrd  /intel-ucode.img
initrd  /initramfs-linux.img
options cryptdevice=UUID=YOUR-UUID-HERE:cryptroot root=/dev/mapper/cryptroot rw
EOF

# Edit the file and replace YOUR-UUID-HERE with actual UUID
vim /boot/loader/entries/arch.conf

# Configure loader
cat > /boot/loader/loader.conf << 'EOF'
default arch.conf
timeout 3
editor no
EOF

# Enable NetworkManager
systemctl enable NetworkManager
```

### Setup Autologin (LUKS handles authentication)
```bash
# Create autologin drop-in
mkdir -p /etc/systemd/system/getty@tty1.service.d
cat > /etc/systemd/system/getty@tty1.service.d/autologin.conf << 'EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty -o '-p -f -- \\u' --noclear --autologin hugo %I $TERM
EOF
```

### Reboot
```bash
exit
umount -R /mnt
reboot
```

Remove the USB and boot into your new system. You'll be prompted for the LUKS password, then auto-logged in.

---

## 3. Post-Install Base Setup

### Connect to Internet
```bash
# WiFi
nmcli device wifi connect "SSID" password "PASSWORD"

# Verify
ping -c 3 archlinux.org
```

### Update System
```bash
sudo pacman -Syu
```

### Install AUR Helper (paru)
```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/paru.git /tmp/paru
cd /tmp/paru
makepkg -si
cd ~ && rm -rf /tmp/paru
```

### Install GPU Drivers

**Intel:**
```bash
sudo pacman -S mesa vulkan-intel intel-media-driver
```

**AMD:**
```bash
sudo pacman -S mesa vulkan-radeon libva-mesa-driver
```

**NVIDIA:**
```bash
sudo pacman -S nvidia nvidia-utils nvidia-settings
# Add to /etc/mkinitcpio.conf MODULES: nvidia nvidia_modeset nvidia_uvm nvidia_drm
sudo mkinitcpio -P
```

---

## 4. Install Caelestia

### Install Core Dependencies
```bash
# Official packages
sudo pacman -S \
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    qt6-base qt6-declarative qt6-wayland qt6-svg \
    pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack \
    polkit-kde-agent power-profiles-daemon \
    noto-fonts noto-fonts-emoji \
    grim slurp wl-clipboard cliphist inotify-tools \
    brightnessctl playerctl ddcutil \
    thunar foot fish fastfetch btop jq eza \
    network-manager-applet blueman bluez bluez-utils trash-cli \
    adw-gtk-theme papirus-icon-theme

# AUR packages (WITHOUT quickshell - we install pinned version separately)
paru -S hyprland-git caelestia-shell caelestia-cli \
    hyprpicker-git app2unit libcava aubio libqalculate \
    ttf-jetbrains-mono-nerd ttf-material-symbols-variable-git \
    ttf-cascadia-code-nerd starship swappy uwsm ghostty
```

### Clone Dotfiles and Install Pinned Quickshell
```bash
# Clone the forked repo (use HTTPS if SSH not set up yet)
git clone git@github.com:KazeTachinuu/caelestia.git ~/.local/share/caelestia
cd ~/.local/share/caelestia

# Install pinned quickshell FIRST (fixes lock screen rendering)
./install-hugo.fish --pin-quickshell

# Run base install script
./install.fish --zen --spotify --vscode=codium

# Run Hugo's customization script (creates configs, sets up auto-start)
./install-hugo.fish

# Optional: Apply privacy patch (hides notification body on lock screen)
./install-hugo.fish --privacy-patch
```

### Enable Required Services
```bash
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
```

### Reboot
```bash
reboot
```

After LUKS password entry, you'll be auto-logged in and Hyprland will start automatically.

---

## 5. Custom Configs Reference

The `install-hugo.fish` script creates these automatically, but here's what they contain:

### `~/.config/caelestia/hypr-vars.conf`
```bash
# Terminal (ghostty instead of foot)
$terminal = ghostty

# Custom keybinds
$kbTerminal = Super, Return
$kbMoveWinToWs = Super+Shift
$kbBrowser = Super, B
$kbLock = Super, X
```

### `~/.config/caelestia/hypr-user.conf`
```bash
# Touchpad settings
input:touchpad {
    natural_scroll = false
}
```

### `~/.config/caelestia/shell.json`
```json
{
    "services": {
        "weatherLocation": "Paris"
    }
}
```

---

## 6. System Configuration

### Git Config
```bash
git config --global user.email "hugo.sibony@epita.fr"
git config --global user.name "Hugo Sibony"
```

### SSH Key for GitHub
```bash
ssh-keygen -t ed25519 -C "hugo.sibony@epita.fr"
cat ~/.ssh/id_ed25519.pub
# Add to GitHub: Settings > SSH Keys > New SSH Key
```

### Additional Tools
```bash
# Developer tools
paru -S neovim fd bat lazygit

# Optional
paru -S zoxide direnv
```

---

## 7. Troubleshooting

### Lock Screen Not Rendering Fully
If the lock screen appears incomplete and requires print screen to refresh:

```bash
# Pin quickshell to the official tested commit
paru -G quickshell-git
cd quickshell-git

# Add prepare() function to PKGBUILD after pkgver():
# prepare() {
#   cd "$_pkgsrc"
#   git checkout 41828c4180fb921df7992a5405f5ff05d2ac2fff
# }

makepkg -si
caelestia shell -k && caelestia shell -d
```

For Qt updates, rebuild quickshell:
```bash
paru -S quickshell-git --rebuild
caelestia shell -k && caelestia shell -d
```

### Hyprland Windowrule Errors
This fork includes fixes for Hyprland 0.53+ syntax. If you see errors:
- `float` should be `float on`
- `match:float` should be `match:float 1`

### Shell Not Starting
```bash
# Check logs
caelestia shell -l

# Restart shell
caelestia shell -k
caelestia shell -d
```

### LUKS Password Not Accepted
If you forget the LUKS password, data is unrecoverable. Use a password manager.

### Autologin Not Working
Check the getty override:
```bash
systemctl status getty@tty1
cat /etc/systemd/system/getty@tty1.service.d/autologin.conf
```

---

## Quick Reference

### Keybinds (Customized)
| Key | Action |
|-----|--------|
| `Super + Return` | Terminal (ghostty) |
| `Super + B` | Browser (zen) |
| `Super + X` | Lock screen |
| `Super + Q` | Close window |
| `Super + Shift + 1-9` | Move window to workspace |
| `Super + 1-9` | Go to workspace |
| `Super + S` | Special workspace |
| `Ctrl + Alt + Delete` | Session menu |

### Important Paths
| Path | Description |
|------|-------------|
| `~/.local/share/caelestia/` | Dotfiles repo |
| `~/.config/caelestia/` | User overrides |
| `~/.config/caelestia/shell.json` | Shell config |
| `~/.config/hypr/` | Symlinked Hyprland config |
| `/etc/xdg/quickshell/caelestia/` | System shell configs |

---

*Last updated: January 2026*
