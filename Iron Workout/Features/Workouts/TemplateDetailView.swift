//
//  TemplateDetailView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import PhosphorSwift

struct TemplateDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: WorkoutTemplate
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @State private var activeSession: WorkoutSession?
    @State private var errorMessage: String?

    private var sortedExercises: [WorkoutTemplateExercise] {
        template.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func exerciseName(for exerciseID: UUID) -> String {
        allExercises.first { $0.id == exerciseID }?.name ?? "Ukendt øvelse"
    }

    var body: some View {
        List {
            Section {
                Text(template.name.isEmpty ? "Uden navn" : template.name)
                    .font(.title2.bold())
                if !template.note.isEmpty {
                    Text(template.note)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Øvelser") {
                if sortedExercises.isEmpty {
                    ContentUnavailableView {
                        Label("Ingen øvelser", systemImage: "list.bullet")
                    } description: {
                        Text("Tilføj øvelser ved at trykke på Rediger øverst.")
                    }
                } else {
                    ForEach(sortedExercises, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exerciseName(for: item.exerciseID))
                                .font(.headline)
                            Text("\(item.targetSets) sæt × \(item.targetReps) reps")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let w = item.targetWeight, w > 0 {
                                Text("\(w, specifier: "%.1f") kg")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let r = item.restSeconds, r > 0 {
                                Text("\(r) sek rest")
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
                    Text("Rediger")
                }
            }
            ToolbarItem(placement: .bottomBar) {
                Button {
                    startWorkout()
                } label: {
                    Label { Text("Start træning") } icon: { Ph.play.fill.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                }
                .buttonStyle(.borderedProminent)
                .disabled(sortedExercises.isEmpty)
            }
        }
        .alert("Fejl", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
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
            errorMessage = "Kunne ikke starte træning: \(error.localizedDescription)"
        }
    }
}
