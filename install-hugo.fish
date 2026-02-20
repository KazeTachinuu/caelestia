#!/usr/bin/env fish
# Hugo's Caelestia Customization
# Patches quickshell via unified diffs applied to user config

set -l script_dir (dirname (status filename))
source $script_dir/lib/logging.fish
source $script_dir/lib/quickshell.fish

set -g MANIFEST $script_dir/patches/manifest.json
set -g PATCH_DIR $script_dir/patches

argparse -n 'install-hugo' 'h/help' 'all' 'privacy' 'battery' 'gpu' 'revert' 'status' 'skip-packages' -- $argv
or exit

if set -q _flag_h
    echo "Usage: ./install-hugo.fish [options]"
    echo
    echo "Options:"
    echo "  --all             Apply all patches"
    echo "  --privacy         Lock screen notification privacy"
    echo "  --battery         Battery percentage + dashboard tab"
    echo "  --gpu             Intel GPU monitoring support"
    echo "  --revert          Revert applied patches"
    echo "  --status          Show which patches are applied"
    echo "  --skip-packages   Skip installing extra packages"
    exit
end

if set -q _flag_all
    set -g _flag_privacy 1
    set -g _flag_battery 1
    set -g _flag_gpu 1
end

function get_patches -a group
    jq -r ".\"$group\"[]" $MANIFEST 2>/dev/null
end

function clean_patch_artifacts
    find $QS_USER -name "*.orig" -delete 2>/dev/null
    find $QS_USER -name "*.rej" -delete 2>/dev/null
end

function apply_group -a group
    get_patches $group | while read patch_name
        set -l patch_file $PATCH_DIR/$patch_name

        if not test -f $patch_file
            warn "  Patch not found: $patch_name"
            continue
        end

        # Check if already applied
        if patch -p1 -d $QS_USER --reverse --dry-run <$patch_file &>/dev/null
            success "  = $patch_name (already applied)"
            continue
        end

        # Try forward apply
        if patch -p1 -d $QS_USER --forward --dry-run <$patch_file &>/dev/null
            patch -p1 -d $QS_USER --forward --no-backup-if-mismatch <$patch_file &>/dev/null
            success "  + $patch_name"
        else
            warn "  ! $patch_name (conflict — base file version mismatch?)"
        end
    end
end

function revert_group -a group
    get_patches $group | while read patch_name
        set -l patch_file $PATCH_DIR/$patch_name

        if not test -f $patch_file
            continue
        end

        if patch -p1 -d $QS_USER --reverse --dry-run <$patch_file &>/dev/null
            patch -p1 -d $QS_USER --reverse <$patch_file &>/dev/null
            success "  - $patch_name"
        end
    end
end

function show_status
    echo
    log "Quickshell Config"
    echo "  System: $QS_SYSTEM"
    echo "  User:   $QS_USER"
    echo

    if qs_user_exists
        success "User config active"
    else
        log "Using system config (no patches applied)"
        return
    end
    echo

    for group in privacy battery gpu
        echo "  [$group]"
        get_patches $group | while read patch_name
            set -l patch_file $PATCH_DIR/$patch_name

            if not test -f $patch_file
                echo "    ? $patch_name (missing)"
                continue
            end

            if patch -p1 -d $QS_USER --reverse --dry-run <$patch_file &>/dev/null
                echo "    ✓ $patch_name"
            else if patch -p1 -d $QS_USER --forward --dry-run <$patch_file &>/dev/null
                echo "    · $patch_name"
            else
                echo "    ! $patch_name (conflict)"
            end
        end
    end
    echo
end

if set -q _flag_status
    show_status
    exit
end

if set -q _flag_revert
    if not qs_user_exists
        log "No user config to revert"
        exit
    end
    log "Reverting patches..."
    for group in gpu battery privacy
        revert_group $group
    end
    clean_patch_artifacts
    echo
    success "Done! Restart: caelestia shell -k && caelestia shell -d"
    exit
end

if not set -q _flag_privacy; and not set -q _flag_battery; and not set -q _flag_gpu
    show_status
    log "Use --all, --privacy, --battery, or --gpu to apply patches"
    exit
end

# Extra packages
if not set -q _flag_skip_packages
    log "Checking packages..."
    set -l packages ghostty neovim fd bat lazygit zoxide direnv
    set -l missing
    for pkg in $packages
        pacman -Q $pkg &>/dev/null; or set -a missing $pkg
    end
    if test (count $missing) -gt 0
        set -l helper (command -v paru; or command -v yay)
        if test -n "$helper"
            log "Installing: $missing"
            $helper -S --needed $missing
        else
            warn "No AUR helper found. Install manually: $missing"
        end
    else
        success "Packages OK"
    end
end

# Clone system quickshell config to user dir
qs_ensure_user

# Apply patches
for group in privacy battery gpu
    set -l flag _flag_$group
    if set -q $flag
        log "Applying $group patches..."
        apply_group $group
    end
end
clean_patch_artifacts

# Intel GPU extras
if set -q _flag_gpu
    if not test -f /usr/local/bin/intel-gpu-usage
        log "Installing intel-gpu-usage helper..."
        printf '%s\n' \
            '#!/usr/bin/env python3' \
            'import subprocess, json, signal, time, sys' \
            'try:' \
            '    p = subprocess.Popen(["intel_gpu_top", "-J", "-s", "400"],' \
            '                         stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)' \
            '    time.sleep(0.4)' \
            '    p.send_signal(signal.SIGTERM)' \
            '    d = p.stdout.read().decode()' \
            '    s = d.find("{")' \
            '    if s < 0:' \
            '        print(0); sys.exit(0)' \
            '    depth = 0' \
            '    for i, c in enumerate(d[s:], s):' \
            '        depth += 1 if c == "{" else (-1 if c == "}" else 0)' \
            '        if depth == 0:' \
            '            print(json.loads(d[s:i+1]).get("engines", {}).get("Render/3D", {}).get("busy", 0))' \
            '            break' \
            'except:' \
            '    print(0)' \
            | sudo tee /usr/local/bin/intel-gpu-usage >/dev/null
        sudo chmod +x /usr/local/bin/intel-gpu-usage
        success "intel-gpu-usage installed"
    end

    if command -v intel_gpu_top &>/dev/null
        if not getcap (which intel_gpu_top) 2>/dev/null | grep -q cap_perfmon
            log "Setting CAP_PERFMON on intel_gpu_top..."
            sudo setcap cap_perfmon=ep (which intel_gpu_top) 2>/dev/null
            and success "Capability set"
            or warn "Could not set capability"
        end
    end
end

echo
success "Done! Restart: caelestia shell -k && caelestia shell -d"
