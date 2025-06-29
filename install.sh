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
    
    # 设置正确的权限
    chown root:wheel "$PLIST_FILE"
    chmod 644 "$PLIST_FILE"
    
    success "创建 LaunchDaemon 配置: $PLIST_FILE"
}

# 卸载旧版本（如果存在）
uninstall_old_version() {
    log "检查并卸载旧版本..."
    
    # 临时关闭 set -e
    set +e
    
    # 检查服务是否在运行
    if launchctl print "system/$SERVICE_NAME" >/dev/null 2>&1; then
        warning "发现运行中的服务，正在停止..."
        
        # 尝试 bootout 命令（较新的 macOS）
        if launchctl bootout system "$PLIST_FILE" 2>/dev/null; then
            warning "使用 bootout 停止服务"
        else
            # 尝试传统的 unload 命令
            launchctl unload "$PLIST_FILE" 2>/dev/null
            warning "使用 unload 停止服务"
        fi
        
        # 等待服务完全停止
        sleep 2
        
        # 再次检查是否还有残留进程
        if launchctl print "system/$SERVICE_NAME" >/dev/null 2>&1; then
            warning "服务可能仍在运行，尝试强制停止..."
            # 尝试通过进程名终止
            pkill -f "run.sh.*daemon" 2>/dev/null
        fi
    fi
    
    # 删除旧的 plist 文件
    if [[ -f "$PLIST_FILE" ]]; then
        rm -f "$PLIST_FILE"
        warning "删除旧版本配置文件"
    fi
    
    # 重新启用 set -e
    set -e
}

# 加载并启动服务
start_service() {
    log "启动 IPv6 监控服务..."
    
    # 使用 bootstrap 命令加载服务（适用于较新的 macOS 版本）
    if launchctl bootstrap system "$PLIST_FILE" 2>/dev/null; then
        success "服务已加载并启动 (bootstrap)"
    else
        # 如果 bootstrap 失败，尝试传统的 load 命令
        log "尝试使用传统 load 命令..."
        if launchctl load "$PLIST_FILE" 2>/dev/null; then
            success "服务已加载并启动 (load)"
        else
            error "服务启动失败"
            warning "请检查配置文件: $PLIST_FILE"
            warning "手动尝试: sudo launchctl bootstrap system '$PLIST_FILE'"
            exit 1
        fi
    fi
    
    # 等待服务启动
    sleep 3
    
    # 使用 launchctl print 检查服务状态
    if SERVICE_INFO=$(launchctl print "system/$SERVICE_NAME" 2>/dev/null); then
        success "服务运行正常"
        log "服务标识: $SERVICE_NAME"
        log "日志文件: $LOG_FILE"
        
        # 提取并显示服务详细状态
        PID=$(echo "$SERVICE_INFO" | grep "pid =" | awk '{print $3}')
        STATE=$(echo "$SERVICE_INFO" | grep "state =" | awk '{print $3}')
        
        if [[ -n "$PID" ]]; then
            log "进程 PID: $PID"
        fi
        if [[ -n "$STATE" ]]; then
            log "服务状态: $STATE"
        fi
    else
        error "服务未能正常启动"
        warning "请检查日志文件: $LOG_FILE"
        warning "手动检查服务状态: launchctl print 'system/$SERVICE_NAME'"
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
        if sudo launchctl bootstrap system "$PLIST_FILE" 2>/dev/null; then
            echo "✓ 服务启动成功 (bootstrap)"
        elif sudo launchctl load "$PLIST_FILE" 2>/dev/null; then
            echo "✓ 服务启动成功 (load)"
        else
            echo "✗ 服务启动失败"
            echo "请检查配置文件: $PLIST_FILE"
        fi
        ;;
    stop)
        echo "停止 IPv6 监控服务..."
        if sudo launchctl bootout system "$PLIST_FILE" 2>/dev/null; then
            echo "✓ 服务停止成功 (bootout)"
        elif sudo launchctl unload "$PLIST_FILE" 2>/dev/null; then
            echo "✓ 服务停止成功 (unload)"
        else
            echo "✗ 服务停止失败"
        fi
        ;;
    restart)
        echo "重启 IPv6 监控服务..."
        # 停止服务
        sudo launchctl bootout system "$PLIST_FILE" 2>/dev/null || sudo launchctl unload "$PLIST_FILE" 2>/dev/null || true
        sleep 1
        # 启动服务
        if sudo launchctl bootstrap system "$PLIST_FILE" 2>/dev/null; then
            echo "✓ 服务重启成功 (bootstrap)"
        elif sudo launchctl load "$PLIST_FILE" 2>/dev/null; then
            echo "✓ 服务重启成功 (load)"
        else
            echo "✗ 服务重启失败"
        fi
        ;;
    status)
        # 使用 launchctl print 命令检查服务状态（更可靠）
        if SERVICE_INFO=$(launchctl print "system/$SERVICE_NAME" 2>/dev/null); then
            echo "✓ IPv6 监控服务正在运行"
            
            # 提取 PID 和状态
            PID=$(echo "$SERVICE_INFO" | grep "pid =" | awk '{print $3}')
            STATE=$(echo "$SERVICE_INFO" | grep "state =" | awk '{print $3}')
            
            if [[ -n "$PID" ]]; then
                echo "PID: $PID"
            fi
            if [[ -n "$STATE" ]]; then
                echo "状态: $STATE"
            fi
            
            # 显示更多详细信息
            echo "服务详情:"
            echo "  配置文件: $PLIST_FILE"
            echo "  日志文件: $LOG_FILE"
            
        else
            echo "✗ IPv6 监控服务未运行"
            # 检查配置文件是否存在
            if [[ -f "$PLIST_FILE" ]]; then
                echo "配置文件存在，尝试启动服务:"
                echo "  sudo launchctl bootstrap system \"$PLIST_FILE\""
            else
                echo "配置文件不存在: $PLIST_FILE"
            fi
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
    echo ""
    warning "如需卸载服务，请运行: sudo launchctl unload $PLIST_FILE && sudo rm -f $PLIST_FILE"
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
    
    show_completion_info
}

# 执行安装
main "$@"
