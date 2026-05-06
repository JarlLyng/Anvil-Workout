# AGENTS.md

Project context for AI assistants working on Anvil Workout.
This file is also mirrored to `AGENTS.md`, `.cursorrules`, `.windsurfrules`, and `.github/copilot-instructions.md`.

## What is this

iOS strength training app. **Paid app** (one-time purchase on the App Store — no subscription, no in-app purchases, no ads). SwiftUI + SwiftData, no backend. Users create workout programs (templates), run them in the gym with a timer and set tracking, and review history/stats afterwards. HealthKit integration for calories and heart rate. Widget extension for home screen streak widget and Live Activity during workouts.

## Tech stack

- SwiftUI, SwiftData, HealthKit, WidgetKit, ActivityKit, Charts, StoreKit
- Sentry for crash reporting (sentry-cocoa via SPM)
- IAMJARL Design Tokens (`IAMJARLDesignTokens` package) for colors/spacing
- Phosphor Icons (`PhosphorSwift` package) — no SF Symbols in app code

## Key conventions

- **English UI** throughout the app
- **Feature-based folders** under `Features/` — no ViewModels, logic in services or views
- **Design tokens only** — never hardcode colors or spacing values
- **Phosphor icons only** — use `Ph.iconName.regular` / `.fill`, never SF Symbols (except tab bar where SwiftUI requires it). Use the `.icon(size:)` helper (default 20pt) instead of manual `.resizable().aspectRatio(contentMode: .fit).frame(width:height:)` chains
- **OnPrimary text** — text on primary-colored surfaces (`.borderedProminent` buttons, accent-colored badges) must use `DesignTokens.Common.OnPrimary.text(colorScheme)`
- **Error handling** — `@State private var errorMessage: String?` + `.alert()` in every view that saves data
- **No navigation titles on tab root views** — tab name is the title
- **Split large views** — extract subviews to separate files when type-checker is slow (see `*Subviews.swift` pattern)

## Important gotchas

- `SetType` raw values are in Danish (`"Arbejdssæt"`, `"Opvarmning"`, `"Dropsæt"`) — these are SwiftData storage keys. **Do not change them** or existing data breaks.
- `LiveActivityAttributes.swift` must have Target Membership on BOTH the main app and widget extension targets.
- Widget extension build number (`CURRENT_PROJECT_VERSION`) must match the main app. Always bump both.
- Sentry script phase must come AFTER "Embed Foundation Extensions" in build phases to avoid dependency cycles.
- App Group `group.com.iamjarl.Iron-Workout` is used for shared SwiftData between app and widget.

## Workflow

- **Task tracking** — use [GitHub Issues](https://github.com/JarlLyng/Anvil-Workout/issues) for bugs, features, and todos. Do not create task-tracking markdown files.
- **SEO/GEO strategy** — `SEO_STRATEGY.md` is maintained by a separate AI. Keep project docs accurate so it has correct context.
- **Marketing website** — static site in `docs/` (served via GitHub Pages). Developer docs are in `docs/dev/`.
- **Business model rule** — the app is a **paid one-time purchase**. Never describe it as "free" in any copy, metadata, or structured data. "Subscription-free" and "distraction-free" are fine.

## Build and run

```bash
open "Anvil Workout.xcodeproj"
# Scheme: Anvil Workout, any simulator -> Cmd+R
```

No extra config needed. Sentry is optional (runs without DSN). HealthKit needs a physical device.

## Project structure

See `docs/dev/ARCHITECTURE.md` for full file tree and data model.
See `docs/dev/DESIGN.md` for icon and color usage.
See `docs/dev/SETUP.md` for Sentry, HealthKit, App Groups, and widget setup.
See `docs/dev/CONTRIBUTING.md` for code patterns and conventions.
