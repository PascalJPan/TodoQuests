# TodoQuests Installation Guide

## Download

Download the latest APK from the [Releases](../../releases) page.

## Installation Instructions

### Android

1. **Enable Unknown Sources**
   - Go to Settings > Security (or Privacy)
   - Enable "Install from Unknown Sources" or "Allow from this source" for your browser/file manager
   - On Android 8.0+, you'll be prompted per-app when installing

2. **Install the APK**
   - Download `app-release.apk` from the releases page
   - Open the downloaded file
   - Tap "Install" when prompted
   - If you see "App not installed" or "There was a problem parsing the package":
     - Make sure you've enabled "Unknown Sources"
     - If you have an older version installed, uninstall it first
     - Try downloading the APK again (it may be corrupted)

3. **Configure the App**
   - Open TodoQuests
   - Tap the settings icon (⚙️) in the top right
   - Enter your Todoist API token:
     - Go to [Todoist Settings > Integrations](https://app.todoist.com/app/settings/integrations)
     - Scroll to "API token" and copy it
     - Paste it into TodoQuests settings
   - Configure XP keywords (default: "xp", "XP", "Xp", "xP")
   - Set your start date if you want to count XP from a specific date
   - Tap "Save"

4. **Add the Widget** (Optional but recommended!)
   - Long-press on your home screen
   - Tap "Widgets"
   - Find "TodoQuests" or "LifeQuests Widget"
   - Drag it to your home screen
   - **Tap the widget to refresh XP without opening the app!**

## Using TodoQuests

### Earning XP

Add XP values to your Todoist tasks:
- `Complete workout +100xp`
- `Read chapter 50 XP`
- `Study for exam +75xp`

When you complete these tasks in Todoist, TodoQuests will:
1. Detect the XP value
2. Add it to your total XP
3. Level you up when you reach the threshold
4. Update the widget automatically

### Refreshing XP

- **From the app:** Pull down to refresh
- **From the widget:** Tap the widget (doesn't open the app!)
- **Manual refresh:** Tap the "Refresh XP" button in the app

### Viewing Progress

- **Main screen:** Shows current level, XP progress bar, and most recent XP gain
- **Logs page:** Tap the list icon (📋) to see your last 10 XP-earning tasks
- **Widget:** Shows level, XP progress, and most recent task

## Troubleshooting

### Widget not updating
1. Make sure you've granted all permissions to the app
2. Check that battery optimization is disabled for TodoQuests
3. Tap the widget to manually refresh
4. Remove and re-add the widget

### "No API key configured"
1. Go to Settings (⚙️)
2. Enter your Todoist API token
3. Tap "Save"

### XP not calculating correctly
1. Check your XP keywords in Settings
2. Make sure your tasks include one of these keywords
3. Verify the format: `+100xp` or `50 XP` (case-insensitive)
4. Check the Logs page to see which tasks are being counted

### App crashes or errors
1. Clear app data: Settings > Apps > TodoQuests > Clear Data
2. Reinstall the app
3. Check your internet connection for Todoist API access

## Requirements

- **Android 5.0** (API 21) or higher
- **Internet connection** for syncing with Todoist
- **Todoist account** with API access

## Privacy & Permissions

TodoQuests requires:
- **Internet:** To fetch completed tasks from Todoist API
- **Storage:** To cache task data locally
- **Network State:** To check connectivity before API calls

**No data is collected or sent anywhere except to Todoist's official API.**

## Support

For issues, feature requests, or questions, please [open an issue](../../issues) on GitHub.
