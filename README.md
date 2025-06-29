# macOS IPv6 Fixed Suffix

A monitoring script for macOS that automatically maintains IPv6 addresses with fixed suffixes when IPv6 prefixes change.

## 🚀 安装

### 方法 1：在线安装（推荐）
```bash
curl -fsSL https://raw.githubusercontent.com/sxzz/macos-ipv6-fixed-suffix/refs/heads/main/install.sh | sudo bash
```

### 方法 2：下载后安装
```bash
curl -fsSL https://raw.githubusercontent.com/sxzz/macos-ipv6-fixed-suffix/refs/heads/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

## ✨ 功能特性

- ✅ **开机自启** - 使用 macOS LaunchDaemon 系统服务
- ✅ **后台运行** - 自动运行无需手动干预
- ✅ **自动重启** - 服务崩溃时自动重启
- ✅ **完整日志** - 详细的操作日志记录
- ✅ **简易管理** - 命令行管理工具

## 📋 使用

安装后使用以下命令管理服务：

```bash
# 查看服务状态
ipv6-monitor status

# 启动服务
ipv6-monitor start

# 停止服务
ipv6-monitor stop

# 重启服务
ipv6-monitor restart

# 查看实时日志
ipv6-monitor log
```

手动运行脚本进行测试：

```bash
sudo ./run.sh
```

## 🗑️ 卸载

运行卸载脚本：

```bash
sudo ./uninstall.sh
```

或手动卸载：

```bash
sudo launchctl unload /Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist
sudo rm -f /Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist
sudo rm -f /usr/local/bin/ipv6-monitor
sudo rm -rf /usr/local/bin/macos-ipv6-fixed-suffix
sudo rm -rf /var/log/macos-ipv6-fixed-suffix
```

## � 工作原理

1. 监控系统 IPv6 前缀变化
2. 自动检测主要网络接口
3. 使用 IPv4 地址最后一段作为 IPv6 后缀
4. 前缀变化时自动添加新的固定后缀地址
5. 清理过期地址

## �🙏 致谢

感谢 GitHub Copilot 协助编写此脚本。

## Sponsors

<p align="center">
  <a href="https://cdn.jsdelivr.net/gh/sxzz/sponsors/sponsors.svg">
    <img src='https://cdn.jsdelivr.net/gh/sxzz/sponsors/sponsors.svg'/>
  </a>
</p>

## License

[MIT](./LICENSE) License © 2025 [Kevin Deng](https://github.com/sxzz)
