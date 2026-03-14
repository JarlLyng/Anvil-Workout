//
//  Exercise.swift
//  IronFlow
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

/// Muscle group for filtering the exercise library.
enum MuscleGroup: String, Codable, CaseIterable {
    case chest = "Chest"
    case back = "Back"
    case legs = "Legs"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case core = "Core"
    case fullBody = "Full Body"
}

@Model
final class Exercise: Identifiable {
    var id: UUID
    var name: String
    var muscleGroupRaw: String
    var equipmentType: String
    var isBuiltin: Bool

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleGroupRaw) ?? .fullBody }
        set { muscleGroupRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        muscleGroup: MuscleGroup,
        equipmentType: String = "",
        isBuiltin: Bool = false
    ) {
        self.id = id
        self.name = name
        self.muscleGroupRaw = muscleGroup.rawValue
        self.equipmentType = equipmentType
        self.isBuiltin = isBuiltin
    }
}
