//
//  WorkoutCompletionView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

struct WorkoutCompletionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]
    var session: WorkoutSession
    var onDone: () -> Void

    private var durationText: String {
        let m = session.durationSeconds / 60
        let s = session.durationSeconds % 60
        if s > 0 { return "\(m)m \(s)s" }
        return "\(m) min"
    }

    private var personalRecords: [PersonalRecord] {
        let previousSessions = allSessions.filter { $0.id != session.id }
        var records: [PersonalRecord] = []

        for exercise in session.exercises {
            let completedWorkingSets = exercise.performedSets.filter {
                $0.isCompleted && $0.setType == .working
            }
            guard !completedWorkingSets.isEmpty else { continue }

            // Find current session's max weight for this exercise
            let currentMaxWeight = completedWorkingSets.compactMap(\.actualWeight).max() ?? 0

            // Find previous best weight for same exercise name
            let previousExercises = previousSessions.flatMap(\.exercises).filter {
                $0.exerciseName == exercise.exerciseName
            }
            let previousSets = previousExercises.flatMap(\.performedSets).filter {
                $0.isCompleted && $0.setType == .working
            }
            let previousMaxWeight = previousSets.compactMap(\.actualWeight).max() ?? 0

            // Weight PR
            if currentMaxWeight > previousMaxWeight && currentMaxWeight > 0 {
                let previousText = previousMaxWeight > 0
                    ? formatWeight(previousMaxWeight)
                    : "Ingen"
                records.append(PersonalRecord(
                    exerciseName: exercise.exerciseName,
                    type: "Vægt",
                    value: formatWeight(currentMaxWeight),
                    previousBest: previousText
                ))
            }

            // Reps PR at same or higher weight
            let currentMaxRepsAtWeight: (reps: Int, weight: Double)? = completedWorkingSets
                .compactMap { set -> (reps: Int, weight: Double)? in
                    guard let reps = set.actualReps, let weight = set.actualWeight else { return nil }
                    return (reps, weight)
                }
                .max { a, b in
                    if a.reps != b.reps { return a.reps < b.reps }
                    return a.weight < b.weight
                }

            if let current = currentMaxRepsAtWeight {
                let previousBestReps = previousSets
                    .compactMap { set -> Int? in
                        guard let reps = set.actualReps,
                              let weight = set.actualWeight,
                              weight >= current.weight else { return nil }
                        return reps
                    }
                    .max() ?? 0

                if current.reps > previousBestReps && current.reps > 0 {
                    let previousText = previousBestReps > 0
                        ? "\(previousBestReps) reps"
                        : "Ingen"
                    records.append(PersonalRecord(
                        exerciseName: exercise.exerciseName,
                        type: "Reps",
                        value: "\(current.reps) reps @ \(formatWeight(current.weight))",
                        previousBest: previousText
                    ))
                }
            }
        }

        return records
    }

    private func formatWeight(_ weight: Double) -> String {
        if weight.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(weight)) kg"
        }
        return String(format: "%.1f kg", weight)
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()
            Ph.checkCircle.fill
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 70, height: 70)
                .foregroundStyle(DesignTokens.ColorToken.State.success)
            Text("Træning afsluttet")
                .font(.title.bold())
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
            VStack(spacing: DesignTokens.Spacing.sm) {
                Label { Text(session.templateName) } icon: { Ph.listBullets.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                Label { Text(durationText) } icon: { Ph.timer.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                Label { Text("\(session.completedSetCount) sæt") } icon: { Ph.checkCircle.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                Label { Text("\(session.exerciseCount) øvelser") } icon: { Ph.barbell.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
            }
            .font(.body)
            .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))

            if !personalRecords.isEmpty {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Ph.trophy.fill
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 40, height: 40)
                        .foregroundStyle(DesignTokens.ColorToken.State.warning)
                    Text("Nye personlige rekorder!")
                        .font(.headline)
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
                    ForEach(personalRecords) { record in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(record.exerciseName)
                                .font(.headline)
                                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
                            Text("Ny: \(record.value)")
                                .font(.subheadline)
                                .foregroundStyle(DesignTokens.ColorToken.State.success)
                            Text("Tidligere: \(record.previousBest)")
                                .font(.subheadline)
                                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignTokens.Spacing.md)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }

            Spacer()
            Button("Færdig") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, DesignTokens.Spacing.xxxl)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Common.Background.app(colorScheme))
        .onAppear {
            if !personalRecords.isEmpty {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }
}

private struct PersonalRecord: Identifiable {
    let id = UUID()
    let exerciseName: String
    let type: String
    let value: String
    let previousBest: String
}
