//
//  ContentView.swift
//  IronFlow
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        TabView {
            WorkoutsView()
                .tabItem {
                    Label("Træning", systemImage: "figure.strengthtraining.traditional")
                }
            HistoryView()
                .tabItem {
                    Label("Historik", systemImage: "clock.arrow.circlepath")
                }
            ExercisesView()
                .tabItem {
                    Label("Øvelser", systemImage: "list.bullet")
                }
            SettingsView()
                .tabItem {
                    Label("Indstillinger", systemImage: "gearshape")
                }
        }
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
