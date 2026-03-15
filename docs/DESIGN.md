# Design system

Iron Workout bruger **IAMJARL Design Tokens** ([iamjarl-design](https://github.com/JarlLyng/iamjarl-design)) og **Phosphor Icons** ([phosphor-swift](https://github.com/phosphor-icons/swift)) til et konsistent visuelt udtryk.

---

## Farver

### Accent Color (primær)

| Mode | Hex | Beskrivelse |
|------|-----|-------------|
| Light | `#CE63FF` | Lilla |
| Dark | `#D0FF00` | Neon-grøn |

Defineret i `Assets.xcassets/AccentColor.colorset` og bruges automatisk som tint-farve i hele appen.

### Design tokens

Farver tilgås via `DesignTokens` fra `IAMJARLDesignTokens`:

```swift
import IAMJARLDesignTokens

// Tekst
DesignTokens.Common.Text.primary(colorScheme)
DesignTokens.Common.Text.secondary(colorScheme)

// Baggrunde
DesignTokens.Common.Background.app(colorScheme)

// State-farver
DesignTokens.ColorToken.State.success   // grøn (afsluttet, godkendt)
DesignTokens.ColorToken.State.warning   // gul/orange (pause, rest)
DesignTokens.ColorToken.State.error     // rød (fejl, slet, puls)
```

### Spacing

```swift
DesignTokens.Spacing.sm    // lille
DesignTokens.Spacing.md    // medium
DesignTokens.Spacing.xl    // stor
DesignTokens.Spacing.xxl   // ekstra stor
DesignTokens.Spacing.xxxl  // ekstra ekstra stor
```

---

## Ikoner — Phosphor

Alle ikoner i appen er Phosphor-ikoner via `PhosphorSwift`. **Ingen SF Symbols bruges.**

### Import

```swift
import PhosphorSwift
```

### API

```swift
// Grundlæggende brug
Ph.barbell.regular          // standard-vægt
Ph.checkCircle.fill         // udfyldt variant

// Med størrelse
Ph.timer.regular
    .frame(width: 20, height: 20)

// Med farve (design token)
Ph.checkCircle.fill
    .color(DesignTokens.ColorToken.State.success)
    .frame(width: 20, height: 20)
```

### Regler

| Regel | Værdi |
|-------|-------|
| Default vægt | `regular` |
| Udfyldt variant | `fill` (kun til aktive/fremhævede states) |
| Inline / toolbar størrelse | 20×20 |
| Primary action størrelse | 24×24 |
| Hero / empty state størrelse | 60–70 |
| Blandede vægte | Undgå — brug konsekvent `regular` eller `fill` |

### Labels

Brug closure-baseret `Label` i stedet for `systemImage`:

```swift
// Korrekt
Label { Text("Start træning") } icon: { Ph.play.fill }

// Forkert — bruger SF Symbols
Label("Start træning", systemImage: "play.fill")
```

### Ikon-oversigt

| Brug | Ikon |
|------|------|
| Træning / barbell | `Ph.barbell.regular` |
| Historik / ur | `Ph.clockCounterClockwise.regular` |
| Øvelser / liste | `Ph.listBullets.regular` |
| Indstillinger / gear | `Ph.gear.regular` |
| Timer | `Ph.timer.regular` |
| Sæt færdigt | `Ph.checkCircle.fill` (.success) |
| Sæt ufærdigt | `Ph.circle.regular` (.secondary) |
| Pause | `Ph.pauseCircle.fill` (.warning) |
| Play / start | `Ph.play.fill` |
| Tilføj | `Ph.plusCircle.fill` |
| Dupliker | `Ph.copySimple.regular` |
| Favorit | `Ph.star.fill` (.yellow) |
| Filter | `Ph.funnelSimple.regular` |
| Mere / menu | `Ph.dotsThreeCircle.regular` |
| Næste øvelse | `Ph.arrowCircleDown.regular` |
| Pil højre | `Ph.caretRight.regular` |
| Kalorier / ild | `Ph.flame.regular` (.warning) |
| Puls / hjerte | `Ph.heart.regular` / `Ph.heart.fill` (.error) |
| Hjerte brudt | `Ph.heartBreak.regular` |
| Advarsel | `Ph.warningCircle.regular` |

---

## UI-retningslinjer

- **Tone:** Native iOS, rolig, rummelig. Store tap-targets. Undgå overfyldte tabeller.
- **Sprog:** Dansk UI-tekst i hele appen.
- **Empty states:** Brug `ContentUnavailableView` med Phosphor-ikon og beskrivende tekst.
- **Fejlhåndtering:** `@State private var errorMessage: String?` + `.alert()` modifier — konsekvent mønster i alle views.
- **Tilgængelighed:** Alle toolbar-ikoner og interaktive ikoner skal have `.accessibilityLabel()`.
