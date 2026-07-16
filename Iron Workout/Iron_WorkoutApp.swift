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
                // Privacy-first (portfolio DNA): crash reporting only. No performance
                // tracing on real users, and no crash screenshot / view hierarchy, which
                // can capture on-screen data. Debug keeps tracing for local diagnosis.
                #if DEBUG
                options.environment = "development"
                options.debug = true
                options.tracesSampleRate = 1.0
                options.attachScreenshot = true
                options.attachViewHierarchy = true
                #else
                options.environment = "production"
                options.debug = false
                options.tracesSampleRate = 0
                #endif
                options.enableLogs = true
                options.beforeSend = { event in
                    // Drop noise from auto-captured system NSErrors that aren't actionable.
                    // Each entry below has a corresponding Sentry issue (IOS-N) we've
                    // confirmed is not a bug but a system signal we can't act on.
                    let noisyDomains: Set<String> = [
                        // IOS-4: Guided Access blocking UIApplication.open
                        "_UIViewServiceHostSessionErrorDomain",
                        "FBSOpenApplicationServiceErrorDomain",
                        "FBSOpenApplicationErrorDomain",
                    ]
                    if let exception = event.exceptions?.first,
                       let type = exception.type {
                        if noisyDomains.contains(type) {
                            return nil
                        }
                        // IOS-1: HealthKit code 11 = HKErrorAuthorizationDenied. Expected
                        // user behaviour (declined permission), not a bug. We still want
                        // other HealthKit errors (e.g. authorization changes mid-workout),
                        // so we filter only code 11.
                        if type == "com.apple.healthkit", exception.value == "Code: 11" {
                            return nil
                        }
                        // IOS-2: ActivityKit.ActivityAuthorization unsupportedTarget.
                        // Means Live Activity isn't supported on the device or in the
                        // current iOS region — nothing to fix in the app.
                        if type == "com.apple.ActivityKit.ActivityAuthorization",
                           exception.value?.contains("unsupportedTarget") == true {
                            return nil
                        }
                        // IOS-6/IOS-7: WatchConnectivity errors on devices with no usable
                        // watch — deviceNotPaired (7005), watchAppNotInstalled (7006),
                        // notReachable (7007), deliveryFailed (7014). Expected, not bugs.
                        // The send paths already guard on isPaired/isWatchAppInstalled;
                        // this catches any that slip through (e.g. unpair mid-send).
                        if type == "WCErrorDomain",
                           let value = exception.value,
                           ["Code: 7005", "Code: 7006", "Code: 7007", "Code: 7014"].contains(value) {
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
            RootView()
                .modelContainer(sharedModelContainer)
                .onAppear {
                    seedExerciseLibraryIfNeeded()
                    WatchStatsBroadcaster.broadcast(from: sharedModelContainer.mainContext)
                }
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
