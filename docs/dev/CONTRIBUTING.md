# Development

## Code style

- Short, readable files — native SwiftUI.
- Avoid unnecessary dependencies.
- English UI text in views, English code names.
- Use design tokens from `IAMJARLDesignTokens` for colors, spacing, and backgrounds — no hardcoded values.
- Use exclusively Phosphor icons (`PhosphorSwift`) — no SF Symbols (except where required by SwiftUI API, e.g. tab bar). Use the `.icon(size:)` extension (default 20pt) for sizing; never write manual `.resizable().aspectRatio(contentMode: .fit).frame(width:height:)` chains.
- Split large views into subview files when the Swift type-checker struggles (compile times > 30s). See `ActiveWorkoutSubviews.swift`, `StatsChartViews.swift`, `DashboardSubviews.swift` for examples.

## Add a new feature

1. Create view(s) under the relevant `Features/` folder. Create a new folder if the feature doesn't fit into an existing one.
2. Shared models go in `Shared/Models/`.
3. Shared logic/services in `Shared/Services/`.
4. Register new SwiftData models in `Iron_WorkoutApp.swift` schema.
5. If the feature needs widget data, ensure the model file has Target Membership on both targets.

## Error handling in views

Use this consistent pattern:

```swift
@State private var errorMessage: String?

// In body:
.alert("Error", isPresented: Binding(
    get: { errorMessage != nil },
    set: { if !$0 { errorMessage = nil } }
)) {
    Button("OK") { errorMessage = nil }
} message: {
    Text(errorMessage ?? "")
}

// On modelContext.save():
do {
    try modelContext.save()
} catch {
    errorMessage = "Could not save: \(error.localizedDescription)"
}
```

## Toast feedback

For non-critical confirmations (duplicate, delete), use the toast pattern from `WorkoutsView.swift`:

```swift
@State private var toastMessage: String?

// Overlay in body:
.overlay(alignment: .bottom) {
    if let toastMessage {
        // Capsule with checkmark + message, auto-dismiss after 2s
    }
}

// Trigger:
private func showToast(_ message: String) {
    toastMessage = message
    Task {
        try? await Task.sleep(for: .seconds(2))
        toastMessage = nil
    }
}
```

## User preferences

Use `@AppStorage` for lightweight user preferences:

| Key | Type | Default | Purpose |
|-----|------|---------|---------|
| `hasSeenOnboarding` | Bool | false | Gate onboarding flow |
| `weightUnit` | String | "kg" | Display unit for weights |
| `weeklyPlan` | String | "{}" | JSON-encoded day-to-template mapping |

## Secrets

Secrets (e.g. Sentry DSN) are managed via `.xcconfig` files:

1. `Iron Workout/Config/DeveloperSettings.xcconfig` is committed and optionally includes `Secrets.xcconfig` (gitignored).
2. `Secrets.xcconfig.example` is the template — copy to `Secrets.xcconfig` locally.
3. Build settings -> Info.plist -> code reads DSN from `Bundle.main`.

Never commit secrets to git.

## Tests

- Unit tests: `Iron WorkoutTests/` — uses the Swift Testing framework (`import Testing`, `@Suite`, `@Test`, `#expect`, `#require`).
- UI tests: `Iron WorkoutUITests/`.
- Run with Cmd+U in Xcode, or unit tests only via CLI:

  ```bash
  xcodebuild test -project "Iron Workout.xcodeproj" -scheme "Iron Workout" \
    -destination 'platform=iOS Simulator,name=iPhone 17' \
    -only-testing:"Iron WorkoutTests"
  ```

- When adding logic that's worth testing, extract it into a pure service (`PersonalRecordService`, `StreakCalculator` are good examples) instead of embedding it in a view. Services use explicit inputs and return values, making them trivial to test.
- SwiftData-dependent services (e.g. `WorkoutSessionService`, `ProgramLibraryService`) can be tested against an in-memory `ModelContainer` — see `WorkoutSessionServiceTests` for the pattern.

## Git

- Branch from `main`.
- Short, descriptive commit messages in English.
- Never push secrets or `.xcuserdata`.
- When bumping build numbers, update all targets (app + widget extension).

## Build performance

If builds hang or take very long (especially around 4/80 on the progress bar), the Swift type-checker is likely struggling with a large view body. Split the view into smaller subview files. Each subview should be in its own struct in a separate file (e.g. `FooSubviews.swift` alongside `FooView.swift`).
