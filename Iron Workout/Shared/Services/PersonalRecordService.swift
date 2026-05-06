//
//  PersonalRecordService.swift
//  Anvil Workout
//
//  Pure, testable logic for detecting personal records. Extracted from WorkoutCompletionView
//  so the algorithm can be exercised with controlled inputs in unit tests, independent of UI.
//

import Foundation

/// A detected personal record for a single exercise in a completed workout.
struct DetectedPersonalRecord: Identifiable, Equatable {
    let id: UUID
    let exerciseName: String
    let type: PRType
    /// Display-ready description of the new record, e.g. "100 kg" or "8 reps @ 80 kg".
    let value: String
    /// Display-ready description of the previous best, or "None" if this is the first time.
    let previousBest: String

    enum PRType: String, Equatable {
        case weight
        case reps
    }

    init(
        id: UUID = UUID(),
        exerciseName: String,
        type: PRType,
        value: String,
        previousBest: String
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.type = type
        self.value = value
        self.previousBest = previousBest
    }
}

enum PersonalRecordService {

    /// Detects personal records in `currentSession` relative to the provided `history` sessions.
    ///
    /// Two kinds of PRs are detected per exercise:
    /// - **Weight PR**: max weight lifted in any completed working set is strictly greater
    ///   than any previous max for the same exercise.
    /// - **Reps PR**: within the current session, the top (reps, weight) pair is found; if
    ///   that same exercise in history has no prior set with the same or higher weight that
    ///   reached the same reps, it's a reps PR.
    ///
    /// Only working sets (`setType == .working`) are considered on both sides.
    /// Exercise identity follows `WorkoutSessionExercise.isSameExercise(as:)` — stable
    /// `exerciseID` when available, falling back to `exerciseName`.
    ///
    /// - Parameters:
    ///   - currentSession: The session whose exercises are being evaluated.
    ///   - history: All other sessions to compare against. The `currentSession` should not
    ///     be included; if it is, it will be filtered out by id.
    static func detectPersonalRecords(
        in currentSession: WorkoutSession,
        history: [WorkoutSession]
    ) -> [DetectedPersonalRecord] {
        let previousSessions = history.filter { $0.id != currentSession.id }
        var records: [DetectedPersonalRecord] = []

        for exercise in currentSession.exercises {
            let completedWorkingSets = exercise.performedSets.filter {
                $0.isCompleted && $0.setType == .working
            }
            guard !completedWorkingSets.isEmpty else { continue }

            let previousSets = previousSessions
                .flatMap(\.exercises)
                .filter { $0.isSameExercise(as: exercise) }
                .flatMap(\.performedSets)
                .filter { $0.isCompleted && $0.setType == .working }

            if let weightPR = weightPR(
                exerciseName: exercise.exerciseName,
                currentSets: completedWorkingSets,
                previousSets: previousSets
            ) {
                records.append(weightPR)
            }

            if let repsPR = repsPR(
                exerciseName: exercise.exerciseName,
                currentSets: completedWorkingSets,
                previousSets: previousSets
            ) {
                records.append(repsPR)
            }
        }

        return records
    }

    // MARK: - Weight PR

    private static func weightPR(
        exerciseName: String,
        currentSets: [PerformedSet],
        previousSets: [PerformedSet]
    ) -> DetectedPersonalRecord? {
        let currentMaxWeight = currentSets.compactMap(\.actualWeight).max() ?? 0
        guard currentMaxWeight > 0 else { return nil }

        let previousMaxWeight = previousSets.compactMap(\.actualWeight).max() ?? 0
        guard currentMaxWeight > previousMaxWeight else { return nil }

        let previousText = previousMaxWeight > 0 ? formatWeight(previousMaxWeight) : "None"
        return DetectedPersonalRecord(
            exerciseName: exerciseName,
            type: .weight,
            value: formatWeight(currentMaxWeight),
            previousBest: previousText
        )
    }

    // MARK: - Reps PR

    private static func repsPR(
        exerciseName: String,
        currentSets: [PerformedSet],
        previousSets: [PerformedSet]
    ) -> DetectedPersonalRecord? {
        let repsWeightPairs: [(reps: Int, weight: Double)] = currentSets.compactMap { set in
            guard let reps = set.actualReps, let weight = set.actualWeight else { return nil }
            return (reps, weight)
        }
        guard let current = repsWeightPairs.max(by: { a, b in
            if a.reps != b.reps { return a.reps < b.reps }
            return a.weight < b.weight
        }) else {
            return nil
        }
        guard current.reps > 0 else { return nil }

        let previousBestReps = previousSets.compactMap { set -> Int? in
            guard let reps = set.actualReps,
                  let weight = set.actualWeight,
                  weight >= current.weight else { return nil }
            return reps
        }.max() ?? 0

        guard current.reps > previousBestReps else { return nil }

        let previousText = previousBestReps > 0 ? "\(previousBestReps) reps" : "None"
        return DetectedPersonalRecord(
            exerciseName: exerciseName,
            type: .reps,
            value: "\(current.reps) reps @ \(formatWeight(current.weight))",
            previousBest: previousText
        )
    }

    // MARK: - Formatting

    private static func formatWeight(_ weight: Double) -> String {
        let unit = WeightFormatter.current
        let display = WeightFormatter.display(weight, in: unit)
        if display.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(display)) \(unit.label)"
        }
        return String(format: "%.1f \(unit.label)", display)
    }
}
