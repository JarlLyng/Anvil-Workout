# Security Policy

## Reporting a vulnerability

If you find a security issue in Anvil Workout, please don't open a public issue. Report it
privately, either through GitHub's
[private vulnerability reporting](https://github.com/JarlLyng/Anvil-Workout/security/advisories/new)
or by email to **support@iamjarl.com**.

Please include:

- What the issue is, and what it would let someone do
- Steps to reproduce
- The affected version (the App Store version, or a commit SHA)
- How you would like to be credited, if at all

You'll get a reply within 7 days. Confirmed issues are fixed and shipped as quickly as App Store
review allows.

## Scope

In scope:

- The app code for iPhone, iPad and Apple Watch
- The marketing site at `anvilworkout.iamjarl.com`, built from `docs/`
- The build scripts in `ci_scripts/` and `Scripts/`

Out of scope:

- Vulnerabilities in dependencies (Sentry, PhosphorSwift, IAMJARLDesignTokens): please report
  those to the projects themselves
- Vulnerabilities in Apple's platforms: please report those to Apple Product Security
- Forks of this repository

## What the app handles

Anvil Workout has no backend, no accounts and no sync. Workouts, programs and settings are stored
on the device with SwiftData. With the user's permission it writes workouts to Apple Health and
reads calories and heart rate back, all through HealthKit on the device. The only data that leaves
the device is Sentry diagnostics, and the
[privacy policy](https://anvilworkout.iamjarl.com/privacy.html) describes exactly what they contain.

## Known, and not a vulnerability

The git history contains a Sentry auth token that was committed by mistake. It was revoked on
2026-09-22, before the repository was made public, and it no longer works: the Sentry API answers
it with 401. There is no need to report it.
