//
//  WorkoutSessionExercise.swift
//  IronFlow
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

@Model
final class WorkoutSessionExercise: Identifiable {
    var id: UUID
    var exerciseName: String
    var sortOrder: Int
    var note: String
    /// Rest i sekunder efter hvert sæt (fra skabelon).
    var restSeconds: Int?

    @Relationship(deleteRule: .cascade, inverse: \PerformedSet.sessionExercise)
    var performedSets: [PerformedSet] = []

    var session: WorkoutSession?

    init(
        id: UUID = UUID(),
        exerciseName: String,
        sortOrder: Int,
        note: String = "",
        restSeconds: Int? = nil,
        performedSets: [PerformedSet] = []
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.sortOrder = sortOrder
        self.note = note
        self.restSeconds = restSeconds
        self.performedSets = performedSets
    }
}
