#!/bin/bash

# IPv6 Prefix Monitoring Script - macOS Version
# Function: Monitor IPv6 prefix changes and automatically add IPv6 addresses with fixed suffixes

# ========== Configuration Section ==========
# IPv6 suffix (default: last segment of IPv4 address)
IPV6_SUFFIX=""

# Prefix length (default: 64)
PREFIX_LENGTH=64

# 监控的网络接口（默认为主要接口，留空自动检测）
INTERFACE=""

# 检查间隔（秒）
CHECK_INTERVAL=10

# IPv6地址标签
IPV6_LABEL="ipv6monitor"

# ========== 函数定义 ==========

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

get_primary_interface() {
    route get default 2>/dev/null | grep interface | awk '{print $2}' | head -1
}

# 获取接口IPv4地址的最后一段作为默认后缀
get_default_ipv6_suffix() {
    local interface="$1"
    local ipv4_addr=$(ifconfig "$interface" 2>/dev/null | grep 'inet ' | grep -v '127.0.0.1' | awk '{print $2}' | head -1)
    if [[ -n "$ipv4_addr" ]]; then
        local last_octet=$(echo "$ipv4_addr" | awk -F. '{print $4}')
        echo "::$last_octet"
    else
        echo "::100"
    fi
}

get_ipv6_prefixes() {
    local interface="$1"
    ifconfig "$interface" 2>/dev/null | grep 'inet6' | grep -v 'fe80:' | grep -v '::1' | grep -v 'deprecated' | awk '{print $2}' | cut -d'/' -f1 | while read addr; do
        if [[ "$addr" =~ ^[23][0-9a-f]{3}: ]]; then
            echo "$addr" | awk -F: '{printf "%s:%s:%s:%s\n", $1, $2, $3, $4}'
        fi
    done | sort -u
}

construct_ipv6_address() {
    local prefix="$1"
    local suffix="$2"
    echo "${prefix}${suffix}"
}

ipv6_address_exists() {
    local interface="$1"
    local address="$2"
    ifconfig "$interface" 2>/dev/null | grep -q "inet6 $address"
}

# 获取所有带标签的IPv6地址
get_labeled_ipv6_addresses() {
    local interface="$1"
    # 在macOS中，我们通过查找包含特定模式的IPv6地址来识别我们管理的地址
    ifconfig "$interface" 2>/dev/null | grep "inet6.*$IPV6_SUFFIX" | awk '{print $2}' | cut -d'/' -f1
}

# 删除所有带标签的IPv6地址
remove_labeled_ipv6_addresses() {
    local interface="$1"
    local addresses=$(get_labeled_ipv6_addresses "$interface")
    
    if [[ -n "$addresses" ]]; then
        echo "$addresses" | while IFS= read -r address; do
            if [[ -n "$address" ]]; then
                log "删除旧的IPv6地址: $address"
                sudo ifconfig "$interface" inet6 "$address" delete 2>/dev/null || true
            fi
        done
    fi
}

# 添加IPv6地址
add_ipv6_address() {
    local interface="$1"
    local address="$2"
    
    if ipv6_address_exists "$interface" "$address"; then
        log "IPv6地址 $address 已存在于接口 $interface"
        return 0
    fi
    
    log "在接口 $interface 上添加IPv6地址: $address/$PREFIX_LENGTH"
    if sudo ifconfig "$interface" inet6 "$address" prefixlen "$PREFIX_LENGTH" alias; then
        log "成功添加IPv6地址: $address"
        return 0
    else
        log "错误: 添加IPv6地址失败: $address"
        return 1
    fi
}

handle_prefix_change() {
    local interface="$1"
    local new_prefixes="$2"
    local is_initial="$3"
    
    if [[ "$is_initial" == "true" ]]; then
        log "首次运行，检测到当前前缀: $new_prefixes"
    else
        log "检测到前缀变动，当前前缀: $new_prefixes"
        # 删除所有旧的带标签的IPv6地址
        remove_labeled_ipv6_addresses "$interface"
    fi
    
    local prefixes_array=()
    while IFS= read -r prefix; do
        if [[ -n "$prefix" ]]; then
            prefixes_array+=("$prefix")
        fi
    done <<< "$new_prefixes"
    
    for prefix in "${prefixes_array[@]}"; do
        local new_address=$(construct_ipv6_address "$prefix" "$IPV6_SUFFIX")
        add_ipv6_address "$interface" "$new_address"
    done
}

monitor_ipv6_changes() {
    local interface="$1"
    local last_prefixes=""
    local is_first_run=true
    
    log "开始监控接口 $interface 的IPv6前缀变动..."
    log "配置 - 后缀: $IPV6_SUFFIX, 前缀长度: $PREFIX_LENGTH, 检查间隔: ${CHECK_INTERVAL}s"
    
    while true; do
        local current_prefixes=$(get_ipv6_prefixes "$interface")
        
        if [[ "$current_prefixes" != "$last_prefixes" ]]; then
            if [[ -n "$current_prefixes" ]]; then
                handle_prefix_change "$interface" "$current_prefixes" "$is_first_run"
            else
                log "当前无有效的IPv6前缀"
                if [[ "$is_first_run" == "false" ]]; then
                    # 如果没有前缀了，清除所有旧地址
                    remove_labeled_ipv6_addresses "$interface"
                fi
            fi
            last_prefixes="$current_prefixes"
            is_first_run=false
        fi
        
        sleep "$CHECK_INTERVAL"
    done
}

# 显示帮助信息
show_help() {
    cat << EOF
IPv6前缀监控脚本

用法: $0 [选项]

选项:
    -i, --interface INTERFACE    指定监控的网络接口
    -s, --suffix SUFFIX          设置IPv6后缀 (默认: $IPV6_SUFFIX)
    -p, --prefix-length LENGTH   设置前缀长度 (默认: $PREFIX_LENGTH)
    -t, --interval SECONDS       设置检查间隔 (默认: $CHECK_INTERVAL)
    -h, --help                   显示此帮助信息

示例:
    $0                           使用默认设置
    $0 -i en0 -s ::200          监控en0接口，使用::200作为后缀
    $0 -p 56 -t 5               使用56位前缀，5秒检查间隔

注意:
    - 脚本需要sudo权限来修改网络接口配置
    - 按Ctrl+C停止监控
EOF
}

# ========== 主程序 ==========

# 解析命令行参数
while [[ $# -gt 0 ]]; do
    case $1 in
        -i|--interface)
            INTERFACE="$2"
            shift 2
            ;;
        -s|--suffix)
            IPV6_SUFFIX="$2"
            shift 2
            ;;
        -p|--prefix-length)
            PREFIX_LENGTH="$2"
            shift 2
            ;;
        -t|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            echo "未知选项: $1"
            show_help
            exit 1
            ;;
    esac
done

# 检查是否以root权限运行
if [[ $EUID -ne 0 ]]; then
    echo "错误: 此脚本需要root权限运行"
    echo "请使用: sudo $0"
    exit 1
fi

# 自动检测接口
if [[ -z "$INTERFACE" ]]; then
    INTERFACE=$(get_primary_interface)
    if [[ -z "$INTERFACE" ]]; then
        echo "错误: 无法自动检测主要网络接口"
        echo "请使用 -i 选项手动指定接口"
        exit 1
    fi
fi

# 验证接口是否存在
if ! ifconfig "$INTERFACE" >/dev/null 2>&1; then
    echo "错误: 网络接口 '$INTERFACE' 不存在"
    exit 1
fi

# 设置默认IPv6后缀（如果未指定）
if [[ -z "$IPV6_SUFFIX" ]]; then
    IPV6_SUFFIX=$(get_default_ipv6_suffix "$INTERFACE")
fi

# 设置信号处理
cleanup_on_exit() {
    log "收到停止信号，清理IPv6地址并退出..."
    remove_labeled_ipv6_addresses "$INTERFACE"
    exit 0
}
trap 'cleanup_on_exit' INT TERM

# 启动监控
log "========== IPv6前缀监控脚本启动 =========="
log "监控接口: $INTERFACE"
log "IPv6后缀: $IPV6_SUFFIX"
log "前缀长度: $PREFIX_LENGTH"
log "检查间隔: ${CHECK_INTERVAL}秒"

monitor_ipv6_changes "$INTERFACE"
