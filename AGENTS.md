# AGENTS.md

Project context for AI assistants working on Anvil Workout.
This file is mirrored verbatim to `.cursorrules`, `.windsurfrules` and
`.github/copilot-instructions.md`, and to `AGENTS.md` with only the title line changed.
**Change one, re-mirror all five.**

## What is Anvil Workout?

A strength training app for iPhone, iPad and Apple Watch. Users build workout programs
(templates), run them in the gym with a rest timer and set tracking, and review history and
progress afterwards. Everything is stored on the device with SwiftData. There is no backend, no
account and no sync service.

- **Developer:** [IAMJARL](https://iamjarl.com). Never the full personal name in copy or docs; see `BRAND_LEGAL.md` in the hub. `LICENSE` is the one deliberate exception: IAMJARL is a sole proprietorship, so the licence names the legal person behind it. Do not "fix" it.
- **Website:** [anvilworkout.iamjarl.com](https://anvilworkout.iamjarl.com)
- **App Store:** [id6760627760](https://apps.apple.com/app/id6760627760)
- **Price:** $2.99 USD one-time. No subscription, no in-app purchases, no ads.
- **Current version:** 1.8.0 (live 2026-09-17)
- **License:** [MIT](LICENSE), like the sibling apps. It covers the code, not the Anvil name, brand or App Store listing.
- **Repo status:** going public. The Sentry token that leaked into git history was revoked on 2026-09-22 and verified dead; the history is kept as is rather than rewritten (#63).
- **Formerly:** Iron Workout. The Xcode project, targets, scheme, folder and bundle ID still carry the old name (#83). **Never change the bundle ID** `com.iamjarl.Iron-Workout` or the App Group `group.com.iamjarl.Iron-Workout`; both would orphan existing users.

## Requirements

- **iOS 17.0+**, iPadOS 17.0+
- **watchOS 10.0+** for the watch app and the watch widget. The widget's floor is set by `.containerBackground(for: .widget)`, which is watchOS 10; everything else it uses is watchOS 9. It drifted to 26.5 once (#85), so check all four watch configs together if you touch deployment targets.

## Strategy lives in the private hub

Target audience, positioning, pricing reasoning, SEO/ASO playbooks, analytics readouts and
competitor analysis are **not** in this repo. They live in the private
[iamjarl-strategy](https://github.com/JarlLyng/iamjarl-strategy) hub, folder `AnvilWorkout/`.
Read that repo's `CONVENTIONS.md` before any audience, positioning, pricing or marketing work,
and write results there.

### Read these hub files before the task they govern

- **`VOICE.md`** before any public copy: App Store text, site copy, release notes, posts, replies. Hard rules: no em-dashes, no bullet lists in copy, minimal emojis, pay-once framing, never "free". Anvil's overlay is athlete-direct, concrete, no bro-hype.
- **`BRAND_LEGAL.md`** before anything naming the maker, copyright or a third-party product.
- **`DESIGN.md`** before App Store screenshots or any brand visual.
- **`ASO_GUIDANCE.md`** before touching App Store metadata; **`SEO_GUIDANCE.md`** before site SEO.
- **`PROJECT_STANDARDS.md`** for the repo conventions this file is meant to satisfy.

### Numbers stay in the hub

**Issues and docs in this repo carry findings, never measured numbers.** No download, sales,
revenue, rating-count or traffic figures here or in issues. State the finding, drop the number.
The repo is slated to go public, so anything written here is written for that audience.

## App features (be precise, do not invent features that do not exist)

**Programs**
- Program builder: exercises, target sets, reps, weight, rest seconds, supersets, per-exercise notes
- Tags for organising and filtering programs
- Bundled library of classic programs (StrongLifts 5×5, Starting Strength, Greyskull LP, GZCLP, Upper/Lower and others), importable and then fully editable

**Running a workout**
- Set tracking with a rest timer and haptics on phone and watch
- Set types: working, warm-up, drop set, failure
- RPE per set, 1 to 10 in half steps
- Tap a pending set to enter actual weight and reps before completing it
- Previous-session reference under each pending set, showing the matching set's weight and reps, with one tap to reuse them (1.8.0)
- Weight carries from an earlier set of the same exercise in the same session; reps stay on the program target
- Plate calculator for per-side barbell loading
- Live Activity on Lock Screen and Dynamic Island
- Recovery prompt for a workout left running, offering to save or discard it

**After**
- History with duration, calories and heart rate
- Per-exercise history and automatic personal-record detection for weight and reps
- Stats: training volume, weekly frequency, estimated 1RM, muscle-group distribution
- Home-screen and watch widgets for the streak

**Data**
- CSV export of workout history
- CSV import from Strong and Hevy, with a preview that lists what cannot be imported before anything is saved
- Apple Health: writes completed workouts, reads calories and heart rate when authorised

**Other surfaces**
- Native iPad layout with multi-pane navigation and a two-column active workout screen
- Apple Watch companion for logging sets, skipping sets and rest haptics

### Features that do NOT exist (common hallucination targets)

- **No cloud sync, no accounts, no server.** Data lives on the device. Backup is whatever the user's iCloud device backup does, which is not an app feature.
- **No iPhone-to-iPad live sync.** Two devices hold two separate stores.
- **The Apple Watch app is not independent.** A workout must be started on the iPhone; the watch mirrors and controls it over WatchConnectivity. It needs no internet, but it does need the phone.
- **No social layer.** No feed, friends, sharing to other users, leaderboards or challenges.
- **No coaching, no generated programs, no automatic progression.** Targets change when the user changes them. There is no AI, no adaptive programming and no deload logic.
- **No Android, no web app, no Mac app.**
- **Import reads Strong and Hevy only**, and it does **not** read Anvil's own CSV export. Export and import are not a round trip.
- **Export covers sessions, exercises and sets only.** Not programs, not the weekly plan, not custom exercise definitions.
- **No timed or distance sets.** Planks, carries and cardio cannot be represented; `PerformedSet` stores reps and weight. The importer reports these as skipped rather than inventing values.
- **No Family Sharing.** Apple removed the toggle for paid apps; see #60. Not a decision of ours.
- **No in-app analytics, no ads, no tracking.** The only outbound traffic is anonymous Sentry crash reporting.
- **No user-facing crash-reporting toggle.** Do not describe crash reports as "optional" in copy.
- **No subscription and no in-app purchases.** Never describe the app as "free".

## Key conventions

- **English UI** throughout the app
- **Feature-based folders** under `Features/`. No ViewModels; logic lives in services or views
- **Design tokens only** via `IAMJARLDesignTokens`. Never hardcode colors or spacing
- **Phosphor icons only**, `Ph.iconName.regular` / `.fill`, never SF Symbols (except the tab bar, where SwiftUI requires them). Use the `.icon(size:)` helper
- **OnPrimary text** on primary-colored surfaces: `DesignTokens.Common.OnPrimary.text(colorScheme)`
- **Error handling**: `@State private var errorMessage: String?` plus `.alert()` in every view that saves
- **No navigation titles on tab root views**; the tab name is the title
- **Split large views** into `*Subviews.swift` when the type-checker slows down
- **Swift Testing**, not XCTest. `@Test`, `@Suite`, `#expect`, `#require`

## Important gotchas

- `SetType` raw values are Danish (`"Arbejdssæt"`, `"Opvarmning"`, `"Dropsæt"`) because they are SwiftData storage keys. **Do not change them** or existing data breaks.
- Release sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which surfaces isolation errors Debug does not. **Always build Release before calling anything release-ready.**
- A scoped `-only-testing:"Iron WorkoutTests/SomeSuite"` can match nothing and pass vacuously. **Run the whole `Iron WorkoutTests` target.**
- `MARKETING_VERSION` must match on all 16 targets including the watch app and watch widget. They have drifted to 1.0 before.
- `LiveActivityAttributes.swift` needs target membership on both the app and the widget extension.
- The Sentry script phase must come after "Embed Foundation Extensions" to avoid a dependency cycle.
- New files are picked up automatically (`PBXFileSystemSynchronizedRootGroup`); no pbxproj editing needed.

## Workflow

- **Task tracking**: [GitHub Issues](https://github.com/JarlLyng/Anvil-Workout/issues). Do not create task-tracking markdown files.
- **Marketing website**: static site in `docs/`, served by GitHub Pages. Developer docs in `docs/dev/`.
- **Business model rule**: paid one-time purchase. Never "free" in any copy, metadata or structured data. "Subscription-free" and "distraction-free" are fine.

## Build and run

```bash
open "Iron Workout.xcodeproj"
# Scheme: Iron Workout, any simulator -> Cmd+R
```

No extra config needed. Sentry is optional (runs without a DSN). HealthKit needs a physical device.

## Keep this file current

When the app ships a version, changes price or OS floor, or gains or loses a feature, update this
file in the same change and re-mirror the four copies. A stale CLAUDE.md is worse than none,
because an assistant will build on what it says.

## Project structure

See `docs/dev/ARCHITECTURE.md` for the file tree and data model.
See `docs/dev/DESIGN.md` for icon and color usage.
See `docs/dev/SETUP.md` for Sentry, HealthKit, App Groups and widget setup.
See `docs/dev/CONTRIBUTING.md` for code patterns.
See `docs/dev/RELEASE.md` for the release checklist.
