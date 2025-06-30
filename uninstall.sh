#!/bin/bash

SERVICE_NAME="com.github.sxzz.macos-ipv6-fixed-suffix"
PLIST_FILE="/Library/LaunchDaemons/$SERVICE_NAME.plist"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}macOS IPv6 Fixed Suffix Uninstaller${NC}"
echo "========================================"
echo ""

if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}Error: Administrator privileges required${NC}"
    echo "Please use: sudo ./uninstall.sh"
    exit 1
fi

echo -e "${YELLOW}Uninstalling service...${NC}"

if launchctl list | grep -q "$SERVICE_NAME"; then
    if launchctl bootout system "$PLIST_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Service stopped (bootout)"
    elif launchctl unload "$PLIST_FILE" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Service stopped (unload)"
    else
        echo -e "${YELLOW}⚠${NC} Failed to stop service"
    fi
else
    echo -e "${YELLOW}⚠${NC} Service is not running"
fi

if [[ -f "$PLIST_FILE" ]]; then
    rm -f "$PLIST_FILE"
    echo -e "${GREEN}✓${NC} Service config file deleted"
fi

if [[ -L "/usr/local/bin/ipv6-monitor" ]]; then
    rm -f "/usr/local/bin/ipv6-monitor"
    echo -e "${GREEN}✓${NC} CLI tool deleted"
fi

if [[ -d "/usr/local/bin/macos-ipv6-fixed-suffix" ]]; then
    rm -rf "/usr/local/bin/macos-ipv6-fixed-suffix"
    echo -e "${GREEN}✓${NC} Program files deleted"
fi

if [[ -d "/var/log/macos-ipv6-fixed-suffix" ]]; then
    rm -rf "/var/log/macos-ipv6-fixed-suffix"
    echo -e "${GREEN}✓${NC} Log files deleted"
fi

echo ""
echo -e "${GREEN}Uninstallation complete!${NC}"
