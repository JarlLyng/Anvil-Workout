//
//  ExerciseDetailView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//

import SwiftUI
import SwiftData
import Charts
import IAMJARLDesignTokens
import PhosphorSwift

struct ExerciseDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    var exercise: Exercise

    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    private var relevantSessions: [WorkoutSession] {
        sessions.filter { session in
            session.exercises.contains { $0.exerciseName == exercise.name }
        }
    }

    /// All completed working sets for this exercise across all sessions.
    private var allCompletedSets: [(set: PerformedSet, session: WorkoutSession)] {
        relevantSessions.flatMap { session in
            session.exercises
                .filter { $0.exerciseName == exercise.name }
                .flatMap { $0.performedSets }
                .filter { $0.isCompleted && $0.setType == .working }
                .map { (set: $0, session: session) }
        }
    }

    private var bestWeight: Double? {
        let weights: [Double] = allCompletedSets.compactMap { $0.set.actualWeight }
        return weights.max()
    }

    private var bestVolumeSet: (reps: Int, weight: Double)? {
        let volumeSets: [(reps: Int, weight: Double, volume: Double)] = allCompletedSets.compactMap { entry in
            guard let reps = entry.set.actualReps, let weight = entry.set.actualWeight, weight > 0 else { return nil }
            return (reps: reps, weight: weight, volume: Double(reps) * weight)
        }
        let best = volumeSets.max(by: { $0.volume < $1.volume })
        return best.map { (reps: $0.reps, weight: $0.weight) }
    }

    private var bestEstimated1RM: Double? {
        let estimates: [Double] = allCompletedSets.compactMap { entry in
            guard let reps = entry.set.actualReps, reps > 0, reps < 37,
                  let weight = entry.set.actualWeight, weight > 0 else { return nil }
            // Brzycki formula: weight × 36 / (37 - reps)
            return weight * 36.0 / (37.0 - Double(reps))
        }
        return estimates.max()
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "en_US")
        return f
    }

    var body: some View {
        List {
            // MARK: - Header
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text(exercise.name)
                        .font(.title2.bold())
                    HStack(spacing: 8) {
                        Text(exercise.muscleGroup.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !exercise.equipmentType.isEmpty {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(exercise.equipmentType)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // MARK: - Personal Records
            if !allCompletedSets.isEmpty {
                Section("Personal Records") {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        prCard(
                            title: "Best Weight",
                            value: bestWeight.map { "\($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "–",
                            icon: Ph.trophy.fill
                        )
                        prCard(
                            title: "Best Volume",
                            value: bestVolumeSet.map { "\($0.reps) × \($0.weight.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "–",
                            icon: Ph.chartBar.fill
                        )
                        prCard(
                            title: "Est. 1RM",
                            value: bestEstimated1RM.map { "\($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "–",
                            icon: Ph.lightning.fill
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                }
            }

            // MARK: - History
            Section("History") {
                if relevantSessions.isEmpty {
                    Text("No workouts with this exercise yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(relevantSessions, id: \.id) { session in
                        sessionRow(session)
                    }
                }
            }
        }
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Subviews

    private func prCard(title: String, value: String, icon: Image) -> some View {
        VStack(spacing: 6) {
            icon
                .icon(size: 22)
                .foregroundStyle(DesignTokens.Common.primary(colorScheme))
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        let exerciseEntries = session.exercises
            .filter { $0.exerciseName == exercise.name }
            .sorted { $0.sortOrder < $1.sortOrder }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(dateFormatter.string(from: session.startedAt))
                    .font(.subheadline.bold())
                Spacer()
                Text(session.templateName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(exerciseEntries, id: \.id) { entry in
                let completedSets = entry.performedSets
                    .filter { $0.isCompleted }
                    .sorted { $0.setIndex < $1.setIndex }

                ForEach(completedSets, id: \.id) { set in
                    HStack(spacing: 4) {
                        Ph.checkCircle.fill
                            .icon(size: 14)
                            .foregroundStyle(DesignTokens.ColorToken.State.success)
                        if let reps = set.actualReps {
                            Text("\(reps) reps")
                                .font(.caption)
                            if let w = set.actualWeight, w > 0 {
                                Text("× \(w.formatted(.number.precision(.fractionLength(1)))) kg")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
