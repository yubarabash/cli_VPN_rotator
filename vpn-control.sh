#!/bin/bash

# VPN Rotation Control Script
# Easy commands to start/stop/status VPN rotation
# Linux version using systemd timers

BASE_DIR="/home/toolik/_TOOLS/_VPN_rotator"
LOG_FILE="$BASE_DIR/vpn-rotation.log"
HEALTHCHECK_LOG="$BASE_DIR/vpn-healthcheck.log"
STATE_FILE="$BASE_DIR/vpn-current-server.txt"
KILLSWITCH="$BASE_DIR/killswitch.sh"
PAUSE_FILE="$BASE_DIR/vpn-rotation-paused.txt"
ROTATOR_SCRIPT="$BASE_DIR/vpn-rotator.sh"
HEALTHCHECK_SCRIPT="$BASE_DIR/vpn-healthcheck.sh"

# Systemd user unit paths
SYSTEMD_USER_DIR="$HOME/.config/systemd/user"
ROTATION_SERVICE="vpn-rotator.service"
ROTATION_TIMER="vpn-rotator.timer"
HEALTHCHECK_SERVICE="vpn-healthcheck.service"
HEALTHCHECK_TIMER="vpn-healthcheck.timer"

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

# Create systemd user unit files
setup_systemd_units() {
    mkdir -p "$SYSTEMD_USER_DIR"

    # VPN Rotator Service
    cat > "$SYSTEMD_USER_DIR/$ROTATION_SERVICE" << EOF
[Unit]
Description=VPN Rotation Service
After=network-online.target

[Service]
Type=oneshot
ExecStart=$ROTATOR_SCRIPT
EOF

    # VPN Rotator Timer (every 15 minutes)
    cat > "$SYSTEMD_USER_DIR/$ROTATION_TIMER" << EOF
[Unit]
Description=VPN Rotation Timer

[Timer]
OnBootSec=1min
OnUnitActiveSec=15min
Persistent=true

[Install]
WantedBy=timers.target
EOF

    # VPN Healthcheck Service
    cat > "$SYSTEMD_USER_DIR/$HEALTHCHECK_SERVICE" << EOF
[Unit]
Description=VPN Healthcheck Service
After=network-online.target

[Service]
Type=oneshot
ExecStart=$HEALTHCHECK_SCRIPT
EOF

    # VPN Healthcheck Timer (every 2 minutes)
    cat > "$SYSTEMD_USER_DIR/$HEALTHCHECK_TIMER" << EOF
[Unit]
Description=VPN Healthcheck Timer

[Timer]
OnBootSec=2min
OnUnitActiveSec=2min
Persistent=true

[Install]
WantedBy=timers.target
EOF

    systemctl --user daemon-reload
}

case "$1" in
    start)
        echo "🚀 Starting VPN rotation service..."
        setup_systemd_units
        systemctl --user enable --now "$ROTATION_TIMER"
        systemctl --user enable --now "$HEALTHCHECK_TIMER"
        # Run initial rotation
        bash "$ROTATOR_SCRIPT"
        echo "✅ VPN rotation started. Will rotate every 15 minutes."
        echo "✅ VPN healthcheck started. Checks VPN health every 2 minutes."
        echo "📝 Check logs: tail -f $LOG_FILE"
        ;;

    stop)
        echo "🛑 Stopping VPN rotation service..."
        systemctl --user stop "$ROTATION_TIMER" 2>/dev/null
        systemctl --user stop "$HEALTHCHECK_TIMER" 2>/dev/null
        systemctl --user disable "$ROTATION_TIMER" 2>/dev/null
        systemctl --user disable "$HEALTHCHECK_TIMER" 2>/dev/null
        sudo killall openvpn 2>/dev/null
        echo "✅ VPN rotation and healthcheck stopped."
        ;;

    restart)
        echo "🔄 Restarting VPN rotation service..."
        systemctl --user stop "$ROTATION_TIMER" 2>/dev/null
        systemctl --user stop "$HEALTHCHECK_TIMER" 2>/dev/null
        sleep 2
        setup_systemd_units
        systemctl --user start "$ROTATION_TIMER"
        systemctl --user start "$HEALTHCHECK_TIMER"
        echo "✅ VPN rotation and healthcheck restarted."
        ;;

    status)
        echo "📊 VPN Rotation Status:"
        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        if systemctl --user is-active --quiet "$ROTATION_TIMER" 2>/dev/null; then
            echo "Rotation Service: ✅ Running"
        else
            echo "Rotation Service: ❌ Stopped"
        fi

        if systemctl --user is-active --quiet "$HEALTHCHECK_TIMER" 2>/dev/null; then
            echo "Healthcheck Service: ✅ Running (every 2 min)"
        else
            echo "Healthcheck Service: ❌ Stopped"
        fi

        if [ -f "$PAUSE_FILE" ]; then
            echo "Rotation: ⏸️  Paused (VPN stays connected)"
        else
            echo "Rotation: ▶️  Active"
        fi

        # Check if OpenVPN process is running
        if pgrep -f openvpn > /dev/null; then
            # Detailed health checks with diagnostics
            tunnel_ok=false
            connectivity_ok=false
            failed_checks=""

            # Check 1: Tunnel interface
            if ip addr | grep -q "inet 10\.96\."; then
                tunnel_ok=true
            else
                failed_checks="tunnel-interface "
            fi

            # Check 2: Internet connectivity (multiple endpoints, longer timeout)
            if curl -s --max-time 10 https://icanhazip.com >/dev/null 2>&1; then
                connectivity_ok=true
            elif curl -s --max-time 10 https://api.ipify.org >/dev/null 2>&1; then
                connectivity_ok=true
            elif ping -c 2 -W 5 8.8.8.8 >/dev/null 2>&1; then
                connectivity_ok=true
            else
                failed_checks="${failed_checks}internet-connectivity"
            fi

            # Display results
            if [ "$tunnel_ok" = true ] && [ "$connectivity_ok" = true ]; then
                echo "OpenVPN: ✅ Connected & Verified"
                if [ -f "$STATE_FILE" ]; then
                    CURRENT_SERVER=$(cat "$STATE_FILE")
                    # Extract country code and get country name
                    COUNTRY_CODE=$(echo "$CURRENT_SERVER" | cut -c1-2)
                    COUNTRY_NAME=$(get_country_name "$COUNTRY_CODE")
                    echo "Current Server: $CURRENT_SERVER ($COUNTRY_NAME)"
                fi
                CURRENT_IP=$(curl -s --max-time 10 https://api.ipify.org 2>/dev/null)
                if [ -n "$CURRENT_IP" ]; then
                    echo "Current IP: $CURRENT_IP"
                else
                    echo "Current IP: (failed to retrieve)"
                fi
            else
                echo "OpenVPN: ⚠️  Process running but issues detected"
                echo "Failed checks: $failed_checks"
                if [ "$tunnel_ok" = false ]; then
                    echo "  └─ Tunnel: No ProtonVPN IP (10.96.x.x) found on interface"
                fi
                if [ "$connectivity_ok" = false ]; then
                    echo "  └─ Connectivity: Cannot reach internet through VPN"
                    echo "     (Tested: icanhazip.com, api.ipify.org, ping 8.8.8.8)"
                fi
                echo "Action: Run 'restart' to fix connection"
            fi
        else
            echo "OpenVPN: ❌ Disconnected"
            # Clean up stale state file if process is not running
            if [ -f "$STATE_FILE" ]; then
                rm -f "$STATE_FILE"
                echo "Note: Cleaned up stale state file"
            fi
        fi

        echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

        if [ -f "$LOG_FILE" ]; then
            echo ""
            echo "📝 Last 5 log entries:"
            tail -5 "$LOG_FILE"
        fi
        ;;

    rotate-now)
        echo "🔄 Forcing immediate rotation..."
        bash "$ROTATOR_SCRIPT"
        ;;

    pause)
        if [ -f "$PAUSE_FILE" ]; then
            echo "⏸️  VPN rotation is already paused."
        else
            touch "$PAUSE_FILE"
            echo "⏸️  VPN rotation paused."
            echo "✅ VPN connection remains active, but will not rotate servers."
            echo "💡 Use 'resume' to continue rotation."
        fi
        ;;

    resume)
        if [ -f "$PAUSE_FILE" ]; then
            rm "$PAUSE_FILE"
            echo "▶️  VPN rotation resumed."
            echo "✅ Will rotate to next server on schedule (every 15 min)."
        else
            echo "▶️  VPN rotation is not paused."
        fi
        ;;

    logs)
        echo "📜 Showing VPN rotation logs (Ctrl+C to exit):"
        tail -f "$LOG_FILE"
        ;;

    healthcheck-logs|hc-logs)
        echo "🏥 Showing VPN healthcheck logs (Ctrl+C to exit):"
        if [ -f "$HEALTHCHECK_LOG" ]; then
            tail -f "$HEALTHCHECK_LOG"
        else
            echo "No healthcheck log file found yet. Healthcheck runs every 2 minutes."
        fi
        ;;

    killswitch-on|ks-on)
        bash "$KILLSWITCH" enable
        ;;

    killswitch-off|ks-off)
        bash "$KILLSWITCH" disable
        ;;

    killswitch-status|ks-status)
        bash "$KILLSWITCH" status
        ;;

    killswitch-test|ks-test)
        bash "$KILLSWITCH" test
        ;;

    *)
        echo "🔐 VPN Rotation Control"
        echo ""
        echo "Usage: $0 {start|stop|restart|status|pause|resume|rotate-now|logs|healthcheck-logs}"
        echo ""
        echo "VPN Commands:"
        echo "  start             - Start automatic VPN rotation + healthcheck"
        echo "  stop              - Stop VPN rotation and disconnect"
        echo "  restart           - Restart the rotation + healthcheck services"
        echo "  status            - Show current VPN status with diagnostics"
        echo "  pause             - Pause rotation (keeps VPN connected)"
        echo "  resume            - Resume rotation"
        echo "  rotate-now        - Force immediate rotation to next server"
        echo "  logs              - Watch live rotation logs"
        echo "  healthcheck-logs  (hc-logs) - Watch live healthcheck logs"
        echo ""
        echo "Kill-Switch Commands:"
        echo "  killswitch-on       (ks-on)     - Enable kill-switch protection"
        echo "  killswitch-off      (ks-off)    - Disable kill-switch"
        echo "  killswitch-status   (ks-status) - Check kill-switch status"
        echo "  killswitch-test     (ks-test)   - Test kill-switch functionality"
        echo ""
        echo "💡 Tip: Healthcheck monitors VPN every 2 min and auto-recovers!"
        echo ""
        exit 1
        ;;
esac
