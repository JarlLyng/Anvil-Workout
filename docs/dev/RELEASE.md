# Release checklist

Steps to ship a new version of Anvil Workout. Do them in order; several were
learned the hard way (see the notes).

## 1. Bump version and build number

In `Iron Workout.xcodeproj/project.pbxproj`:

- **`MARKETING_VERSION`** → the new version (e.g. `1.5.0`) on **all** targets. This is the
  one that matters for the release flow.
- **`CURRENT_PROJECT_VERSION`** → the build number. **Xcode Cloud assigns its own build
  number and ignores this**, so for the normal (cloud) flow you don't need to touch it. Keep
  it bumped and consistent only for the manual-archive fallback in §4.

> ⚠️ **`MARKETING_VERSION` must match across all targets**, including the watch app
> (`watchkitapp`) and watch widget (`watchkitapp.Anvil-Watch-Widget`), not just the iOS app
> and iOS widget. Apple rejects an archive whose embedded watch app version differs from the
> host app. (These have drifted to `1.0` before — check them.)

Quick check:
```bash
grep -oE "MARKETING_VERSION = [0-9.]+;" "Iron Workout.xcodeproj/project.pbxproj" | sort | uniq -c
grep -oE "CURRENT_PROJECT_VERSION = [0-9]+;" "Iron Workout.xcodeproj/project.pbxproj" | sort | uniq -c
```

## 2. Update AI-facing / marketing metadata (keep it accurate)

Google's guidance requires structured data and metadata to stay accurate, and
`llms.txt` feeds AI engines a summary. Update for the new version:

- `docs/index.html` JSON-LD: **`softwareVersion`** and add any new features to **`featureList`**.
- `docs/llms.txt`: add new features under **Key features**.
- `docs/index.html` **roadmap section**: move the shipped items to "Recently shipped"
  (with the new version tag) and refresh "Coming next" with what is actually in development.
- Keep JSON-LD valid. (Google ignores `llms.txt`; keep it only for other AI engines.)

## 3. Verify — Release config, then full test target

- **Build the Release configuration**, not just a Debug/simulator build:
  ```bash
  xcodebuild -project "Iron Workout.xcodeproj" -scheme "Iron Workout" \
    -configuration Release -destination 'generic/platform=iOS Simulator' \
    build CODE_SIGNING_ALLOWED=NO
  ```
  > ⚠️ Release sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`, which surfaces
  > concurrency/isolation errors that a Debug build does **not** catch. Archiving
  > will fail on them otherwise.
- **Run the full `Iron WorkoutTests` target**, not a scoped run:
  ```bash
  xcodebuild ... test -only-testing:"Iron WorkoutTests"
  ```
  > ⚠️ A scoped `-only-testing:"Iron WorkoutTests/SomeSuite"` can match nothing
  > (suite display name ≠ type name) and report success vacuously. The full
  > target is the authoritative run.

## 4. Build and upload (Xcode Cloud)

- Merge `main` into `release` and push — that triggers the Xcode Cloud workflow,
  which archives the iOS app (watch app + widgets are embedded) and delivers the
  build to App Store Connect:
  ```bash
  git checkout release && git merge main --ff-only && git push && git checkout main
  ```
- Sentry secrets come from the workflow's environment variables
  (`SENTRY_DSN`, `SENTRY_AUTH_TOKEN`, `SENTRY_ORG`, `SENTRY_PROJECT`) via
  `ci_scripts/ci_post_clone.sh`, which regenerates the gitignored
  `Secrets.xcconfig` and installs `sentry-cli`. Check the build log for
  "Secrets.xcconfig generated" — without it the build ships without crash reporting.
- Watch the build in Xcode (Report Navigator → Cloud) or App Store Connect.
- **Manual fallback** (Xcode Cloud down or credits exhausted): Xcode →
  Product → Archive (Release scheme) → Distribute App → App Store Connect.
  The archive triggers `Scripts/sentry-upload-dsyms.sh` locally; the dSYM
  warning about the prebuilt `Sentry.framework` is harmless.

## 5. App Store Connect

- Create the new version, select the uploaded build.
- Paste **What's New** release notes (EN + DA — the app UI is English but the DK
  storefront copy can be Danish). Follow the portfolio voice rules (`VOICE.md` in the
  private strategy hub; see CLAUDE.md → Voice): no em-dashes, pay-once framing, never
  "free". Short feature lists are fine here — App Store descriptions and release notes
  are explicitly carved out of the no-bullets rule (that ban is for posts and replies).
- Update screenshots if the UI changed materially.
- Submit for review.

## 6. Tag the release

After the release commit is pushed:
```bash
git tag -a vX.Y.Z -m "Anvil Workout X.Y.Z (build N)"
git push origin vX.Y.Z
```

## 7. Post-launch

- Watch Sentry for version-specific crashes for the first few days.
- Consider a short "shipped X.Y.Z" update where the audience is (Indie Hackers, etc.).
