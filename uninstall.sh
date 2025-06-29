#!/bin/bash

# macOS IPv6 Fixed Suffix 简易卸载脚本

SERVICE_NAME="com.github.sxzz.macos-ipv6-fixed-suffix"
PLIST_FILE="/Library/LaunchDaemons/$SERVICE_NAME.plist"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}macOS IPv6 Fixed Suffix 卸载程序${NC}"
echo "========================================"
echo ""

# 检查权限
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}错误: 需要管理员权限${NC}"
    echo "请使用: sudo ./uninstall.sh"
    exit 1
fi

echo -e "${YELLOW}正在卸载服务...${NC}"

# 停止并卸载服务
if launchctl list | grep -q "$SERVICE_NAME"; then
    launchctl unload "$PLIST_FILE" 2>/dev/null
    echo -e "${GREEN}✓${NC} 服务已停止"
else
    echo -e "${YELLOW}⚠${NC} 服务未在运行"
fi

# 删除配置文件
if [[ -f "$PLIST_FILE" ]]; then
    rm -f "$PLIST_FILE"
    echo -e "${GREEN}✓${NC} 删除服务配置文件"
fi

# 删除命令行工具
if [[ -L "/usr/local/bin/ipv6-monitor" ]]; then
    rm -f "/usr/local/bin/ipv6-monitor"
    echo -e "${GREEN}✓${NC} 删除命令行工具"
fi

echo ""
echo -e "${GREEN}服务卸载完成！${NC}"
echo ""
echo "如需完全清理，可手动删除以下目录（可选）："
echo "  sudo rm -rf /usr/local/bin/macos-ipv6-fixed-suffix"
echo "  sudo rm -rf /var/log/macos-ipv6-fixed-suffix"
