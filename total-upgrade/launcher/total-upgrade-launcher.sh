#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# @a2ml-metadata begin
# (
#   id                   = "total-upgrade-launcher"
#   type                 = "launcher"
#   version              = "1.0.0"
#   app-name             = "total-upgrade"
#   app-display          = "Total Upgrade"
#   app-url              = ""
#   standards-compliance = [
#     "launcher-standard.adoc"
#   ]
#   modes = [
#     "--start"
#     "--stop"
#     "--status"
#     "--auto"
#     "--integ"
#     "--disinteg"
#     "--help"
#     "--version"
#   ]
#   platforms = [
#     "linux"
#     "macos"
#     "windows"
#   ]
# )
# @a2ml-metadata end

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
APP_NAME="total-upgrade"
APP_DISPLAY="Total Upgrade"
APP_DESC="Cross-platform meta-manager for tool and package management"
APP_CATEGORIES="Development;System;Utility;"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMMAND="cargo run --release --" # During dev; usually an absolute path to the compiled binary
URL="" 
PID_FILE="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/${APP_NAME}-daemon.pid"
LOG_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/${APP_NAME}"
LOG_FILE="${LOG_DIR}/daemon.log"
MODE="${1:---tui}"
FORCE="false"
[[ "${2:-}" == "--force" ]] && FORCE="true"

mkdir -p "$LOG_DIR"

# ----------------------------------------------------------------------------
# PLATFORM DETECTION
# ----------------------------------------------------------------------------
case "$(uname -s)" in
    Linux*)                          PLATFORM="linux"   ;;
    Darwin*)                         PLATFORM="macos"   ;;
    CYGWIN*|MINGW*|MSYS*|Windows_NT) PLATFORM="windows" ;;
    *)                               PLATFORM="unknown" ;;
esac

case "$PLATFORM" in
    linux)
        APPS_DIR="$HOME/.local/share/applications"
        ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"
        DESKTOP_SHORTCUT_DIR="$HOME/Desktop"
        BIN_DIR="$HOME/.local/bin"
        AUTOSTART_DIR="$HOME/.config/autostart"
        DESKTOP_FILE_TARGET="$APPS_DIR/${APP_NAME}.desktop"
        DESKTOP_SHORTCUT_TARGET="$DESKTOP_SHORTCUT_DIR/${APP_NAME}.desktop"
        AUTOSTART_TARGET="$AUTOSTART_DIR/${APP_NAME}-daemon.desktop"
        ICON_TARGET="$ICON_DIR/${APP_NAME}.png"
        LAUNCHER_TARGET="$BIN_DIR/${APP_NAME}-launcher"
        ;;
    macos)
        APPS_DIR="$HOME/Applications"
        DESKTOP_SHORTCUT_DIR="$HOME/Desktop"
        BIN_DIR="$HOME/.local/bin"
        AUTOSTART_DIR="$HOME/Library/LaunchAgents"
        DESKTOP_FILE_TARGET="$APPS_DIR/${APP_DISPLAY}.app"
        DESKTOP_SHORTCUT_TARGET="$DESKTOP_SHORTCUT_DIR/${APP_DISPLAY}.command"
        AUTOSTART_TARGET="$AUTOSTART_DIR/org.hyperpolymath.${APP_NAME}.plist"
        ICON_TARGET="$APPS_DIR/${APP_DISPLAY}.app/Contents/Resources/icon.png"
        LAUNCHER_TARGET="$BIN_DIR/${APP_NAME}-launcher"
        ;;
    windows)
        APPDATA_DIR="${APPDATA:-$HOME/AppData/Roaming}"
        START_MENU_DIR="$APPDATA_DIR/Microsoft/Windows/Start Menu/Programs"
        DESKTOP_SHORTCUT_DIR="$HOME/Desktop"
        AUTOSTART_DIR="$APPDATA_DIR/Microsoft/Windows/Start Menu/Programs/Startup"
        BIN_DIR="$HOME/.local/bin"
        DESKTOP_FILE_TARGET="$START_MENU_DIR/${APP_DISPLAY}.lnk"
        DESKTOP_SHORTCUT_TARGET="$DESKTOP_SHORTCUT_DIR/${APP_DISPLAY}.lnk"
        AUTOSTART_TARGET="$AUTOSTART_DIR/${APP_DISPLAY} Daemon.lnk"
        ICON_TARGET="$BIN_DIR/${APP_NAME}.ico"
        LAUNCHER_TARGET="$BIN_DIR/${APP_NAME}-launcher.sh"
        ;;
esac

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

log() { echo "[$APP_NAME] $1"; }
err() { echo "[$APP_NAME] ERROR: $1" >&2; }
warn() { echo "[$APP_NAME] WARN: $1" >&2; }

is_running() {
  [ -f "$PID_FILE" ] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null
}

start_daemon() {
  if is_running; then
    log "Daemon already running (PID: $(cat "$PID_FILE"))"
    return 0
  fi
  log "Starting $APP_NAME background daemon..."
  cd "$REPO_DIR"
  # Run the Rust binary in daemon mode
  nohup $COMMAND --daemon >"$LOG_FILE" 2>&1 &
  echo $! > "$PID_FILE"
  log "Daemon started successfully"
  return 0
}

stop_daemon() {
  if ! is_running; then
    log "No running daemon found"
    return 0
  fi
  log "Stopping $APP_NAME daemon..."
  kill "$(cat "$PID_FILE")" 2>/dev/null || true
  rm -f "$PID_FILE"
  log "Daemon stopped"
}

run_tui() {
  cd "$REPO_DIR"
  exec $COMMAND
}

# ============================================================================
# SYSTEM INTEGRATION — --integ / --disinteg
# ============================================================================

already_integrated() {
    [ -f "$DESKTOP_FILE_TARGET" ] || [ -f "$LAUNCHER_TARGET" ]
}

write_linux_desktop_file() {
    local target="$1"
    local term="${2:-true}"
    local mode="${3:---tui}"
    local name_ext="${4:-}"
    cat > "$target" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=$APP_DISPLAY$name_ext
Comment=$APP_DESC
Exec=$LAUNCHER_TARGET $mode
Icon=applications-system
Terminal=$term
Categories=$APP_CATEGORIES
StartupNotify=true
StartupWMClass=$APP_NAME
EOF
    chmod 444 "$target"
}

do_integ_linux() {
    mkdir -p "$APPS_DIR" "$ICON_DIR" "$BIN_DIR" "$DESKTOP_SHORTCUT_DIR" "$AUTOSTART_DIR"
    cp "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" "$LAUNCHER_TARGET"
    chmod +x "$LAUNCHER_TARGET"

    write_linux_desktop_file "$DESKTOP_FILE_TARGET" "true" "--tui"
    write_linux_desktop_file "$DESKTOP_SHORTCUT_TARGET" "true" "--tui"
    
    # Autostart daemon (no terminal)
    write_linux_desktop_file "$AUTOSTART_TARGET" "false" "--start" " Daemon"

    command -v update-desktop-database >/dev/null 2>&1 && \
        update-desktop-database "$APPS_DIR" 2>/dev/null || true

    if command -v gio >/dev/null 2>&1; then
        gio set "$DESKTOP_FILE_TARGET" "metadata::trusted" true 2>/dev/null || true
        gio set "$DESKTOP_SHORTCUT_TARGET" "metadata::trusted" true 2>/dev/null || true
    fi
}

do_integ_macos() {
    mkdir -p "$APPS_DIR" "$BIN_DIR" "$DESKTOP_SHORTCUT_DIR" "$AUTOSTART_DIR"
    cp "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" "$LAUNCHER_TARGET"
    chmod +x "$LAUNCHER_TARGET"
    local bundle="$DESKTOP_FILE_TARGET"
    mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
    cat > "$bundle/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<plist version="1.0"><dict>
<key>CFBundleName</key><string>$APP_DISPLAY</string>
<key>CFBundleIdentifier</key><string>org.hyperpolymath.$APP_NAME</string>
<key>CFBundleExecutable</key><string>$APP_NAME</string>
<key>CFBundleIconFile</key><string>icon</string>
</dict></plist>
PLIST
    cat > "$bundle/Contents/MacOS/$APP_NAME" <<EOF
#!/usr/bin/env bash
exec "$LAUNCHER_TARGET" --tui
EOF
    chmod +x "$bundle/Contents/MacOS/$APP_NAME"
    cat > "$DESKTOP_SHORTCUT_TARGET" <<EOF
#!/usr/bin/env bash
exec "$LAUNCHER_TARGET" --tui
EOF
    chmod +x "$DESKTOP_SHORTCUT_TARGET"
    
    # Autostart plist
    cat > "$AUTOSTART_TARGET" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>org.hyperpolymath.$APP_NAME</string>
    <key>ProgramArguments</key><array><string>$LAUNCHER_TARGET</string><string>--start</string></array>
    <key>RunAtLoad</key><true/>
</dict>
</plist>
EOF
}

do_integ_windows() {
    mkdir -p "$BIN_DIR" "$(dirname "$DESKTOP_FILE_TARGET")" "$DESKTOP_SHORTCUT_DIR" "$AUTOSTART_DIR"
    cp "$SCRIPT_DIR/$(basename "${BASH_SOURCE[0]}")" "$LAUNCHER_TARGET"
    chmod +x "$LAUNCHER_TARGET"
    if command -v powershell.exe >/dev/null 2>&1; then
        powershell.exe -NoProfile -NonInteractive -Command "
            \$ws = New-Object -ComObject WScript.Shell
            \$sc = \$ws.CreateShortcut('$DESKTOP_FILE_TARGET')
            \$sc.TargetPath = 'bash.exe'
            \$sc.Arguments = '-c \"$LAUNCHER_TARGET --tui\"'
            \$sc.Save()
            \$sc2 = \$ws.CreateShortcut('$DESKTOP_SHORTCUT_TARGET')
            \$sc2.TargetPath = 'bash.exe'
            \$sc2.Arguments = '-c \"$LAUNCHER_TARGET --tui\"'
            \$sc2.Save()
            \$sc3 = \$ws.CreateShortcut('$AUTOSTART_TARGET')
            \$sc3.TargetPath = 'bash.exe'
            \$sc3.Arguments = '-c \"$LAUNCHER_TARGET --start\"'
            \$sc3.WindowStyle = 7
            \$sc3.Save()
        " 2>/dev/null
    else
        warn "PowerShell not available. Skipping shortcut creation."
    fi
}

do_integ() {
    if already_integrated && [ "$FORCE" != "true" ]; then
        warn "$APP_DISPLAY is already integrated with the system."
        read -rp "Reinstall? [y/N] " confirm
        [[ ! "$confirm" =~ ^[Yy]$ ]] && { log "Nothing changed."; return 0; }
    fi
    log "Integrating $APP_DISPLAY with the $PLATFORM desktop..."
    case "$PLATFORM" in
        linux)   do_integ_linux   ;;
        macos)   do_integ_macos   ;;
        windows) do_integ_windows ;;
        *)       err "Unsupported platform: $PLATFORM"; return 1 ;;
    esac
    log "✓ $APP_DISPLAY integrated. Remove with: $LAUNCHER_TARGET --disinteg"
}

do_disinteg() {
    log "Removing $APP_DISPLAY system integration..."
    is_running && stop_daemon
    local targets=(
        "$DESKTOP_FILE_TARGET" "$DESKTOP_SHORTCUT_TARGET"
        "$AUTOSTART_TARGET" "$LAUNCHER_TARGET"
    )
    for t in "${targets[@]}"; do
        [ -z "$t" ] && continue
        if [ -e "$t" ] || [ -L "$t" ]; then
            [ -d "$t" ] && rm -rf "$t" || rm -f "$t"
            log "  - $t"
        fi
    done
    [ "$PLATFORM" = "linux" ] && command -v update-desktop-database >/dev/null 2>&1 && \
        update-desktop-database "$APPS_DIR" 2>/dev/null || true
    log "✓ $APP_DISPLAY removed."
}

# ============================================================================
# MAIN SWITCH
# ============================================================================

case "$MODE" in
  --start)              start_daemon ;;
  --stop)               stop_daemon ;;
  --status)
    if is_running; then
      log "Daemon is running (PID: $(cat "$PID_FILE"))"
    else
      log "Daemon is not running"
    fi
    ;;
  --tui)                run_tui ;;
  --integ)              do_integ ;;
  --disinteg)           do_disinteg ;;
  --version|-V)         exec $COMMAND --version ;;
  --help|-h)
    cat <<EOF
$APP_DISPLAY launcher

Modes:
  --tui        Launch the interactive TUI (default)
  --start      Start the background daemon (silent)
  --stop       Stop the background daemon
  --status     Check daemon status
  --integ      Install as desktop app & autostart daemon
  --disinteg   Remove system integration
  --help       Show this help
  --version    Show version
EOF
    ;;
  *)                    run_tui ;;
esac
