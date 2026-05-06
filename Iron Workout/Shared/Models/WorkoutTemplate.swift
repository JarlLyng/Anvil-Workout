//
//  WorkoutTemplate.swift
//  Anvil Workout
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
    /// Stable slug of the program from `ProgramLibraryService` if this template was imported
    /// from the pre-built library. `nil` for user-created templates. Used to look up the
    /// original author for display (e.g. "Inspired by Rippetoe") and to group related templates.
    var sourceProgramID: String?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplateExercise.template)
    var exercises: [WorkoutTemplateExercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        note: String = "",
        isFavorite: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sourceProgramID: String? = nil
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceProgramID = sourceProgramID
    }
}
