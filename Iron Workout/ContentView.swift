//
//  ContentView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import Sentry
import IAMJARLDesignTokens

/// Top-level destinations shared between the iPhone tab bar and the iPad
/// sidebar. Adding a new tab? Add it here once and it appears in both layouts.
enum RootDestination: String, CaseIterable, Identifiable, Hashable {
    case home
    case workouts
    case exercises
    case stats
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: "Home"
        case .workouts: "Workouts"
        case .exercises: "Exercises"
        case .stats: "Stats"
        case .settings: "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .workouts: "dumbbell.fill"
        case .exercises: "list.bullet"
        case .stats: "chart.bar.fill"
        case .settings: "gearshape.fill"
        }
    }
}

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// A workout that was started but never finalized. Detected on launch — see #48.
    @State private var staleSession: WorkoutSession?
    @State private var staleSessionError: String?

    /// iPad sidebar selection. Ignored on iPhone (TabView manages its own selection).
    @State private var selectedDestination: RootDestination? = .home

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .tint(DesignTokens.Common.primary(colorScheme))
        .task { checkForStaleSession() }
        .alert(
            "Unfinished workout",
            isPresented: Binding(get: { staleSession != nil }, set: { if !$0 { staleSession = nil } })
        ) {
            Button("Save Workout") { saveStaleSession() }
            Button("Discard", role: .destructive) { discardStaleSession() }
        } message: {
            if let s = staleSession {
                Text(staleSessionPrompt(for: s))
            }
        }
        .alert(
            "Error",
            isPresented: Binding(get: { staleSessionError != nil }, set: { if !$0 { staleSessionError = nil } })
        ) {
            Button("OK") { staleSessionError = nil }
        } message: {
            Text(staleSessionError ?? "")
        }
    }

    // MARK: - Layouts

    private var iPhoneLayout: some View {
        TabView {
            ForEach(RootDestination.allCases) { destination in
                destinationView(destination)
                    .tabItem {
                        Label(destination.title, systemImage: destination.systemImage)
                    }
            }
        }
    }

    private var iPadLayout: some View {
        NavigationSplitView {
            List(RootDestination.allCases, selection: $selectedDestination) { destination in
                NavigationLink(value: destination) {
                    Label(destination.title, systemImage: destination.systemImage)
                }
            }
            .navigationTitle("Anvil")
            .navigationSplitViewColumnWidth(min: 200, ideal: 240, max: 280)
        } detail: {
            if let destination = selectedDestination {
                destinationView(destination)
            } else {
                ContentUnavailableView("Select a tab",
                                       systemImage: "sidebar.left",
                                       description: Text("Pick a section from the sidebar."))
            }
        }
    }

    @ViewBuilder
    private func destinationView(_ destination: RootDestination) -> some View {
        switch destination {
        case .home: DashboardView()
        case .workouts: WorkoutsView()
        case .exercises: ExercisesView()
        case .stats: StatsView()
        case .settings: SettingsView()
        }
    }

    // MARK: - Stale session handling

    private func checkForStaleSession() {
        staleSession = WorkoutSessionService.findStaleSession(modelContext: modelContext)
    }

    private func staleSessionPrompt(for session: WorkoutSession) -> String {
        let endDate = WorkoutSessionService.bestGuessEndDate(for: session)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        let relative = formatter.localizedString(for: session.startedAt, relativeTo: .now)
        let completedSets = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count

        if completedSets > 0 {
            let durationMin = max(1, Int(endDate.timeIntervalSince(session.startedAt) / 60))
            return "You started \(session.templateName) \(relative) and logged \(completedSets) set\(completedSets == 1 ? "" : "s") over \(durationMin) min, but never tapped End. Save it to your history?"
        } else {
            return "You started \(session.templateName) \(relative) but didn't log any sets. Discard it?"
        }
    }

    private func saveStaleSession() {
        guard let session = staleSession else { return }
        let endDate = WorkoutSessionService.bestGuessEndDate(for: session)
        let context = modelContext

        Task {
            // Write to Apple Health retroactively if authorized — does nothing if user denied.
            let health = HealthKitService.shared
            if health.isAvailable {
                do {
                    let result = try await health.saveCompletedWorkout(
                        startDate: session.startedAt,
                        endDate: endDate
                    )
                    await MainActor.run {
                        session.calories = result.calories
                        session.averageHeartRate = result.averageHeartRate
                    }
                } catch {
                    SentrySDK.capture(error: error)
                }
            }
            await MainActor.run {
                do {
                    try WorkoutSessionService.finalizeSession(session, endedAt: endDate, modelContext: context)
                } catch {
                    SentrySDK.capture(error: error)
                    staleSessionError = "Could not save the workout: \(error.localizedDescription)"
                }
                staleSession = nil
            }
        }
    }

    private func discardStaleSession() {
        guard let session = staleSession else { return }
        do {
            try WorkoutSessionService.discardSession(session, modelContext: modelContext)
        } catch {
            SentrySDK.capture(error: error)
            staleSessionError = "Could not discard the session: \(error.localizedDescription)"
        }
        staleSession = nil
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [
            Exercise.self,
            WorkoutTemplate.self,
            WorkoutTemplateExercise.self,
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            PerformedSet.self
        ], inMemory: true)
}
