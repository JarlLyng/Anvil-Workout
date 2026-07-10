# Anvil Workout

[![Co-created with AI](https://madebyhuman.iamjarl.com/badges/co-created-white.svg)](https://madebyhuman.iamjarl.com)

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
open "Anvil Workout.xcodeproj"
# Select scheme "Anvil Workout", pick a simulator -> Cmd+R
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

- **Name:** Anvil Workout
- **Developer:** IAMJARL
- **Subtitle:** Plan. Lift. Track. Progress.
- **Listing:** [apps.apple.com/app/id6760627760](https://apps.apple.com/app/id6760627760)
- **Website:** [anvilworkout.iamjarl.com](https://anvilworkout.iamjarl.com)

---

## Marketing website

Static site served from `docs/` via GitHub Pages on the custom domain `anvilworkout.iamjarl.com`. Each page is hand-authored HTML with full structured data (BreadcrumbList, WebPage, plus page-specific schemas) for SEO.

| Page | Target |
|------|--------|
| [`docs/index.html`](docs/index.html) | Overview + features + screenshots + FAQ + CTA |
| [`docs/programs.html`](docs/programs.html) | The six built-in programs with SEO-rich descriptions |
| [`docs/offline-workout-app.html`](docs/offline-workout-app.html) | "offline workout app" landing page |
| [`docs/apple-health-strength-training.html`](docs/apple-health-strength-training.html) | "Apple Health strength training" landing page |
| [`docs/no-subscription-workout-app.html`](docs/no-subscription-workout-app.html) | "no subscription workout app" philosophy + comparison |
| [`docs/support.html`](docs/support.html) | FAQ + contact |
| [`docs/privacy.html`](docs/privacy.html) | Privacy policy |

Also in `docs/`: `sitemap.xml`, `robots.txt`, `llms.txt`, `style.css`, `CNAME`, `screenshots/` (for the index hero + gallery), and favicon/OG image assets. Deployment is handled by [`.github/workflows/pages.yml`](.github/workflows/pages.yml) which triggers on every push to `main` that touches `docs/`.

SEO/ASO strategy and target-audience/ICP material live in the private [`iamjarl-strategy`](https://github.com/JarlLyng/iamjarl-strategy) hub (under `AnvilWorkout/`), not in this repo — keep strategic material there, never in public code or issues.
