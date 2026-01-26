#!/usr/bin/env fish

# Hugo's Caelestia Post-Install Script
# Run this AFTER ./install.fish to apply Hugo-specific customizations

argparse -n 'install-hugo.fish' -X 0 \
    'h/help' \
    'privacy-patch' \
    'battery-patch' \
    'pin-quickshell' \
    'skip-packages' \
    'skip-configs' \
    'skip-autostart' \
    -- $argv
or exit

if set -q _flag_h
    echo 'usage: ./install-hugo.fish [-h] [--privacy-patch] [--battery-patch] [--pin-quickshell] [--skip-packages] [--skip-configs] [--skip-autostart]'
    echo
    echo "Hugo's post-install customization script. Run after ./install.fish"
    echo
    echo 'options:'
    echo '  -h, --help          show this help message and exit'
    echo '  --privacy-patch     apply privacy patch to lock screen notifications'
    echo '  --battery-patch     add battery percentage to bar + battery tab in dashboard'
    echo '  --pin-quickshell    rebuild quickshell pinned to tested commit (fixes lock screen)'
    echo '  --skip-packages     skip installing additional packages'
    echo '  --skip-configs      skip setting up user configs'
    echo '  --skip-autostart    skip adding Hyprland auto-start to fish'
    exit
end

# Helper functions
function _out -a colour text
    set_color $colour
    echo $argv[3..] -- ":: $text"
    set_color normal
end

function log -a text
    _out cyan $text $argv[2..]
end

function warn -a text
    _out yellow $text $argv[2..]
end

function err -a text
    _out red $text $argv[2..]
end

function success -a text
    _out green $text $argv[2..]
end

# Variables
set -l config_dir ~/.config/caelestia
set -l script_dir (dirname (status filename))

# Header
set_color magenta
echo '╭─────────────────────────────────────────────────╮'
echo '│         Hugo\'s Caelestia Setup Script          │'
echo '╰─────────────────────────────────────────────────╯'
set_color normal
echo

# Check if base install.fish was run (skip check if only pinning quickshell)
if not set -q _flag_pin_quickshell
    if not test -L ~/.config/hypr
        err 'Hyprland config not symlinked. Run ./install.fish first!'
        exit 1
    end
end

# ─────────────────────────────────────────────────────────
# 1. Install Additional Packages
# ─────────────────────────────────────────────────────────
if not set -q _flag_skip_packages; and test -L ~/.config/hypr
    log 'Checking additional packages...'

    # Detect AUR helper
    if command -v paru &>/dev/null
        set aur_helper paru
    else if command -v yay &>/dev/null
        set aur_helper yay
    else
        err 'No AUR helper found (paru or yay). Install one first.'
        exit 1
    end

    # Packages Hugo uses
    set -l hugo_packages \
        ghostty \
        neovim \
        fd \
        bat \
        lazygit \
        zoxide \
        direnv

    set -l missing_packages
    for pkg in $hugo_packages
        if not pacman -Q $pkg &>/dev/null
            set -a missing_packages $pkg
        end
    end

    if test (count $missing_packages) -gt 0
        log "Installing missing packages: $missing_packages"
        $aur_helper -S --needed $missing_packages
    else
        success 'All additional packages already installed'
    end
end

# ─────────────────────────────────────────────────────────
# 2. Setup User Configs
# ─────────────────────────────────────────────────────────
if not set -q _flag_skip_configs; and test -L ~/.config/hypr
    log 'Setting up user configs...'
    mkdir -p $config_dir

    # hypr-vars.conf
    if not test -f $config_dir/hypr-vars.conf; or not grep -q 'terminal' $config_dir/hypr-vars.conf
        log 'Creating hypr-vars.conf...'
        printf '%s\n' \
            '# Terminal (ghostty instead of foot)' \
            '$terminal = ghostty' \
            '' \
            '# Custom keybinds' \
            '$kbTerminal = Super, Return' \
            '$kbMoveWinToWs = Super+Shift' \
            '$kbBrowser = Super, B' \
            '$kbLock = Super, X' \
            > $config_dir/hypr-vars.conf
        success 'Created hypr-vars.conf'
    else
        success 'hypr-vars.conf already configured'
    end

    # hypr-user.conf
    if not test -f $config_dir/hypr-user.conf; or test (wc -l < $config_dir/hypr-user.conf) -lt 2
        log 'Creating hypr-user.conf...'
        printf '%s\n' \
            '# Touchpad settings' \
            'input:touchpad {' \
            '    natural_scroll = false' \
            '}' \
            > $config_dir/hypr-user.conf
        success 'Created hypr-user.conf'
    else
        success 'hypr-user.conf already configured'
    end

    # shell.json
    if not test -f $config_dir/shell.json
        log 'Creating shell.json...'
        printf '%s\n' \
            '{' \
            '    "services": {' \
            '        "weatherLocation": "Paris"' \
            '    }' \
            '}' \
            > $config_dir/shell.json
        success 'Created shell.json'
    else
        success 'shell.json already exists'
    end
end

# ─────────────────────────────────────────────────────────
# 3. Apply Privacy Patch (optional)
# ─────────────────────────────────────────────────────────
if set -q _flag_privacy_patch; and test -L ~/.config/hypr
    set -l notif_file /etc/xdg/quickshell/caelestia/modules/lock/NotifGroup.qml
    set -l patch_file $script_dir/patches/NotifGroup-privacy.qml

    if test -f $patch_file
        if test -f $notif_file
            # Check if already patched (privacy version has simpler NotifLine)
            if grep -q 'modelData.body' $notif_file
                log 'Applying privacy patch to lock screen notifications...'

                # Backup original
                sudo cp $notif_file $notif_file.orig

                # Apply patch
                sudo cp $patch_file $notif_file

                success 'Privacy patch applied. Restart shell: caelestia shell -k && caelestia shell -d'
            else
                success 'Privacy patch already applied'
            end
        else
            warn 'NotifGroup.qml not found - is caelestia-shell installed?'
        end
    else
        warn 'Patch file not found at patches/NotifGroup-privacy.qml'
        warn 'Create it first or manually apply the patch'
    end
end

# ─────────────────────────────────────────────────────────
# 4. Apply Battery Patch (optional)
# ─────────────────────────────────────────────────────────
if set -q _flag_battery_patch; and test -L ~/.config/hypr
    set -l qs_modules /etc/xdg/quickshell/caelestia/modules
    set -l patches_applied 0

    log 'Applying battery patches...'

    # Patch 1: StatusIcons - add battery percentage to bar
    set -l status_icons_file $qs_modules/bar/components/StatusIcons.qml
    set -l status_icons_patch $script_dir/patches/StatusIcons-battery-percent.qml
    if test -f $status_icons_patch; and test -f $status_icons_file
        if not grep -q 'Battery percentage text' $status_icons_file
            log 'Adding battery percentage to status bar...'
            sudo cp $status_icons_file $status_icons_file.orig
            sudo cp $status_icons_patch $status_icons_file
            set patches_applied (math $patches_applied + 1)
        else
            success 'StatusIcons battery percentage already applied'
        end
    else
        warn 'StatusIcons patch files not found'
    end

    # Patch 2: Performance tab (clean version without battery, battery is in its own tab)
    set -l perf_file $qs_modules/dashboard/Performance.qml
    set -l perf_patch $script_dir/patches/Performance.qml
    if test -f $perf_patch; and test -f $perf_file
        # Check if battery was removed from Performance (no UPower import)
        if grep -q 'Quickshell.Services.UPower' $perf_file
            log 'Cleaning Performance tab (removing battery)...'
            sudo cp $perf_file $perf_file.orig
            sudo cp $perf_patch $perf_file
            set patches_applied (math $patches_applied + 1)
        else
            success 'Performance tab already clean'
        end
    else
        warn 'Performance patch files not found'
    end

    # Patch 3: Dashboard Tabs - add Battery tab
    set -l tabs_file $qs_modules/dashboard/Tabs.qml
    set -l tabs_patch $script_dir/patches/dashboard-Tabs.qml
    if test -f $tabs_patch; and test -f $tabs_file
        if not grep -q 'battery_full' $tabs_file
            log 'Adding Battery tab to dashboard...'
            sudo cp $tabs_file $tabs_file.orig
            sudo cp $tabs_patch $tabs_file
            set patches_applied (math $patches_applied + 1)
        else
            success 'Dashboard Battery tab already applied'
        end
    else
        warn 'Tabs patch files not found'
    end

    # Patch 4: Dashboard Content - add Battery pane
    set -l content_file $qs_modules/dashboard/Content.qml
    set -l content_patch $script_dir/patches/dashboard-Content.qml
    if test -f $content_patch; and test -f $content_file
        if not grep -q 'Battery {}' $content_file
            log 'Adding Battery pane to dashboard...'
            sudo cp $content_file $content_file.orig
            sudo cp $content_patch $content_file
            set patches_applied (math $patches_applied + 1)
        else
            success 'Dashboard Battery pane already applied'
        end
    else
        warn 'Content patch files not found'
    end

    # Patch 5: Battery.qml component (Resource circles style)
    set -l battery_file $qs_modules/dashboard/Battery.qml
    set -l battery_patch $script_dir/patches/dashboard-Battery.qml
    if test -f $battery_patch
        # Check if using new Resource circles style (has "component Resource")
        if not test -f $battery_file; or not grep -q 'component Resource' $battery_file
            log 'Updating Battery.qml component...'
            if test -f $battery_file
                sudo cp $battery_file $battery_file.orig
            end
            sudo cp $battery_patch $battery_file
            set patches_applied (math $patches_applied + 1)
        else
            success 'Battery.qml component already up to date'
        end
    else
        warn 'Battery.qml patch file not found'
    end

    if test $patches_applied -gt 0
        success "Applied $patches_applied battery patches. Restart shell: caelestia shell -k && caelestia shell -d"
    else
        success 'All battery patches already applied'
    end
end

# ─────────────────────────────────────────────────────────
# 5. Pin Quickshell to Tested Commit (optional)
# ─────────────────────────────────────────────────────────
if set -q _flag_pin_quickshell
    set -l qs_pkgbuild_dir $script_dir/patches/quickshell-git

    if test -d $qs_pkgbuild_dir
        set -l current_commit (pacman -Q quickshell-git 2>/dev/null | grep -oP 'g[a-f0-9]+' | sed 's/^g//')
        set -l target_commit "41828c4"

        if test "$current_commit" = "$target_commit"
            success "Quickshell already pinned to $target_commit"
        else
            log "Building quickshell pinned to commit $target_commit..."
            log "This will take a few minutes..."

            set -l build_dir /tmp/quickshell-build-$fish_pid
            mkdir -p $build_dir
            cp $qs_pkgbuild_dir/* $build_dir/
            cd $build_dir

            makepkg -si --noconfirm
            set -l build_status $status

            cd -
            rm -rf $build_dir

            if test $build_status -eq 0
                success "Quickshell pinned to $target_commit"
            else
                err "Quickshell build failed"
            end
        end
    else
        err "Quickshell PKGBUILD not found at $qs_pkgbuild_dir"
    end
end

# ─────────────────────────────────────────────────────────
# 6. Setup Hyprland Auto-Start
# ─────────────────────────────────────────────────────────
if not set -q _flag_skip_autostart; and test -L ~/.config/hypr
    set -l fish_config ~/.config/fish/config.fish

    if test -f $fish_config
        if not grep -q 'uwsm start' $fish_config
            log 'Adding Hyprland auto-start to fish config...'

            # Add before the last 'end' of is-interactive block, or at end
            echo '' >> $fish_config
            echo '# Auto-start Hyprland on TTY1' >> $fish_config
            echo 'if test (tty) = /dev/tty1' >> $fish_config
            echo '    uwsm start hyprland-uwsm.desktop' >> $fish_config
            echo 'end' >> $fish_config

            success 'Added Hyprland auto-start'
        else
            success 'Hyprland auto-start already configured'
        end
    else
        warn 'Fish config not found at ~/.config/fish/config.fish'
    end
end

# ─────────────────────────────────────────────────────────
# 7. Reload Hyprland
# ─────────────────────────────────────────────────────────
if pgrep -x Hyprland &>/dev/null; and test -L ~/.config/hypr
    log 'Reloading Hyprland config...'
    hyprctl reload
    success 'Hyprland reloaded'
end

# ─────────────────────────────────────────────────────────
# Done
# ─────────────────────────────────────────────────────────
echo
success 'Hugo setup complete!'
echo
log 'Next steps:'
echo '  1. Fix lock screen rendering: ./install-hugo.fish --pin-quickshell'
echo '  2. Apply privacy patch: ./install-hugo.fish --privacy-patch'
echo '  3. Apply battery patches: ./install-hugo.fish --battery-patch'
echo '  4. Configure git: git config --global user.email "hugo.sibony@epita.fr"'
echo '  5. Generate SSH key: ssh-keygen -t ed25519 -C "hugo.sibony@epita.fr"'
echo '  6. Reboot to test auto-start'
