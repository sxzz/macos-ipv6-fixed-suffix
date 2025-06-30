#!/bin/bash

# macOS IPv6 Fixed Suffix Installer Script
# Features: Install program, set auto-start on boot, and run in background

set -e

SERVICE_NAME="com.github.sxzz.macos-ipv6-fixed-suffix"
INSTALL_DIR="/usr/local/bin/macos-ipv6-fixed-suffix"
PLIST_DIR="/Library/LaunchDaemons"
PLIST_FILE="$PLIST_DIR/$SERVICE_NAME.plist"
LOG_DIR="/var/log/macos-ipv6-fixed-suffix"
LOG_FILE="$LOG_DIR/ipv6_monitor.log"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${BLUE}[$(date '+%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This installer script must be run as administrator."
        echo "Please use: sudo ./install.sh"
        exit 1
    fi
}

check_system() {
    if [[ "$(uname)" != "Darwin" ]]; then
        error "This script only supports macOS."
        exit 1
    fi
    success "System check passed (macOS)"
}

create_directories() {
    log "Creating necessary directories..."
    if [[ ! -d "$INSTALL_DIR" ]]; then
        mkdir -p "$INSTALL_DIR"
        success "Created install directory: $INSTALL_DIR"
    fi
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
        success "Created log directory: $LOG_DIR"
    fi
}

download_files() {
    log "Downloading program files..."
    local run_script_url="https://raw.githubusercontent.com/sxzz/macos-ipv6-fixed-suffix/refs/heads/main/run.sh"
    if command -v wget >/dev/null 2>&1; then
        if wget -q "$run_script_url" -O "$INSTALL_DIR/run.sh"; then
            chmod +x "$INSTALL_DIR/run.sh"
            success "Downloaded main script to: $INSTALL_DIR/run.sh"
        else
            error "Failed to download script"
            exit 1
        fi
    elif command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$run_script_url" -o "$INSTALL_DIR/run.sh"; then
            chmod +x "$INSTALL_DIR/run.sh"
            success "Downloaded main script to: $INSTALL_DIR/run.sh"
        else
            error "Failed to download script"
            exit 1
        fi
    else
        error "curl or wget is required to download files"
        exit 1
    fi
}

create_launchd_plist() {
    log "Creating LaunchDaemon configuration file..."
    cat >"$PLIST_FILE" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SERVICE_NAME</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/run.sh</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
    <key>UserName</key>
    <string>root</string>
    <key>WorkingDirectory</key>
    <string>/tmp</string>
    <key>ThrottleInterval</key>
    <integer>10</integer>
</dict>
</plist>
EOF
    chown root:wheel "$PLIST_FILE"
    chmod 644 "$PLIST_FILE"
    success "Created LaunchDaemon config: $PLIST_FILE"
}

uninstall_old_version() {
    log "Checking and uninstalling old version if exists..."
    set +e
    if launchctl print "system/$SERVICE_NAME" >/dev/null 2>&1; then
        warning "Found running service, stopping..."
        if launchctl bootout system "$PLIST_FILE" 2>/dev/null; then
            warning "Stopped service using bootout"
        else
            launchctl unload "$PLIST_FILE" 2>/dev/null
            warning "Stopped service using unload"
        fi
        sleep 2
        if launchctl print "system/$SERVICE_NAME" >/dev/null 2>&1; then
            warning "Service may still be running, trying to force stop..."
            pkill -f "run.sh.*daemon" 2>/dev/null
        fi
    fi
    if [[ -f "$PLIST_FILE" ]]; then
        rm -f "$PLIST_FILE"
        warning "Deleted old config file"
    fi
    set -e
}

start_service() {
    log "Starting IPv6 monitor service..."
    if launchctl bootstrap system "$PLIST_FILE" 2>/dev/null; then
        success "Service loaded and started (bootstrap)"
    else
        log "Trying legacy load command..."
        if launchctl load "$PLIST_FILE" 2>/dev/null; then
            success "Service loaded and started (load)"
        else
            error "Failed to start service"
            warning "Please check config file: $PLIST_FILE"
            warning "Try manually: sudo launchctl bootstrap system '$PLIST_FILE'"
            exit 1
        fi
    fi
    sleep 3
    if SERVICE_INFO=$(launchctl print "system/$SERVICE_NAME" 2>/dev/null); then
        success "Service is running"
        log "Service label: $SERVICE_NAME"
        log "Log file: $LOG_FILE"
        PID=$(echo "$SERVICE_INFO" | grep "pid =" | awk '{print $3}')
        STATE=$(echo "$SERVICE_INFO" | grep "state =" | awk '{print $3}')
        if [[ -n "$PID" ]]; then
            log "Process PID: $PID"
        fi
        if [[ -n "$STATE" ]]; then
            log "Service state: $STATE"
        fi
    else
        error "Service failed to start"
        warning "Please check log file: $LOG_FILE"
        warning "Check service status manually: launchctl print 'system/$SERVICE_NAME'"
        exit 1
    fi
}

create_management_scripts() {
    log "Creating management script..."
    cat >"$INSTALL_DIR/control.sh" <<'EOF'
#!/bin/bash

SERVICE_NAME="com.github.sxzz.macos-ipv6-fixed-suffix"
PLIST_FILE="/Library/LaunchDaemons/$SERVICE_NAME.plist"
LOG_FILE="/var/log/macos-ipv6-fixed-suffix/ipv6_monitor.log"

case "$1" in
    start)
        echo "Starting IPv6 monitor service..."
        if sudo launchctl bootstrap system "$PLIST_FILE" 2>/dev/null; then
            echo "✓ Service started (bootstrap)"
        elif sudo launchctl load "$PLIST_FILE" 2>/dev/null; then
            echo "✓ Service started (load)"
        else
            echo "✗ Failed to start service"
            echo "Please check config file: $PLIST_FILE"
        fi
        ;;
    stop)
        echo "Stopping IPv6 monitor service..."
        if sudo launchctl bootout system "$PLIST_FILE" 2>/dev/null; then
            echo "✓ Service stopped (bootout)"
        elif sudo launchctl unload "$PLIST_FILE" 2>/dev/null; then
            echo "✓ Service stopped (unload)"
        else
            echo "✗ Failed to stop service"
        fi
        ;;
    restart)
        echo "Restarting IPv6 monitor service..."
        sudo launchctl bootout system "$PLIST_FILE" 2>/dev/null || sudo launchctl unload "$PLIST_FILE" 2>/dev/null || true
        sleep 1
        if sudo launchctl bootstrap system "$PLIST_FILE" 2>/dev/null; then
            echo "✓ Service restarted (bootstrap)"
        elif sudo launchctl load "$PLIST_FILE" 2>/dev/null; then
            echo "✓ Service restarted (load)"
        else
            echo "✗ Failed to restart service"
        fi
        ;;
    status)
        if SERVICE_INFO=$(launchctl print "system/$SERVICE_NAME" 2>/dev/null); then
            echo "✓ IPv6 monitor service is running"
            PID=$(echo "$SERVICE_INFO" | grep "pid =" | awk '{print $3}')
            STATE=$(echo "$SERVICE_INFO" | grep "state =" | awk '{print $3}')
            if [[ -n "$PID" ]]; then
                echo "PID: $PID"
            fi
            if [[ -n "$STATE" ]]; then
                echo "State: $STATE"
            fi
            echo "Service details:"
            echo "  Config file: $PLIST_FILE"
            echo "  Log file: $LOG_FILE"
        else
            echo "✗ IPv6 monitor service is not running"
            if [[ -f "$PLIST_FILE" ]]; then
                echo "Config file exists, try starting service:"
                echo "  sudo launchctl bootstrap system \"$PLIST_FILE\""
            else
                echo "Config file does not exist: $PLIST_FILE"
            fi
        fi
        ;;
    log)
        if [[ -f "$LOG_FILE" ]]; then
            tail -f "$LOG_FILE"
        else
            echo "Log file does not exist: $LOG_FILE"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|log}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the service"
        echo "  stop    - Stop the service"
        echo "  restart - Restart the service"
        echo "  status  - Show service status"
        echo "  log     - Show real-time log"
        exit 1
        ;;
esac
EOF
    chmod +x "$INSTALL_DIR/control.sh"
    success "Created management script: $INSTALL_DIR/control.sh"
    if [[ ! -L "/usr/local/bin/ipv6-monitor" ]]; then
        ln -s "$INSTALL_DIR/control.sh" "/usr/local/bin/ipv6-monitor"
        success "Created CLI tool: ipv6-monitor"
    fi
}

show_completion_info() {
    echo ""
    echo "=================================="
    success "Installation complete!"
    echo "=================================="
    echo ""
    echo "Service info:"
    echo "  Service name: $SERVICE_NAME"
    echo "  Install directory: $INSTALL_DIR"
    echo "  Log file: $LOG_FILE"
    echo ""
    echo "Management commands:"
    echo "  Check status: ipv6-monitor status"
    echo "  Start service: ipv6-monitor start"
    echo "  Stop service: ipv6-monitor stop"
    echo "  Restart service: ipv6-monitor restart"
    echo "  View log: ipv6-monitor log"
    echo ""
    echo "The service is set to start on boot and will automatically monitor IPv6 address changes in the background."
    echo ""
    warning "To uninstall the service, run: sudo launchctl unload $PLIST_FILE && sudo rm -f $PLIST_FILE"
}

main() {
    echo "macOS IPv6 Fixed Suffix Installer"
    echo "=================================="
    echo ""
    check_root
    check_system
    uninstall_old_version
    create_directories
    download_files
    create_launchd_plist
    start_service
    create_management_scripts
    show_completion_info
}

main "$@"
