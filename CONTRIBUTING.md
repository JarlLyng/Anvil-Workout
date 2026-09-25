# Contributing to Anvil Workout

Thanks for your interest. Anvil Workout is a solo indie project: I (Jarl) build it for the way I
train, and ship what makes it better for lifters who want a focused tool. That shapes what this
repo accepts.

## Welcome

- **Bug reports.** Open an [issue](https://github.com/JarlLyng/Anvil-Workout/issues) with steps to
  reproduce, what you expected, what happened, and your device and iOS version.
- **Feature requests.** Open an issue. Everything gets read, but the bar for new features is
  deliberately high; see the principles below.
- **Documentation fixes.** Typos, broken links and outdated examples in `docs/`. Pull requests are
  welcome and almost always merged.
- **Forks.** The code is MIT-licensed, so you can fork it and build your own version. The Anvil
  Workout name and brand are not covered by the licence.

## A harder sell

- **Large pull requests without an issue first.** Open an issue so we can talk about whether it
  fits.
- **Refactors that don't fix a bug or unblock a feature.**
- **New dependencies.** The app has three: Sentry, PhosphorSwift and the IAMJARL design tokens.
  Adding one needs a strong case.

## Principles

Anvil Workout is a focused strength training app: build a program, run it in the gym, see your
progress. It is a one-time purchase, keeps everything on the device, and has no account.

Changes that fit: making a workout faster to run, better Apple Watch and iPad support,
accessibility, accurate data, and bringing history in from other apps.

Changes that don't: social features, accounts and cloud sync, subscriptions or in-app purchases,
ads or analytics, and generated programs or coaching.

## Working on the code

Build and run instructions are in the [README](README.md). Code patterns and conventions are in
[`docs/dev/CONTRIBUTING.md`](docs/dev/CONTRIBUTING.md), and the architecture in
[`docs/dev/ARCHITECTURE.md`](docs/dev/ARCHITECTURE.md). If you work with an AI assistant,
[`AGENTS.md`](AGENTS.md) is its context file, including the list of things the app deliberately
does not do.

Before opening a pull request, run the whole `Iron WorkoutTests` target and build the Release
configuration. Release turns on stricter concurrency checking that a Debug build does not, so code
that builds in Debug can still fail to archive.

## Security

Please don't report security issues in public. See [SECURITY.md](SECURITY.md).
