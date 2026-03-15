# Udvikling

## Kodestil

- Korte, læsbare filer — native SwiftUI.
- Undgå unødvendige dependencies.
- Dansk UI-tekst i views, engelske kodenavne (variabel- og funktionsnavne).
- Brug design tokens fra `IAMJARLDesignTokens` til farver, spacing og baggrunde — ikke hardcodede værdier.
- Brug udelukkende Phosphor-ikoner (`PhosphorSwift`) — ingen SF Symbols.

## Tilføj en ny feature

1. Opret view(s) under den relevante `Features/`-mappe. Opret en ny mappe hvis featuren ikke passer ind i en eksisterende.
2. Delte modeller tilføjes i `Shared/Models/`.
3. Delt logik/services i `Shared/Services/`.
4. Registrér nye SwiftData-modeller i `Iron_WorkoutApp.swift` schema.

## Fejlhåndtering i views

Brug dette konsistente mønster:

```swift
@State private var errorMessage: String?

// I body:
.alert("Fejl", isPresented: Binding(
    get: { errorMessage != nil },
    set: { if !$0 { errorMessage = nil } }
)) {
    Button("OK") { errorMessage = nil }
} message: {
    Text(errorMessage ?? "")
}

// Ved modelContext.save():
do {
    try modelContext.save()
} catch {
    errorMessage = "Kunne ikke gemme: \(error.localizedDescription)"
}
```

## Secrets

Hemmeligheder (fx Sentry DSN) håndteres via `.xcconfig`-filer:

1. Filen `Iron Workout/Config/Secrets.xcconfig` er **gitignored**.
2. Der ligger en `Secrets.xcconfig.example` som template.
3. Build settings læser fra xcconfig → Info.plist → koden læser fra `Bundle.main`.

Commit aldrig secrets til git.

## Tests

- Unit tests: `Iron WorkoutTests/`
- UI tests: `Iron WorkoutUITests/`
- Kør med ⌘U i Xcode.

## Git

- Branch fra `main`.
- Skriv korte, beskrivende commit-beskeder på engelsk.
- Push aldrig secrets eller `.xcuserdata`.
