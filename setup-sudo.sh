#!/bin/bash

# Setup sudo access for OpenVPN without password
# This is safe - it only allows running openvpn, nothing else

echo "This will configure sudo to allow OpenVPN without password"
echo "You'll need to enter your password once"
echo ""

# Detect OS and set paths accordingly
if [[ "$OSTYPE" == "darwin"* ]]; then
    OPENVPN_PATH="/usr/local/bin/openvpn"
    FIREWALL_CMD="/sbin/pfctl"
else
    # Linux
    OPENVPN_PATH="/usr/sbin/openvpn"
    FIREWALL_CMD="/usr/sbin/iptables"
fi

# Create sudoers entries
SUDOERS_FILE="/etc/sudoers.d/vpn-rotator"

# Check if entry already exists
if [ -f "$SUDOERS_FILE" ]; then
    echo "✅ VPN sudo rules already exist"
    echo "Removing old rules to update..."
    sudo rm -f "$SUDOERS_FILE"
fi

echo "Adding sudo rules for OpenVPN and kill-switch..."
cat << EOF | sudo tee "$SUDOERS_FILE" > /dev/null
# VPN Rotator sudo rules
$USER ALL=(ALL) NOPASSWD: $OPENVPN_PATH
$USER ALL=(ALL) NOPASSWD: $FIREWALL_CMD
$USER ALL=(ALL) NOPASSWD: /usr/bin/killall openvpn
EOF
sudo chmod 440 "$SUDOERS_FILE"
echo "✅ Sudo rules added for OpenVPN and firewall"

echo ""
echo "Testing sudo access..."
if sudo -n $OPENVPN_PATH --version >/dev/null 2>&1; then
    echo "✅ OpenVPN can now run without password"
else
    echo "⚠️  OpenVPN test failed"
fi

echo ""
echo "✅ Setup complete! You can now:"
echo "   - Run VPN rotation automatically"
echo "   - Use kill-switch to protect against leaks"
