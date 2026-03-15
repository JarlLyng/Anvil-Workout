# Arkitektur

## Projektstruktur

```
Iron Workout/
├── Iron_WorkoutApp.swift              # App-entry, SwiftData container, Sentry init
├── ContentView.swift                  # Tab-bar (Træning, Historik, Øvelser, Indstillinger)
├── Info.plist                         # Merger med auto-genereret plist, SENTRY_DSN
├── Iron Workout.entitlements          # HealthKit capability
├── Config/
│   ├── Secrets.xcconfig               # Sentry DSN (gitignored)
│   └── Secrets.xcconfig.example       # Template til nye udviklere
│
├── Features/
│   ├── Workouts/                      # Skabeloner og aktiv træning
│   │   ├── WorkoutsView.swift         # Liste over programmer
│   │   ├── TemplateDetailView.swift   # Detaljevisning af skabelon
│   │   ├── CreateEditTemplateView.swift
│   │   ├── ExercisePickerView.swift   # Vælg øvelse fra bibliotek
│   │   ├── EditTemplateExerciseSheet.swift
│   │   ├── ActiveWorkoutView.swift    # Under-træning: timer, sæt, rest, pause
│   │   ├── WorkoutCompletionView.swift # Opsummering efter træning
│   │   └── EditPerformedSetSheet.swift
│   │
│   ├── History/
│   │   ├── HistoryView.swift          # Liste over afsluttede træninger
│   │   └── SessionDetailView.swift    # Detalje: øvelser, sæt-for-sæt, Health
│   │
│   ├── Exercises/
│   │   └── ExercisesView.swift        # Øvelsesbibliotek, søg, filter
│   │
│   ├── Health/
│   │   └── HealthKitService.swift     # HealthKit: tilladelser, workout start/slut
│   │
│   └── Settings/
│       └── SettingsView.swift         # Indstillinger, Health-tilladelser
│
└── Shared/
    ├── Models/                        # SwiftData-modeller
    │   ├── Exercise.swift
    │   ├── WorkoutTemplate.swift
    │   ├── WorkoutTemplateExercise.swift
    │   ├── WorkoutSession.swift
    │   ├── WorkoutSessionExercise.swift
    │   └── PerformedSet.swift
    │
    ├── Services/
    │   ├── ExerciseLibraryService.swift   # Seed af øvelsesbibliotek
    │   ├── WorkoutSessionService.swift    # Opret/afslut session fra skabelon
    │   └── SentryConfig.swift             # Læser DSN fra Info.plist
    │
    └── Components/
        └── DesignSystem.swift             # Helpers til design tokens
```

## Arkitekturprincipper

- **Feature-baseret mappestruktur** — skærme grupperet efter feature, ikke efter type.
- **Ingen ViewModel-lag** — logik ligger i services eller direkte i views, hvor det er simpelt nok. SwiftData's `@Query` og `@Bindable` erstatter meget af det en ViewModel normalt gør.
- **Single source of truth** — alle domænemodeller i `Shared/Models`, brugt af både UI og services.
- **Services til sideeffekter** — `WorkoutSessionService`, `ExerciseLibraryService` og `HealthKitService` håndterer forretningslogik uden at være bundet til UI.

---

## Datamodel (SwiftData)

### Modeller

| Model | Formål |
|-------|--------|
| **Exercise** | Én øvelse i biblioteket (navn, muskelgruppe, udstyr, `isBuiltin`) |
| **WorkoutTemplate** | Et program (navn, note, favorit, liste af øvelser) |
| **WorkoutTemplateExercise** | Én øvelse i en skabelon inkl. mål (sæt, reps, vægt, rest, note) |
| **WorkoutSession** | En gennemført træning (skabelonnavn, start/slut, varighed, kcal, puls) |
| **WorkoutSessionExercise** | Én øvelse i en session (navn, rækkefølge, rest) |
| **PerformedSet** | Ét sæt (mål/faktisk reps og vægt, completed/skipped, tidsstempel) |

### Relationer

```
WorkoutTemplate
  └── [WorkoutTemplateExercise]    (cascade delete)

WorkoutSession
  └── [WorkoutSessionExercise]     (cascade delete)
       └── [PerformedSet]          (cascade delete)

Exercise (standalone — refereres via exerciseID, slettes ikke med skabelon)
```

### Seeding

Øvelsesbiblioteket seedes i `ExerciseLibraryService.seedIfNeeded(modelContext:)` ved app-start. Der seedes kun hvis der ikke allerede findes built-in øvelser (`isBuiltin == true`).

---

## Brugerflow

```
┌─────────────┐     ┌──────────────┐     ┌──────────────────┐
│  Opret/vælg │────→│ Start træning│────→│  Aktiv træning    │
│  skabelon   │     │  fra skabelon│     │  (timer, sæt,     │
│             │     │              │     │   rest, pause)    │
└─────────────┘     └──────────────┘     └────────┬─────────┘
                                                   │
                                          ┌────────▼─────────┐
                                          │  Afslut træning   │
                                          │  (gem + Health)   │
                                          └────────┬─────────┘
                                                   │
                                          ┌────────▼─────────┐
                                          │  Historik         │
                                          │  (sessions,       │
                                          │   sæt, kcal, puls)│
                                          └──────────────────┘
```

1. **Træning-fanen:** Opret/rediger/slet/dupliker/favoritér skabeloner. Tilføj øvelser, sæt sæt/reps/vægt/rest.
2. **Aktiv træning:** Timer, HealthKit-workout, markér sæt færdig/skip, spring øvelse over, pause/genoptag, rest-timer.
3. **Afslut:** Session gemmes (varighed, sæt, evt. kcal/puls fra Health), afslutningsskærm.
4. **Historik:** Liste over sessions; detaljevisning med sæt-for-sæt og Health-data.
5. **Øvelser:** Søg og filter i det indbyggede bibliotek.
6. **Indstillinger:** Health-tilladelser.

---

## Dependencies (SPM)

| Pakke | Version | Formål |
|-------|---------|--------|
| [sentry-cocoa](https://github.com/getsentry/sentry-cocoa) | 9.7.0 | Crash reporting og performance |
| [iamjarl-design](https://github.com/JarlLyng/iamjarl-design) | branch: main | Design tokens (farver, spacing, typografi) |
| [phosphor-swift](https://github.com/phosphor-icons/swift) | 2.1.0 | Ikon-bibliotek |
