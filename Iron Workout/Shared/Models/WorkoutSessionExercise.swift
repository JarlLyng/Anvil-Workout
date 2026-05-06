//
//  WorkoutSessionExercise.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

@Model
final class WorkoutSessionExercise: Identifiable {
    var id: UUID
    /// Stable reference to the source Exercise. Preferred over exerciseName for identity.
    /// Optional for backward compatibility with sessions created before v1.1 — data from
    /// earlier installs is backfilled on app launch by DataMigrationService.
    var exerciseID: UUID?
    /// Snapshot of the exercise name at session creation time. Preserved intentionally so
    /// history still reads correctly if the source Exercise is renamed or deleted.
    var exerciseName: String
    var sortOrder: Int
    var note: String
    /// Rest in seconds after each set (from template).
    var restSeconds: Int?
    var supersetID: UUID?

    @Relationship(deleteRule: .cascade, inverse: \PerformedSet.sessionExercise)
    var performedSets: [PerformedSet] = []

    var session: WorkoutSession?

    init(
        id: UUID = UUID(),
        exerciseID: UUID? = nil,
        exerciseName: String,
        sortOrder: Int,
        note: String = "",
        restSeconds: Int? = nil,
        supersetID: UUID? = nil,
        performedSets: [PerformedSet] = []
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.sortOrder = sortOrder
        self.note = note
        self.restSeconds = restSeconds
        self.supersetID = supersetID
        self.performedSets = performedSets
    }
}

// MARK: - Identity helpers

extension WorkoutSessionExercise {
    /// Returns true if this session exercise represents the given `Exercise`.
    /// Prefers the stable `exerciseID` match; falls back to name match only when the ID
    /// is missing (legacy data from before v1.1).
    func matches(_ exercise: Exercise) -> Bool {
        if let exerciseID {
            return exerciseID == exercise.id
        }
        return exerciseName == exercise.name
    }

    /// Returns true if two session exercises represent the same source Exercise.
    /// Used by PR detection, stats aggregation, and history linking.
    func isSameExercise(as other: WorkoutSessionExercise) -> Bool {
        if let myID = exerciseID, let otherID = other.exerciseID {
            return myID == otherID
        }
        return exerciseName == other.exerciseName
    }
}
