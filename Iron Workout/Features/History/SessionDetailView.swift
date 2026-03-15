//
//  SessionDetailView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct SessionDetailView: View {
    var session: WorkoutSession

    private var durationText: String {
        let m = session.durationSeconds / 60
        let s = session.durationSeconds % 60
        if s > 0 { return "\(m)m \(s)s" }
        return "\(m) min"
    }

    private var sortedExercises: [WorkoutSessionExercise] {
        session.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(session.templateName)
                        .font(.title2.bold())
                    Text(session.startedAt, style: .date)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 20) {
                        Label(durationText, systemImage: "timer")
                        Label("\(session.completedSetCount) sæt", systemImage: "checkmark.circle")
                        Label("\(session.exerciseCount) øvelser", systemImage: "list.bullet")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            ForEach(sortedExercises, id: \.id) { ex in
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(ex.exerciseName)
                            .font(.headline)
                        if !ex.note.isEmpty {
                            Text(ex.note)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(ex.performedSets.sorted { $0.setIndex < $1.setIndex }, id: \.id) { set in
                            setRow(set: set)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("Øvelse \(ex.sortOrder + 1)")
                }
            }

            if session.calories != nil || session.averageHeartRate != nil {
                Section("Health") {
                    if let cal = session.calories, cal > 0 {
                        Label("\(Int(cal)) kcal forbrugt", systemImage: "flame")
                    }
                    if let hr = session.averageHeartRate, hr > 0 {
                        Label("Gns. puls \(Int(hr)) bpm", systemImage: "heart")
                    }
                }
            }
        }
        .navigationTitle("Træning")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func setRow(set: PerformedSet) -> some View {
        HStack(spacing: 12) {
            Image(systemName: set.isCompleted ? "checkmark.circle.fill" : "circle")
                .foregroundStyle(set.isCompleted ? .green : .secondary)
                .font(.caption)
            if set.isCompleted {
                if let reps = set.actualReps {
                    Text("Sæt \(set.setIndex + 1): \(reps) reps")
                        .font(.subheadline)
                    if let w = set.actualWeight, w > 0 {
                        Text("· \(w.formatted(.number.precision(.fractionLength(1)))) kg")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Sæt \(set.setIndex + 1): Spring over")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Sæt \(set.setIndex + 1): Ikke fuldført")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
