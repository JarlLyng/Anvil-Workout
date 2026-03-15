# Iron Workout

iOS-app til at planlægge og gennemføre styrketræning: opret skabeloner, kør træningen i hallen, og få det gemt i historik og Apple Health uden unødigt ballast.

**Plan din træning → træn → tryk færdig → sessionen gemmes.**

---

## Overblik

| Område | Teknologi |
|--------|-----------|
| UI | SwiftUI |
| Persistens | SwiftData |
| Health | HealthKit |
| Monitoring | Sentry (sentry-cocoa) |
| Design system | [IAMJARL Design Tokens](https://github.com/JarlLyng/iamjarl-design) |
| Ikoner | [Phosphor Icons](https://github.com/phosphor-icons/swift) |
| Sprog | Swift 5, dansk UI-tekst |

Ingen backend, login eller eksterne APIs ud over Health og Sentry.

---

## Hurtig start

```bash
git clone <repo-url>
open "Iron Workout.xcodeproj"
# Vælg scheme "Iron Workout", vælg simulator → ⌘R
```

Appen kører uden yderligere konfiguration. Øvelsesbiblioteket seedes automatisk ved første start.

Se [docs/SETUP.md](docs/SETUP.md) for fuld opsætning inkl. Sentry og HealthKit.

---

## Dokumentation

| Dokument | Indhold |
|----------|---------|
| [docs/SETUP.md](docs/SETUP.md) | Krav, installation, Sentry-konfiguration, HealthKit, secrets |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Projektstruktur, datamodel, relationer, brugerflow |
| [docs/DESIGN.md](docs/DESIGN.md) | Design system, Phosphor-ikoner, farver, UI-retningslinjer |
| [docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) | Udvikling, kodestil, tilføjelse af features, tests |

---

## Roadmap

- **Færdig (MVP):** Skabeloner, træningsflow, historik, HealthKit, Sentry, pause/skip, design tokens, Phosphor-ikoner.
- **Senere:** Apple Watch-companion, personlige rekorder, avanceret historik/statistik, export/import af skabeloner.

---

## App Store

- **Navn:** Iron Workout
- **Undertekst:** fx "Workout Planner" / "Plan and Track Workouts"
- **Positionering:** Plan din træning. Følg flowet.
