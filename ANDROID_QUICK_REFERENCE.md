# Android VPN Rotation - Quick Reference

## Apps Needed (Total: ~$3.49)

1. **OpenVPN for Android** - FREE
   - https://play.google.com/store/apps/details?id=de.blinkt.openvpn

2. **Tasker** - $3.49
   - https://play.google.com/store/apps/details?id=net.dinglisch.android.taskerm

## One-Time Setup (15 minutes)

1. Install both apps
2. Import your `.ovpn` files into OpenVPN for Android
3. Enable "Allow external apps" in OpenVPN settings
4. Create Tasker tasks (see below)
5. Disable battery optimization for both apps

## Tasker Tasks Summary

### Task 1: VPN Rotate (Main Task)

**Purpose:** Disconnect current VPN and connect to next server

**Actions:**
```
1. Test File: VPN/paused.txt → Stop if exists
2. Plugin: OpenVPN → Disconnect
3. Wait: 3 seconds
4. Variable Set: %VPN_INDEX = %VPN_INDEX + 1 (wrap at 11)
5. Plugin: OpenVPN → Connect to profile #%VPN_INDEX
6. Write File: VPN/rotation.log (append log entry)
```

**Profile:** Time-based, every 15 minutes

---

### Task 2: VPN Pause

**Purpose:** Stop rotation without disconnecting

**Actions:**
```
1. Write File: VPN/paused.txt (content: "paused")
2. Notify: "VPN Rotation Paused"
```

**Trigger:** Quick Settings Tile or widget

---

### Task 3: VPN Resume

**Purpose:** Resume rotation

**Actions:**
```
1. Delete File: VPN/paused.txt
2. Notify: "VPN Rotation Resumed"
```

**Trigger:** Quick Settings Tile or widget

---

### Task 4: VPN Status (Optional)

**Purpose:** Show current status

**Actions:**
```
1. Test Net: VPN Active → %VPN_ACTIVE
2. HTTP Get: https://api.ipify.org → %HTTPD
3. Test File: VPN/paused.txt → %PAUSED
4. Flash: "VPN: %VPN_ACTIVE\nIP: %HTTPD\nPaused: %PAUSED"
```

**Trigger:** Widget or manual

## Server List (Update for your configs)

Create a file with your server names:

```
ao.protonvpn.udp
au.protonvpn.udp
bd.protonvpn.udp
us.protonvpn.udp
es.protonvpn.udp
bg.protonvpn.udp
mz.protonvpn.udp
ch.protonvpn.udp
uk.protonvpn.udp
se.protonvpn.udp
rw.protonvpn.udp
```

## Quick Actions

| Action | Method |
|--------|--------|
| Pause Rotation | Quick Settings → VPN Pause |
| Resume Rotation | Quick Settings → VPN Resume |
| Force Rotate Now | Run "VPN Rotate" task manually |
| Check Status | Run "VPN Status" task |
| View Logs | File Manager → VPN/rotation.log |

## Troubleshooting Quick Fixes

| Problem | Solution |
|---------|----------|
| Tasker stops rotating | Disable battery optimization for Tasker |
| OpenVPN won't connect | Enable "Allow external apps" in settings |
| Rotation skips randomly | Check Android's Doze mode settings |
| Quick Settings tiles missing | Edit tiles, drag from bottom section |

## Battery Optimization Settings

**Critical:** Disable for these apps:

1. **Settings → Battery → Battery Optimization**
2. Select "All apps"
3. Find and set to "Don't optimize":
   - Tasker
   - OpenVPN for Android

## File Locations on Device

```
Internal Storage/VPN/
├── rotation.log       ← Rotation history
├── paused.txt         ← Exists = rotation paused
└── current-server.txt ← Current server name
```

## Testing Checklist

- [ ] OpenVPN profiles imported
- [ ] Credentials saved in each profile
- [ ] "Allow external apps" enabled
- [ ] Tasker tasks created
- [ ] Time profile enabled
- [ ] Battery optimization disabled
- [ ] Quick Settings tiles added
- [ ] Manual rotation test successful
- [ ] Pause/resume test successful
- [ ] 15-minute auto-rotation verified

## Advanced: Send Intent Method (No Plugin)

If OpenVPN plugin doesn't work, use **Send Intent** action:

**Disconnect:**
```
Action: de.blinkt.openvpn.api.DISCONNECT_VPN
Target: Service
```

**Connect:**
```
Action: de.blinkt.openvpn.api.CONNECT_VPN
Extra: de.blinkt.openvpn.api.profileName:your-profile-name
Target: Service
Package: de.blinkt.openvpn
```

## Advantages Over iOS/macOS

- Works on all Android versions 5.0+
- No jailbreak/root required
- Integrates with Tasker automation
- Can trigger based on location, WiFi, time, etc.
- Visual feedback via notifications

## Key Differences from macOS Version

| Feature | macOS | Android (Tasker) |
|---------|-------|------------------|
| Scheduling | LaunchD | Tasker Time Profile |
| Control | Shell script | Tasker tasks |
| Status | Command line | Notification/Widget |
| Pause/Resume | File flag | File flag (same) |
| Kill Switch | PF firewall | Android built-in |
| Logs | Text file | Text file (same) |

## Cost Breakdown

- OpenVPN for Android: **FREE**
- Tasker: **$3.49** (one-time)
- ProtonVPN subscription: **(your existing cost)**

**Total additional cost: $3.49**

## Alternative Free Option

If you don't want to buy Tasker, you can use:

- **MacroDroid** (FREE with limitations)
  - 5 macros max on free version
  - Similar functionality to Tasker
  - Download: https://play.google.com/store/apps/details?id=com.arlosoft.macrodroid

## Support Resources

- Full setup guide: `ANDROID_TASKER_SETUP.md`
- OpenVPN docs: https://ics-openvpn.blinkt.de/
- Tasker wiki: https://tasker.joaoapps.com/
- Reddit: r/tasker for help
