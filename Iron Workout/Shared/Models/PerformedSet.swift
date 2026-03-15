//
//  PerformedSet.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

@Model
final class PerformedSet: Identifiable {
    var id: UUID
    var setIndex: Int
    var targetReps: Int
    var actualReps: Int?
    var targetWeight: Double?
    var actualWeight: Double?
    var isCompleted: Bool
    var completedAt: Date?

    var sessionExercise: WorkoutSessionExercise?

    init(
        id: UUID = UUID(),
        setIndex: Int,
        targetReps: Int,
        actualReps: Int? = nil,
        targetWeight: Double? = nil,
        actualWeight: Double? = nil,
        isCompleted: Bool = false,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.setIndex = setIndex
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.targetWeight = targetWeight
        self.actualWeight = actualWeight
        self.isCompleted = isCompleted
        self.completedAt = completedAt
    }
}
