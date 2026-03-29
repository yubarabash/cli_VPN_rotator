# Android VPN Rotation with Tasker (No Root Required)

This guide shows how to implement automatic VPN server rotation on Android using Tasker and OpenVPN for Android.

## Required Apps

1. **OpenVPN for Android** (Free)
   - Download: [Google Play Store](https://play.google.com/store/apps/details?id=de.blinkt.openvpn)
   - By Arne Schwabe
   - Official OpenVPN client with Tasker support

2. **Tasker** (Paid, ~$3.49)
   - Download: [Google Play Store](https://play.google.com/store/apps/details?id=net.dinglisch.android.taskerm)
   - Automation app for Android
   - Essential for automation

3. **OpenVPN for Android Tasker Plugin** (Optional but recommended)
   - Some versions include this built-in
   - Check OpenVPN for Android settings → "Allow external apps"

## Setup Instructions

### Step 1: Import Your ProtonVPN Configs

1. Copy all your `.ovpn` files from macOS to Android:
   ```
   From: /Users/miramar/lv/Resources/VPN_rotator/_servers/
   To: Android device (e.g., Downloads or Documents folder)
   ```

2. Open **OpenVPN for Android**

3. Tap the **+** button → **Import** → **Import Profile from SD card**

4. Import each `.ovpn` file (ao, au, bd, us, es, etc.)

5. For each profile:
   - Tap the profile
   - Under "Authentication/Encryption" → Enable "Inline authentication"
   - Enter your ProtonVPN username and password
   - Save

### Step 2: Enable Tasker Integration

1. Open **OpenVPN for Android**

2. Go to **Settings** (⚙️)

3. Enable **"Allow external apps to start VPN"**

4. This allows Tasker to control OpenVPN

### Step 3: Create Tasker Profile for Rotation

#### Create the Rotation Task

1. Open **Tasker**

2. Go to **Tasks** tab → Tap **+** to create new task

3. Name it: **"VPN Rotate"**

4. Add actions (tap **+** for each):

   **Action 1: Stop Current VPN**
   - Category: **Plugin**
   - Plugin: **OpenVPN for Android**
   - Configuration: **Disconnect**
   - Timeout: 10 seconds

   **Action 2: Wait**
   - Category: **Task**
   - Action: **Wait**
   - Seconds: **3**

   **Action 3: Get Next Server**
   - Category: **Variables**
   - Action: **Variable Set**
   - Name: `%SERVERS`
   - To: `ao,au,bd,us,es,bg,mz,ch,uk,se,rw` (your server list)

   **Action 4: Calculate Next Index**
   - Category: **Variables**
   - Action: **Variable Add**
   - Name: `%VPN_INDEX`
   - Value: `1`
   - Wrap Around: `11` (number of servers)

   **Action 5: Get Current Server**
   - Category: **Variables**
   - Action: **Variable Split**
   - Name: `%SERVERS`
   - Splitter: `,`

   **Action 6: Connect to Next Server**
   - Category: **Plugin**
   - Plugin: **OpenVPN for Android**
   - Configuration: **Connect to profile**
   - Profile: `%SERVERS%VPN_INDEX.protonvpn.udp` (match your naming)

   **Action 7: Log Rotation**
   - Category: **File**
   - Action: **Write File**
   - File: `VPN/rotation.log`
   - Text: `%DATE %TIME - Rotated to server %SERVERS%VPN_INDEX`
   - Append: ✓
   - Add Newline: ✓

#### Create Time-Based Profile

1. Go to **Profiles** tab → Tap **+**

2. Select **Time**

3. Configure:
   - From: `00:00`
   - To: `23:59`
   - Repeat: `15` minutes

4. Link to task: **"VPN Rotate"**

5. Enable the profile

### Step 4: Add Pause/Resume Functionality

#### Create Pause Task

1. **Tasks** tab → **+** → Name: **"VPN Pause Rotation"**

2. Add actions:

   **Action 1: Create Pause Flag**
   - Category: **File**
   - Action: **Write File**
   - File: `VPN/paused.txt`
   - Text: `paused`

   **Action 2: Show Notification**
   - Category: **Alert**
   - Action: **Notify**
   - Title: `VPN Rotation Paused`
   - Text: `VPN stays connected, rotation disabled`
   - Icon: `⏸️`

#### Create Resume Task

1. **Tasks** tab → **+** → Name: **"VPN Resume Rotation"**

2. Add actions:

   **Action 1: Delete Pause Flag**
   - Category: **File**
   - Action: **Delete File**
   - File: `VPN/paused.txt`

   **Action 2: Show Notification**
   - Category: **Alert**
   - Action: **Notify**
   - Title: `VPN Rotation Resumed`
   - Text: `Will rotate every 15 minutes`
   - Icon: `▶️`

#### Update Rotation Task to Check Pause State

Edit the **"VPN Rotate"** task:

1. Add as **first action**:

   **Action 1: Check if Paused**
   - Category: **File**
   - Action: **Test File**
   - Type: `Exists`
   - File: `VPN/paused.txt`
   - Store result in: `%PAUSED`

   **Action 2: Stop if Paused**
   - Category: **Task**
   - Action: **Stop**
   - If: `%PAUSED eq true`

(Then all your existing rotation actions continue)

### Step 5: Create Quick Settings Tiles (Android 7+)

#### For Pause

1. Go to **Profiles** tab → **+**

2. Select **Event** → **UI** → **Quick Setting Tile**

3. Name: `VPN Pause`

4. Link to task: **"VPN Pause Rotation"**

#### For Resume

1. Repeat for **"VPN Resume Rotation"**

2. Name: `VPN Resume`

#### Add to Quick Settings

1. Swipe down notification panel twice

2. Tap **Edit** (pencil icon)

3. Drag **"VPN Pause"** and **"VPN Resume"** tiles to quick settings

4. Now you can pause/resume with one tap

## Alternative: Simpler Sequential Approach

If the above is too complex, here's a simpler method that just cycles through profiles:

### Simple Rotation Task

1. Create task: **"VPN Simple Rotate"**

2. Add these actions:

   ```
   Action 1: Plugin → OpenVPN for Android → Disconnect
   Action 2: Wait → 3 seconds
   Action 3: Plugin → OpenVPN for Android → Connect to "ao.protonvpn.udp"
   Action 4: Wait → 15 minutes

   Action 5: Plugin → OpenVPN for Android → Disconnect
   Action 6: Wait → 3 seconds
   Action 7: Plugin → OpenVPN for Android → Connect to "au.protonvpn.udp"
   Action 8: Wait → 15 minutes

   [... repeat for each server ...]

   Action N: Goto Action 1 (loop back to start)
   ```

3. Create profile: **Time** → Any time → Repeat: Never

4. Link to **"VPN Simple Rotate"**

5. Run task manually once - it will loop forever

This is simpler but less flexible.

## Monitoring & Status

### Create Status Check Task

1. **Tasks** tab → **+** → Name: **"VPN Status"**

2. Add actions:

   **Action 1: Get Current Connection**
   - Category: **Net**
   - Action: **Test Net**
   - Type: `VPN Active`
   - Store in: `%VPN_ACTIVE`

   **Action 2: Get External IP**
   - Category: **Net**
   - Action: **HTTP Get**
   - Server: `https://api.ipify.org`
   - Output File: (leave empty, stores in %HTTPD)

   **Action 3: Read Pause State**
   - Category: **File**
   - Action: **Test File**
   - File: `VPN/paused.txt`
   - Store in: `%PAUSED`

   **Action 4: Show Status**
   - Category: **Alert**
   - Action: **Flash**
   - Text:
     ```
     VPN: %VPN_ACTIVE
     IP: %HTTPD
     Paused: %PAUSED
     ```

3. Add widget to home screen:
   - Long press home screen → **Widgets** → **Tasker** → **Task Shortcut**
   - Select **"VPN Status"**

## Troubleshooting

### OpenVPN Doesn't Connect via Tasker

- Check "Allow external apps" is enabled in OpenVPN settings
- Make sure profile names match exactly (case-sensitive)
- Try manually connecting to profiles first to ensure they work

### Rotation Stops Working

- Check Tasker battery optimization is disabled
- Android Settings → Battery → Battery Optimization → Tasker → Don't optimize
- Same for OpenVPN for Android

### Can't Find OpenVPN Plugin in Tasker

- Update OpenVPN for Android to latest version
- In Tasker, try: Plugin → OpenVPN for Android
- If missing, use "Send Intent" action instead (advanced)

## Limitations Compared to macOS Version

- No automatic scheduling via system service (relies on Tasker profile)
- Tasker must be running (keep it battery-optimized-exempt)
- Less precise timing (Android can delay background tasks)
- Manual profile import required
- No command-line control

## Advantages

- No root required
- Works on all Android devices
- Easy pause/resume via quick settings
- Can integrate with other Tasker automation
- Battery-friendly (Tasker is optimized)

## Next Steps

1. Test rotation manually first
2. Enable the timed profile
3. Monitor logs for 24 hours
4. Add pause/resume tiles
5. Set up status widget

## Files Created on Android

```
Internal Storage/
├── VPN/
│   ├── rotation.log       # Rotation history
│   ├── paused.txt         # Pause state flag
│   └── current-server.txt # Current server name
```

## Support

- OpenVPN for Android docs: https://ics-openvpn.blinkt.de/
- Tasker wiki: https://tasker.joaoapps.com/userguide/en/
- ProtonVPN configs: https://account.protonvpn.com/downloads
