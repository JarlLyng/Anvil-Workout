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

    /// User-assigned tags for grouping and filtering templates (e.g. "Hypertrophy",
    /// "Powerlifting", "Deload"). Defaults to empty so existing data is unaffected.
    var tags: [String] = []

    @Relationship(deleteRule: .cascade, inverse: \WorkoutTemplateExercise.template)
    var exercises: [WorkoutTemplateExercise] = []

    init(
        id: UUID = UUID(),
        name: String,
        note: String = "",
        isFavorite: Bool = false,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        sourceProgramID: String? = nil,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.isFavorite = isFavorite
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.sourceProgramID = sourceProgramID
        self.tags = tags
    }
}

// MARK: - Tag helpers

enum TemplateTag {
    /// Normalizes a raw tag: trims whitespace and collapses internal runs of spaces.
    static func normalize(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(whereSeparator: { $0 == " " || $0 == "\t" })
            .joined(separator: " ")
    }

    /// Returns `tags` with `raw` appended, unless it is blank or a case-insensitive
    /// duplicate. Preserves the casing already stored.
    static func adding(_ raw: String, to tags: [String]) -> [String] {
        let normalized = normalize(raw)
        guard !normalized.isEmpty else { return tags }
        if tags.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame }) {
            return tags
        }
        return tags + [normalized]
    }
}
