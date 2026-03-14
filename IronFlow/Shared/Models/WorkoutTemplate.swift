//
//  WorkoutTemplate.swift
//  IronFlow
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

@Model
final class WorkoutTemplate: Identifiable {
    var id: UUID
    var name: String
    var note: String
    var isFavorite: Bool
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplateExercise.template)
    var exercises: [WorkoutTemplateExercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        note: String = "",
        isFavorite: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
