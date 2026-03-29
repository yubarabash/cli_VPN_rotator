#!/bin/bash

# VPN Rotation Script
# Rotates through ProtonVPN servers every 15 minutes

BASE_DIR="/home/toolik/_TOOLS/_VPN_rotator"
CONFIG_DIR="$BASE_DIR/_servers"
AUTH_FILE="$BASE_DIR/auth.txt"
LOG_FILE="$BASE_DIR/vpn-rotation.log"
STATE_FILE="$BASE_DIR/vpn-current-server.txt"
PID_FILE="$BASE_DIR/vpn-rotation.pid"
PAUSE_FILE="$BASE_DIR/vpn-rotation-paused.txt"
LOCK_FILE="$BASE_DIR/vpn-rotation.lock"
MAX_RETRIES=3
CONNECTION_TIMEOUT=15
LOCK_ACQUIRED=false

# Function to log messages
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to get country name from country code
get_country_name() {
    local code="$1"
    case "$code" in
        al) echo "Albania" ;;
        ao) echo "Angola" ;;
        ar) echo "Argentina" ;;
        au) echo "Australia" ;;
        az) echo "Azerbaijan" ;;
        bd) echo "Bangladesh" ;;
        bg) echo "Bulgaria" ;;
        bn) echo "Brunei" ;;
        br) echo "Brazil" ;;
        ca) echo "Canada" ;;
        ch) echo "Switzerland" ;;
        ci) echo "Côte d'Ivoire" ;;
        cl) echo "Chile" ;;
        cm) echo "Cameroon" ;;
        co) echo "Colombia" ;;
        dz) echo "Algeria" ;;
        ec) echo "Ecuador" ;;
        er) echo "Eritrea" ;;
        es) echo "Spain" ;;
        gh) echo "Ghana" ;;
        hk) echo "Hong Kong" ;;
        in) echo "India" ;;
        jo) echo "Jordan" ;;
        kr) echo "South Korea" ;;
        kw) echo "Kuwait" ;;
        ly) echo "Libya" ;;
        mz) echo "Mozambique" ;;
        rw) echo "Rwanda" ;;
        se) echo "Sweden" ;;
        sv) echo "El Salvador" ;;
        td) echo "Chad" ;;
        uk) echo "United Kingdom" ;;
        us) echo "United States" ;;
        *) echo "Unknown" ;;
    esac
}

# Acquire lock to prevent duplicate executions
acquire_lock() {
    # Check if lock file exists and process is still running
    if [ -f "$LOCK_FILE" ]; then
        LOCK_PID=$(cat "$LOCK_FILE" 2>/dev/null)
        if [ -n "$LOCK_PID" ] && ps -p "$LOCK_PID" > /dev/null 2>&1; then
            log "Another rotation is already in progress (PID: $LOCK_PID). Skipping."
            exit 0
        else
            # Stale lock file, remove it
            rm -f "$LOCK_FILE"
        fi
    fi

    # Create lock file with current PID
    echo $$ > "$LOCK_FILE"
    LOCK_ACQUIRED=true
}

# Clean up lock and state on exit (only if we acquired the lock)
cleanup() {
    if [ "$LOCK_ACQUIRED" = true ]; then
        rm -f "$LOCK_FILE"
    fi
}

trap cleanup EXIT

# Verify actual VPN connectivity
verify_connection() {
    # Check if OpenVPN process is running
    if ! pgrep -f openvpn > /dev/null; then
        log "⚠️  OpenVPN process not found"
        # Clean up stale state file
        rm -f "$STATE_FILE"
        return 1
    fi

    # Check if tunnel interface has an IP in ProtonVPN range (10.96.0.0/16)
    if ! ip addr | grep -q "inet 10\.96\."; then
        log "⚠️  VPN tunnel interface not found or no IP assigned"
        return 1
    fi

    # Verify we can actually reach the internet through the VPN (curl has built-in timeout)
    if curl -s --max-time $CONNECTION_TIMEOUT https://icanhazip.com >/dev/null 2>&1; then
        return 0
    else
        log "⚠️  VPN tunnel present but no internet connectivity"
        return 1
    fi
}

# Get current IP with timeout
get_current_ip() {
    local ip=$(curl -s --max-time $CONNECTION_TIMEOUT https://api.ipify.org 2>/dev/null)
    if [ -z "$ip" ]; then
        log "⚠️  Failed to retrieve IP address"
        echo "unknown"
    else
        echo "$ip"
    fi
}

# Function to disconnect current VPN
disconnect_vpn() {
    log "Disconnecting current VPN..."
    sudo killall openvpn 2>/dev/null
    sleep 2

    # Clean up state file when disconnecting
    rm -f "$STATE_FILE"

    # Verify disconnection
    if pgrep -f openvpn > /dev/null; then
        log "⚠️  Warning: OpenVPN process still running after kill attempt"
        sudo killall -9 openvpn 2>/dev/null
        sleep 1
    fi
}

# Function to connect to VPN
connect_vpn() {
    local config_file="$1"
    local server_name=$(basename "$config_file" .ovpn)
    local retry=0

    while [ $retry -lt $MAX_RETRIES ]; do
        if [ $retry -gt 0 ]; then
            log "Retry attempt $retry/$MAX_RETRIES for $server_name"
            sleep 3
        fi

        log "Connecting to $server_name..."

        # Start OpenVPN in background
        sudo /usr/sbin/openvpn \
            --config "$config_file" \
            --auth-user-pass "$AUTH_FILE" \
            --daemon \
            --log-append "$LOG_FILE" \
            --writepid "$PID_FILE"

        # Wait for OpenVPN to fully establish connection and routes
        # Increased to 15 seconds to ensure routes are stable
        sleep 15

        # Verify connection with actual connectivity test
        if verify_connection; then
            log "✅ Connected to $server_name"
            echo "$server_name" > "$STATE_FILE"

            # Get new IP with timeout
            NEW_IP=$(get_current_ip)

            # Extract country code from server name (first 2 letters)
            local country_code=$(echo "$server_name" | cut -c1-2)
            local country_name=$(get_country_name "$country_code")

            log "New IP: $NEW_IP ($country_name)"
            return 0
        else
            log "❌ Connection verification failed for $server_name"
            sudo killall openvpn 2>/dev/null
            retry=$((retry + 1))
        fi
    done

    log "❌ Failed to connect to $server_name after $MAX_RETRIES attempts"
    return 1
}

# Function to get next server (random selection)
get_next_server() {
    # Get all .ovpn files
    local servers=($(ls "$CONFIG_DIR"/*.ovpn 2>/dev/null))

    if [ ${#servers[@]} -eq 0 ]; then
        log "ERROR: No .ovpn files found in $CONFIG_DIR"
        exit 1
    fi

    # Get current server to avoid selecting it again
    local current_server=""
    if [ -f "$STATE_FILE" ]; then
        current_server=$(cat "$STATE_FILE")
    fi

    # If only one server, return it
    if [ ${#servers[@]} -eq 1 ]; then
        echo "${servers[0]}"
        return
    fi

    # Select random server different from current one
    local next_server=""
    local attempts=0
    while [ $attempts -lt 50 ]; do
        local random_index=$(( RANDOM % ${#servers[@]} ))
        local candidate=$(basename "${servers[$random_index]}" .ovpn)

        if [ "$candidate" != "$current_server" ]; then
            next_server="${servers[$random_index]}"
            break
        fi
        attempts=$((attempts + 1))
    done

    # Fallback: if we somehow didn't find a different server, just pick the first one
    if [ -z "$next_server" ]; then
        next_server="${servers[0]}"
    fi

    echo "$next_server"
}

# Main rotation function
rotate_vpn() {
    # Acquire lock to prevent duplicate executions
    acquire_lock

    # Check if rotation is paused
    if [ -f "$PAUSE_FILE" ]; then
        log "⏸️  VPN rotation is paused. Skipping rotation. (VPN remains connected)"
        # Still verify connection health even when paused
        if ! verify_connection; then
            log "⚠️  VPN appears disconnected while paused. Consider resuming rotation."
        fi
        return 0
    fi

    log "========== VPN Rotation Started =========="

    # Check if auth file exists
    if [ ! -f "$AUTH_FILE" ]; then
        log "ERROR: Auth file not found at $AUTH_FILE"
        log "Please create it with your ProtonVPN credentials:"
        log "Line 1: username"
        log "Line 2: password"
        exit 1
    fi

    # Disconnect current VPN
    disconnect_vpn

    # Get next server to connect to
    NEXT_SERVER=$(get_next_server)

    # Connect to next server with retry logic
    if connect_vpn "$NEXT_SERVER"; then
        log "✅ Rotation successful. Next rotation in 15 minutes."
    else
        log "❌ Rotation failed after all retry attempts. Will retry on next schedule."
        # Try to keep some connection by attempting to connect to any available server
        log "Attempting emergency connection to any available server..."
        local servers=($(ls "$CONFIG_DIR"/*.ovpn 2>/dev/null | sort -R))
        for emergency_server in "${servers[@]}"; do
            if connect_vpn "$emergency_server"; then
                log "✅ Emergency connection established"
                break
            fi
        done
    fi

    log "=========================================="
}

# Run rotation
rotate_vpn
