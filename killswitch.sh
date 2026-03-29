#!/bin/bash

# VPN Kill-Switch
# Blocks all internet traffic when VPN is disconnected
# Linux version using iptables

BASE_DIR="/home/parallels/_TOOLS/_VPN_rotator"
KILLSWITCH_STATE="$BASE_DIR/killswitch-enabled.txt"
LOG_FILE="$BASE_DIR/killswitch.log"
IPTABLES_BACKUP="$BASE_DIR/iptables-backup.rules"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if VPN is connected
is_vpn_connected() {
    if pgrep -f openvpn > /dev/null; then
        return 0
    else
        return 1
    fi
}

# Enable kill-switch
enable_killswitch() {
    log "Enabling kill-switch..."

    # Backup current iptables rules
    sudo iptables-save > "$IPTABLES_BACKUP"

    # Flush existing rules in our chain if it exists
    sudo iptables -F VPN_KILLSWITCH 2>/dev/null
    sudo iptables -X VPN_KILLSWITCH 2>/dev/null

    # Create custom chain for kill-switch
    sudo iptables -N VPN_KILLSWITCH

    # Allow loopback
    sudo iptables -A VPN_KILLSWITCH -i lo -j ACCEPT
    sudo iptables -A VPN_KILLSWITCH -o lo -j ACCEPT

    # Allow established connections
    sudo iptables -A VPN_KILLSWITCH -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # Allow DNS (needed for VPN connection)
    sudo iptables -A VPN_KILLSWITCH -p udp --dport 53 -j ACCEPT
    sudo iptables -A VPN_KILLSWITCH -p tcp --dport 53 -j ACCEPT

    # Allow OpenVPN traffic (common ports)
    sudo iptables -A VPN_KILLSWITCH -p udp --dport 1194 -j ACCEPT
    sudo iptables -A VPN_KILLSWITCH -p tcp --dport 1194 -j ACCEPT
    sudo iptables -A VPN_KILLSWITCH -p udp --dport 443 -j ACCEPT
    sudo iptables -A VPN_KILLSWITCH -p tcp --dport 443 -j ACCEPT

    # Allow all traffic on tun interfaces (VPN tunnel)
    sudo iptables -A VPN_KILLSWITCH -o tun+ -j ACCEPT
    sudo iptables -A VPN_KILLSWITCH -i tun+ -j ACCEPT

    # Allow local network (optional - comment out for stricter security)
    sudo iptables -A VPN_KILLSWITCH -d 192.168.0.0/16 -j ACCEPT
    sudo iptables -A VPN_KILLSWITCH -s 192.168.0.0/16 -j ACCEPT
    sudo iptables -A VPN_KILLSWITCH -d 10.0.0.0/8 -j ACCEPT
    sudo iptables -A VPN_KILLSWITCH -s 10.0.0.0/8 -j ACCEPT

    # Drop everything else
    sudo iptables -A VPN_KILLSWITCH -j DROP

    # Insert our chain into OUTPUT and INPUT
    sudo iptables -I OUTPUT -j VPN_KILLSWITCH
    sudo iptables -I INPUT -j VPN_KILLSWITCH

    echo "enabled" > "$KILLSWITCH_STATE"
    log "✅ Kill-switch ENABLED - All traffic blocked except VPN"
}

# Disable kill-switch
disable_killswitch() {
    log "Disabling kill-switch..."

    # Remove references to our chain
    sudo iptables -D OUTPUT -j VPN_KILLSWITCH 2>/dev/null
    sudo iptables -D INPUT -j VPN_KILLSWITCH 2>/dev/null

    # Flush and delete our chain
    sudo iptables -F VPN_KILLSWITCH 2>/dev/null
    sudo iptables -X VPN_KILLSWITCH 2>/dev/null

    rm -f "$KILLSWITCH_STATE"
    log "✅ Kill-switch DISABLED - Normal traffic allowed"
}

# Check kill-switch status
check_status() {
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VPN Kill-Switch Status"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if [ -f "$KILLSWITCH_STATE" ]; then
        echo "Kill-Switch: ✅ ENABLED (protection active)"
    else
        echo "Kill-Switch: ❌ DISABLED (no protection)"
    fi

    if is_vpn_connected; then
        echo "VPN Status: ✅ CONNECTED"
        echo "Internet: ✅ Traffic allowed through VPN"
    else
        echo "VPN Status: ❌ DISCONNECTED"
        if [ -f "$KILLSWITCH_STATE" ]; then
            echo "Internet: 🛑 BLOCKED (kill-switch active)"
        else
            echo "Internet: ⚠️  UNPROTECTED (no kill-switch)"
        fi
    fi

    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

# Monitor mode - continuously check VPN status
monitor() {
    log "Starting kill-switch monitor..."

    while true; do
        if [ -f "$KILLSWITCH_STATE" ]; then
            if ! is_vpn_connected; then
                log "⚠️  VPN DISCONNECTED - Kill-switch blocking traffic"
                # Ensure rules are still active
                if ! sudo iptables -L VPN_KILLSWITCH &>/dev/null; then
                    enable_killswitch
                fi
            fi
        fi
        sleep 5
    done
}

case "$1" in
    enable|on)
        enable_killswitch
        ;;

    disable|off)
        disable_killswitch
        ;;

    status)
        check_status
        ;;

    monitor)
        monitor
        ;;

    test)
        echo "Testing kill-switch..."
        echo ""
        echo "1. Checking current VPN status..."
        if is_vpn_connected; then
            echo "   ✅ VPN is connected"
        else
            echo "   ❌ VPN is not connected"
        fi

        echo ""
        echo "2. Checking your current IP..."
        CURRENT_IP=$(curl -s --max-time 5 https://api.ipify.org)
        if [ -n "$CURRENT_IP" ]; then
            echo "   Current IP: $CURRENT_IP"
        else
            echo "   🛑 Cannot reach internet (kill-switch working)"
        fi

        echo ""
        check_status
        ;;

    *)
        echo "🔐 VPN Kill-Switch Control"
        echo ""
        echo "Usage: $0 {enable|disable|status|monitor|test}"
        echo ""
        echo "Commands:"
        echo "  enable   - Enable kill-switch (block traffic when VPN drops)"
        echo "  disable  - Disable kill-switch (allow traffic without VPN)"
        echo "  status   - Show current kill-switch and VPN status"
        echo "  monitor  - Continuously monitor VPN (keeps kill-switch active)"
        echo "  test     - Test kill-switch functionality"
        echo ""
        exit 1
        ;;
esac
