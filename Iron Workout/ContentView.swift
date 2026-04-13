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
            Tab("Hjem", systemImage: "house.fill") {
                DashboardView()
            }
            Tab("Træning", systemImage: "dumbbell.fill") {
                WorkoutsView()
            }
            Tab("Historik", systemImage: "clock.arrow.counterclockwise") {
                HistoryView()
            }
            Tab("Øvelser", systemImage: "list.bullet") {
                ExercisesView()
            }
            Tab("Statistik", systemImage: "chart.bar.fill") {
                StatsView()
            }
            Tab("Indstillinger", systemImage: "gearshape.fill") {
                SettingsView()
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
