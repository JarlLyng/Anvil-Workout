//
//  SessionSummaryViews.swift
//  Anvil Workout
//
//  The parts of a finished workout, shared by the completion screen and a workout opened
//  from History: what it added up to, the records it set, and each exercise's sets.
//

import SwiftUI
import IAMJARLDesignTokens
import PhosphorSwift

/// Time, work sets and volume, how the volume compares with the last time this program
/// was trained, and Health's calories and heart rate when there are any.
struct SessionNumbersCard: View {
    let session: WorkoutSession
    /// The last workout with the same name before this one.
    let previous: WorkoutSession?
    let unit: WeightUnit

    var body: some View {
        let volume = TrainingSummary.volumeKg(of: session)
        let sets = TrainingSummary.workSetCount(of: session)
        SectionCard(title: "Summary") {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                BigNumber(
                    value: session.durationSeconds > 0 ? TrainingSummary.durationText(seconds: session.durationSeconds) : "–",
                    label: "time"
                )
                BigNumber(value: "\(sets)", label: sets == 1 ? "set" : "sets")
                BigNumber(value: WeightFormatter.volume(kg: volume, in: unit), label: "volume")
            }
            if let comparison = comparison(volume: volume) {
                Text(comparison)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            if let health = healthLine {
                Text(health)
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// "Volume up 6% on last time, 28 Sep". Nothing when either workout lifted no weight.
    private func comparison(volume: Double) -> String? {
        guard let previous else { return volume > 0 ? "First time with this program" : nil }
        guard let change = TrainingSummary.percentChange(from: TrainingSummary.volumeKg(of: previous), to: volume),
              volume > 0 else { return nil }
        let when = previous.startedAt.formatted(.dateTime.day().month(.abbreviated))
        if change == 0 { return "Same volume as last time, \(when)" }
        return "Volume \(change > 0 ? "up" : "down") \(abs(change))% on last time, \(when)"
    }

    /// "312 kcal · 128 bpm average", from Apple Health.
    private var healthLine: String? {
        var parts: [String] = []
        if let calories = session.calories, calories > 0 { parts.append("\(Int(calories)) kcal") }
        if let heartRate = session.averageHeartRate, heartRate > 0 { parts.append("\(Int(heartRate)) bpm average") }
        return parts.isEmpty ? nil : parts.joined(separator: " \u{00B7} ")
    }
}

/// The records a workout set: the new best, and the one it beat.
struct SessionRecordsCard: View {
    let records: [DetectedPersonalRecord]

    var body: some View {
        SectionCard(title: records.count == 1 ? "New record" : "New records") {
            VStack(spacing: DesignTokens.Spacing.md) {
                ForEach(records) { record in
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                        Ph.trophy.fill
                            .icon(size: 16)
                            .foregroundStyle(DesignTokens.ColorToken.State.warning)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.exerciseName)
                                .font(.subheadline.weight(.semibold))
                            Text("Before: \(record.previousBest)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(record.value)
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}

/// Each exercise on one line with its work sets, "5 × 5 · 100 kg", for the completion
/// screen.
struct SessionExercisesCard: View {
    let exercises: [WorkoutSessionExercise]
    let unit: WeightUnit

    var body: some View {
        SectionCard(title: "Exercises") {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                ForEach(exercises, id: \.id) { exercise in
                    let summary = TrainingSummary.setsSummary(TrainingSummary.workSets(of: exercise), unit: unit)
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .firstTextBaseline) {
                            name(exercise)
                            Spacer(minLength: DesignTokens.Spacing.sm)
                            sets(summary)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            name(exercise)
                            sets(summary)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    private func name(_ exercise: WorkoutSessionExercise) -> some View {
        Text(exercise.exerciseName)
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
    }

    private func sets(_ summary: String?) -> some View {
        Text(summary ?? "Not done")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(summary == nil ? .tertiary : .secondary)
    }
}

/// One exercise of a past workout, set by set: warm-ups marked W, work sets numbered,
/// drop and failure sets and RPE noted, and skipped sets kept visible.
struct SessionExerciseDetailCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let exercise: WorkoutSessionExercise
    let unit: WeightUnit

    private var sortedSets: [PerformedSet] {
        exercise.performedSets.sorted { $0.setIndex < $1.setIndex }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.exerciseName)
                    .font(.headline)
                    .accessibilityAddTraits(.isHeader)
                if !exercise.note.isEmpty {
                    Text(exercise.note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            VStack(spacing: DesignTokens.Spacing.sm) {
                let labels = setLabels
                ForEach(sortedSets, id: \.id) { set in
                    setRow(set, label: labels[set.id] ?? "")
                }
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }

    /// "W" for warm-ups, then 1, 2, 3 for the rest, so the numbers match the sets that count.
    private var setLabels: [UUID: String] {
        var number = 0
        var labels: [UUID: String] = [:]
        for set in sortedSets {
            if set.setType == .warmup {
                labels[set.id] = "W"
            } else {
                number += 1
                labels[set.id] = "\(number)"
            }
        }
        return labels
    }

    private func setRow(_ set: PerformedSet, label: String) -> some View {
        let done = set.isCompleted && set.actualReps != nil
        return HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
            Text(label)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(set.setType == .warmup ? AnyShapeStyle(DesignTokens.ColorToken.State.warning) : AnyShapeStyle(.secondary))
                .frame(width: 24, alignment: .leading)
            if done {
                Text(setText(set))
                    .font(.body.monospacedDigit())
                if set.setType == .drop || set.setType == .failure {
                    Text(set.setType.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(set.setType == .drop ? DesignTokens.Common.primary(colorScheme) : DesignTokens.ColorToken.State.error)
                }
            } else {
                Text(set.isCompleted ? "Skipped" : "Not done")
                    .font(.body)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            if done, let rpe = set.rpe {
                Text("RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))")
                    .font(.footnote.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText(set, label: label, done: done))
    }

    /// "5 × 117.5 kg", or "8 reps" without weight.
    private func setText(_ set: PerformedSet) -> String {
        let reps = set.actualReps ?? 0
        guard let kg = set.actualWeight, kg > 0 else { return reps == 1 ? "1 rep" : "\(reps) reps" }
        return "\(reps) × \(WeightFormatter.compact(kg: kg, in: unit))"
    }

    private func accessibilityText(_ set: PerformedSet, label: String, done: Bool) -> String {
        let name = set.setType == .warmup ? "Warm-up set" : "Set \(label)"
        guard done else { return "\(name), \(set.isCompleted ? "skipped" : "not done")" }
        var parts = [name, setText(set)]
        if set.setType == .drop || set.setType == .failure { parts.append(set.setType.displayName) }
        if let rpe = set.rpe { parts.append("RPE \(rpe.formatted(.number.precision(.fractionLength(0...1))))") }
        return parts.joined(separator: ", ")
    }
}
