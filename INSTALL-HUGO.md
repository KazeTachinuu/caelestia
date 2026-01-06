# Hugo's Caelestia Setup Guide

Complete guide to reinstall Arch Linux and restore this customized Caelestia setup.

## Table of Contents
1. [Arch Linux Installation](#1-arch-linux-installation)
2. [Post-Install Base Setup](#2-post-install-base-setup)
3. [Install Hyprland & Dependencies](#3-install-hyprland--dependencies)
4. [Install Caelestia](#4-install-caelestia)
5. [Restore Custom Configs](#5-restore-custom-configs)
6. [System Configuration](#6-system-configuration)
7. [Troubleshooting](#7-troubleshooting)

---

## 1. Arch Linux Installation

### Download & Prepare
1. Download the latest ISO from https://archlinux.org/download/
2. Verify the signature (recommended)
3. Create bootable USB: `dd bs=4M if=archlinux.iso of=/dev/sdX status=progress oflag=sync`
4. Disable Secure Boot in BIOS

### Install using archinstall
Boot from USB and run:
```bash
archinstall
```

**Recommended settings:**
| Setting | Value |
|---------|-------|
| Language | English |
| Locale | `en_GB.UTF-8` |
| Keyboard | Your layout (us, fr, etc.) |
| Mirror region | Your country |
| Disk | Use best-effort partition (or manual with BTRFS) |
| Bootloader | systemd-boot (UEFI) or GRUB |
| Swap | zram or swap file |
| Hostname | Your choice |
| Root password | Set one |
| User | Create your user with sudo |
| Profile | Minimal |
| Audio | Pipewire |
| Network | NetworkManager |
| Additional packages | `git base-devel vim fish` |

### Reboot
```bash
reboot
```

---

## 2. Post-Install Base Setup

### Login and connect to internet
```bash
# If using WiFi
nmcli device wifi connect "SSID" password "PASSWORD"

# Verify connection
ping archlinux.org
```

### Update system
```bash
sudo pacman -Syu
```

### Install AUR helper (yay)
```bash
sudo pacman -S --needed git base-devel
git clone https://aur.archlinux.org/yay.git
cd yay
makepkg -si
cd .. && rm -rf yay
```

### Set shell to fish (optional)
```bash
chsh -s /usr/bin/fish
```

---

## 3. Install Hyprland & Dependencies

### Core packages
```bash
sudo pacman -S xdg-desktop-portal-hyprland xdg-desktop-portal-gtk \
    qt6-base qt6-declarative qt6-wayland qt6-svg \
    pipewire wireplumber pipewire-pulse pipewire-alsa \
    polkit-kde-agent power-profiles-daemon \
    ttf-font-awesome noto-fonts noto-fonts-emoji \
    grim slurp wl-clipboard cliphist inotify-tools \
    brightnessctl playerctl ddcutil lm_sensors \
    thunar foot fish fastfetch btop jq eza \
    network-manager-applet blueman bluez bluez-utils trash-cli \
    adw-gtk-theme papirus-icon-theme qt5ct qt6ct
```

### AUR packages
**Important:** `quickshell-git` is required (not a tagged release), and `hyprland-git` is needed for Hyprland 0.53+ features.

```bash
yay -S hyprland-git quickshell-git caelestia-shell caelestia-meta \
    hyprpicker-git app2unit libcava aubio libqalculate \
    ttf-jetbrains-mono-nerd ttf-material-symbols-variable-git \
    ttf-cascadia-code-nerd starship swappy uwsm ghostty
```

> **Note:** If `caelestia-meta` fails to install, install individual packages above instead.

### Login manager
Caelestia uses UWSM to manage the Hyprland session. Install a greeter:

```bash
sudo pacman -S greetd
yay -S greetd-tuigreet
```

Configure greetd (`/etc/greetd/config.toml`):
```toml
[terminal]
vt = 1

[default_session]
command = "tuigreet --time --remember --cmd 'uwsm start hyprland-uwsm.desktop'"
user = "greeter"
```

Enable the service:
```bash
sudo systemctl enable greetd
```

### GPU Drivers

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

**Intel:**
```bash
sudo pacman -S mesa vulkan-intel intel-media-driver
```

---

## 4. Install Caelestia

### Clone the forked repo
```bash
git clone git@github.com:KazeTachinuu/caelestia.git ~/.local/share/caelestia
```

If SSH not set up yet, use HTTPS:
```bash
git clone https://github.com/KazeTachinuu/caelestia.git ~/.local/share/caelestia
```

### Run install script
```bash
cd ~/.local/share/caelestia
./install.fish
```

This creates symlinks for all config files.

### Enable required services
```bash
sudo systemctl enable --now power-profiles-daemon
sudo systemctl enable --now NetworkManager
sudo systemctl enable --now bluetooth
```

### Reboot and start Hyprland
After rebooting, the greetd login manager will start. Log in and Hyprland should launch automatically with the Caelestia shell.

---

## 5. Restore Custom Configs

### User configs
Copy these files to `~/.config/caelestia/`:

**hypr-vars.conf:**
```bash
# Apps
$terminal = ghostty

# Keybinds
$kbTerminal = Super, Return
$kbMoveWinToWs = Super+Shift
$kbBrowser = Super, B
$kbLock = Super, X
```

**hypr-user.conf:**
```bash
# Input overrides
input:touchpad {
    natural_scroll = false
}
```

### Privacy-friendly lock screen notifications
Replace the system NotifGroup.qml to hide notification content on lock screen:

```bash
sudo cp ~/dotfiles-backup/NotifGroup-privacy.qml /etc/xdg/quickshell/caelestia/modules/lock/NotifGroup.qml
```

<details>
<summary>NotifGroup-privacy.qml content (click to expand)</summary>

```qml
pragma ComponentBehavior: Bound

import qs.components
import qs.components.effects
import qs.services
import qs.config
import qs.utils
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

StyledRect {
    id: root

    required property string modelData

    readonly property list<var> notifs: Notifs.list.filter(notif => notif.appName === modelData)
    readonly property string image: notifs.find(n => n.image.length > 0)?.image ?? ""
    readonly property string appIcon: notifs.find(n => n.appIcon.length > 0)?.appIcon ?? ""
    readonly property string urgency: notifs.some(n => n.urgency === NotificationUrgency.Critical) ? "critical" : notifs.some(n => n.urgency === NotificationUrgency.Normal) ? "normal" : "low"

    property bool expanded

    anchors.left: parent?.left
    anchors.right: parent?.right
    implicitHeight: content.implicitHeight + Appearance.padding.normal * 2

    clip: true
    radius: Appearance.rounding.normal
    color: root.urgency === "critical" ? Colours.palette.m3secondaryContainer : Colours.layer(Colours.palette.m3surfaceContainerHigh, 2)

    RowLayout {
        id: content

        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Appearance.padding.normal

        spacing: Appearance.spacing.normal

        Item {
            Layout.alignment: Qt.AlignLeft | Qt.AlignTop
            implicitWidth: Config.notifs.sizes.image
            implicitHeight: Config.notifs.sizes.image

            Component {
                id: imageComp

                Image {
                    source: Qt.resolvedUrl(root.image)
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    asynchronous: true
                    width: Config.notifs.sizes.image
                    height: Config.notifs.sizes.image
                }
            }

            Component {
                id: appIconComp

                ColouredIcon {
                    implicitSize: Math.round(Config.notifs.sizes.image * 0.6)
                    source: Quickshell.iconPath(root.appIcon)
                    colour: root.urgency === "critical" ? Colours.palette.m3onError : root.urgency === "low" ? Colours.palette.m3onSurface : Colours.palette.m3onSecondaryContainer
                    layer.enabled: root.appIcon.endsWith("symbolic")
                }
            }

            Component {
                id: materialIconComp

                MaterialIcon {
                    text: Icons.getNotifIcon(root.notifs[0]?.summary, root.urgency)
                    color: root.urgency === "critical" ? Colours.palette.m3onError : root.urgency === "low" ? Colours.palette.m3onSurface : Colours.palette.m3onSecondaryContainer
                    font.pointSize: Appearance.font.size.large
                }
            }

            ClippingRectangle {
                anchors.fill: parent
                color: root.urgency === "critical" ? Colours.palette.m3error : root.urgency === "low" ? Colours.layer(Colours.palette.m3surfaceContainerHighest, 3) : Colours.palette.m3secondaryContainer
                radius: Appearance.rounding.full

                Loader {
                    anchors.centerIn: parent
                    asynchronous: true
                    sourceComponent: root.image ? imageComp : root.appIcon ? appIconComp : materialIconComp
                }
            }

            Loader {
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                asynchronous: true
                active: root.appIcon && root.image

                sourceComponent: StyledRect {
                    implicitWidth: Config.notifs.sizes.badge
                    implicitHeight: Config.notifs.sizes.badge

                    color: root.urgency === "critical" ? Colours.palette.m3error : root.urgency === "low" ? Colours.palette.m3surfaceContainerHighest : Colours.palette.m3secondaryContainer
                    radius: Appearance.rounding.full

                    ColouredIcon {
                        anchors.centerIn: parent
                        implicitSize: Math.round(Config.notifs.sizes.badge * 0.6)
                        source: Quickshell.iconPath(root.appIcon)
                        colour: root.urgency === "critical" ? Colours.palette.m3onError : root.urgency === "low" ? Colours.palette.m3onSurface : Colours.palette.m3onSecondaryContainer
                        layer.enabled: root.appIcon.endsWith("symbolic")
                    }
                }
            }
        }

        ColumnLayout {
            Layout.topMargin: -Appearance.padding.small
            Layout.bottomMargin: -Appearance.padding.small / 2 - (root.expanded ? 0 : spacing)
            Layout.fillWidth: true
            spacing: Math.round(Appearance.spacing.small / 2)

            RowLayout {
                Layout.bottomMargin: -parent.spacing
                Layout.fillWidth: true
                spacing: Appearance.spacing.smaller

                StyledText {
                    Layout.fillWidth: true
                    text: root.modelData
                    color: Colours.palette.m3onSurfaceVariant
                    font.pointSize: Appearance.font.size.small
                    elide: Text.ElideRight
                }

                StyledText {
                    animate: true
                    text: root.notifs[0]?.timeStr ?? ""
                    color: Colours.palette.m3outline
                    font.pointSize: Appearance.font.size.small
                }

                StyledRect {
                    implicitWidth: expandBtn.implicitWidth + Appearance.padding.smaller * 2
                    implicitHeight: groupCount.implicitHeight + Appearance.padding.small

                    color: root.urgency === "critical" ? Colours.palette.m3error : Colours.layer(Colours.palette.m3surfaceContainerHighest, 2)
                    radius: Appearance.rounding.full

                    opacity: root.notifs.length > Config.notifs.groupPreviewNum ? 1 : 0
                    Layout.preferredWidth: root.notifs.length > Config.notifs.groupPreviewNum ? implicitWidth : 0

                    StateLayer {
                        color: root.urgency === "critical" ? Colours.palette.m3onError : Colours.palette.m3onSurface

                        function onClicked(): void {
                            root.expanded = !root.expanded;
                        }
                    }

                    RowLayout {
                        id: expandBtn

                        anchors.centerIn: parent
                        spacing: Appearance.spacing.small / 2

                        StyledText {
                            id: groupCount

                            Layout.leftMargin: Appearance.padding.small / 2
                            animate: true
                            text: root.notifs.length
                            color: root.urgency === "critical" ? Colours.palette.m3onError : Colours.palette.m3onSurface
                            font.pointSize: Appearance.font.size.small
                        }

                        MaterialIcon {
                            Layout.rightMargin: -Appearance.padding.small / 2
                            animate: true
                            text: root.expanded ? "expand_less" : "expand_more"
                            color: root.urgency === "critical" ? Colours.palette.m3onError : Colours.palette.m3onSurface
                        }
                    }

                    Behavior on opacity {
                        Anim {}
                    }

                    Behavior on Layout.preferredWidth {
                        Anim {}
                    }
                }
            }

            Repeater {
                model: ScriptModel {
                    values: root.notifs.slice(0, Config.notifs.groupPreviewNum)
                }

                NotifLine {
                    id: notif

                    ParallelAnimation {
                        running: true

                        Anim {
                            target: notif
                            property: "opacity"
                            from: 0
                            to: 1
                        }
                        Anim {
                            target: notif
                            property: "scale"
                            from: 0.7
                            to: 1
                        }
                        Anim {
                            target: notif.Layout
                            property: "preferredHeight"
                            from: 0
                            to: notif.implicitHeight
                        }
                    }

                    ParallelAnimation {
                        running: notif.modelData.closed
                        onFinished: notif.modelData.unlock(notif)

                        Anim {
                            target: notif
                            property: "opacity"
                            to: 0
                        }
                        Anim {
                            target: notif
                            property: "scale"
                            to: 0.7
                        }
                        Anim {
                            target: notif.Layout
                            property: "preferredHeight"
                            to: 0
                        }
                    }
                }
            }

            Loader {
                Layout.fillWidth: true

                opacity: root.expanded ? 1 : 0
                Layout.preferredHeight: root.expanded ? implicitHeight : 0
                active: opacity > 0
                asynchronous: true

                sourceComponent: ColumnLayout {
                    Repeater {
                        model: ScriptModel {
                            values: root.notifs.slice(Config.notifs.groupPreviewNum)
                        }

                        NotifLine {}
                    }
                }

                Behavior on opacity {
                    Anim {}
                }
            }
        }
    }

    Behavior on implicitHeight {
        Anim {
            duration: Appearance.anim.durations.expressiveDefaultSpatial
            easing.bezierCurve: Appearance.anim.curves.expressiveDefaultSpatial
        }
    }

    // Only change: show summary/title only, hide body content
    component NotifLine: StyledText {
        id: notifLine

        required property Notifs.Notif modelData

        Layout.fillWidth: true
        text: modelData.summary.replace(/\n/g, " ")
        color: root.urgency === "critical" ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        elide: Text.ElideRight

        Component.onCompleted: modelData.lock(this)
        Component.onDestruction: modelData.unlock(this)
    }
}
```
</details>

---

## 6. System Configuration

### Set locale to European (Celsius, 24h, metric)
```bash
sudo localectl set-locale LANG=en_GB.UTF-8
```

### Set timezone
```bash
sudo timedatectl set-timezone Europe/Paris
```

### Configure git
```bash
git config --global user.email "hugo.sibony@epita.fr"
git config --global user.name "Hugo Sibony"
```

### SSH key for GitHub
```bash
ssh-keygen -t ed25519 -C "hugo.sibony@epita.fr"
cat ~/.ssh/id_ed25519.pub
# Add to GitHub: Settings > SSH Keys
```

---

## 7. Troubleshooting

### Lock screen not rendering properly
Rebuild quickshell after Qt updates:
```bash
yay -S quickshell-git --rebuild
caelestia shell -k && caelestia shell -d
```

### Hyprland windowrule errors
This fork already includes fixes for Hyprland 0.53+ syntax. If you see errors:
- `float` should be `float on`
- `match:float` should be `match:float 1`
- `match:fullscreen false` should be `match:fullscreen 0`

### Shell not starting
```bash
# Check logs
caelestia shell -l

# Restart shell
caelestia shell -k
caelestia shell -d
```

### Weather not showing
Set your location in `~/.config/caelestia/shell.json`:
```json
"services": {
    "weatherLocation": "Paris",
    ...
}
```

---

## Quick Reference

### Keybinds (customized)
| Key | Action |
|-----|--------|
| `Super + Return` | Terminal (ghostty) |
| `Super + B` | Browser |
| `Super + X` | Lock |
| `Super + Q` | Close window |
| `Super + Shift + 1-9` | Move window to workspace |
| `Super + 1-9` | Go to workspace |

### Important paths
| Path | Description |
|------|-------------|
| `~/.local/share/caelestia/` | Dotfiles repo |
| `~/.config/caelestia/` | User overrides |
| `~/.config/caelestia/shell.json` | Shell config |
| `~/.config/hypr/` | Symlinked Hyprland config |

---

## Backup Checklist

Before reinstalling, backup:
- [ ] `~/.config/caelestia/` (user configs)
- [ ] `~/.config/caelestia/shell.json` (shell settings)
- [ ] `/etc/xdg/quickshell/caelestia/modules/lock/NotifGroup.qml` (privacy patch)
- [ ] `~/.ssh/` (SSH keys)
- [ ] Any wallpapers in `~/Pictures/Wallpapers/`

---

*Last updated: January 2026*
