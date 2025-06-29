# macOS IPv6 Fixed Suffix

A monitoring script for macOS that automatically maintains IPv6 addresses with fixed suffixes when IPv6 prefixes change.

## 🚀 Quick Installation

### Method 1: Direct Installation (Recommended)
```bash
curl -fsSL https://raw.githubusercontent.com/sxzz/macos-ipv6-fixed-suffix/refs/heads/main/install.sh | sudo bash
```

### Method 2: Download and Install
```bash
curl -fsSL https://raw.githubusercontent.com/sxzz/macos-ipv6-fixed-suffix/refs/heads/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

## ✨ Features

- ✅ **Auto-start on boot** - Uses macOS LaunchDaemon system service
- ✅ **Background operation** - Runs automatically without manual intervention
- ✅ **Auto-restart** - Automatically restarts if the service crashes
- ✅ **Complete logging** - Detailed operation logs
- ✅ **Easy management** - Command-line management tools

## 📋 Management Commands

After installation, use these commands to manage the service:

```bash
# Check service status
ipv6-monitor status

# Start service
ipv6-monitor start

# Stop service
ipv6-monitor stop

# Restart service
ipv6-monitor restart

# View real-time logs
ipv6-monitor log
```

## 💻 Manual Usage

For testing or manual operation, you can run the script directly:

```bash
sudo ./run.sh
```

## 🗑️ Uninstallation

### Simple Uninstall (Recommended)
```bash
sudo launchctl unload /Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist
sudo rm -f /Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist
sudo rm -f /usr/local/bin/ipv6-monitor
```

### Complete Uninstall (Including All Files)
```bash
# Stop and remove service
sudo launchctl unload /Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist
sudo rm -f /Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist

# Remove program files
sudo rm -rf /usr/local/bin/macos-ipv6-fixed-suffix
sudo rm -f /usr/local/bin/ipv6-monitor

# Remove log files
sudo rm -rf /var/log/macos-ipv6-fixed-suffix
```

## 📂 Installation Locations

- **Program files**: `/usr/local/bin/macos-ipv6-fixed-suffix/`
- **Service configuration**: `/Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist`
- **Log files**: `/var/log/macos-ipv6-fixed-suffix/ipv6_monitor.log`
- **Command tool**: `/usr/local/bin/ipv6-monitor`

## 🔧 How It Works

1. Monitors system IPv6 prefix changes
2. Auto-detects the primary network interface
3. Uses the last octet of IPv4 address as IPv6 suffix
4. Automatically adds new fixed-suffix addresses when prefix changes
5. Cleans up expired addresses

## 🙏 Acknowledgments

Thanks to GitHub Copilot for assistance in writing this script.

## Sponsors

<p align="center">
  <a href="https://cdn.jsdelivr.net/gh/sxzz/sponsors/sponsors.svg">
    <img src='https://cdn.jsdelivr.net/gh/sxzz/sponsors/sponsors.svg'/>
  </a>
</p>

## License

[MIT](./LICENSE) License © 2025 [Kevin Deng](https://github.com/sxzz)
