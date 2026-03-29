# AGENTS.md

This file provides guidelines for agentic coding assistants working on this VPN rotation system.

## Build/Lint/Test Commands

This is a bash-based automation project with no formal build system. Manual testing is performed by running scripts directly.

```bash
# One-time setup (configures passwordless sudo)
./setup-sudo.sh

# Start the VPN rotation and healthcheck services
./vpn-control.sh start

# Common control operations
./vpn-control.sh stop          # Stop and disconnect
./vpn-control.sh restart       # Restart services
./vpn-control.sh status        # Show status with diagnostics
./vpn-control.sh rotate-now    # Force immediate rotation
./vpn-control.sh pause         # Pause rotation (keep VPN connected)
./vpn-control.sh resume        # Resume rotation
./vpn-control.sh logs          # Watch rotation logs
./vpn-control.sh hc-logs       # Watch healthcheck logs

# Kill-switch operations
./vpn-control.sh ks-on         # Enable kill-switch
./vpn-control.sh ks-off        # Disable kill-switch
./vpn-control.sh ks-status     # Check status
./vpn-control.sh ks-test       # Test functionality

# Direct script testing (advanced)
./vpn-rotator.sh               # Run single rotation
./vpn-healthcheck.sh           # Run healthcheck once
./killswitch.sh status         # Check kill-switch status
```

## Code Style Guidelines

### General Structure
- All scripts MUST start with `#!/bin/bash`
- Include a descriptive header comment explaining the script's purpose
- Define BASE_DIR at the top: `BASE_DIR="/home/toolik/_TOOLS/_VPN_rotator"` (note: update hardcoded paths!)
- Use 4-space indentation consistently
- End files with a blank line

### Variables and Constants
- UPPERCANCE for configuration paths and constants: `LOG_FILE="$BASE_DIR/vpn-rotation.log"`
- lowercase_with_underscores for local variables: `local server_name=$(basename "$config_file" .ovpn)`
- Always quote variables in double quotes to prevent word splitting and globbing
- Use `local` for function-local variables to avoid polluting global scope

### Function Definitions
- Snake_case naming: `connect_vpn()`, `verify_connection()`, `get_country_name()`
- Functions should be short and single-purpose
- Use descriptive function names that clearly state what they do
- Document purpose with a brief comment above the function

### Logging and Output
- Use the log() function pattern for consistency:
  ```bash
  log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
  }
  ```
- Always include timestamps in logs
- Use emoji prefixes sparingly for visual clarity in main control script only: `✅` `❌` `⚠️` `🚀`
- Use `/dev/null` to suppress command output when not needed: `2>/dev/null`

### Error Handling
- Check for file existence before use: `if [ ! -f "$AUTH_FILE" ]; then`
- Use explicit error messages and log them
- Use exit codes: `exit 0` for success, `exit 1` for errors
- Implement retry logic for network operations (MAX_RETRIES常数为3)
- Always clean up on exit using trap:
  ```bash
  cleanup() {
      rm -f "$LOCK_FILE"
  }
  trap cleanup EXIT
  ```

### State Management
- Use .txt files for state: `vpn-current-server.txt`, `vpn-rotation-paused.txt`, `killswitch-enabled.txt`
- Use .lock files to prevent concurrent execution (with PID inside)
- Always clean up stale state files when processes exit
- Check for existence of pause/lock files before operations

### System Integration
- Use systemd user timers for scheduling (NOT cron)
- Systemd unit files are generated dynamically in `~/.config/systemd/user/`
- Use `systemctl --user` commands for user-level services
- Rotation timer: every 15 minutes (OnUnitActiveSec=15min)
- Healthcheck timer: every 2 minutes (OnUnitActiveSec=2min)

### Security and Permissions
- auth.txt MUST have 600 permissions
- Sudo access is configured via `/etc/sudoers.d/vpn-rotator`
- Never log credentials or sensitive information
- Always use `sudo -n` for passwordless commands
- Verify OpenVPN process exit properly before assuming connected

### Network and VPN Specifics
- ProtonVPN tunnel IPs are in range `10.96.0.0/16`
- Always verify tunnel interface IP + internet connectivity after connecting
- Use curl with timeouts: `curl -s --max-time $TIMEOUT`
- Kill-switch uses iptables to block all non-VPN traffic
- Common OpenVPN ports: UDP 1194, TCP 1194, UDP 443, TCP 443

### Conventions and Patterns
- Random server selection with fallback for single-server case
- Disconnect before connect (don't chain connections)
- Wait for routes to stabilize (15 seconds after OpenVPN connection)
- Use `pgrep -f openvpn` to check if OpenVPN is running
- Log rotation trimmed to 1000 lines in healthcheck
- Always verify connection was actually successful before marking it as connected

### Important Notes
- BASE_DIR is HARDCODED in every script - if the directory moves, all scripts need updating!
- Currently inconsistent paths: some use `/home/parallels/...`, some `/home/toolik/...` - standardize to `/home/toolik/...`
- No automated testing exists - manual verification required
- Kill-switch requires manual enable/disable (not automatic)
- iOS/Android support exists via transfer-to-android.sh but is separate from Linux automation
