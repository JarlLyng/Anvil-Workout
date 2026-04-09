//
//  PerformedSet.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

enum SetType: String, Codable, CaseIterable {
    case working = "Arbejdssæt"
    case warmup = "Opvarmning"
    case drop = "Dropsæt"
    case failure = "Failure"
}

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
    var setTypeRaw: String = SetType.working.rawValue

    var setType: SetType {
        get { SetType(rawValue: setTypeRaw) ?? .working }
        set { setTypeRaw = newValue.rawValue }
    }

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
