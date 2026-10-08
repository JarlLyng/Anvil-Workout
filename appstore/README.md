# App Store screenshots

App Store Connect marketing screenshots, versioned per release. These are not site images
(`docs/` is what Pages serves) and are uploaded to App Store Connect only, at exact slot sizes.

## Layout

```
appstore/
  manifest.json     the set: raw capture, slot, caption, position per poster
  raw/en, raw/da    the captures, so a set can be re-composed without re-shooting
  <version>/en, da  the composed posters to upload
```

Current: **`1.10.0/`**, five iPhone 6.9" posters, three iPad 13" posters and two Apple Watch
screens (Series 11, 46 mm, 416 × 496) per locale. Apple scales the 6.9" and 13" sets down to the
smaller slots, and wants the same watch size in every locale. Superseded sets are deleted; git
history keeps them.

## Order

Apple's [asset best practices](https://developer.apple.com/app-store/asset-best-practices/) ask
for screenshots in the order someone would use the app, and show up to three of them in search
results. So the set runs: a set being logged, the home screen with the pay-once promise, the
screen after a workout, Stats over the weeks, then History. The first two are the hub's two
heaviest frames (the wedge, then the objection); the first three are what a searcher sees.

## Style

The portfolio standard from `DESIGN.md` in the private strategy hub: dark ground, lime
`#D0FF00` accent, a drawn device bezel, captions alternating top and bottom with bleed on the
top ones. Captions follow `VOICE.md` and the app's overlay: concrete, no hype, no em-dashes,
pay-once framing, no third-party names. The demo program is the library's 5×5 under the
plain name Full Body A and B for that reason.

The English set is in pounds and the Danish set in kilograms, each in its own region's date
and number format, because that is what a buyer in each storefront would see.

## Regenerating

Capture uses the app's Debug-only screenshot mode (`Shared/Services/ScreenshotMode.swift`):
demo history on an empty store, no onboarding, no permission prompts, one screen per launch.

```sh
xcrun simctl ui <device> appearance dark
xcrun simctl status_bar <device> override --time 9:41 --batteryState charged --batteryLevel 100
xcrun simctl launch <device> com.iamjarl.Iron-Workout -screenshots -screen <screen> -weightUnit lbs
xcrun simctl io <device> screenshot appstore/raw/en/iphone-<screen>.png
```

Screens: `workout`, `home`, `stats`, `completion`, `history`, `library`, `onboarding`, `programs`, `exercises`. Use an
iPhone 6.9" simulator (16 Pro Max) and a 13" iPad, with the simulator's region set to the
locale (`defaults write -g AppleLocale da_DK` through `simctl spawn`) and the app reinstalled
between locales so the demo history is rebuilt in the right unit.

The watch screens come from the watch app's own Debug demo, on an Apple Watch Series 11 (46 mm)
simulator:

```sh
xcrun simctl launch <watch> com.iamjarl.Iron-Workout.watchkitapp -AnvilWatchDemo set -weightUnit lbs
```

States: `set`, `rest`, `paused`, `done`; the set uses `set` and `rest`. `simctl io screenshot`
cannot write into this folder (macOS refuses the simulator access to it), so capture to a
temporary folder and copy the files into `raw/`.

Then compose with the hub's tool:

```sh
python3 <hub>/tools/appstore_screenshots.py batch appstore/manifest.json
```
