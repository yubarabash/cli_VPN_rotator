# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Bash-based automatic VPN rotation system for ProtonVPN on Linux. Uses systemd user timers for scheduling, iptables for kill-switch, and OpenVPN for connections.

## Common Commands

```bash
# One-time setup (configures passwordless sudo for openvpn/iptables)
./setup-sudo.sh

# Start rotation + healthcheck services
./vpn-control.sh start

# Control
./vpn-control.sh stop
./vpn-control.sh restart
./vpn-control.sh status
./vpn-control.sh rotate-now
./vpn-control.sh pause / resume

# Kill-switch
./vpn-control.sh ks-on
./vpn-control.sh ks-off
./vpn-control.sh ks-status
./vpn-control.sh ks-test

# Logs
./vpn-control.sh logs          # rotation log
./vpn-control.sh hc-logs       # healthcheck log
```

## Architecture

- **`vpn-control.sh`** - Main CLI interface. Manages systemd user timer units (`~/.config/systemd/user/`). Generates and installs the `.service` and `.timer` unit files on `start`.
- **`vpn-rotator.sh`** - Core rotation logic. Randomly selects a `.ovpn` config from `_servers/` (avoiding the current server), disconnects the existing OpenVPN session, connects to the new server with up to 3 retries, and verifies connectivity via tunnel IP (10.96.0.0/16 range) + HTTP reachability. Uses a lock file to prevent concurrent runs.
- **`vpn-healthcheck.sh`** - Runs every 2 minutes via systemd timer. Checks OpenVPN process, tunnel interface IP, and internet connectivity. On failure, triggers `vpn-rotator.sh` for recovery. Trims its log at 1000 lines.
- **`killswitch.sh`** - Creates a custom `VPN_KILLSWITCH` iptables chain that allows loopback, established connections, DNS, OpenVPN ports, tun+ interfaces, and local subnets, then drops everything else. Inserted into INPUT/OUTPUT chains when enabled.
- **`setup-sudo.sh`** - Writes `/etc/sudoers.d/vpn-rotator` granting NOPASSWD for `openvpn`, `iptables`, and `killall openvpn`.

## Key State Files

| File | Purpose |
|------|---------|
| `vpn-current-server.txt` | Name of the currently connected server (basename without `.ovpn`) |
| `vpn-rotation-paused.txt` | Presence pauses rotation (VPN stays connected) |
| `vpn-rotation.lock` | Lock file with PID to prevent concurrent rotations |
| `killswitch-enabled.txt` | Presence indicates kill-switch is active |
| `iptables-backup.rules` | iptables state saved before kill-switch activation |

## Important Notes

- **Hardcoded paths**: All scripts have `BASE_DIR` hardcoded to `/home/parallels/_TOOLS/_VPN_rotator`. If the directory moves or runs under a different user, all scripts need this updated.
- **VPN tunnel detection**: Connection verification checks for IPs in `10.96.0.0/16` (ProtonVPN-specific range). Non-ProtonVPN configs will fail verification.
- **Rotation timer**: 15 minutes (`OnUnitActiveSec=15min` in the generated timer unit). Change by editing the timer unit or modifying `setup_systemd_units()` in `vpn-control.sh` and restarting.
- **Adding servers**: Drop `.ovpn` files into `_servers/`. They are picked up automatically on the next rotation (no restart needed).
- **`auth.txt`**: Must contain ProtonVPN username on line 1, password on line 2. Must have 600 permissions.
