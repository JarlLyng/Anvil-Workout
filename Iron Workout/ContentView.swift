//
//  ContentView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Hjem", systemImage: "house.fill")
                }
            WorkoutsView()
                .tabItem {
                    Label("Træning", systemImage: "dumbbell.fill")
                }
            HistoryView()
                .tabItem {
                    Label("Historik", systemImage: "clock.arrow.counterclockwise")
                }
            ExercisesView()
                .tabItem {
                    Label("Øvelser", systemImage: "list.bullet")
                }
            StatsView()
                .tabItem {
                    Label("Statistik", systemImage: "chart.bar.fill")
                }
            SettingsView()
                .tabItem {
                    Label("Indstillinger", systemImage: "gearshape.fill")
                }
        }
        .tint(DesignTokens.Common.primary(colorScheme))
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
