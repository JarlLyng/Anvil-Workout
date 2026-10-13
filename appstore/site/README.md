# Site captures

The hero loop and the tour screens for the redesigned anvilworkout.iamjarl.com (#110). The
files the site serves go in `docs/assets/site/`. This folder holds how to make them again.

**Remake them whenever the workout screen, the program library or Stats changes.** The site is
public imagery, and an old capture advertises an old app.

## What the captures show

The Debug demo history (`Shared/Services/DemoHistory.swift`): 24 weeks of a 5×5 program three
times a week, two of the weeks off, in round 5 lb steps. It is the library's StrongLifts 5×5
under the plain name Full Body A and B. Nothing on these screens is a streak; the Home screen,
which shows one, is never captured for the site.

- **The loop:** Full Body A, Back Squat, set 3 of 5 at 5 × 305 lb with sets 1 and 2 done. Done is
  tapped, rest starts at 3:00 and counts down, and set 4 comes up with last session's
  300 lb × 5 beside it.
- **The tour:** the Program Library, the same workout two sets in, and Stats over 12 weeks
  scrolled to the records and the estimated one-rep max.

English, in pounds, in the US region's formats.

## Set up the simulator

An iPhone 18 Pro on iOS 27, so the captures are 1206 × 2622. Light appearance, and the status
bar Apple's marketing rules ask for: full signal, Wi-Fi and battery, at 9:41.

```bash
U=<iPhone 18 Pro UDID>
xcrun simctl spawn $U defaults write -g AppleLocale -string en_US
xcrun simctl spawn $U defaults write -g AppleLanguages -array en
xcrun simctl shutdown $U; xcrun simctl boot $U
xcrun simctl ui $U appearance light
xcrun simctl status_bar $U override --time "9:41" --dataNetwork wifi --wifiMode active --wifiBars 3 \
  --cellularMode active --cellularBars 4 --operatorName "" --batteryState discharging --batteryLevel 100
```

The locale has to be the simulator's own, not only a launch argument, or the status bar writes
the time in the wrong language.

## The app's site mode

A Debug build reads these launch arguments (`Shared/Services/ScreenshotMode.swift`). None of
them exist in a release build.

| Argument | Effect |
|---|---|
| `-screenshots -screen library\|workout\|stats` | Demo history on an empty store, no onboarding or permission prompts, one screen open |
| `-weightUnit lbs` | The demo history built in pounds |
| `-siteScroll records` | Stats opens scrolled to the records, with the estimated one-rep max below |
| `-siteAutoDone 3` | The workout screen marks its current set done 3 s after it opens, as a tap on Done would |

**Install the app fresh before every capture.** The workout capture leaves a workout under way in
the store, and Stats counts its sets, so a Stats capture after it shows today's half-finished
workout as a record.

```bash
fresh() { xcrun simctl uninstall $U com.iamjarl.Iron-Workout; xcrun simctl install $U "$APP"; }
```

## The tour screens

```bash
fresh; xcrun simctl launch $U com.iamjarl.Iron-Workout -screenshots -screen library -weightUnit lbs
xcrun simctl io $U screenshot library.png
sips -s format jpeg -s formatOptions 80 -z 1308 602 library.png --out tour-library.jpg
```

The workout the same way with `-screen workout`, and Stats with
`-screen stats -siteScroll records`. 602 × 1308 is half the capture.

## The loop

Record a fresh launch with `-siteAutoDone`, then find the cut on a contact sheet.

```bash
fresh
xcrun simctl io $U recordVideo --codec=h264 --force loop-raw.mp4 &   # stop with kill -INT after ~18 s
sleep 2; xcrun simctl launch $U com.iamjarl.Iron-Workout -screenshots -screen workout -siteAutoDone 3 -weightUnit lbs
swift appstore/site/loopkit.swift sheet  loop-raw.mp4 sheet.jpg 2 17 0.5 8
swift appstore/site/loopkit.swift encode loop-raw.mp4 workout-loop.mp4 6.75 8.0 602 1308 700000
swift appstore/site/loopkit.swift poster workout-loop.mp4 workout-loop-poster.jpg 4.3 602 1308 0.8
```

In the 2026-10-13 recording, Done landed at 8.75 s and the clocks ticked at about x.75 s, so the
cut runs from 6.75 s for 8 seconds: two seconds of set 3 waiting, then rest from 3:00 to 2:55.
Both ends fall on a tick, so the repeat keeps the rhythm. Times shift a little with every
recording, so check the sheet. `encode` also paints out the Dynamic Island, which a simulator
recording draws and a screenshot doesn't. The loop comes out at about 280 KB.

The poster is the frame at 4.3 s: rest counting, set 4 up next with last session's weight and
reps. The page reads the same before the video plays, without the script and under reduce
motion.

## The social card

`docs/og-image.png`, the site's `og:image` and the repo's GitHub social preview, comes from
`social-card.html` in this folder: the name, the headline, one line of outcome and the workout
screen from the tour, on the site's own identity. Render it at twice the size and scale it down,
so the type is sharp:

```bash
python3 -m http.server 8766 --bind 127.0.0.1    # from the repo root, so the page finds the tour screen
# then a headless Chrome at 1200 × 630 and a device scale factor of 2, scaled to 1200 × 630
```

It comes out at about 180 KB, under the 1 MB the platforms allow. The GitHub half is a manual
upload by the owner: Settings, then Social preview.
