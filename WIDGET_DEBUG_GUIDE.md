# Widget Click Debugging Guide

This guide helps you diagnose why widget clicks may not be triggering XP updates.

## Quick Start: View Debug Logs in the App

1. **Open the LifeQuests app**
2. **Tap the Logs icon** (list icon) in the top-right corner
3. **Switch to the "Debug Logs" tab**
4. **Click your widget** from the home screen
5. **Return to the app** and check the Debug Logs

### What to Look For:

✅ **If widget clicks are working**, you should see these events in order:
```
WIDGET_CLICK         → Widget was clicked
REFRESH_START        → Background refresh started
API_CALL_START       → Calling Todoist API
API_CALL_RESPONSE    → Got response from API
REFRESH_SUCCESS      → XP calculation complete
```

❌ **If widget clicks aren't working**, you might see:
- **No logs at all** → Background callback not registered (app needs to be opened once after install)
- **CALLBACK_FAILED** → URI is null or malformed
- **NO_API_KEY** → API key not configured
- **XP_REFRESH_DEBOUNCED** → Clicked too quickly (wait 500ms between clicks)
- **API_CALL_RESPONSE with Status 401** → Invalid API key
- **REFRESH_ERROR** → Error during XP calculation

---

## Advanced: Real-Time Logcat Debugging

For more detailed debugging, you can view real-time Android logs using `adb logcat`.

### Prerequisites

1. **Enable USB Debugging** on your Android device:
   - Go to **Settings → About Phone**
   - Tap **Build Number** 7 times to enable Developer Options
   - Go to **Settings → Developer Options**
   - Enable **USB Debugging**

2. **Install Android Platform Tools** (includes `adb`):
   - **Mac (Homebrew)**: `brew install android-platform-tools`
   - **Windows/Linux**: Download from [developer.android.com](https://developer.android.com/tools/releases/platform-tools)

3. **Connect your device** via USB and authorize the computer when prompted

### Test ADB Connection

```bash
adb devices
```

You should see your device listed. If not, check USB debugging is enabled and cable is connected.

---

## Watching Widget Click Logs

### Option 1: Filtered Logs (Recommended)

This shows only LifeQuests-related logs:

```bash
adb logcat | grep -E "LifeQuest|flutter|🔄|✅|❌|🔍"
```

### Option 2: Flutter Logs Only

Shows all Flutter debug output:

```bash
adb logcat flutter:D *:S
```

### Option 3: Widget Provider Logs Only

Shows only Android widget-specific logs:

```bash
adb logcat LifeQuestWidgetProvider:D *:S
```

### Option 4: Full Verbose (All Logs)

```bash
adb logcat -v time
```

---

## Testing the Widget

### Step-by-Step Test Procedure

1. **Start logcat** in a terminal:
   ```bash
   adb logcat | grep -E "LifeQuest|🔄|✅|❌"
   ```

2. **Open the LifeQuests app** once (this registers the background callback)
   - Look for: `🔍 [timestamp] CALLBACK_REGISTERED | Background callback registered successfully`

3. **Exit the app** (press Home button, don't force-close)

4. **Click the widget** on your home screen

5. **Watch the terminal** for log output

### Expected Output (Successful Click)

```
🔍 [2025-11-13 10:30:15.123] WIDGET_CLICK | URI: lifequest://refresh
🔄 Widget clicked - triggering background XP refresh
🔍 [2025-11-13 10:30:15.125] REFRESH_START | Background callback triggered
🔍 [2025-11-13 10:30:15.130] XP_REFRESH_STARTED | Beginning XP calculation
🔍 [2025-11-13 10:30:15.135] API_KEY_FOUND | API key configured (abc12345...)
🔍 [2025-11-13 10:30:15.140] API_CALL_START | Todoist attempt 1/3
📡 Fetching tasks from Todoist (attempt 1/3)
🔍 [2025-11-13 10:30:15.580] API_CALL_RESPONSE | Status 200 in 440ms
✅ Fetched 47 completed tasks from Todoist
🔍 [2025-11-13 10:30:15.620] XP_REFRESH_COMPLETE | XP calculation finished
🔍 [2025-11-13 10:30:15.625] REFRESH_SUCCESS | Completed in 502ms
✅ Background refresh completed in 502ms
```

### Common Error Patterns

#### Pattern 1: No Logs at All
```
[No output after clicking widget]
```
**Diagnosis**: Background callback not registered
**Fix**: Open the app at least once, then try clicking the widget again

---

#### Pattern 2: Missing API Key
```
❌ [2025-11-13 10:30:15.135] NO_API_KEY | API key not configured
⚠️ No API key configured, skipping Todoist fetch
```
**Diagnosis**: API key not set
**Fix**: Go to Settings in the app and add your Todoist API key

---

#### Pattern 3: Invalid API Key
```
🔍 [2025-11-13 10:30:15.580] API_CALL_RESPONSE | Status 401 in 210ms
❌ Todoist API authentication failed (401) - invalid API key
```
**Diagnosis**: API key is incorrect or expired
**Fix**: Get a new API key from [Todoist Settings](https://todoist.com/app/settings/integrations/developer)

---

#### Pattern 4: Debouncing (Too Fast)
```
🔍 [2025-11-13 10:30:15.123] WIDGET_CLICK | URI: lifequest://refresh
🔍 [2025-11-13 10:30:15.125] XP_REFRESH_COOLDOWN | Cooldown 350ms remaining
⚠️ Refresh called too soon, skipping (cooldown: 0s)
```
**Diagnosis**: Clicked widget again before 500ms cooldown expired
**Fix**: Wait at least 500ms between widget clicks

---

#### Pattern 5: Network Timeout
```
🔍 [2025-11-13 10:30:15.140] API_CALL_START | Todoist attempt 1/3
📡 Fetching tasks from Todoist (attempt 1/3)
[30 seconds pass]
❌ [2025-11-13 10:30:45.150] REFRESH_ERROR | Failed after 30000ms: TimeoutException
```
**Diagnosis**: Todoist API not responding (slow network or API down)
**Fix**: Check internet connection, try again later

---

## Clearing Debug Logs

To reset all diagnostic logs:

1. Open the LifeQuests app
2. Go to Logs page
3. Tap the **trash icon** in the top-right
4. Confirm deletion

---

## Troubleshooting Checklist

If widget clicks still don't work after reviewing logs:

- [ ] **App opened at least once** after installing/updating
- [ ] **Widget added** to home screen properly
- [ ] **USB Debugging enabled** (for logcat)
- [ ] **Device connected** via USB (`adb devices` shows device)
- [ ] **API key configured** in Settings
- [ ] **Internet connection** active
- [ ] **Todoist API** not rate-limiting (Status 429)
- [ ] **Waiting 500ms** between clicks
- [ ] **Check Debug Logs tab** in the app

---

## Common Issues & Solutions

### Issue: "App never opens after install"
**Solution**: This is intentional for background refresh. The app should NOT open when you click the widget. The widget updates in the background.

### Issue: "Logs say CALLBACK_REGISTERED but widget clicks don't work"
**Possible causes**:
1. Widget was added before app was opened → Remove and re-add widget
2. ProGuard/code shrinking issue → Check release build configuration
3. WorkManager not initialized → Check AndroidManifest.xml

### Issue: "Widget updates in debug but not release builds"
**Possible causes**:
1. ProGuard rules missing → Check `proguard-rules.pro` includes home_widget classes
2. Background callback tree-shaken → Verify `@pragma('vm:entry-point')` in main.dart

---

## Getting Help

If you're still stuck after checking logs:

1. **Clear debug logs** (trash icon in Logs page)
2. **Click the widget** 2-3 times (wait 1 second between clicks)
3. **Take a screenshot** of the Debug Logs tab
4. **Copy logcat output** from terminal
5. Include both when reporting the issue

---

## Technical Details

### Log Event Types

| Event | Meaning | Location |
|-------|---------|----------|
| `APP_START` | App launched, registering callback | main.dart:50 |
| `CALLBACK_REGISTERED` | Background callback registered | main.dart:52 |
| `WIDGET_CLICK` | Widget was clicked | main.dart:16 |
| `REFRESH_START` | XP refresh beginning | main.dart:25 |
| `REFRESH_SUCCESS` | XP refresh completed | main.dart:32 |
| `REFRESH_ERROR` | XP refresh failed | main.dart:37 |
| `XP_REFRESH_STARTED` | Starting XP calculation | xp_service.dart:33 |
| `XP_REFRESH_COMPLETE` | XP calculation done | xp_service.dart:37 |
| `XP_REFRESH_DEBOUNCED` | Ignored due to in-progress refresh | xp_service.dart:18 |
| `XP_REFRESH_COOLDOWN` | Ignored due to cooldown | xp_service.dart:27 |
| `API_KEY_FOUND` | API key configured | xp_service.dart:60 |
| `NO_API_KEY` | API key missing | xp_service.dart:58 |
| `API_CALL_START` | Calling Todoist API | xp_service.dart:186 |
| `API_CALL_RESPONSE` | Got API response | xp_service.dart:195 |

### Architecture

```
User clicks widget
    ↓
Android OS broadcasts intent: lifequest://refresh
    ↓
HomeWidgetBackgroundReceiver catches intent
    ↓
home_widget plugin invokes Flutter backgroundCallback()
    ↓
backgroundCallback() calls LifeQuestService.refreshXP()
    ↓
refreshXP() fetches from Todoist & updates widget
    ↓
Widget redraws with new data (no app opening)
```

All steps are logged to both console (logcat) and persistent storage (Debug Logs in app).
