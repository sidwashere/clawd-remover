#!/usr/bin/env bash
# ClawD/OpenClaw/MoltBot/Clawdbot Universal Removal Utility v3.1
# Licensed for all OSes: macOS, Linux, WSL, Git‑bash/Cygwin etc.

set -euo pipefail
IFS=$'\n\t'

# Detect if we're in a supported shell
if [[ -z "${BASH_VERSION:-}" ]]; then
    echo "ERROR: This script requires bash. Please run with: bash clawd-remover.sh"
    exit 1
fi

# Detect terminal capabilities for ANSI color support
if [[ "${TERM:-}" == "dumb" ]] || [[ ! -t 1 ]] && [[ "${CI:-}" != "true" ]]; then
    COLORS_ENABLED=0
else
    COLORS_ENABLED=1
fi

# ANSI colors for fun CLI graphics (conditionally enabled)
if [[ $COLORS_ENABLED -eq 1 ]]; then
    RED="\033[0;31m"
    GREEN="\033[0;32m"
    YELLOW="\033[0;33m"
    BLUE="\033[0;34m"
    MAGENTA="\033[0;35m"
    CYAN="\033[0;36m"
    RESET="\033[0m"
else
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    RESET=""
fi

log()    { echo -e "${CYAN}$1${RESET}"; }
warn()   { echo -e "${YELLOW}⚠️  $1${RESET}"; }
error()  { echo -e "${RED}❌ $1${RESET}" >&2; }
success(){ echo -e "${GREEN}✅ $1${RESET}"; }

# print a random text/ASCII-art banner occasionally (non-blocking)
maybe_easter_egg() {
    [[ $COLORS_ENABLED -eq 0 ]] && return 0
    # 20% chance to show something
    (( RANDOM % 5 == 0 )) || return 0
    local eggs=(
"🐙  Keep calm and squirt on."
"🎩  Did you know? ClawD stands for 'Can't Leave A Wild D...'"
"🦀  Crushin' claws, one line at a time!"
"✨  You're almost free of the bot!"
"📡  Signal lost... the claw has been removed."
    )
    (echo -e "${MAGENTA}${eggs[RANDOM % ${#eggs[@]}]}${RESET}" 2>/dev/null || true) >&2
    return 0
}

# Trigger easter egg after operations (non-blocking) 
trigger_easter_egg() {
    maybe_easter_egg || true &
}

# spinner helper used in loops (Windows-safe)
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    # Skip spinner on Windows or when colors disabled
    if [[ "${OSTYPE}" == "msys"* ]] || [[ "${OSTYPE}" == "cygwin"* ]] || [[ $COLORS_ENABLED -eq 0 ]]; then
        wait "$pid" 2>/dev/null || true
        return
    fi
    while ps -p $pid &>/dev/null 2>&1; do
        printf "\r${BLUE}[%c]${RESET} " "${spinstr:0:1}"
        spinstr="${spinstr:1}${spinstr:0:1}"
        sleep $delay
    done
    printf "\r"  # clear line
}

# target names / keywords used in processes, packages, folders
TARGETS=("openclaw" "clawdbot" "moltbot" "clawd" "molt" "openclawbot")

check_command() {
    command -v "$1" &>/dev/null || return 1
    return 0
}

# Safe process detection with fallbacks
has_process() {
    local pattern="$1"
    if command -v pgrep &>/dev/null; then
        pgrep -f "$pattern" &>/dev/null && return 0 || return 1
    elif command -v ps &>/dev/null; then
        ps aux 2>/dev/null | grep -i "$pattern" | grep -v grep &>/dev/null && return 0 || return 1
    else
        return 1
    fi
}

# Safe kill process with fallbacks
kill_process_safe() {
    local pattern="$1"
    if command -v pkill &>/dev/null; then
        pkill -9 -f "$pattern" 2>/dev/null || true
    elif [[ "${OSTYPE}" == "msys"* ]] || [[ "${OSTYPE}" == "cygwin"* ]]; then
        taskkill //F //IM "${pattern}.exe" 2>/dev/null || true
        taskkill //F //IM "${pattern}" 2>/dev/null || true
    elif command -v ps &>/dev/null && command -v kill &>/dev/null; then
        ps aux 2>/dev/null | grep -i "$pattern" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null || true
    fi
}

kill_background_processes() {
    log "🛑 Stopping any running ClawD-related processes..."
    local pattern
    local found_any=0
    
    for pattern in "${TARGETS[@]}"; do
        if has_process "$pattern"; then
            found_any=1
            kill_process_safe "$pattern"
            sleep 0.5
            kill_process_safe "$pattern"
            sleep 0.5
        fi
    done
    
    # Final verification with timeout
    sleep 1
    local verify_attempts=0
    while [[ $verify_attempts -lt 3 ]]; do
        local still_running=0
        for pattern in "${TARGETS[@]}"; do
            if has_process "$pattern"; then
                still_running=1
                break
            fi
        done
        [[ $still_running -eq 0 ]] && break
        verify_attempts=$((verify_attempts+1))
        sleep 1
    done
    
    if [[ $found_any -eq 0 ]]; then
        success "No ClawD processes found."
    else
        # Check final status
        local any_remain=0
        for pattern in "${TARGETS[@]}"; do
            if has_process "$pattern"; then
                any_remain=1
                break
            fi
        done
        if [[ $any_remain -eq 0 ]]; then
            success "All ClawD processes terminated."
        else
            warn "Some processes still running after retries. Run script again as sudo/ADMIN."
        fi
    fi
}

cleanup_containers() {
    local engine=""
    if check_command docker; then
        engine="docker"
    elif check_command podman; then
        engine="podman"
    else
        # No container engine found, skip
        return 0
    fi
    
    log "🐳 Cleaning $engine containers/images..."
    
    # Stop and remove containers
    local containers
    containers=$($engine ps -a -q --filter "ancestor=openclaw/openclaw" --filter "name=openclaw" 2>/dev/null || echo "")
    if [[ -n "$containers" ]]; then
        $engine stop $containers 2>/dev/null || true
        $engine rm -f $containers 2>/dev/null || true
    fi
    
    # Remove images
    $engine rmi openclaw/openclaw:latest 2>/dev/null || true
    for img in openclaw clawdbot moltbot molt openclawbot; do
        $engine rmi "$img:latest" 2>/dev/null || true
        $engine rmi "$img" 2>/dev/null || true
    done
    
    success "Container cleanup completed for $engine."
}

remove_services() {
    case "$OSTYPE" in
        darwin*)
            log "🍎 Removing macOS LaunchAgents..."
            local plists=("$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist" \
                          "$HOME/Library/LaunchAgents/com.openclaw.gateway.plist" \
                          "$HOME/Library/LaunchAgents/com.clawdbot.gateway.plist" \
                          "$HOME/Library/LaunchDaemons/ai.openclaw.gateway.plist" \
                          "$HOME/Library/LaunchDaemons/com.openclaw.gateway.plist" \
                          "$HOME/Library/LaunchDaemons/com.clawdbot.gateway.plist")
            for plist in "${plists[@]}"; do
                if [[ -f "$plist" ]]; then
                    launchctl bootout gui/$UID "$plist" 2>/dev/null || launchctl unload "$plist" 2>/dev/null || true
                    rm -f "$plist" 2>/dev/null || true
                fi
            done
            rm -rf /Applications/OpenClaw.app 2>/dev/null || true
            ;;
        linux-gnu*)
            if check_command systemctl; then
                log "🐧 Disabling systemd units..."
                for svc in openclaw clawdbot moltbot molt openclawbot; do
                    systemctl --user disable --now "$svc".service 2>/dev/null || true
                    systemctl --global disable --now "$svc".service 2>/dev/null || true
                    rm -f "$HOME/.config/systemd/user/$svc.service" 2>/dev/null || true
                done
                systemctl --user daemon-reload 2>/dev/null || true
            fi
            ;;
        msys*|cygwin*)
            log "🪟 Windows environment detected; skipping UNIX service removal."
            ;;
        *)
            log "ℹ️  Unknown OSTYPE '$OSTYPE'; skipping service removal."
            ;;
    esac
    success "Service units and launch agents removed."
}

package_uninstall() {
    log "📦 Uninstalling packages via known package managers..."
    local cmds=("npm uninstall -g" "pnpm remove -g" "yarn global remove" "bun remove -g" \
                "brew uninstall" "apt-get remove -y" "apt remove -y" \
                "yum remove -y" "dnf remove -y" "pacman -Rns --noconfirm" \
                "zypper rm -y" "emerge --unmerge" \
                "pip3 uninstall -y" "pip uninstall -y" "conda remove -y")
    
    for base in "${cmds[@]}"; do
        # Get the first word (command name)
        local cmd_name="${base%% *}"
        # Only proceed if command exists
        if ! check_command "$cmd_name"; then
            continue
        fi
        
        for pkg in "${TARGETS[@]}"; do
            # Try uninstall but don't fail on error
            (eval "$base $pkg" 2>/dev/null || true)
        done
    done
    
    success "Package managers have been queried for ClawD component removal."
}

wipe_data() {
    log "🧨 Removing configuration and data directories..."
    local dirs=("$HOME/.openclaw" "$HOME/.clawdbot" "$HOME/clawdbot" "$HOME/.moltbot" \
                "$HOME/.molt" "$HOME/.config/openclaw" "$HOME/.config/clawdbot" \
                "$HOME/.cache/openclaw" "$HOME/.cache/clawdbot" "$HOME/.local/share/openclaw")
    
    for d in "${dirs[@]}"; do
        if [[ -e "$d" ]]; then
            rm -rf "$d" 2>/dev/null || warn "Could not remove: $d"
        fi
    done
    
    # macOS-specific log directories
    if [[ "$OSTYPE" == darwin* ]]; then
        rm -rf "$HOME/Library/Logs/OpenClaw" 2>/dev/null || true
        rm -rf "$HOME/Library/Logs/Clawdbot" 2>/dev/null || true
        rm -rf "$HOME/Library/Caches/openclaw" 2>/dev/null || true
        rm -rf "$HOME/Library/Caches/clawdbot" 2>/dev/null || true
        rm -rf "$HOME/Library/Application Support/openclaw" 2>/dev/null || true
    fi
    
    success "Data directories cleaned."
}

cleanup_links() {
    log "🧹 Cleaning up leftover binaries from PATH..."
    for bin in "${TARGETS[@]}"; do
        # Use 'which' with proper error handling
        local binpath
        binpath=$(command -v "$bin" 2>/dev/null || echo "")
        
        if [[ -n "$binpath" ]] && [[ -f "$binpath" ]]; then
            # Try to remove, with sudo fallback
            if ! rm -f "$binpath" 2>/dev/null; then
                if check_command sudo; then
                    sudo -n rm -f "$binpath" 2>/dev/null || warn "Could not remove binary: $binpath"
                else
                    warn "Could not remove binary: $binpath (no sudo)"
                fi
            fi
        fi
        
        # Also check common PATH locations for Windows
        if [[ "${OSTYPE}" == "msys"* ]] || [[ "${OSTYPE}" == "cygwin"* ]]; then
            local exe_path="/usr/local/bin/${bin}.exe"
            if [[ -f "$exe_path" ]]; then
                rm -f "$exe_path" 2>/dev/null || true
            fi
        fi
    done
    success "Binary link cleanup completed."
}

verify_final() {
    log "🔍 Performing final verification..."
    local leftovers=0
    echo ""

    # Check processes
    for bin in "${TARGETS[@]}"; do
        if has_process "$bin"; then
            warn "Found running process: $bin"
            leftovers=$((leftovers+1))
        fi
    done
    
    # Check commands on PATH
    for bin in "${TARGETS[@]}"; do
        if command -v "$bin" &>/dev/null; then
            warn "Found binary on PATH: $bin"
            leftovers=$((leftovers+1))
        fi
    done
    
    # Check data directories
    local dirs=("$HOME/.openclaw" "$HOME/.clawdbot" "$HOME/clawdbot" "$HOME/.moltbot" \
                "$HOME/.molt" "$HOME/.config/openclaw" "$HOME/.config/clawdbot")
    for d in "${dirs[@]}"; do
        if [[ -e "$d" ]]; then
            warn "Found leftover directory: $d"
            leftovers=$((leftovers+1))
        fi
    done
    
    echo ""
    if [[ $leftovers -eq 0 ]]; then
        success "🎯 All checks passed. ClawD/Clawdbot removed successfully."
        echo ""
        echo -e "${YELLOW}[SECURITY ALERT]${RESET} Rotate any API keys or credentials that may have been stored."
        echo ""
        return 0
    else
        error "Some items could not be removed automatically. Inspect warnings above and retry."
        return 1
    fi
}

main() {
    echo ""
    log "🚀 Starting universal ClawD removal procedure (v3.1)..."
    log "OS: ${OSTYPE} | Shell: ${BASH_VERSION}"
    echo ""
    
    # Run all cleanup steps
    kill_background_processes
    cleanup_containers
    remove_services
    package_uninstall
    wipe_data
    cleanup_links
    
    # Final verification
    verify_final
    local final_status=$?
    
    echo ""
    if [[ $final_status -eq 0 ]]; then
        success "Removal completed successfully!"
        exit 0
    else
        error "Removal completed with warnings. Please review above."
        exit 1
    fi
}

# Run the script
main "$@"
