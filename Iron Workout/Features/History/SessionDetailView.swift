//
//  SessionDetailView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

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
                        Label { Text(durationText) } icon: { Ph.timer.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18) }
                        Label { Text("\(session.completedSetCount) sæt") } icon: { Ph.checkCircle.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18) }
                        Label { Text("\(session.exerciseCount) øvelser") } icon: { Ph.listBullets.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 18, height: 18) }
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
                        Label { Text("\(Int(cal)) kcal forbrugt") } icon: { Ph.flame.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                    }
                    if let hr = session.averageHeartRate, hr > 0 {
                        Label { Text("Gns. puls \(Int(hr)) bpm") } icon: { Ph.heart.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                    }
                }
            }
        }
        .navigationTitle("Træning")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorForSetType(_ type: SetType) -> Color {
        switch type {
        case .working: return .primary
        case .warmup: return .orange
        case .drop: return .blue
        case .failure: return .red
        }
    }

    private func setRow(set: PerformedSet) -> some View {
        HStack(spacing: 12) {
            Group {
                if set.isCompleted {
                    Ph.checkCircle.fill
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(DesignTokens.ColorToken.State.success)
                } else {
                    Ph.circle.regular
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 16, height: 16)
            .accessibilityLabel(set.isCompleted ? "Fuldført" : "Ikke fuldført")
            if set.isCompleted {
                if let reps = set.actualReps {
                    HStack(spacing: 4) {
                        Text("Sæt \(set.setIndex + 1): \(reps) reps")
                            .font(.subheadline)
                        if set.setType != .working {
                            Text("(\(set.setType.rawValue))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(colorForSetType(set.setType))
                        }
                    }
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
