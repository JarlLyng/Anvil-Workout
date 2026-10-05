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

Current: **`1.10.0/`**, five iPhone 6.9" posters and three iPad 13" posters per locale. Apple
scales the 6.9" and 13" sets down to the smaller slots. Superseded sets are deleted; git
history keeps them.

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

Screens: `workout`, `home`, `stats`, `completion`, `history`, `library`, `onboarding`. Use an
iPhone 6.9" simulator (16 Pro Max) and a 13" iPad, with the simulator's region set to the
locale (`defaults write -g AppleLocale da_DK` through `simctl spawn`) and the app reinstalled
between locales so the demo history is rebuilt in the right unit.

Then compose with the hub's tool:

```sh
python3 <hub>/tools/appstore_screenshots.py batch appstore/manifest.json
```
