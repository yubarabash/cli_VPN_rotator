#!/bin/bash

# Transfer VPN configs to Android device
# Requires adb (Android Debug Bridge)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVERS_DIR="$SCRIPT_DIR/_servers"
ANDROID_PATH="/sdcard/Download/VPN_configs"

echo "📱 Android VPN Config Transfer Tool"
echo "===================================="
echo ""

# Check if adb is installed
if ! command -v adb &> /dev/null; then
    echo "❌ Error: adb (Android Debug Bridge) not found"
    echo ""
    echo "Install options:"
    echo "  macOS:  brew install android-platform-tools"
    echo "  Linux:  sudo apt install adb"
    echo ""
    echo "Or download from: https://developer.android.com/studio/releases/platform-tools"
    exit 1
fi

# Check if device is connected
echo "🔍 Checking for connected Android devices..."
DEVICE_COUNT=$(adb devices | grep -v "List" | grep "device" | wc -l | tr -d ' ')

if [ "$DEVICE_COUNT" -eq 0 ]; then
    echo "❌ No Android device detected"
    echo ""
    echo "Setup steps:"
    echo "  1. Enable 'Developer Options' on your Android device"
    echo "     Settings → About Phone → Tap 'Build Number' 7 times"
    echo ""
    echo "  2. Enable 'USB Debugging'"
    echo "     Settings → Developer Options → USB Debugging"
    echo ""
    echo "  3. Connect device via USB cable"
    echo "  4. Authorize the computer on your device"
    echo ""
    exit 1
fi

DEVICE_NAME=$(adb devices | grep -v "List" | grep "device" | awk '{print $1}')
echo "✅ Connected to: $DEVICE_NAME"
echo ""

# Count .ovpn files
OVPN_COUNT=$(ls "$SERVERS_DIR"/*.ovpn 2>/dev/null | wc -l | tr -d ' ')

if [ "$OVPN_COUNT" -eq 0 ]; then
    echo "❌ No .ovpn files found in $SERVERS_DIR"
    exit 1
fi

echo "📂 Found $OVPN_COUNT .ovpn files"
echo ""

# Create directory on Android
echo "📱 Creating directory on Android..."
adb shell mkdir -p "$ANDROID_PATH" 2>/dev/null

# Transfer files
echo "🚀 Transferring files..."
echo ""

TRANSFERRED=0
for ovpn_file in "$SERVERS_DIR"/*.ovpn; do
    filename=$(basename "$ovpn_file")
    echo "  → $filename"
    adb push "$ovpn_file" "$ANDROID_PATH/" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        ((TRANSFERRED++))
    else
        echo "    ⚠️  Failed to transfer $filename"
    fi
done

echo ""
echo "✅ Transferred $TRANSFERRED/$OVPN_COUNT files"
echo ""

# Also transfer the auth file (without credentials for security)
echo "📄 Creating auth template..."
cat > /tmp/auth-template.txt << 'EOF'
YOUR_PROTONVPN_USERNAME
YOUR_PROTONVPN_PASSWORD
EOF

adb push /tmp/auth-template.txt "$ANDROID_PATH/auth-template.txt" > /dev/null 2>&1
rm /tmp/auth-template.txt

# Transfer guide documents
echo "📚 Transferring setup guides..."
if [ -f "$SCRIPT_DIR/ANDROID_TASKER_SETUP.md" ]; then
    adb push "$SCRIPT_DIR/ANDROID_TASKER_SETUP.md" "$ANDROID_PATH/" > /dev/null 2>&1
    echo "  → ANDROID_TASKER_SETUP.md"
fi

if [ -f "$SCRIPT_DIR/ANDROID_QUICK_REFERENCE.md" ]; then
    adb push "$SCRIPT_DIR/ANDROID_QUICK_REFERENCE.md" "$ANDROID_PATH/" > /dev/null 2>&1
    echo "  → ANDROID_QUICK_REFERENCE.md"
fi

echo ""
echo "🎉 Transfer complete!"
echo ""
echo "Files are located at:"
echo "  $ANDROID_PATH"
echo ""
echo "Next steps:"
echo "  1. Open 'OpenVPN for Android' app"
echo "  2. Tap '+' → Import Profile from SD card"
echo "  3. Navigate to Download/VPN_configs/"
echo "  4. Import each .ovpn file"
echo "  5. Add your ProtonVPN credentials to each profile"
echo "  6. Follow ANDROID_TASKER_SETUP.md for Tasker configuration"
echo ""
echo "💡 Tip: You can also access the files via:"
echo "    Files app → Download → VPN_configs"
echo ""
