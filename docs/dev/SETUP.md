# Setup

## Requirements

- **Xcode 27.1** or later, with the Swift 5 language mode. Releases are built with it on Xcode Cloud, and its iOS 27.1 SDK is what gives the app the whole inner display on iPhone Duo. Older versions of Xcode aren't tested.
- macOS with Xcode Command Line Tools
- Deployment target: iOS 17.0+

## Run the app

1. Clone the repo and open `Iron Workout.xcodeproj` in Xcode. The project, scheme, targets and folders still carry the app's former name, Iron Workout (#83).
2. Select scheme **Iron Workout** and a simulator (e.g. iPhone 17) or a physical device.
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
- `Iron Workout/Iron Workout.entitlements`
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

## Sentry (anonymous diagnostics)

The app uses [Sentry](https://sentry.io) (sentry-cocoa) for anonymous diagnostics: crash, hang and error reports, MetricKit diagnostics, crash-free sessions and three feature counts. `Iron Workout/Shared/Services/DiagnosticsService.swift` defines all of it, and the switch in Settings (Send Anonymous Diagnostics) turns all of it off straight away.

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
- Sentry is not started when the app runs as the unit tests' host, so test runs send nothing.

### What is sent, and why it is anonymous

Anonymous is a recipe, not Sentry's default. Out of the box sentry-cocoa sends a random installation ID as the user, as every session's `did` and on every metric, and a hash of the vendor ID (`contexts.app.device_app_hash`) on every event (#129). `DiagnosticsService` therefore:

1. puts one shared user, `anonymous`, on the initial scope, and sets it again in `beforeSend`, which in sentry-cocoa 9 sees every error, crash report, MetricKit diagnostic and trace;
2. drops `contexts.app.device_app_hash` and `contexts.device.id` in `beforeSend`;
3. keeps only the SDK's coarse facts (release, environment, OS, device model) and the app's own `source` attribute in `beforeSendMetric`, so a count never carries `user.id`;
4. writes `anonymous` into the SDK's `INSTALLATION` file in Caches before the SDK starts, because a session's `did` always comes from that file, whatever user is set;
5. keeps `sendDefaultPii` off, and in release builds has no screenshots, no view hierarchy and no performance tracing (`tracesSampleRate` 0);
6. reports the environment as `development` for Debug and simulator builds, `testflight` for TestFlight (a sandbox receipt) and `production` only for App Store builds.

The counts, all with `value` 1:

| Count | Attribute | When |
|-------|-----------|------|
| `workout.finished` | none | a workout is saved, from End or from the prompt for a workout left running |
| `set.completed` | `source`: `phone` or `watch` | a set is marked done |
| `import.finished` | `source`: `strong` or `hevy` | an import from Strong or Hevy is saved |

Nothing from the user's data goes out: no program or exercise names, weights, reps, notes or record IDs, in a count, an event or a breadcrumb. `PersistenceLogger` sends a failing file's name, never its path, which holds the app container's per-install UUID.

`Iron Workout/PrivacyInfo.xcprivacy` declares Crash Data, Performance Data and Other Diagnostic Data (purpose App Functionality) and Product Interaction (purpose Analytics), all not linked to the user and not used for tracking. The App Store label for the release that ships this reads Data Not Linked to You: Diagnostics (Crash Data, Performance Data, Other Diagnostic Data) and Usage Data (Product Interaction).

The Sentry organisation also removes `user.id`, `contexts.device.id` and `contexts.app.device_app_hash` before storage and stores no IP addresses. That is set up in Sentry, as the safety net for crashes the app's code can't reach.

### The envelope test (after every sentry-cocoa upgrade)

Points 3 and 4 lean on SDK internals, so check the outgoing payload after each upgrade, before shipping:

1. Run a small HTTP server on `127.0.0.1` that saves each POST body, gunzipped.
2. Build Release for a simulator with `SENTRY_DSN=http://test@127.0.0.1:<port>/1` and `SENTRY_AUTH_TOKEN=` on the `xcodebuild` command line, over an install whose `Library/Caches/INSTALLATION` holds a random ID.
3. Make it crash once, then launch it again, capture a message and a count, and send it to the background so the session ends and the metrics flush. A temporary launch-argument switch in `DiagnosticsService.start()` does this; don't commit it.
4. Search every saved envelope for the old installation ID and for `device_app_hash`, and check that `user`, a metric's attributes and the session's `did` say `anonymous`.

Last run: sentry-cocoa 9.34.0, 2026-11-15, on an install whose `INSTALLATION` held a random ID. A crash report, an error, a session and the three counts all said `anonymous`; the old ID and `device_app_hash` appeared nowhere. The first run found the app's bundle path, with its per-install container UUID, in stack frames and debug images, which is why `beforeSend` now replaces that UUID with a fixed one. The second run confirmed it, with the app's frames still marked as in-app.

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
- Entitlement `com.apple.developer.healthkit` is set in `Iron Workout/Iron Workout.entitlements`.
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
