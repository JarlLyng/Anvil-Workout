//
//  Iron_WorkoutApp.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import Sentry

@main
struct Iron_WorkoutApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    init() {
        if let dsn = SentryConfig.dsn, !dsn.isEmpty {
            SentrySDK.start { options in
                options.dsn = dsn
                #if DEBUG
                options.environment = "development"
                options.debug = true
                options.tracesSampleRate = 1.0
                #else
                options.environment = "production"
                options.debug = false
                options.tracesSampleRate = 0.2
                #endif
                options.attachScreenshot = true
                options.attachViewHierarchy = true
                options.enableLogs = true
                options.beforeSend = { event in
                    // Drop noise from auto-captured system NSErrors that aren't actionable:
                    // e.g. Guided Access blocking `UIApplication.open` (Sentry IOS-4).
                    let noisyDomains: Set<String> = [
                        "_UIViewServiceHostSessionErrorDomain",
                        "FBSOpenApplicationServiceErrorDomain",
                        "FBSOpenApplicationErrorDomain",
                    ]
                    if let exception = event.exceptions?.first,
                       let type = exception.type {
                        if noisyDomains.contains(type) {
                            return nil
                        }
                        // Sentry IOS-3: NSFileReadUnknownError fires on view-dismiss without
                        // an in-app stack trace. Suppressed pending repro on a real device.
                        // Re-enable by removing this branch when investigating GH #40.
                        if type == "NSCocoaErrorDomain", exception.value == "Code: 256" {
                            return nil
                        }
                    }
                    return event
                }
            }
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            WorkoutTemplateExercise.self,
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            PerformedSet.self,
        ])
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.com.iamjarl.Iron-Workout")
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            SentrySDK.capture(error: error)
            SentrySDK.flush(timeout: 2)
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                ContentView()
                    .onAppear { seedExerciseLibraryIfNeeded() }
            } else {
                OnboardingView()
                    .onAppear { seedExerciseLibraryIfNeeded() }
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private func seedExerciseLibraryIfNeeded() {
        let context = sharedModelContainer.mainContext
        ExerciseLibraryService.seedIfNeeded(modelContext: context)
        // Run after library seeding so any matching-by-name migrations have the full library available.
        DataMigrationService.runMigrationsIfNeeded(modelContext: context)
    }
}
