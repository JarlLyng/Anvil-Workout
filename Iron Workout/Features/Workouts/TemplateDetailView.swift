//
//  TemplateDetailView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

struct TemplateDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: WorkoutTemplate
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @State private var activeSession: WorkoutSession?
    @State private var errorMessage: String?

    private var sortedExercises: [WorkoutTemplateExercise] {
        template.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func exerciseName(for exerciseID: UUID) -> String {
        allExercises.first { $0.id == exerciseID }?.name ?? "Unknown exercise"
    }

    var body: some View {
        List {
            Section {
                Text(template.name.isEmpty ? "Untitled" : template.name)
                    .font(.title2.bold())
                if !template.note.isEmpty {
                    Text(template.note)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Exercises") {
                if sortedExercises.isEmpty {
                    ContentUnavailableView {
                        Label("No Exercises", systemImage: "list.bullet")
                    } description: {
                        Text("Add exercises by tapping Edit above.")
                    }
                } else {
                    ForEach(sortedExercises, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exerciseName(for: item.exerciseID))
                                .font(.headline)
                            Text("\(item.targetSets) sets x \(item.targetReps) reps")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let w = item.targetWeight, w > 0 {
                                Text("\(w, specifier: "%.1f") kg")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let r = item.restSeconds, r > 0 {
                                Text("\(r) s rest")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    CreateEditTemplateView(template: template)
                } label: {
                    Text("Edit")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    startWorkout()
                } label: {
                    Label { Text("Start Workout") } icon: { Ph.play.fill.icon() }
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                .disabled(sortedExercises.isEmpty)
            }
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .fullScreenCover(item: $activeSession) { session in
            ActiveWorkoutView(
                session: session,
                onComplete: { },
                onEndWorkout: { activeSession = nil }
            )
        }
    }

    private func startWorkout() {
        do {
            let session = try WorkoutSessionService.createSession(from: template, modelContext: modelContext)
            activeSession = session
        } catch {
            errorMessage = "Could not start workout: \(error.localizedDescription)"
        }
    }
}
