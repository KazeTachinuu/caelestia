set -g QS_SYSTEM /etc/xdg/quickshell/caelestia
set -g QS_USER ~/.config/quickshell/caelestia

function qs_user_exists
    test -d $QS_USER -a -f $QS_USER/shell.qml
end

function qs_system_exists
    test -d $QS_SYSTEM -a -f $QS_SYSTEM/shell.qml
end

function qs_clone_to_user
    if qs_user_exists
        return 0
    end

    if not qs_system_exists
        err "System quickshell config not found at $QS_SYSTEM"
        return 1
    end

    log "Cloning quickshell config to user directory..."
    mkdir -p (dirname $QS_USER)
    cp -r $QS_SYSTEM $QS_USER
    success "Cloned to $QS_USER"
end

function qs_reset
    if qs_user_exists
        log "Removing user quickshell config..."
        rm -rf $QS_USER
        success "Removed. System config will be used."
    else
        log "No user config to remove"
    end
end

function qs_ensure_user
    if not qs_user_exists
        qs_clone_to_user
    end
end
