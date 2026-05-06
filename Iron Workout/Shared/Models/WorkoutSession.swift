//
//  WorkoutSession.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

@Model
final class WorkoutSession: Identifiable {
    var id: UUID
    var templateName: String
    var startedAt: Date
    var endedAt: Date?
    var durationSeconds: Int
    var exerciseCount: Int
    var completedSetCount: Int
    var calories: Double?
    var averageHeartRate: Double?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSessionExercise.session)
    var exercises: [WorkoutSessionExercise] = []

    init(
        id: UUID = UUID(),
        templateName: String,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        durationSeconds: Int = 0,
        exerciseCount: Int = 0,
        completedSetCount: Int = 0,
        calories: Double? = nil,
        averageHeartRate: Double? = nil
    ) {
        self.id = id
        self.templateName = templateName
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.durationSeconds = durationSeconds
        self.exerciseCount = exerciseCount
        self.completedSetCount = completedSetCount
        self.calories = calories
        self.averageHeartRate = averageHeartRate
    }
}
