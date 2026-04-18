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
    }
}
