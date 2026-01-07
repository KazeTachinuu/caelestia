#!/bin/bash
# Open terminal in the cwd of the focused terminal (if any)

get_cwd() {
    local pid cwd child_pids window_info current_pid found_cwd

    window_info=$(hyprctl activewindow -j 2>/dev/null) || return 1
    
    pid=$(echo "$window_info" | jq -r '.pid // empty')
    [[ -z "$pid" || ! -d "/proc/$pid" ]] && return 1
    
    current_pid="$pid"
    
    # Traverse child processes to find deepest shell with valid cwd
    while true; do
        child_pids=$(pgrep -P "$current_pid" 2>/dev/null)
        [[ -z "$child_pids" ]] && break
        
        local found=0
        for child in $child_pids; do
            if [[ -d "/proc/$child/cwd" ]]; then
                cwd=$(readlink -f "/proc/$child/cwd" 2>/dev/null)
                if [[ -d "$cwd" ]]; then
                    found_cwd="$cwd"
                    current_pid="$child"
                    found=1
                    break
                fi
            fi
        done
        
        [[ $found -eq 0 ]] && break
    done
    
    [[ -n "$found_cwd" ]] && echo "$found_cwd" && return 0
    return 1
}

cwd=$(get_cwd) || cwd="$HOME"
exec app2unit -- foot -D "$cwd"
