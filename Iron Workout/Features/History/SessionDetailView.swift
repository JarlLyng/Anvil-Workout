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
    @Environment(\.colorScheme) private var colorScheme
    var session: WorkoutSession
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

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
                        Label { Text(durationText) } icon: { Ph.timer.regular.icon(size: 18) }
                        Label { Text("\(session.completedSetCount) sets") } icon: { Ph.checkCircle.regular.icon(size: 18) }
                        Label { Text("\(session.exerciseCount) exercises") } icon: { Ph.listBullets.regular.icon(size: 18) }
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
                    Text("Exercise \(ex.sortOrder + 1)")
                }
            }

            if session.calories != nil || session.averageHeartRate != nil {
                Section("Health") {
                    if let cal = session.calories, cal > 0 {
                        Label { Text("\(Int(cal)) kcal burned") } icon: { Ph.flame.regular.icon() }
                    }
                    if let hr = session.averageHeartRate, hr > 0 {
                        Label { Text("Avg. heart rate \(Int(hr)) bpm") } icon: { Ph.heart.regular.icon() }
                    }
                }
            }
        }
        .navigationTitle("Workout")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func colorForSetType(_ type: SetType) -> Color {
        switch type {
        case .working: return .primary
        case .warmup: return DesignTokens.ColorToken.State.warning
        case .drop: return DesignTokens.Common.primary(colorScheme)
        case .failure: return DesignTokens.ColorToken.State.error
        }
    }

    private func setRow(set: PerformedSet) -> some View {
        HStack(spacing: 12) {
            Group {
                if set.isCompleted {
                    Ph.checkCircle.fill
                        .icon(size: 16)
                        .foregroundStyle(DesignTokens.ColorToken.State.success)
                } else {
                    Ph.circle.regular
                        .icon(size: 16)
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityLabel(set.isCompleted ? "Completed" : "Not completed")
            if set.isCompleted {
                if let reps = set.actualReps {
                    HStack(spacing: 4) {
                        Text("Set \(set.setIndex + 1): \(reps) reps")
                            .font(.subheadline)
                        if set.setType != .working {
                            Text("(\(set.setType.rawValue))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(colorForSetType(set.setType))
                        }
                    }
                    if let w = set.actualWeight, w > 0 {
                        Text("· \(WeightFormatter.format(kg: w, in: weightUnit))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Set \(set.setIndex + 1): Skipped")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("Set \(set.setIndex + 1): Not completed")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }
}
