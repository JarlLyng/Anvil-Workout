//
//  ContentView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

struct ContentView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TabView {
            WorkoutsView()
                .tabItem {
                    Label { Text("Træning") } icon: { Ph.barbell.regular.frame(width: 24, height: 24) }
                }
            HistoryView()
                .tabItem {
                    Label { Text("Historik") } icon: { Ph.clockCounterClockwise.regular.frame(width: 24, height: 24) }
                }
            ExercisesView()
                .tabItem {
                    Label { Text("Øvelser") } icon: { Ph.listBullets.regular.frame(width: 24, height: 24) }
                }
            SettingsView()
                .tabItem {
                    Label { Text("Indstillinger") } icon: { Ph.gear.regular.frame(width: 24, height: 24) }
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
