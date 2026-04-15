# Iron Workout

Paid iOS app (one-time purchase, no subscription) for planning and executing strength training: create programs, run workouts in the gym, and have everything saved to history and Apple Health with zero friction.

**Plan your workout -> train -> tap done -> session saved.**

---

## Overview

| Area | Technology |
|------|-----------|
| UI | SwiftUI |
| Persistence | SwiftData |
| Health | HealthKit |
| Widgets | WidgetKit + ActivityKit (Live Activity) |
| Monitoring | Sentry (sentry-cocoa) |
| Design system | [IAMJARL Design Tokens](https://github.com/JarlLyng/iamjarl-design) |
| Icons | [Phosphor Icons](https://github.com/phosphor-icons/swift) |
| Language | Swift 5, English UI |

No backend, login, or external APIs beyond Health and Sentry. Paid app (one-time purchase) — no subscription, no in-app purchases, no ads.

---

## Quick start

```bash
git clone <repo-url>
open "Iron Workout.xcodeproj"
# Select scheme "Iron Workout", pick a simulator -> Cmd+R
```

The app runs without additional configuration. The exercise library is seeded automatically on first launch.

See [docs/dev/SETUP.md](docs/dev/SETUP.md) for full setup including Sentry, HealthKit, App Groups, and Widget Extension.

---

## Features

- **Dashboard** — Weekly metrics (workouts, streak, volume), weekly planner, quick-start recommendations
- **Programs** — Create, edit, duplicate, favorite workout templates with exercises, sets, reps, weight, rest timers, and supersets
- **Active Workout** — Timer, set-by-set tracking, rest timer with circular progress, pause/resume, skip exercises, per-exercise notes
- **Workout Completion** — Summary with personal records detection, share workout, App Store review prompt
- **History** — Searchable list of completed workouts with detailed session views
- **Exercises** — Searchable exercise library with per-exercise history and PR tracking (best weight, volume, estimated 1RM)
- **Stats** — Volume chart, weekly frequency, estimated 1RM progression, muscle group distribution
- **Settings** — Weight unit preference (kg/lbs), HealthKit permissions, CSV data export
- **Onboarding** — 3-page intro for new users
- **Widget** — Home screen streak widget (small + medium sizes)
- **Live Activity** — Lock Screen and Dynamic Island showing current exercise, time, and set progress during workouts

---

## Documentation

| Document | Contents |
|----------|---------|
| [docs/dev/SETUP.md](docs/dev/SETUP.md) | Requirements, installation, Sentry, HealthKit, App Groups, Widget Extension |
| [docs/dev/ARCHITECTURE.md](docs/dev/ARCHITECTURE.md) | Project structure, data model, relationships, user flow |
| [docs/dev/DESIGN.md](docs/dev/DESIGN.md) | Design system, Phosphor icons, colors, UI guidelines |
| [docs/dev/CONTRIBUTING.md](docs/dev/CONTRIBUTING.md) | Development, code style, adding features, tests |

---

## App Store

- **Name:** Iron Workout
- **Developer:** IAMJARL
- **Subtitle:** Plan and Track Workouts
