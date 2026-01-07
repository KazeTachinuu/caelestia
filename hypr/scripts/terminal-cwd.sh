#!/bin/bash
# Get the current working directory from the active terminal window
# Falls back to $HOME seamlessly if anything fails

get_cwd() {
    local pid cwd child_pids

    # Get active window info
    local window_info
    window_info=$(hyprctl activewindow -j 2>/dev/null) || return 1
    
    pid=$(echo "$window_info" | jq -r '.pid // empty')
    [[ -z "$pid" ]] && return 1
    
    # Check if process exists
    [[ -d "/proc/$pid" ]] || return 1
    
    # Try to find the deepest child shell process (handles nested shells, tmux, etc.)
    local current_pid="$pid"
    local found_cwd=""
    
    while true; do
        # Get children of current process
        child_pids=$(pgrep -P "$current_pid" 2>/dev/null)
        [[ -z "$child_pids" ]] && break
        
        # Check each child for a valid cwd
        for child in $child_pids; do
            if [[ -d "/proc/$child/cwd" ]]; then
                cwd=$(readlink -f "/proc/$child/cwd" 2>/dev/null)
                if [[ -d "$cwd" ]]; then
                    found_cwd="$cwd"
                    current_pid="$child"
                    break
                fi
            fi
        done
        
        # If we didn't find any valid child, stop
        [[ "$current_pid" == "$pid" ]] && break
        pid="$current_pid"
    done
    
    # If we found a cwd, use it; otherwise try the original process
    if [[ -n "$found_cwd" ]]; then
        echo "$found_cwd"
        return 0
    fi
    
    return 1
}

# Output cwd or fallback to HOME
get_cwd || echo "$HOME"
