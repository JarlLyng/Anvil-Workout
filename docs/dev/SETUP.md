# Setup

## Requirements

- **Xcode 16+** with Swift 5
- macOS with Xcode Command Line Tools
- Deployment target: iOS 17.0+

## Run the app

1. Clone the repo and open `Iron Workout.xcodeproj` in Xcode.
2. Select scheme **Iron Workout** and a simulator (e.g. iPhone 16) or a physical device.
3. Run (Cmd+R).

The app runs immediately. SPM packages resolve automatically on first open.

---

## Widget Extension

The project includes a WidgetKit extension (`IronWorkoutWidgetExtension`) providing:
- **Streak widget** (small + medium) — shows workout streak and weekly stats
- **Live Activity** — Lock Screen and Dynamic Island during active workouts

### Shared file: LiveActivityAttributes.swift

`Iron Workout/Shared/Models/LiveActivityAttributes.swift` defines `IronWorkoutWidgetAttributes` used by both the main app and the widget extension. This file **must have Target Membership** on both:
- Iron Workout (main app)
- IronWorkoutWidgetExtension

To verify: select the file in Xcode -> File Inspector (right panel) -> Target Membership -> check both targets.

### Build number matching

The widget extension's `CURRENT_PROJECT_VERSION` (CFBundleVersion) **must match** the main app's. When bumping the build number, update it in all targets. In `project.pbxproj`, search for `CURRENT_PROJECT_VERSION` and ensure all occurrences have the same value.

---

## App Groups

Both the main app and widget extension use App Group `group.com.iamjarl.Iron-Workout` to share the SwiftData store. This is configured in:
- `Iron Workout.entitlements`
- `IronWorkoutWidgetExtension.entitlements`

Both files should contain:

```xml
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.iamjarl.Iron-Workout</string>
</array>
```

The `ModelContainer` in `Iron_WorkoutApp.swift` uses `.groupContainer(.identifier("group.com.iamjarl.Iron-Workout"))` to store data in the shared container.

---

## Sentry (crash and performance monitoring)

The app uses [Sentry](https://sentry.io) (sentry-cocoa) for crash reporting and performance monitoring.

### Configuration

Sentry DSN is **not hardcoded**. It's read from a `.xcconfig` file via build settings and Info.plist:

1. Copy the example file:
   ```bash
   cp "Iron Workout/Config/Secrets.xcconfig.example" "Iron Workout/Config/Secrets.xcconfig"
   ```
2. Open `Iron Workout/Config/Secrets.xcconfig` and insert your DSN:
   ```
   SENTRY_DSN = https://<your-key>@<host>.ingest.sentry.io/<project-id>
   ```
3. The file is **gitignored** — never committed.

### How it works

```
DeveloperSettings.xcconfig -> (#include? Secrets.xcconfig) -> Build Settings -> Info.plist -> SentryConfig.swift
```

- Target **Iron Workout** uses `Iron Workout/Config/DeveloperSettings.xcconfig` as base configuration. It optionally includes `Secrets.xcconfig` (same folder), which is gitignored.
- `Info.plist` contains `$(SENTRY_DSN)` which Xcode expands from build settings.
- `SentryConfig.swift` reads DSN from `Bundle.main.infoDictionary`.
- If DSN is empty or missing, Sentry is not started — the app runs normally.

### dSYM upload to Sentry (optional, recommended for production)

On **Archive** builds, a Run Script phase executes `Scripts/sentry-upload-dsyms.sh` which uploads debug symbols using [sentry-cli](https://docs.sentry.io/cli/installation/).

1. Install CLI: `brew install sentry-cli`
2. In Sentry: **Settings -> Auth Tokens** — create a token with appropriate permissions.
3. In `Secrets.xcconfig`, add:
   - `SENTRY_AUTH_TOKEN = ...`
   - `SENTRY_ORG = your-org-slug`
   - `SENTRY_PROJECT = iron-workout-ios`

The script phase is configured with `runOnlyForDeploymentPostprocessing = 1` so it only runs on Archive (not debug builds). It is ordered **after** the "Embed Foundation Extensions" phase to avoid build cycles with the widget extension.

If the token or CLI is missing, the script skips the upload with a note in the build log — the build does not fail.

### "Upload Symbols Failed" warning

When uploading an archive, Xcode may show a warning about missing dSYMs for the pre-built `Sentry.framework` (SPM binary). This is harmless — Sentry has its own debug symbols for SDK code. Your app code symbols are uploaded separately.

---

## HealthKit

HealthKit is used to save workouts and retrieve calories/heart rate from Apple Watch or other sources.

### Requirements

- **Physical device required** — simulators do not support Health data.
- Entitlement `com.apple.developer.healthkit` is set in `Iron Workout.entitlements`.
- Info.plist keys for Health (read/write) are set in the project's build settings.

### Permissions

The user grants Health access from **Settings -> Health** in the app. The app requests:

- Write: Workouts
- Read: Active Energy Burned, Heart Rate

### Without HealthKit

If the user does not grant permission, the app works fully — it just doesn't save Health data, and kcal/heart rate are not shown in history.

---

## Encryption compliance

`ITSAppUsesNonExemptEncryption` is set to `NO` in build settings. The app does not use encryption beyond HTTPS (standard network calls to Sentry).

---

## Privacy manifest

`PrivacyInfo.xcprivacy` is included in the main app target. Update it if new data collection or tracking is added.
