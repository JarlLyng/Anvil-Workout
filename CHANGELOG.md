# Changelog

What changed in each version of Anvil Workout, newest first. Dates are when a version was tagged
for release; it reaches the App Store after review.

## 1.9.0 (unreleased)

- Crash reports can be turned off in Settings, under Privacy. It takes effect straight away.
- Crash reports carry less. They no longer include the names of programs or exercises or any
  numbers from workouts, and the app no longer sends anything when it opens. A report only goes out
  when the app crashes, hangs or hits an error.
- The Apple Watch widget works on watchOS 10 and later. It previously needed a much newer watchOS
  than the watch app itself.

## 1.8.0 (2026-09-16)

- Every pending set shows what you lifted in the matching set last time, with one tap to reuse it.
  Imported history counts, so it works from the first workout after switching apps.
- A weight correction carries to the following sets of the same exercise in the same workout. Reps
  stay on the program target.
- Workouts imported from Strong keep their workout length, and no longer come back as unfinished
  workouts asking to be saved or discarded. Existing imports are repaired on launch.
- The import preview lists anything that cannot be imported, such as timed or distance sets,
  before anything is saved. Per-exercise notes are now imported.

## 1.7.1 (2026-07-24)

- Crash reports never include a screenshot or the screen's view hierarchy, and there is no
  performance tracing on your device.

## 1.7.0 (2026-07-15)

- Settings has an "Also from IAMJARL" section with the maker's other apps.
- Reliability fixes for iPhones without a paired Apple Watch.

## 1.6.0 (2026-07-05)

- RPE per set, 1 to 10 in half steps.
- Tap a pending set to enter the actual weight and reps before marking it done.

## 1.5.0 (2026-06-22)

- Import your workout history from Strong or Hevy as a CSV file.
- A plate calculator in the active workout shows what to load on each side of the bar.
- Tags for grouping and filtering programs.

## Earlier

- **1.4.0**: An Apple Watch companion for logging and skipping sets, with a wrist tap when rest
  ends and a Smart Stack widget. A native iPad layout with a two-column active workout screen.
- **1.3.0**: An accessibility pass across the workout screens.
- **1.2.0**: Renamed from Iron Workout to Anvil Workout. Share a program with a link. A workout
  left running is offered for saving the next time the app opens.
- **1.1**: kg and lb respected in every weight display, and a fix for programs disappearing when
  the app and its widget shared storage.
- **1.0.0** (April 2026): First release.
