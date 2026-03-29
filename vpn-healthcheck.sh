#!/bin/bash

# VPN Healthcheck Script
# Monitors VPN connection health and triggers recovery if needed
# Runs every 2-3 minutes to ensure reliable VPN connectivity
# Linux version

BASE_DIR="/home/parallels/_TOOLS/_VPN_rotator"
LOG_FILE="$BASE_DIR/vpn-healthcheck.log"
ROTATION_SCRIPT="$BASE_DIR/vpn-rotator.sh"
STATE_FILE="$BASE_DIR/vpn-current-server.txt"
PAUSE_FILE="$BASE_DIR/vpn-rotation-paused.txt"
MAX_LOG_LINES=1000

# Function to log with timestamp and diagnostic info
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

# Function to log detailed diagnostics
log_diagnostics() {
    local check_type="$1"
    local result="$2"

    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log "HEALTHCHECK: $check_type - $result"

    # OpenVPN process status
    if pgrep -f openvpn > /dev/null; then
        log "  └─ OpenVPN Process: ✅ Running (PID: $(pgrep -f openvpn | head -1))"
    else
        log "  └─ OpenVPN Process: ❌ Not running"
    fi

    # Tunnel interface status
    local tunnel_ip=$(ip addr show 2>/dev/null | grep -oP 'inet 10\.96\.\K[0-9.]+' | head -1)
    if [ -n "$tunnel_ip" ]; then
        log "  └─ Tunnel Interface: ✅ Active (10.96.$tunnel_ip)"
    else
        log "  └─ Tunnel Interface: ❌ No ProtonVPN IP found"
    fi

    # Routing status
    local default_route=$(ip route | grep "^0.0.0.0/1" | awk '{print $3}')
    if [ -n "$default_route" ]; then
        log "  └─ VPN Routing: ✅ Default route via $default_route"
    else
        log "  └─ VPN Routing: ⚠️  No VPN default route found"
    fi

    # Current server
    if [ -f "$STATE_FILE" ]; then
        log "  └─ Current Server: $(cat "$STATE_FILE")"
    else
        log "  └─ Current Server: ⚠️  State file missing"
    fi

    log "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Trim log file if too large
trim_log() {
    if [ -f "$LOG_FILE" ]; then
        local line_count=$(wc -l < "$LOG_FILE")
        if [ "$line_count" -gt "$MAX_LOG_LINES" ]; then
            tail -n "$MAX_LOG_LINES" "$LOG_FILE" > "$LOG_FILE.tmp"
            mv "$LOG_FILE.tmp" "$LOG_FILE"
            log "🗑️  Trimmed log file to $MAX_LOG_LINES lines"
        fi
    fi
}

# Check if VPN is paused
if [ -f "$PAUSE_FILE" ]; then
    # Even when paused, log if connection is down
    if ! pgrep -f openvpn > /dev/null; then
        log_diagnostics "PAUSED MODE CHECK" "⚠️  VPN disconnected while paused"
    fi
    exit 0
fi

# Main health check logic
check_vpn_health() {
    local failed_checks=""

    # Check 1: OpenVPN process
    if ! pgrep -f openvpn > /dev/null; then
        failed_checks="${failed_checks}process "
    fi

    # Check 2: Tunnel interface with ProtonVPN IP
    if ! ip addr | grep -q "inet 10\.96\."; then
        failed_checks="${failed_checks}tunnel "
    fi

    # Check 3: Internet connectivity through VPN
    # Use multiple endpoints with longer timeout for reliability
    local connectivity_ok=false

    # Try primary endpoint (10 second timeout)
    if curl -s --max-time 10 https://icanhazip.com >/dev/null 2>&1; then
        connectivity_ok=true
    # Fallback to secondary endpoint
    elif curl -s --max-time 10 https://api.ipify.org >/dev/null 2>&1; then
        connectivity_ok=true
    # Last resort: ping test
    elif ping -c 2 -W 5 8.8.8.8 >/dev/null 2>&1; then
        connectivity_ok=true
    fi

    if [ "$connectivity_ok" = false ]; then
        failed_checks="${failed_checks}connectivity "
    fi

    # Evaluate results
    if [ -z "$failed_checks" ]; then
        # All checks passed - log success periodically (every 10th check)
        if [ $((RANDOM % 10)) -eq 0 ]; then
            log "✅ VPN healthy - all checks passed"
        fi
        return 0
    else
        # Health check failed
        log_diagnostics "HEALTH CHECK FAILED" "❌ Failed: $failed_checks"
        log "🔄 Triggering immediate VPN rotation for recovery..."

        # Trigger rotation for recovery
        bash "$ROTATION_SCRIPT"

        # Verify recovery
        sleep 5
        if pgrep -f openvpn > /dev/null && ip addr | grep -q "inet 10\.96\."; then
            log_diagnostics "RECOVERY" "✅ VPN recovered successfully"
        else
            log_diagnostics "RECOVERY" "❌ Recovery failed - will retry on next healthcheck"
        fi

        return 1
    fi
}

# Run healthcheck
check_vpn_health

# Trim log periodically
trim_log
