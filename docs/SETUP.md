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
DeveloperSettings.xcconfig → (#include? Secrets.xcconfig) → Build Settings → Info.plist → SentryConfig.swift
```

- Target **Iron Workout** bruger `Iron Workout/Config/DeveloperSettings.xcconfig` som *base configuration*. Den inkluderer valgfrit `Secrets.xcconfig` (samme mappe), som er gitignored.
- `Info.plist` indeholder `$(SENTRY_DSN)` som Xcode ekspanderer fra build settings.
- `SentryConfig.swift` læser DSN fra `Bundle.main.infoDictionary`.
- Hvis DSN er tom eller mangler, startes Sentry ikke — appen kører normalt.

### App Store Connect: «Upload Symbols Failed» for Sentry.framework

Ved upload af arkiv kan Xcode vise en **advarsel** om, at arkivet ikke indeholder dSYM for det **forhåndsbyggede** `Sentry.framework` (SPM binary). Det er et kendt mønster: Apple forventer en dSYM med samme UUID som frameworket, men den følger ikke altid med i arkivet. **Sentry har allerede debug-filer til deres egne builds**, så crashes i SDK-kode kan stadig symboliceres i Sentry. Advarslen er derfor ofte **harmløs**; upload kan fuldføres (se fx [sentry-cocoa#6813](https://github.com/getsentry/sentry-cocoa/issues/6813)).

For **din app-kode** og øvrige frameworks: sørg for Release med **DWARF with dSYM** (allerede projektstandard) og overvej automatisk upload til Sentry (næste afsnit).

### dSYM-upload til Sentry (valgfrit, anbefalet til produktion)

Ved **Release**-build (fx Archive) kører en *Run Script*-fase `Scripts/sentry-upload-dsyms.sh`, som uploader `$DWARF_DSYM_FOLDER_PATH` med [sentry-cli](https://docs.sentry.io/cli/installation/), hvis token og org er sat.

1. Installer CLI: `brew install sentry-cli`
2. I Sentry: **Settings → Auth Tokens** — opret token med passende rettigheder til projektet.
3. I `Secrets.xcconfig` (ud over DSN), tilføj fx:
   - `SENTRY_AUTH_TOKEN = …`
   - `SENTRY_ORG = dit-org-slug`
   - `SENTRY_PROJECT = iron-workout-ios` (standard sættes også i `DeveloperSettings.xcconfig`)

Mangler token eller CLI, springer scriptet upload over med en note i build-loggen — byg fejler ikke.

Projektet har **User Script Sandboxing** slået fra (krav fra Sentry til denne type script).

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
