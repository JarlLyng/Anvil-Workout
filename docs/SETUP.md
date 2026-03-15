# Opsætning

## Krav

- **Xcode 16+** med Swift 5
- macOS med Xcode Command Line Tools
- Deployment target: iOS 17.0+

## Kør appen

1. Clone repo og åbn `Iron Workout.xcodeproj` i Xcode.
2. Vælg scheme **Iron Workout** og en simulator (fx iPhone 16) eller et fysisk device.
3. Run (⌘R).

Appen kører direkte. SPM-pakker resolves automatisk ved første åbning.

---

## Sentry (fejl- og performanceovervågning)

Appen bruger [Sentry](https://sentry.io) (sentry-cocoa) til crash reporting og performance monitoring.

### Konfiguration

Sentry DSN er **ikke hardcoded** i koden. Den læses fra en `.xcconfig`-fil via build settings og Info.plist:

1. Kopiér eksempelfilen:
   ```bash
   cp "Iron Workout/Config/Secrets.xcconfig.example" "Iron Workout/Config/Secrets.xcconfig"
   ```
2. Åbn `Iron Workout/Config/Secrets.xcconfig` og indsæt din DSN:
   ```
   SENTRY_DSN = https://<din-nøgle>@<host>.ingest.sentry.io/<projekt-id>
   ```
3. Filen er **gitignored** — den committes aldrig.

### Hvordan det virker

```
Secrets.xcconfig → Build Settings (SENTRY_DSN) → Info.plist → SentryConfig.swift
```

- `Info.plist` indeholder `$(SENTRY_DSN)` som Xcode ekspanderer fra build settings.
- `SentryConfig.swift` læser DSN fra `Bundle.main.infoDictionary`.
- Hvis DSN er tom eller mangler, startes Sentry ikke — appen kører normalt.

### Sentry-projekt

Projektnavn i Sentry: `iron-workout-ios`. Opret projekt i Sentry og brug dens DSN (Project Settings → Client Keys).

---

## HealthKit

HealthKit bruges til at gemme træninger og hente kalorier/puls fra Apple Watch eller andre kilder.

### Krav

- **Fysisk device påkrævet** — simulator understøtter ikke Health-data.
- Entitlement `com.apple.developer.healthkit` er allerede tilføjet i `Iron Workout.entitlements`.
- Info.plist-keys for Health (læs/skriv) er sat i projektets build settings.

### Tilladelser

Brugeren anmoder om Health-adgang under **Indstillinger → Health** i appen. Appen anmoder om:

- Skriv: Workouts
- Læs: Active Energy Burned, Heart Rate

### Uden HealthKit

Hvis brugeren ikke giver tilladelse, fungerer appen stadig fuldt — der gemmes bare ikke Health-data, og kcal/puls vises ikke i historikken.

---

## Encryption compliance

`ITSAppUsesNonExemptEncryption` er sat til `NO` i build settings. Appen bruger ikke kryptering ud over HTTPS (standard netværkskald til Sentry).
