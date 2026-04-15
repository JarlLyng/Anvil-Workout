# Design system

Iron Workout uses **IAMJARL Design Tokens** ([iamjarl-design](https://github.com/JarlLyng/iamjarl-design)) and **Phosphor Icons** ([phosphor-swift](https://github.com/phosphor-icons/swift)) for a consistent visual language.

---

## Colors

### Accent Color (primary)

| Mode | Hex | Description |
|------|-----|-------------|
| Light | `#CE63FF` | Purple |
| Dark | `#D0FF00` | Neon green |

Defined in `Assets.xcassets/AccentColor.colorset` and used automatically as the tint color throughout the app.

### Design tokens

Colors are accessed via `DesignTokens` from `IAMJARLDesignTokens`:

```swift
import IAMJARLDesignTokens

// Text
DesignTokens.Common.Text.primary(colorScheme)
DesignTokens.Common.Text.secondary(colorScheme)

// Backgrounds
DesignTokens.Common.Background.app(colorScheme)

// State colors
DesignTokens.ColorToken.State.success   // green (completed, approved)
DesignTokens.ColorToken.State.warning   // yellow/orange (pause, rest, favorites)
DesignTokens.ColorToken.State.error     // red (error, delete, heart rate)

// OnPrimary (text on primary-colored surfaces)
DesignTokens.Common.OnPrimary.text(colorScheme)  // #FFFFFF in light, #000000 in dark

// Primary color
DesignTokens.Common.primary(colorScheme)          // accent color
```

### OnPrimary rule

Text on primary-colored surfaces (`.borderedProminent` buttons, accent-colored badges like the weekly plan today-indicator) **must** use `DesignTokens.Common.OnPrimary.text(colorScheme)`, not hardcoded `.white` or SwiftUI's default button text color. This ensures correct contrast in both light and dark mode.

### Spacing

```swift
DesignTokens.Spacing.xs     // extra small
DesignTokens.Spacing.sm     // small
DesignTokens.Spacing.md     // medium
DesignTokens.Spacing.lg     // large
DesignTokens.Spacing.xl     // extra large
DesignTokens.Spacing.xxl    // 2x extra large
DesignTokens.Spacing.xxxl   // 3x extra large
```

### Corner radius

```swift
DesignTokens.Radius.lg      // cards, backgrounds
```

---

## Icons — Phosphor

All icons in the app are Phosphor icons via `PhosphorSwift`. **No SF Symbols are used** (except in system-provided views like `ContentUnavailableView` where SF Symbols are required by the API).

### Import

```swift
import PhosphorSwift
```

### API

Use the `.icon(size:)` helper extension (defined in `Shared/Components/DesignSystem.swift`) to size icons. Default size is 20pt.

```swift
// Basic usage with helper (preferred)
Ph.timer.regular.icon()                    // 20x20 (default)
Ph.checkCircle.fill.icon(size: 16)         // 16x16
Ph.pauseCircle.fill.icon(size: 60)         // 60x60 (hero)

// With color
Ph.checkCircle.fill
    .icon()
    .foregroundStyle(DesignTokens.ColorToken.State.success)

// The helper replaces this verbose chain:
// Ph.timer.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
```

### Rules

| Rule | Value |
|------|-------|
| Default weight | `regular` |
| Filled variant | `fill` (only for active/highlighted states) |
| Inline / toolbar size | 20x20 |
| Primary action size | 24x24 |
| Hero / empty state size | 60-70 |
| Mixed weights | Avoid — use consistently `regular` or `fill` |

### Labels

Use closure-based `Label` instead of `systemImage`:

```swift
// Correct
Label { Text("Start workout") } icon: { Ph.play.fill.icon() }

// Wrong — uses SF Symbols
Label("Start workout", systemImage: "play.fill")
```

### Icon reference

| Usage | Icon |
|-------|------|
| Workout / barbell | `Ph.barbell.regular` |
| Timer | `Ph.timer.regular` |
| Set completed | `Ph.checkCircle.fill` (.success) |
| Set pending | `Ph.circle.regular` (.secondary) |
| Pause | `Ph.pauseCircle.fill` (.warning) |
| Play / start | `Ph.play.fill` |
| Add | `Ph.plusCircle.fill` |
| Duplicate | `Ph.copySimple.regular` |
| Favorite | `Ph.star.fill` (.warning) |
| More / menu | `Ph.dotsThreeCircle.regular` |
| Next exercise | `Ph.arrowCircleDown.regular` |
| Chevron right | `Ph.caretRight.regular` |
| Calories / fire | `Ph.flame.regular` (.warning) |
| Heart rate | `Ph.heart.fill` (.error) |
| Share | `Ph.shareFat.regular` |
| Trophy / PR | `Ph.trophy.fill` (.warning) |
| Superset link | `Ph.link.fill` (.warning) |
| Notes | `Ph.notepad.regular` |
| List | `Ph.listBullets.regular` |

### Tab bar icons

The tab bar uses SF Symbols (required by SwiftUI `Tab` API):

| Tab | SF Symbol |
|-----|-----------|
| Home | `house.fill` |
| Workouts | `dumbbell.fill` |
| History | `clock.arrow.circlepath` |
| Exercises | `list.bullet` |
| Stats | `chart.bar.fill` |
| Settings | `gearshape.fill` |

---

## UI guidelines

- **Tone:** Native iOS, calm, spacious. Large tap targets. Avoid dense tables.
- **Language:** English UI text throughout the app.
- **Empty states:** Use `ContentUnavailableView` with descriptive text and action button.
- **Error handling:** `@State private var errorMessage: String?` + `.alert()` modifier — consistent pattern across all views.
- **Accessibility:** All toolbar icons and interactive icons must have `.accessibilityLabel()`.
- **Cards:** Use `.background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))` for card-style containers.
- **Navigation:** No duplicate titles — tab name serves as the page title, so `.navigationTitle` is omitted on tab root views.
