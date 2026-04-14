# Project context — see CLAUDE.md for the canonical version.
# This file is a mirror. Edit CLAUDE.md and copy here when updating.

Project context for AI assistants working on Iron Workout.

## What is this

iOS strength training app. SwiftUI + SwiftData, no backend. Users create workout programs (templates), run them in the gym with a timer and set tracking, and review history/stats afterwards. HealthKit integration for calories and heart rate. Widget extension for home screen streak widget and Live Activity during workouts.

## Tech stack

- SwiftUI, SwiftData, HealthKit, WidgetKit, ActivityKit, Charts, StoreKit
- Sentry for crash reporting (sentry-cocoa via SPM)
- IAMJARL Design Tokens (`IAMJARLDesignTokens` package) for colors/spacing
- Phosphor Icons (`PhosphorSwift` package) — no SF Symbols in app code

## Key conventions

- **English UI** throughout the app
- **Feature-based folders** under `Features/` — no ViewModels, logic in services or views
- **Design tokens only** — never hardcode colors or spacing values
- **Phosphor icons only** — use `Ph.iconName.regular` / `.fill`, never SF Symbols (except tab bar where SwiftUI requires it)
- **Error handling** — `@State private var errorMessage: String?` + `.alert()` in every view that saves data
- **No navigation titles on tab root views** — tab name is the title
- **Split large views** — extract subviews to separate files when type-checker is slow (see `*Subviews.swift` pattern)

## Important gotchas

- `SetType` raw values are in Danish (`"Arbejdssæt"`, `"Opvarmning"`, `"Dropsæt"`) — these are SwiftData storage keys. **Do not change them** or existing data breaks.
- `LiveActivityAttributes.swift` must have Target Membership on BOTH the main app and widget extension targets.
- Widget extension build number (`CURRENT_PROJECT_VERSION`) must match the main app. Always bump both.
- Sentry script phase must come AFTER "Embed Foundation Extensions" in build phases to avoid dependency cycles.
- App Group `group.com.iamjarl.Iron-Workout` is used for shared SwiftData between app and widget.

## Build and run

```bash
open "Iron Workout.xcodeproj"
# Scheme: Iron Workout, any simulator -> Cmd+R
```

No extra config needed. Sentry is optional (runs without DSN). HealthKit needs a physical device.

## Project structure

See `docs/ARCHITECTURE.md` for full file tree and data model.
See `docs/DESIGN.md` for icon and color usage.
See `docs/SETUP.md` for Sentry, HealthKit, App Groups, and widget setup.
See `docs/CONTRIBUTING.md` for code patterns and conventions.
