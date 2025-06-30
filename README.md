# macOS IPv6 Fixed Suffix

A monitoring script for macOS that automatically maintains IPv6 addresses with fixed suffixes when IPv6 prefixes change.

## 🚀 Installation

### Method 1: Online Installation (Recommended)

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

- ✅ **Auto Start on Boot** - Uses macOS LaunchDaemon system service
- ✅ **Runs in Background** - Automatically runs without manual intervention
- ✅ **Automatic Restart** - Service will restart automatically if it crashes
- ✅ **Full Logging** - Detailed operation logs
- ✅ **Easy Management** - Command-line management tool

## 📋 Usage

After installation, use the following commands to manage the service:

```bash
# Check service status
ipv6-monitor status

# Start the service
ipv6-monitor start

# Stop the service
ipv6-monitor stop

# Restart the service
ipv6-monitor restart

# View real-time logs
ipv6-monitor log
```

To manually run the script for testing:

```bash
sudo ./run.sh
```

## 🗑️ Uninstallation

Run the uninstall script:

```bash
sudo ./uninstall.sh
```

Or uninstall manually:

```bash
sudo launchctl unload /Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist
sudo rm -f /Library/LaunchDaemons/com.github.sxzz.macos-ipv6-fixed-suffix.plist
sudo rm -f /usr/local/bin/ipv6-monitor
sudo rm -rf /usr/local/bin/macos-ipv6-fixed-suffix
sudo rm -rf /var/log/macos-ipv6-fixed-suffix
```

## ⚙️ How It Works

1. Monitors system IPv6 prefix changes
2. Automatically detects the primary network interface
3. Uses the last segment of the IPv4 address as the IPv6 suffix
4. Automatically adds new fixed-suffix addresses when the prefix changes
5. Cleans up expired addresses

## 🙏 Acknowledgements

Thanks to GitHub Copilot for assisting in writing this script.

## Sponsors

<p align="center">
  <a href="https://cdn.jsdelivr.net/gh/sxzz/sponsors/sponsors.svg">
    <img src='https://cdn.jsdelivr.net/gh/sxzz/sponsors/sponsors.svg'/>
  </a>
</p>

## License

[MIT](./LICENSE) License © 2025 [Kevin Deng](https://github.com/sxzz)
