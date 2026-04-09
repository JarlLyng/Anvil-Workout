//
//  WorkoutTemplateExercise.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

@Model
final class WorkoutTemplateExercise: Identifiable {
    var id: UUID
    var exerciseID: UUID
    var sortOrder: Int
    var targetSets: Int
    var targetReps: Int
    var targetWeight: Double?
    var restSeconds: Int?
    var note: String
    var supersetID: UUID?

    var template: WorkoutTemplate?

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        sortOrder: Int,
        targetSets: Int = 3,
        targetReps: Int = 10,
        targetWeight: Double? = nil,
        restSeconds: Int? = 90,
        note: String = "",
        supersetID: UUID? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.sortOrder = sortOrder
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.restSeconds = restSeconds
        self.note = note
        self.supersetID = supersetID
    }
}
