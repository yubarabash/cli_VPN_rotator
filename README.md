# VPN Rotator with Kill-Switch

Automatic VPN rotation system with kill-switch protection for ProtonVPN.

## 📁 Directory Structure

```
VPN_rotator/
├── _servers/              # VPN server configurations (11 servers)
├── auth.txt              # ProtonVPN credentials
├── vpn-rotator.sh        # Main rotation script
├── vpn-control.sh        # Control interface
├── killswitch.sh         # Kill-switch protection
├── setup-sudo.sh         # One-time sudo setup
└── README.md             # This file
```

## 🚀 Quick Start

### 1. Setup (One-time)

```bash
# Run sudo setup (enter your password once)
~/lv/Resources/VPN_rotator/setup-sudo.sh
```

### 2. Start VPN Rotation

```bash
# Start automatic rotation (every 15 minutes)
~/lv/Resources/VPN_rotator/vpn-control.sh start

# Enable kill-switch protection
~/lv/Resources/VPN_rotator/vpn-control.sh ks-on
```

---

## 🎮 VPN Commands

| Command | Shortcut | Description |
|---------|----------|-------------|
| `start` | - | Start automatic rotation |
| `stop` | - | Stop and disconnect |
| `restart` | - | Restart the service |
| `status` | - | Show current status |
| `rotate-now` | - | Force immediate rotation |
| `logs` | - | Watch live logs |

---

## 🛡️ Kill-Switch Commands

| Command | Shortcut | Description |
|---------|----------|-------------|
| `killswitch-on` | `ks-on` | Enable kill-switch |
| `killswitch-off` | `ks-off` | Disable kill-switch |
| `killswitch-status` | `ks-status` | Check status |
| `killswitch-test` | `ks-test` | Test functionality |

### What is Kill-Switch?

Kill-switch blocks **ALL internet traffic** if VPN disconnects, preventing IP leaks.

**How it works:**
- ✅ VPN connected → Traffic flows through VPN
- ❌ VPN disconnected → All traffic blocked (no leaks!)

---

## 📊 Status Check

```bash
# Check VPN status
~/lv/Resources/VPN_rotator/vpn-control.sh status

# Check kill-switch status
~/lv/Resources/VPN_rotator/vpn-control.sh ks-status

# Check your current IP
curl https://api.ipify.org
```

---

## 🌍 Servers

Place .ovnp files with your credentials in the *_servers* folder. The app will randomly rotate them.

---

## ⚙️ Configuration

### Change Rotation Interval

Edit: `~/Library/LaunchAgents/com.vpn.rotator.plist`

Change `<integer>900</integer>` (seconds):
- 300 = 5 minutes
- 600 = 10 minutes
- 900 = 15 minutes (default)
- 1800 = 30 minutes

Then restart: `vpn-control.sh restart`

### Add More Servers

1. Drop `.ovpn` files into `_servers/` folder
2. Restart rotation service

---

## 🔒 Security Features

- ✅ Automatic VPN rotation (prevents tracking)
- ✅ Kill-switch protection (prevents IP leaks)
- ✅ Secure credential storage (600 permissions)
- ✅ Logging for audit trail
- ✅ macOS firewall integration (pf)

---

## 📝 Log Files

- `vpn-rotation.log` - Main rotation log
- `vpn-rotation-error.log` - Error log
- `killswitch.log` - Kill-switch log
- `vpn-current-server.txt` - Current server

---

## 🆘 Troubleshooting

### VPN won't connect

```bash
# Check logs
tail -50 ~/lv/Resources/VPN_rotator/vpn-rotation.log

# Test single connection
sudo /usr/local/bin/openvpn --config ~/lv/Resources/VPN_rotator/_servers/us.protonvpn.udp.ovpn --auth-user-pass ~/lv/Resources/VPN_rotator/auth.txt
```

### Kill-switch not working

```bash
# Re-run sudo setup
~/lv/Resources/VPN_rotator/setup-sudo.sh

# Test kill-switch
~/lv/Resources/VPN_rotator/vpn-control.sh ks-test
```

### Can't access internet

```bash
# Disable kill-switch
~/lv/Resources/VPN_rotator/vpn-control.sh ks-off

# Check VPN status
~/lv/Resources/VPN_rotator/vpn-control.sh status
```

---

## 💡 Pro Tips

1. **Always enable kill-switch** for maximum protection
2. **Check logs regularly** to ensure smooth operation
3. **Test after setup** with `ks-test` command
4. **Rotate immediately** when needed with `rotate-now`
5. **Monitor your IP** with `curl https://api.ipify.org`

---

## ⚠️ Important Notes

- Kill-switch uses macOS `pf` firewall
- Sudo access required (configured via setup script)
- Credentials stored securely with 600 permissions
- Rotation interval: 15 minutes (configurable)
- All traffic blocked if VPN drops (when kill-switch enabled)

---

## 📞 Quick Reference

```bash
# Full path to control script
~/lv/Resources/VPN_rotator/vpn-control.sh

# Common workflow
vpn-control.sh start      # Start rotation
vpn-control.sh ks-on      # Enable protection
vpn-control.sh status     # Check everything
vpn-control.sh logs       # Monitor activity

# Emergency
vpn-control.sh stop       # Stop everything
vpn-control.sh ks-off     # Remove protection
```

---

Generated: December 2025
