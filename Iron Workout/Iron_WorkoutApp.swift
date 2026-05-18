//
//  Iron_WorkoutApp.swift
//  Anvil Workout
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
                        // Sentry IOS-3 (NSCocoaErrorDomain 256) was previously suppressed
                        // pending repro. Now re-enabled — v1.1.0 fixes the suspected root
                        // cause (widget extension declared a partial SwiftData schema for
                        // the shared App Group store, which could corrupt store state on
                        // every widget refresh). We need this signal back to verify whether
                        // 1.1.0 actually resolved it.
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
            RootView()
                .modelContainer(sharedModelContainer)
                .onAppear { seedExerciseLibraryIfNeeded() }
        }
    }

    private func seedExerciseLibraryIfNeeded() {
        let context = sharedModelContainer.mainContext
        ExerciseLibraryService.seedIfNeeded(modelContext: context)
        // Run after library seeding so any matching-by-name migrations have the full library available.
        DataMigrationService.runMigrationsIfNeeded(modelContext: context)
    }
}

/// Hoists the universal-link handler to the top-level scene so a shared-program link
/// works from any state — onboarding, main app, foreground or cold launch. The
/// `ImportProgramSheet` is presented above whatever view is currently visible.
private struct RootView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var pendingImport: SharedProgramPayload?
    @State private var importError: String?
    @State private var importToast: String?

    var body: some View {
        Group {
            if hasSeenOnboarding {
                ContentView()
            } else {
                OnboardingView()
            }
        }
        .onOpenURL { url in
            handleIncomingURL(url)
        }
        .sheet(item: $pendingImport) { payload in
            ImportProgramSheet(payload: payload) { name in
                importToast = "\(name) added"
            }
        }
        .alert(
            "Could not open link",
            isPresented: Binding(get: { importError != nil }, set: { if !$0 { importError = nil } })
        ) {
            Button("OK") { importError = nil }
        } message: {
            Text(importError ?? "")
        }
        .overlay(alignment: .bottom) {
            if let importToast {
                Text(importToast)
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 80)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .task {
                        try? await Task.sleep(for: .seconds(2))
                        self.importToast = nil
                    }
            }
        }
        .animation(.easeInOut, value: importToast)
    }

    private func handleIncomingURL(_ url: URL) {
        guard ProgramShareService.isShareURL(url) else {
            // Not our link — ignore. iOS may pass us URLs from other handlers we
            // don't own.
            return
        }
        do {
            let payload = try ProgramShareService.decodePayload(from: url)
            pendingImport = payload
        } catch {
            SentrySDK.capture(error: error)
            importError = (error as? LocalizedError)?.errorDescription
                ?? "The shared program link couldn't be read."
        }
    }
}

extension SharedProgramPayload: Identifiable {
    /// Stable per-instance identity for `.sheet(item:)`. We don't need a real ID
    /// since the payload is presented once and dismissed.
    var id: String { name + String(exercises.count) }
}
