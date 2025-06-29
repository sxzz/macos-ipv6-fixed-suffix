#!/bin/bash

# macOS IPv6 Fixed Suffix 安装脚本
# 功能：安装程序、设置开机自启并在后台运行

set -e

# 配置变量
SERVICE_NAME="com.github.sxzz.macos-ipv6-fixed-suffix"
INSTALL_DIR="/usr/local/bin/macos-ipv6-fixed-suffix"
PLIST_DIR="/Library/LaunchDaemons"
PLIST_FILE="$PLIST_DIR/$SERVICE_NAME.plist"
LOG_DIR="/var/log/macos-ipv6-fixed-suffix"
LOG_FILE="$LOG_DIR/ipv6_monitor.log"

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日志函数
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

# 检查是否以root权限运行
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "此安装脚本需要管理员权限运行"
        echo "请使用: sudo ./install.sh"
        exit 1
    fi
}

# 检查系统
check_system() {
    if [[ "$(uname)" != "Darwin" ]]; then
        error "此脚本仅支持 macOS 系统"
        exit 1
    fi
    success "系统检查通过 (macOS)"
}

# 创建必要的目录
create_directories() {
    log "创建必要的目录..."
    
    # 创建安装目录
    if [[ ! -d "$INSTALL_DIR" ]]; then
        mkdir -p "$INSTALL_DIR"
        success "创建安装目录: $INSTALL_DIR"
    fi
    
    # 创建日志目录
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR"
        chmod 755 "$LOG_DIR"
        success "创建日志目录: $LOG_DIR"
    fi
}

# 下载程序文件
download_files() {
    log "下载程序文件..."
    
    # 下载主脚本
    local run_script_url="https://raw.githubusercontent.com/sxzz/macos-ipv6-fixed-suffix/refs/heads/main/run.sh"
    
    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL "$run_script_url" -o "$INSTALL_DIR/run.sh"; then
            chmod +x "$INSTALL_DIR/run.sh"
            success "下载主脚本到: $INSTALL_DIR/run.sh"
        else
            error "下载脚本失败"
            exit 1
        fi
    elif command -v wget >/dev/null 2>&1; then
        if wget -q "$run_script_url" -O "$INSTALL_DIR/run.sh"; then
            chmod +x "$INSTALL_DIR/run.sh"
            success "下载主脚本到: $INSTALL_DIR/run.sh"
        else
            error "下载脚本失败"
            exit 1
        fi
    else
        error "需要 curl 或 wget 来下载文件"
        exit 1
    fi
}

# 创建 LaunchDaemon plist 文件
create_launchd_plist() {
    log "创建 LaunchDaemon 配置文件..."
    
    cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$SERVICE_NAME</string>
    
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/run.sh</string>
        <string>--daemon</string>
        <string>--log-file</string>
        <string>$LOG_FILE</string>
    </array>
    
    <key>RunAtLoad</key>
    <true/>
    
    <key>KeepAlive</key>
    <dict>
        <key>SuccessfulExit</key>
        <false/>
        <key>Crashed</key>
        <true/>
    </dict>
    
    <key>StandardOutPath</key>
    <string>$LOG_FILE</string>
    
    <key>StandardErrorPath</key>
    <string>$LOG_FILE</string>
    
    <key>UserName</key>
    <string>root</string>
    
    <key>GroupName</key>
    <string>wheel</string>
    
    <key>ThrottleInterval</key>
    <integer>10</integer>
    
    <key>ProcessType</key>
    <string>Background</string>
    
    <key>LimitLoadToSessionType</key>
    <string>System</string>
</dict>
</plist>
EOF
    
    # 设置正确的权限
    chown root:wheel "$PLIST_FILE"
    chmod 644 "$PLIST_FILE"
    
    success "创建 LaunchDaemon 配置: $PLIST_FILE"
}

# 卸载旧版本（如果存在）
uninstall_old_version() {
    log "检查并卸载旧版本..."
    
    # 停止服务
    if launchctl list | grep -q "$SERVICE_NAME"; then
        launchctl unload "$PLIST_FILE" 2>/dev/null || true
        warning "停止旧版本服务"
    fi
    
    # 删除旧的 plist 文件
    if [[ -f "$PLIST_FILE" ]]; then
        rm -f "$PLIST_FILE"
        warning "删除旧版本配置文件"
    fi
}

# 加载并启动服务
start_service() {
    log "启动 IPv6 监控服务..."
    
    # 加载服务
    if launchctl load "$PLIST_FILE"; then
        success "服务已加载并启动"
    else
        error "服务启动失败"
        exit 1
    fi
    
    # 等待片刻让服务启动
    sleep 2
    
    # 检查服务状态
    if launchctl list | grep -q "$SERVICE_NAME"; then
        success "服务运行正常"
        log "服务标识: $SERVICE_NAME"
        log "日志文件: $LOG_FILE"
    else
        error "服务未能正常启动"
        exit 1
    fi
}

# 创建管理脚本
create_management_scripts() {
    log "创建管理脚本..."
    
    # 创建控制脚本
    cat > "$INSTALL_DIR/control.sh" << 'EOF'
#!/bin/bash

SERVICE_NAME="com.github.sxzz.macos-ipv6-fixed-suffix"
PLIST_FILE="/Library/LaunchDaemons/$SERVICE_NAME.plist"
LOG_FILE="/var/log/macos-ipv6-fixed-suffix/ipv6_monitor.log"

case "$1" in
    start)
        echo "启动 IPv6 监控服务..."
        sudo launchctl load "$PLIST_FILE"
        ;;
    stop)
        echo "停止 IPv6 监控服务..."
        sudo launchctl unload "$PLIST_FILE"
        ;;
    restart)
        echo "重启 IPv6 监控服务..."
        sudo launchctl unload "$PLIST_FILE" 2>/dev/null || true
        sleep 1
        sudo launchctl load "$PLIST_FILE"
        ;;
    status)
        if launchctl list | grep -q "$SERVICE_NAME"; then
            echo "✓ IPv6 监控服务正在运行"
            echo "PID: $(launchctl list | grep "$SERVICE_NAME" | awk '{print $1}')"
        else
            echo "✗ IPv6 监控服务未运行"
        fi
        ;;
    log)
        if [[ -f "$LOG_FILE" ]]; then
            tail -f "$LOG_FILE"
        else
            echo "日志文件不存在: $LOG_FILE"
        fi
        ;;
    *)
        echo "用法: $0 {start|stop|restart|status|log}"
        echo ""
        echo "命令说明:"
        echo "  start   - 启动服务"
        echo "  stop    - 停止服务"
        echo "  restart - 重启服务"
        echo "  status  - 查看服务状态"
        echo "  log     - 查看实时日志"
        exit 1
        ;;
esac
EOF
    
    chmod +x "$INSTALL_DIR/control.sh"
    success "创建管理脚本: $INSTALL_DIR/control.sh"
    
    # 在 /usr/local/bin 创建符号链接
    if [[ ! -L "/usr/local/bin/ipv6-monitor" ]]; then
        ln -s "$INSTALL_DIR/control.sh" "/usr/local/bin/ipv6-monitor"
        success "创建命令行工具: ipv6-monitor"
    fi
}

# 显示安装完成信息
show_completion_info() {
    echo ""
    echo "=================================="
    success "安装完成！"
    echo "=================================="
    echo ""
    echo "服务信息："
    echo "  服务名称: $SERVICE_NAME"
    echo "  安装目录: $INSTALL_DIR"
    echo "  日志文件: $LOG_FILE"
    echo ""
    echo "管理命令："
    echo "  查看状态: ipv6-monitor status"
    echo "  启动服务: ipv6-monitor start"
    echo "  停止服务: ipv6-monitor stop"
    echo "  重启服务: ipv6-monitor restart"
    echo "  查看日志: ipv6-monitor log"
    echo ""
    echo "服务已设置为开机自启，将在后台自动监控 IPv6 地址变化。"
    echo "后台模式运行，无需手动确认，自动添加 IPv6 地址。"
    echo ""
    warning "如需卸载服务，请运行: sudo launchctl unload $PLIST_FILE && sudo rm -f $PLIST_FILE"
}

# 创建卸载说明
create_uninstall_info() {
    log "创建卸载说明..."
    
    cat > "$INSTALL_DIR/UNINSTALL.md" << 'EOF'
# 卸载说明

如需卸载 macOS IPv6 Fixed Suffix 服务，请执行以下命令：

## 停止并卸载服务
```bash
sudo launchctl unload /Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist
sudo rm -f /Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist
```

## 删除命令行工具（可选）
```bash
sudo rm -f /usr/local/bin/ipv6-monitor
```

## 完全删除安装文件和日志（可选）
```bash
sudo rm -rf /usr/local/bin/macos-ipv6-fixed-suffix
sudo rm -rf /var/log/macos-ipv6-fixed-suffix
```
EOF
    
    success "创建卸载说明: $INSTALL_DIR/UNINSTALL.md"
}

# 主安装流程
main() {
    echo "macOS IPv6 Fixed Suffix 安装程序"
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
    create_uninstall_info
    
    show_completion_info
}

# 执行安装
main "$@"
