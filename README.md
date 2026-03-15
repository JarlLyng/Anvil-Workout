# Iron Workout

iOS-app til at planlægge og gennemføre styrketræning: opret skabeloner, kør træningen i hallen, og få det gemt i historik og Apple Health uden unødigt ballast.

**Kort sagt:** Plan din træning → træn → tryk færdig → sessionen gemmes.

---

## Kom i gang (ny udvikler)

### Krav

- Xcode 15+ (projektet bruger iOS 26.2 / Xcode 26 som deployment target; juster evt. i projektindstillinger)
- macOS med Xcode Command Line Tools

### Kør appen

1. Clone repo og åbn `Iron Workout.xcodeproj` i Xcode.
2. Vælg scheme **Iron Workout** og en simulator (fx iPhone 17) eller et fysisk device.
3. Run (⌘R).

Appen kører uden yderligere konfiguration. Øvelsesbiblioteket seedes automatisk ved første start.

### Sentry (fejl- og performanceovervågning)

Appen bruger [Sentry](https://sentry.io) (sentry-cocoa) til crash reporting og performance.

- **Konfiguration:** Åbn `Iron Workout/Shared/Services/SentryConfig.swift` og sæt `dsn` til din DSN-streng fra Sentry-projektet (Project Settings → Client Keys). Hvis `dsn` er `nil` eller tom, startes Sentry ikke.
- **Sentry-projekt:** `iron-workout-ios` (opret evt. projekt i Sentry og brug dens DSN).

### HealthKit på device

HealthKit virker kun på **fysisk device**. Simulator understøtter typisk ikke health data. Tilføj evt. HealthKit-capability under Signing & Capabilities i Xcode hvis den mangler på target.

---

## Tech stack

| Område        | Teknologi |
|---------------|-----------|
| UI            | SwiftUI   |
| Persistens    | SwiftData |
| Health        | HealthKit |
| Monitoring    | Sentry (sentry-cocoa) |
| Sprog         | Swift 5, dansk UI-tekst |

Ingen backend, login eller eksterne APIs ud over Health og Sentry.

---

## Projektstruktur

```
Iron Workout/
├── Iron_WorkoutApp.swift          # App-entry, SwiftData container, Sentry init
├── ContentView.swift              # Tab-bar (Træning, Historik, Øvelser, Indstillinger)
│
├── Features/
│   ├── Workouts/                  # Skabeloner og aktiv træning
│   │   ├── WorkoutsView.swift     # Liste over programmer
│   │   ├── TemplateDetailView.swift
│   │   ├── CreateEditTemplateView.swift
│   │   ├── ExercisePickerView.swift
│   │   ├── EditTemplateExerciseSheet.swift
│   │   ├── ActiveWorkoutView.swift   # Under-træning: timer, sæt, rest, pause
│   │   ├── WorkoutCompletionView.swift
│   │   └── EditPerformedSetSheet.swift
│   │
│   ├── History/
│   │   ├── HistoryView.swift      # Liste over afsluttede træninger
│   │   └── SessionDetailView.swift   # Detalje: øvelser, sæt-for-sæt, Health
│   │
│   ├── Exercises/
│   │   └── ExercisesView.swift    # Øvelsesbibliotek, søg, filter
│   │
│   ├── Health/
│   │   └── HealthKitService.swift # HealthKit: tilladelser, workout start/slut, kcal/puls
│   │
│   └── Settings/
│       └── SettingsView.swift     # Indstillinger, Health-tilladelser
│
└── Shared/
    ├── Models/                    # SwiftData-modeller
    │   ├── Exercise.swift
    │   ├── WorkoutTemplate.swift
    │   ├── WorkoutTemplateExercise.swift
    │   ├── WorkoutSession.swift
    │   ├── WorkoutSessionExercise.swift
    │   └── PerformedSet.swift
    │
    └── Services/
        ├── ExerciseLibraryService.swift   # Seed af indbygget øvelsesbibliotek
        ├── WorkoutSessionService.swift    # Opret/afslut session fra skabelon
        └── SentryConfig.swift             # DSN for Sentry (sæt her)
```

- **Features/** indeholder skærmene og flow (Workouts, History, Exercises, Health, Settings).
- **Shared/Models** er den eneste kilde til domænemodeller; de bruges af SwiftData og UI.
- **Shared/Services** bruges til bibliotek-seed, session-logik og Sentry-config.

---

## Datamodel (SwiftData)

| Model                   | Formål |
|-------------------------|--------|
| **Exercise**            | Én øvelse i biblioteket (navn, muskelgruppe, udstyr, `isBuiltin`) |
| **WorkoutTemplate**     | Et program (navn, note, favorit, rækkefølge af øvelser) |
| **WorkoutTemplateExercise** | Én øvelse i en skabelon inkl. mål (sæt, reps, vægt, rest, note) |
| **WorkoutSession**      | En gennemført træning (skabelonnavn, start/slut, varighed, kcal, puls) |
| **WorkoutSessionExercise** | Én øvelse i en session (navn, rækkefølge, rest fra skabelon) |
| **PerformedSet**        | Ét sæt (mål/ faktisk reps og vægt, completed/skipped) |

Relationer: `WorkoutTemplate` → `[WorkoutTemplateExercise]`. `WorkoutSession` → `[WorkoutSessionExercise]` → `[PerformedSet]`. Alle sammen med cascade delete hvor det giver mening.

Øvelsesbiblioteket seedes i `ExerciseLibraryService.seedIfNeeded(modelContext:)` ved app-start (kun hvis der endnu ikke findes built-in øvelser).

---

## Brugerflow (hvad appen gør)

1. **Træning-fanen:** Opret/rediger/slet/dupliker/favoritér skabeloner. Tilføj øvelser fra biblioteket, sæt sæt/reps/vægt/rest. Start træning fra en skabelon.
2. **Aktiv træning:** Timer kører, HealthKit-workout startes (hvis tilladelse). Brugeren markerer sæt som færdig eller skip, kan springe øvelse over, pause/genoptag, redigere faktiske reps/vægt. Efter hvert sæt kan rest-timer køre (fra skabelon).
3. **Afslut:** Session gemmes (varighed, sæt, evt. kcal/puls fra Health), HealthKit-workout afsluttes, afslutningsskærm vises.
4. **Historik:** Liste over sessions med dato, varighed, sæt; detaljevisning med sæt-for-sæt og evt. Health-data.
5. **Øvelser:** Søg og filter i det indbyggede bibliotek (fx ved tilføjelse til skabelon).
6. **Indstillinger:** Health-tilladelser (læs/skriv træning, puls, kalorier).

---

## Design og UI

- **Design system:** Iron Workout bruger **IAMJARL design system** ([iamjarl-design](https://github.com/JarlLyng/iamjarl-design)) via Swift Package — farver, spacing, radius og typografi kommer fra `IAMJARLDesignTokens`. Tab-bar tint og eksempelvis afslutningsskærmen er allerede opdateret; øvrige skærme kan gradvist skiftes til tokens (`.foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))`, `DesignTokens.Spacing.md`, osv.).
- **Tilføjelse:** I Xcode: File → Add Package Dependencies → `https://github.com/JarlLyng/iamjarl-design` (branch `main` indtil der er version-tags). Hjælpe-API: `Iron Workout/Shared/Components/DesignSystem.swift`.
- **Tone:** Native iOS, rolig, rummelig, store tap-targets. Undgå overfyldte tabeller og meget tekniske formularer.

---

## Konfiguration og capabilities

- **Sentry:** DSN i `Shared/Services/SentryConfig.swift`. Uden DSN kører appen normalt; Sentry slås bare ikke til.
- **HealthKit:** Entitlement `com.apple.developer.healthkit` er tilføjet (`Iron Workout.entitlements`). Info.plist-keys for Health (læs/skriv) er sat i projektets build settings.
- **Sprog:** UI er på dansk (tekster i koden og i empty states).

---

## Udvikling

- **Arkitektur:** Feature-baseret mapper, få dependencies. SwiftData + `@Query` / `@Bindable` i views. Ingen formel view-model-lag; logik i services eller direkte i views hvor det er simpelt.
- **Nye features:** Tilføj views under passende `Features/`-mappe; delte modeller i `Shared/Models`, delte services i `Shared/Services`.
- **Tests:** Unit/UI-targets findes (`Iron WorkoutTests`, `Iron WorkoutUITests`); udvid efter behov.
- **Kodestil:** Korte, læsbare filer; native SwiftUI; undgå unødvendige dependencies.

---

## Roadmap (kort)

- **Færdig (MVP):** Skabeloner, træningsflow, historik, HealthKit, Sentry, pause/skip øvelse, polish.
- **Senere:** Apple Watch-companion, personlige rekorder, mere avanceret historik/statistik, fuld UI-migration til design-tokens, export/import af skabeloner.

---

## App Store-retning

- **Navn:** Iron Workout
- **Undertekst:** fx "Workout Planner" / "Plan and Track Workouts"  
- **Positionering:** Plan din træning. Følg flowet.
