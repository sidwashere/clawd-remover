#!/usr/bin/env bash
# ClawD/OpenClaw/MoltBot/Clawdbot Universal Removal Utility v3.0
# Licensed for all OSes: macOS, Linux, WSL, Git‑bash/Cygwin etc.

set -euo pipefail
IFS=$'\n\t'

# ANSI colors for fun CLI graphics
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
RESET="\033[0m"

log()    { echo -e "${CYAN}$1${RESET}"; maybe_easter_egg || true; }
warn()   { echo -e "${YELLOW}⚠️  $1${RESET}"; }
error()  { echo -e "${RED}❌ $1${RESET}" >&2; }
success(){ echo -e "${GREEN}✅ $1${RESET}"; }

# print a random text/ASCII-art banner occasionally
maybe_easter_egg() {
    # 20% chance to show something
    (( RANDOM % 5 == 0 )) || return 0
    local eggs=(
"🐙  Keep calm and squirt on."
"🎩  Did you know? ClawD stands for 'Can't Leave A Wild D...'"
"🦀  Crushin' claws, one line at a time!"
"✨  You're almost free of the bot!"
"📡  Signal lost... the claw has been removed."
    )
    echo -e "${MAGENTA}${eggs[RANDOM % ${#eggs[@]}]}${RESET}"
    return 0
}

# spinner helper used in loops
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\\'
    while ps -p $pid &>/dev/null; do
        printf "\r${BLUE}[%c]${RESET} " "${spinstr:0:1}"
        spinstr="${spinstr:1}${spinstr:0:1}"
        sleep $delay
    done
    printf "\r"  # clear line
}

# target names / keywords used in processes, packages, folders
TARGETS=("openclaw" "clawdbot" "moltbot" "clawd" "molt" "openclawbot")

check_command() {
    command -v "$1" &>/dev/null
}

kill_background_processes() {
    log "🛑 Stopping any running ClawD-related processes..."
    local pattern
    for pattern in "${TARGETS[@]}"; do
        if check_command pkill; then
            for i in {1..3}; do
                pkill -9 -f "$pattern" 2>/dev/null || true
                # show spinner during the short sleep to indicate activity
                ( sleep 1 ) &
                spinner $!
            done
        elif [[ "$OSTYPE" == "msys"* || "$OSTYPE" == "cygwin"* ]]; then
            taskkill //F //IM "$pattern.exe" 2>/dev/null || true
        else
            # fallback to ps/grep
            ps aux | grep -i "$pattern" | grep -v grep | awk '{print $2}' | xargs -r kill -9 2>/dev/null || true
        fi
    done
    # verification
    ( sleep 1 ) & spinner $!
    if pgrep -f "$(IFS='|'; echo "${TARGETS[*]}")" &>/dev/null; then
        warn "Some processes still running after retries. Run script again as sudo/ADMIN."
    else
        success "No ClawD processes remain."
    fi
}

cleanup_containers() {
    if check_command docker || check_command podman; then
        local engine=$(check_command docker && echo docker || echo podman)
        log "🐳 Cleaning $engine containers/images..."
        local containers=$($engine ps -a -q --filter "ancestor=openclaw/openclaw" --filter "name=openclaw" 2>/dev/null || true)
        if [[ -n "$containers" ]]; then
            $engine stop $containers 2>/dev/null || true
            $engine rm -f $containers 2>/dev/null || true
        fi
        $engine rmi openclaw/openclaw:latest 2>/dev/null || true
        success "No $engine containers or images detected."
    fi
}

remove_services() {
    case "$OSTYPE" in
        darwin*)
            log "🍎 Removing macOS LaunchAgents..."
            local plists=("$HOME/Library/LaunchAgents/ai.openclaw.gateway.plist" \
                          "$HOME/Library/LaunchAgents/com.openclaw.gateway.plist" \
                          "$HOME/Library/LaunchAgents/com.clawdbot.gateway.plist")
            for plist in "${plists[@]}"; do
                if [[ -f "$plist" ]]; then
                    launchctl bootout gui/$UID "$plist" 2>/dev/null || launchctl unload "$plist" 2>/dev/null || true
                    rm -f "$plist"
                fi
            done
            rm -rf /Applications/OpenClaw.app 2>/dev/null || true
            ;;
        linux-gnu*|darwin*)
            if check_command systemctl; then
                log "🐧 Disabling systemd units..."
                for svc in openclaw clawdbot; do
                    systemctl --user disable --now "$svc".service 2>/dev/null || true
                    rm -f "$HOME/.config/systemd/user/$svc.service" || true
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
    local cmds=("npm uninstall -g" "pnpm remove -g" "bun remove -g" \
                "brew uninstall" "apt-get remove -y" "yum remove -y" \
                "dnf remove -y" "pacman -Rns --noconfirm" "zypper rm -y" \
                "pip3 uninstall -y")
    for base in "${cmds[@]}"; do
        for pkg in "${TARGETS[@]}"; do
            if check_command ${base%% *}; then
                (eval "$base $pkg" 2>/dev/null || true)
            fi
        done
    done
    success "Package managers have been asked to uninstall ClawD components."
}

wipe_data() {
    log "🧨 Removing configuration and data directories..."
    local dirs=("$HOME/.openclaw" "$HOME/.clawdbot" "$HOME/clawdbot" "$HOME/.moltbot" "$HOME/.config/openclaw" )
    for d in "${dirs[@]}"; do
        rm -rf "$d" 2>/dev/null || true
    done
    ([[ "$OSTYPE" == darwin* ]] && rm -rf "$HOME/Library/Logs/OpenClaw" 2>/dev/null) || true
    success "Data directories wiped."
}

cleanup_links() {
    log "🧹 Cleaning up leftover binaries from PATH..."
    for bin in "${TARGETS[@]}"; do
        if BINPATH=$(which "$bin" 2>/dev/null || true) && [[ -n "$BINPATH" ]]; then
            # try non-interactive sudo first; if that fails or is unavailable, fall back to plain rm
            if check_command sudo; then
                sudo -n rm -f "$BINPATH" 2>/dev/null || rm -f "$BINPATH" || true
            else
                rm -f "$BINPATH" || true
            fi
        fi
    done
    success "Binary links removed."
}

verify_final() {
    log "🔍 Performing final verification..."
    local leftovers=0

    # processes
    if pgrep -f "$(IFS='|'; echo "${TARGETS[*]}")" &>/dev/null; then
        warn "👀 Some related processes still running."
        leftovers=$((leftovers+1))
    fi
    # commands
    for bin in "${TARGETS[@]}"; do
        if which "$bin" &>/dev/null; then
            warn "👀 Found binary '$bin' on PATH."
            leftovers=$((leftovers+1))
        fi
    done
    # folders
    for d in "$HOME/.openclaw" "$HOME/.clawdbot" "$HOME/clawdbot" "$HOME/.moltbot"; do
        if [[ -e $d ]]; then
            warn "👀 Leftover directory: $d"
            leftovers=$((leftovers+1))
        fi
    done

    if [[ $leftovers -eq 0 ]]; then
        success "🎯 All checks passed. ClawD/Clawdbot removed successfully."
        log "⚠️  SECURITY ALERT: rotate any API keys or credentials that may have been stored."
        exit 0
    else
        error "⚠️  Some items could not be removed automatically. Inspect warnings above and retry."
        exit 1
    fi
}

main() {
    log "🚀 Starting universal clean procedure..."
    kill_background_processes
    cleanup_containers
    remove_services
    package_uninstall
    wipe_data
    cleanup_links
    verify_final
}

# run the script
main
