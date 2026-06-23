# Architecture

## Project structure

```
Anvil Workout/
├── Iron_WorkoutApp.swift              # App entry, SwiftData container, Sentry init, onboarding gate
├── ContentView.swift                  # Tab bar (Home, Workouts, History, Exercises, Stats, Settings)
├── Info.plist                         # Merges with auto-generated plist, SENTRY_DSN
├── Anvil Workout.entitlements          # HealthKit + App Group
├── PrivacyInfo.xcprivacy              # Privacy manifest
├── Config/
│   ├── DeveloperSettings.xcconfig     # Base config (includes Secrets.xcconfig)
│   └── Secrets.xcconfig               # Sentry credentials (gitignored)
│
├── Features/
│   ├── Dashboard/
│   │   ├── DashboardView.swift        # Weekly metrics grid, planner, recommendations
│   │   ├── DashboardSubviews.swift    # DashboardCard, WeeklyPlanRow
│   │   └── WeeklyPlanEditorSheet.swift# Edit weekly plan (day -> template mapping)
│   │
│   ├── Workouts/
│   │   ├── WorkoutsView.swift         # Program list with search and tag filtering
│   │   ├── TemplateDetailView.swift   # Template detail, start workout
│   │   ├── CreateEditTemplateView.swift # Edit program incl. tags
│   │   ├── ExercisePickerView.swift   # Pick exercise from library
│   │   ├── EditTemplateExerciseSheet.swift
│   │   ├── ActiveWorkoutView.swift    # Active workout: timer, sets, rest, pause, Live Activity, plate calc
│   │   ├── ActiveWorkoutSubviews.swift# WorkoutTimerBar, PauseOverlay, RestBar, SetRow
│   │   ├── PlateCalculatorSheet.swift # Per-side plate breakdown for a target weight
│   │   ├── WorkoutCompletionView.swift# Summary with PR detection, share, review prompt
│   │   ├── EditPerformedSetSheet.swift
│   │   ├── ProgramLibraryView.swift   # Browse pre-built programs grouped by level
│   │   └── ProgramLibraryDetailView.swift # Preview + "Add to My Programs"
│   │
│   ├── History/
│   │   ├── HistoryView.swift          # Searchable list of completed workouts
│   │   └── SessionDetailView.swift    # Detail: exercises, set-by-set, Health data
│   │
│   ├── Exercises/
│   │   ├── ExercisesView.swift        # Exercise library with search
│   │   ├── ExerciseDetailView.swift   # Per-exercise history, PRs, 1RM chart
│   │   └── CreateExerciseSheet.swift  # Add custom exercise
│   │
│   ├── Stats/
│   │   ├── StatsView.swift            # Stats coordinator with computed data
│   │   └── StatsChartViews.swift      # Volume, frequency, 1RM, muscle group charts
│   │
│   ├── Health/
│   │   └── HealthKitService.swift     # HealthKit: auth, workout start/end, metrics query
│   │
│   ├── Onboarding/
│   │   └── OnboardingView.swift       # 3-page onboarding with Next/Skip/Get Started
│   │
│   └── Settings/
│       └── SettingsView.swift         # Units, CSV export/import (Strong/Hevy), Health, About
│
└── Shared/
    ├── Models/                        # SwiftData models + static reference data
    │   ├── Exercise.swift
    │   ├── WorkoutTemplate.swift
    │   ├── WorkoutTemplateExercise.swift
    │   ├── WorkoutSession.swift
    │   ├── WorkoutSessionExercise.swift  # exerciseID + exerciseName snapshot
    │   ├── PerformedSet.swift
    │   ├── ProgramLibraryEntry.swift     # Static program library data types (not @Model)
    │   └── LiveActivityAttributes.swift  # Shared with widget (needs Target Membership on both)
    │
    ├── Services/
    │   ├── ExerciseLibraryService.swift   # Seed exercise library on first launch
    │   ├── ProgramLibraryService.swift    # Pre-built programs + import to WorkoutTemplate
    │   ├── ProgramShareService.swift      # Encode/decode a template as a universal-link URL
    │   ├── WorkoutSessionService.swift    # Create/finalize session from template
    │   ├── PersonalRecordService.swift    # Detect PRs (pure, testable)
    │   ├── StreakCalculator.swift         # Calculate workout streak (pure, testable)
    │   ├── PlateCalculator.swift          # Barbell plate loading math (pure, testable)
    │   ├── WeightFormatter.swift          # kg/lb display + input conversion (storage is always kg)
    │   ├── WorkoutCSVImporter.swift       # Parse Strong/Hevy CSV exports (pure, testable)
    │   ├── WorkoutCSVImportService.swift  # Persist parsed CSV sessions to SwiftData
    │   ├── WatchConnectivityService.swift # iPhone-side WCSession: broadcast snapshots, receive actions
    │   ├── WatchStatsBroadcaster.swift    # Build WatchStatsSnapshot from SwiftData for the watch widget
    │   ├── LiveActivityService.swift      # Start/update/end Live Activity
    │   ├── DataMigrationService.swift     # Runtime data migrations (tracked via UserDefaults flags)
    │   ├── PersistenceLogger.swift        # Structured logging for SwiftData save/fetch failures
    │   └── SentryConfig.swift             # Reads DSN from Info.plist
    │
    ├── Watch/
    │   └── WatchContracts.swift           # Codable snapshot/action contracts (mirrored to watch targets)
    │
    └── Components/
        ├── DesignSystem.swift             # Design token helpers
        └── TagComponents.swift            # FlowLayout + tag chips for template tags

IronWorkoutWidget/
├── IronWorkoutWidgetBundle.swift          # Widget bundle (streak widget + Live Activity)
├── IronWorkoutWidget.swift                # Streak widget (small + medium) with SwiftData
├── IronWorkoutWidgetLiveActivity.swift    # Live Activity UI (Lock Screen + Dynamic Island)
├── IronWorkoutWidgetControl.swift         # Control center widget stub
├── AppIntent.swift                        # Widget configuration intent
├── Info.plist
└── IronWorkoutWidgetExtension.entitlements # App Group for shared data

Anvil Watch Watch App/                       # watchOS companion app
├── AnvilWatchApp.swift                      # Watch app entry
├── WatchRootView.swift                      # Routes between idle and active-workout states
├── WatchActiveWorkoutView.swift             # Active workout: current set, Done/Skip, rest timer
├── WatchIdleView.swift                      # Standby state when no workout is active
├── WatchConnectivityClient.swift            # Watch-side WCSession: receive snapshots, send actions
└── WatchContracts.swift                     # Mirror of Shared/Watch/WatchContracts.swift

Anvil Watch Widget/                          # watchOS widget / Smart Stack tile
├── Anvil_Watch_WidgetBundle.swift           # Watch widget bundle
├── AnvilWatchWidget.swift                   # Streak/stats tile backed by WatchStatsSnapshot
└── WatchContracts.swift                     # Mirror of Shared/Watch/WatchContracts.swift
```

## Architecture principles

- **Feature-based folder structure** — screens grouped by feature, not by type.
- **No ViewModel layer** — logic lives in services or directly in views where simple enough. SwiftData's `@Query` and `@Bindable` replace much of what a ViewModel normally does.
- **Single source of truth** — all domain models in `Shared/Models/`, used by both UI and services.
- **Services for side effects** — `WorkoutSessionService`, `ExerciseLibraryService`, `ProgramLibraryService`, `HealthKitService`, and `LiveActivityService` handle business logic without being bound to UI.
- **Pure services for pure logic** — `PersonalRecordService`, `StreakCalculator`, `PlateCalculator`, and `WorkoutCSVImporter` are side-effect-free and covered by unit tests in `Anvil WorkoutTests`.
- **View splitting for compilation** — heavy views are split into subview files (e.g. `ActiveWorkoutSubviews.swift`, `StatsChartViews.swift`, `DashboardSubviews.swift`) to avoid Swift type-checker bottlenecks.

---

## Data migrations

### When to use which approach

**`DataMigrationService` (lightweight, runtime)**

Use for backfills and data transformations that don't change the schema shape. Each migration is a pure Swift function guarded by a UserDefaults flag, runs on app launch via `runMigrationsIfNeeded`.

Good fits:
- Populate a new optional field with derived/inferred values (e.g. backfill `exerciseID` by matching `exerciseName` to the library)
- Normalize existing data (e.g. trim whitespace, fix casing)
- Clean up orphaned records

Example: `backfillExerciseIDsIfNeeded` (added in v1.1) populates `WorkoutSessionExercise.exerciseID` for sessions created in v1.0.x.

**SwiftData `VersionedSchema` + `MigrationPlan` (heavyweight)**

Use when the schema shape changes. Required for:
- Renaming a property
- Changing a property type (e.g. `String` → `UUID`)
- Splitting one model into two
- Removing a property (after a deprecation window)

This approach requires declaring each schema version as a `VersionedSchema` enum, a `SchemaMigrationPlan` with `MigrationStage` entries (lightweight or custom), and wiring the plan into `ModelContainer` at init time. More boilerplate, but SwiftData handles the transaction safely.

### Rules of thumb

- **Prefer lightweight migrations** when possible — they're easier to reason about and debug, and don't risk container init failure.
- **Always keep a snapshot field** when migrating identity-style references (e.g. `exerciseName` was kept alongside `exerciseID` so history still reads correctly if the source entity is renamed or deleted).
- **Make migrations idempotent** — safe to run twice if the UserDefaults flag somehow gets cleared.
- **Capture errors to Sentry** but do not crash the app — surface the migration on next launch if it fails.

---

## Data model (SwiftData)

### Models

| Model | Purpose |
|-------|---------|
| **Exercise** | One exercise in the library (name, muscle group, equipment, `isBuiltin`) |
| **WorkoutTemplate** | A program (name, note, favorite, tags, list of exercises) |
| **WorkoutTemplateExercise** | One exercise in a template incl. targets (sets, reps, weight, rest, note, supersetID) |
| **WorkoutSession** | A completed workout (template name, start/end, duration, kcal, heart rate) |
| **WorkoutSessionExercise** | One exercise in a session (name, sort order, rest, note, supersetID) |
| **PerformedSet** | One set (target/actual reps and weight, completed/skipped, timestamp, set type) |

### Relationships

```
WorkoutTemplate
  └── [WorkoutTemplateExercise]    (cascade delete)

WorkoutSession
  └── [WorkoutSessionExercise]     (cascade delete)
       └── [PerformedSet]          (cascade delete)

Exercise (standalone — referenced via exerciseID, not deleted with template)
```

### Set types

`PerformedSet.setType` uses a `SetType` enum with raw values stored in SwiftData via `setTypeRaw`. The raw values are in Danish for backwards compatibility with existing data:

| Case | Raw value | Meaning |
|------|-----------|---------|
| `.working` | `"Arbejdssæt"` | Working set |
| `.warmup` | `"Opvarmning"` | Warm-up set |
| `.drop` | `"Dropsæt"` | Drop set |
| `.failure` | `"Failure"` | Failure set |

**Do not change these raw values** — they are persisted storage keys.

### Seeding

The exercise library is seeded in `ExerciseLibraryService.seedIfNeeded(modelContext:)` at app start. It only seeds if no built-in exercises exist (`isBuiltin == true`).

### App Group and shared data

The app and widget extension share data via App Group `group.com.iamjarl.Iron-Workout`. The `ModelContainer` in `Iron_WorkoutApp.swift` is configured with `.groupContainer(.identifier("group.com.iamjarl.Iron-Workout"))` so both targets access the same SwiftData store.

---

## Apple Watch companion

The phone is the source of truth. During a workout it broadcasts a lean `ActiveWorkoutSnapshot` to the watch (`WatchConnectivityService` → `WatchConnectivityClient`); the watch sends `WatchAction` values back (mark set done/skip, pause, rest). Between workouts, `WatchStatsBroadcaster` pushes a `WatchStatsSnapshot` that backs the watch widget / Smart Stack tile without the watch querying SwiftData itself.

These Codable contracts live in `Shared/Watch/WatchContracts.swift` and are **mirrored** into both watch targets (`Anvil Watch Watch App/` and `Anvil Watch Widget/`) because Xcode's synchronized file groups don't share a single file across top-level targets. Any change must be applied to all three copies, or encoding/decoding breaks silently. `WatchContractsTests` pins the wire format to catch phone-side drift.

---

## User flow

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐
│ Create/pick  │────>│ Start workout│────>│  Active workout   │
│ template     │     │ from template│     │  (timer, sets,    │
│              │     │              │     │   rest, pause)    │
└─────────────┘     └──────────────┘     └────────┬─────────┘
                                                   │
                                          ┌────────v─────────┐
                                          │  End workout      │
                                          │  (save + Health)  │
                                          └────────┬─────────┘
                                                   │
                                          ┌────────v─────────┐
                                          │  Completion       │
                                          │  (PRs, share,     │
                                          │   review prompt)  │
                                          └────────┬─────────┘
                                                   │
                                          ┌────────v─────────┐
                                          │  History / Stats  │
                                          └──────────────────┘
```

1. **Home tab:** Dashboard with weekly metrics, streak, weekly planner, quick-start.
2. **Workouts tab:** Create/edit/delete/duplicate/favorite templates, organize with tags and filter by them. Add exercises with sets/reps/weight/rest/supersets.
3. **Active workout:** Timer, HealthKit workout, Live Activity on Lock Screen, mark sets done/skip, per-exercise notes, rest timer, pause/resume, plate calculator.
4. **Completion:** Session saved (duration, sets, kcal/heart rate from Health). PR detection for weight and reps. Share workout summary. App Store review prompt at 5th, 15th, and 50th workout.
5. **History tab:** Searchable list of sessions; detail view with set-by-set data and Health metrics.
6. **Exercises tab:** Searchable library; per-exercise detail with history, PRs, and estimated 1RM.
7. **Stats tab:** Volume over time, weekly frequency, estimated 1RM progression, muscle group distribution.
8. **Settings tab:** Weight unit (kg/lbs), CSV export, CSV import from Strong/Hevy, Health permissions, about.

---

## Dependencies (SPM)

| Package | Version | Purpose |
|---------|---------|--------|
| [sentry-cocoa](https://github.com/getsentry/sentry-cocoa) | 9.7.0 | Crash reporting and performance |
| [iamjarl-design](https://github.com/JarlLyng/iamjarl-design) | branch: main | Design tokens (colors, spacing, typography) |
| [phosphor-swift](https://github.com/phosphor-icons/swift) | 2.1.0 | Icon library |
