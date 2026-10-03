# Changelog

What changed in each version of Anvil Workout, newest first. Dates are when a version was tagged
for release; it reaches the App Store after review.

## Unreleased

- The home screen opens on the workout to do next, with its exercises and a Start button at the
  top. The week is one strip of days, trained and planned, with the week's workouts, volume and
  streak below it. Recent workouts show their length, sets and volume. A new lifter sees a way to
  pick or build a first program instead of a page of zeros.
- The workout screen puts the numbers first. The current set is a card with its reps and weight as
  the largest thing on screen and the only Done button; the other sets are single lines, and
  tapping one makes it the current set. Rest reads as a clock, and the top shows which exercise you
  are on and how many sets are done.
- Stats looks back over 4, 12 or 26 weeks. It opens on what the period added up to and how volume
  compares with the period before, then volume, workouts or sets per week with the current week
  marked. Records show the latest one for each exercise, with the previous best. Strength follows
  the estimated one-rep max of the lift you train most, or any other you pick, and muscle groups
  count the sets in the period.
- Warm-up sets no longer count towards volume or sets, on the home screen or in Stats. Drop and
  failure sets still do. The estimated one-rep max only uses sets of 1 to 12 reps, in Stats and on
  each exercise.
- Record weights use your region's decimal separator, like every other weight in the app.
- A new lifter starts in three short steps: the unit they lift in, whether workouts go to Apple
  Health, and how to start: pick a program from the library, import history from Strong or Hevy,
  or build a program. Picking or building one opens the app on its first workout. Asking about
  Health here means the system no longer asks at the start of the first workout in the gym, unless
  it was skipped.
- The home screen's first card can import history from Strong or Hevy directly, instead of sending
  you to Settings.
- Programs from the library start with weights you can load when you lift in pounds: 40 kg reads
  90 lb instead of 88.2 lb.
- With nothing planned for today, the home screen offers the program after the last one trained,
  in the order programs were added. A new lifter starts on Workout A rather than B, and a library
  program alternates its own workouts.
- The screen after a workout leads with time, sets and volume, and says how the volume compares
  with the last time you did the same program. New records come next, then each exercise in one
  line, such as "5 × 5 · 100 kg". An exercise's first time is no longer listed as a record.
- History groups workouts into this week, last week and months, in the same rows as the home
  screen, and search finds exercises as well as programs. A past workout opens with the same
  summary and records, then every set, with warm-ups marked W and the work sets numbered.
- The first launch after installing the app no longer crashes. The home-screen widget could create
  the app's database at the same moment the app opened it.

## 1.9.1 (2026-10-03)

- The rest timer keeps time while the phone is locked. It used to stop in your pocket and pick up
  where it left off on unlock, so a rest could run far past its length. The Apple Watch now counts
  down on its own as well, instead of waiting for the phone.
- The Live Activity on the Lock Screen and in the Dynamic Island shows up. Earlier versions never
  displayed it, because the app was missing the setting that turns it on. It keeps the workout clock
  running, counts rest down with a bar, and says when rest is over, all without the app open.
- The Apple Watch workout screen fits on one screen, down to the 40 mm watch. The workout clock
  moves up beside the time, Done stands out from Skip, and rest is a ring with the next set below
  it.
- The watch shows weights in your unit, kg or lb, and the same weight as the phone. It used to
  show the program's target in kg, even after a corrected weight had carried to the next set.

## 1.9.0 (2026-09-23)

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
