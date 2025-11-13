# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**LifeQuests** is a Flutter-based gamification app that integrates with Todoist to track completed tasks and award XP (experience points). Users level up based on XP earned from completed tasks, with configurable milestone levels that display special visual effects.

The project consists of:
- **Flutter app** (`life_quests/`) - Mobile application for iOS/Android
- **Level framework** (`level_framework.ipynb`) - Python notebook that generates XP progression tables

## Development Commands

### Flutter App

Navigate to the `life_quests/` directory for all Flutter commands:

```bash
cd life_quests
```

**Run the app:**
```bash
flutter run
```

**Build for specific platform:**
```bash
flutter build ios
flutter build android
flutter build macos
```

**Build distributable release APK:**
```bash
flutter build apk --release
```
The signed APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

**Get dependencies:**
```bash
flutter pub get
```

**Analyze code:**
```bash
flutter analyze
```

**Run tests:**
```bash
flutter test
```

**Clean build artifacts:**
```bash
flutter clean
```

### Level Framework (Python)

The `level_framework.ipynb` notebook generates XP progression data. It uses pandas and numpy to calculate:
- XP required for each level (with 2% growth rate per level)
- Cumulative total XP needed
- 10th level milestones with 1.5x XP multipliers

Output: `data/level_framework_df.csv`

## Architecture

### Core Services

**XP Service** (`lib/xp_service.dart`)
- Central service managing all XP calculations and Todoist API integration
- Implements debouncing (2-second cooldown) to prevent duplicate refresh calls
- Retry logic for API requests (3 attempts with exponential backoff)
- Fetches up to 200 completed tasks from Todoist API
- Parses task content for XP keywords (configurable, defaults: "xp", "XP", "Xp", "xP")
- Calculates total XP using regex pattern matching
- Computes level progression using formula: `baseXP * level + multiplier * level^exponent`
- Maintains rolling log of last 10 XP-earning tasks
- Updates home widget with current stats

**Widget Service** (`lib/lifequest_widget.dart`)
- Manages home screen widget updates for iOS and Android
- Uses `home_widget` package for cross-platform widget support
- Syncs XP data to widget storage using app groups
- Supports widget tap actions to trigger background XP refresh

**Milestone Helper** (`lib/milestone_helper.dart`)
- Determines if current level is a milestone level
- Provides color schemes for milestone celebrations:
  - Levels 5-9: Orange/Red/Gold
  - Levels 10-24: Green/Yellow/Orange
  - Levels 25-49: Blue/Cyan/Green
  - Levels 50-99: Purple/Blue/Cyan
  - Levels 100+: Gold/Purple/Red
- Configurable milestone levels via settings (default: 5,10,25,50,100)

### UI Components

**Main Page** (`lib/main.dart`)
- Displays current level, XP progress bar, and most recent XP gain
- Pull-to-refresh gesture triggers XP sync
- Registers background callback for widget interactions (doesn't open app)
- Special milestone UI with gradient backgrounds for milestone levels

**Settings Page** (`lib/settings_page.dart`)
- Todoist API key configuration
- XP formula parameters (baseXP, multiplier, exponent)
- XP keyword customization (comma-separated list)
- Milestone level configuration
- Start date filter for XP counting
- Triggers full XP refresh on save

**Logs Page** (`lib/logs_page.dart`)
- Displays last 10 XP-earning tasks
- Shows task name, XP value, and total accumulated XP
- Auto-refreshes when app returns to foreground
- Handles both new JSON format and legacy pipe-delimited format for backward compatibility

### Data Storage

Uses `shared_preferences` for persistent storage:
- `apiKey` - Todoist API bearer token
- `level` - Current player level
- `xpInLevel` - XP progress within current level
- `xpNeeded` - Total XP required for next level
- `totalXP` - Lifetime XP earned
- `recent` - JSON array of last 10 XP-earning tasks
- `recentLast` - Formatted string of most recent XP gain
- `xpKeywords` - Comma-separated keyword list
- `milestoneLevels` - Comma-separated milestone level list
- `startDate` - ISO 8601 timestamp for filtering tasks
- `baseXP`, `levelMultiplier`, `levelExponent` - Formula parameters
- `lastSync` - ISO 8601 timestamp of last Todoist sync

### Widget Background Refresh

The app uses `home_widget` package's background callback system for widget interactions:
- **Widget taps trigger background refresh** without opening the app
- Uses `HomeWidget.registerInteractivityCallback()` in main.dart
- Android: Widget sends broadcast intent to `HomeWidgetBackgroundReceiver`
- Background isolate executes refresh via `backgroundCallback()` function
- WorkManager ensures reliable execution even when app is closed
- Shared data storage via app group: `group.com.example.life_quests`

**Important**: Widget clicks run entirely in the background. The app never opens during refresh.

#### Critical Requirements for Background Callback

The `backgroundCallback()` function in `lib/main.dart` **MUST** include these initializations:

```dart
@pragma('vm:entry-point')
Future<void> backgroundCallback(Uri? uri) async {
  // REQUIRED: Initialize Flutter bindings for background isolate
  WidgetsFlutterBinding.ensureInitialized();

  // REQUIRED: Set app group ID for widget communication
  await HomeWidget.setAppGroupId('group.com.example.life_quests');

  // ... rest of callback logic
}
```

**Why this is critical:**
- `WidgetsFlutterBinding.ensureInitialized()` - Without this, `SharedPreferences` will fail silently in the background isolate, causing widget data not to update
- `HomeWidget.setAppGroupId()` - Required for the widget to read/write shared data between the app and widget on Android/iOS
- The `@pragma('vm:entry-point')` annotation prevents tree-shaking from removing the callback in release builds

**Common symptoms if these are missing:**
- Widget click triggers refresh (logs show `WIDGET_CLICK`)
- XP calculation completes (logs show `XP_REFRESH_COMPLETE`)
- Widget display does NOT update with new values
- No errors are thrown (fails silently)

## Key Implementation Details

### XP Calculation Formula

```dart
xpForLevel = baseXP * level + multiplier * pow(level, exponent)
```

Default values:
- `baseXP`: 990
- `multiplier`: 10
- `exponent`: 2.25

### Task XP Parsing

Tasks are parsed using regex pattern:
```
([+-]?\s*\d+)\s*(?:xp|XP|Xp|xP)\b
```

Examples of valid formats:
- `+100xp Complete workout`
- `50 XP Read book`
- `-25xp Penalty task`

### Error Handling

- Network failures retry with exponential backoff
- Invalid API keys return specific error messages
- Rate limiting (429) respects `retry-after` header
- Negative level calculations default to level 0
- Failed widget updates don't break the refresh flow
- Malformed JSON in logs falls back to legacy format

## Platform Support

**Primary Platform: Android**
- Full widget support with true background refresh (no app opening)
- Uses `home_widget` package v0.8.1+ with WorkManager for reliability

**Note**: iOS/macOS/Linux/Windows/Web platforms exist in the project structure but are not actively developed or tested.

## Dependencies

Key packages:
- `flutter` (SDK ^3.9.2)
- `http` (^1.2.2) - Todoist API requests
- `shared_preferences` (^2.3.2) - Local data persistence
- `home_widget` (^0.8.1) - Cross-platform widget support
- `flutter_local_notifications` (^19.5.0) - Notification support (upgraded from 17.2.2)
- `cupertino_icons` (^1.0.8) - iOS-style icons

Dev dependencies:
- `flutter_test` - Testing framework
- `flutter_lints` (^6.0.0) - Code analysis rules (upgraded from 5.0.0)

### Dependency Compatibility Notes

**Android Build Configuration** (`android/app/build.gradle.kts`):
- `desugar_jdk_libs` must be version `2.1.4` or higher (required by `flutter_local_notifications` 19.5.0+)
- Lower versions (e.g., 2.0.4) will cause build failures with AAR metadata errors

**Common Dependency Issues:**
1. **Missing imports in release builds** - If you see errors about `BasicMessageChannel`, `PlatformException`, or `BinaryMessenger` not being defined:
   - Run `flutter clean`
   - Run `flutter pub upgrade --major-versions` to update packages
   - Check that `desugar_jdk_libs` is at the correct version in `build.gradle.kts`

2. **ProGuard/R8 tree-shaking** - Release builds require proper ProGuard rules (`android/app/proguard-rules.pro`):
   ```proguard
   # Keep home_widget plugin classes
   -keep class es.antonborri.home_widget.** { *; }
   -keep class androidx.work.** { *; }

   # Keep widget provider and background receiver
   -keep class * extends android.appwidget.AppWidgetProvider { *; }
   -keep class * extends android.content.BroadcastReceiver { *; }
   -keep class com.example.life_quests.LifeQuestWidgetProvider { *; }
   ```

**Debugging Widget Issues:**
- Use `adb logcat | grep -E "flutter|LifeQuestWidget"` to monitor logs
- Look for `WIDGET_CLICK`, `XP_REFRESH_COMPLETE`, and `WIDGET_UPDATE_RESULT` messages
- Check that `ACTION_APPWIDGET_UPDATE` is received after refresh completes
- Verify widget data shows updated values in logs: `📊 Widget data: Level=X, XP=Y/Z`

## APK Signing and Distribution

### Release Signing Configuration

The app uses a custom signing key for release builds to ensure APKs can be distributed and installed on any device.

**Signing files (NOT in git):**
- `android/key.properties` - Contains keystore credentials
- `android/todoquest-release-key.jks` - The signing keystore file

**Signing configuration** (`android/app/build.gradle.kts`):
- Automatically loads signing config from `android/key.properties`
- Falls back to debug signing if `key.properties` doesn't exist
- Signing key details:
  - Alias: `todoquest`
  - Validity: 10,000 days
  - Algorithm: RSA 2048-bit

### Building for Distribution

**To create a distributable APK:**
```bash
flutter build apk --release
```

The signed APK will be at: `build/app/outputs/flutter-apk/app-release.apk`

**Common APK Issues:**

1. **"Problem parsing package" error** - Usually means:
   - APK is debug-signed and device doesn't trust debug certificate
   - Trying to install over an existing app with different signature
   - Solution: Uninstall existing app first, or use properly signed release APK

2. **Missing signing key** - If building on a new machine:
   - The `android/key.properties` and `android/todoquest-release-key.jks` files are gitignored for security
   - Need to either copy these files from the original dev machine OR generate new ones
   - Warning: New signing key means users must uninstall old version before installing new one

3. **Signature verification fails** - Check that:
   - `android/key.properties` exists and has correct paths
   - Keystore file path in `key.properties` is correct (should be `../todoquest-release-key.jks`)
   - Keystore passwords match

### Regenerating Signing Key (if lost)

If the signing key is lost, generate a new one:
```bash
cd android
keytool -genkey -v -keystore todoquest-release-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias todoquest \
  -storepass todoquest123 -keypass todoquest123 \
  -dname "CN=LifeQuests, OU=Dev, O=LifeQuests, L=Unknown, S=Unknown, C=US"
```

**Important:** Users will need to uninstall the old app before installing with the new signature.
