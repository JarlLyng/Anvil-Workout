//
//  PerformedSet.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

enum SetType: String, Codable, CaseIterable {
    // IMPORTANT: raw values are SwiftData storage keys persisted in user databases.
    // The Danish strings are historical (the schema shipped with them) — DO NOT change
    // them or existing data breaks. User-facing labels live on `displayName` below.
    case working = "Arbejdssæt"
    case warmup = "Opvarmning"
    case drop = "Dropsæt"
    case failure = "Failure"

    /// English label shown in the UI and used in CSV export. Decoupled from `rawValue`
    /// so the storage key (Danish, for legacy reasons) can stay stable.
    var displayName: String {
        switch self {
        case .working: return "Working"
        case .warmup: return "Warm-up"
        case .drop: return "Drop set"
        case .failure: return "Failure"
        }
    }
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
    /// Rate of Perceived Exertion (1–10, half steps allowed). Optional and additive so
    /// existing data is unaffected; logging speed must not depend on filling it in.
    var rpe: Double?

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
        completedAt: Date? = nil,
        rpe: Double? = nil
    ) {
        self.id = id
        self.setIndex = setIndex
        self.targetReps = targetReps
        self.actualReps = actualReps
        self.targetWeight = targetWeight
        self.actualWeight = actualWeight
        self.isCompleted = isCompleted
        self.completedAt = completedAt
        self.rpe = rpe
    }
}
