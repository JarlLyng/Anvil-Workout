//
//  ProgramLibraryEntry.swift
//  Anvil Workout
//
//  Static reference data for the pre-built program library. These are plain structs
//  (not SwiftData @Model) because they're immutable bundled content — users import
//  them as editable copies via `ProgramLibraryService.importProgram(_:modelContext:)`,
//  which produces regular WorkoutTemplate records that the user fully owns.
//

import Foundation

enum ProgramLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        }
    }
}

enum ProgramGoal: String, Codable, CaseIterable {
    case strength
    case hypertrophy
    case powerlifting
    case general

    var displayName: String {
        switch self {
        case .strength: return "Strength"
        case .hypertrophy: return "Hypertrophy"
        case .powerlifting: return "Powerlifting"
        case .general: return "General"
        }
    }
}

/// One workout within a program (e.g. "Workout A" in Starting Strength, or "Push Day" in PPL).
struct ProgramWorkout: Codable, Hashable {
    let name: String
    let exercises: [ProgramExercise]
}

/// One exercise line within a program workout, with target sets, reps, and optional
/// suggested starting weight.
struct ProgramExercise: Codable, Hashable {
    /// Name must exactly match an entry in `ExerciseLibraryService.builtinExercises`.
    /// Validated at import time.
    let exerciseName: String
    let sets: Int
    let reps: Int
    /// Suggested starting weight in kg. Users adjust during their first workout based on
    /// their own strength level. `nil` for bodyweight or unknown-weight exercises.
    let suggestedWeight: Double?
    let restSeconds: Int
    /// Optional extra guidance, e.g. "Last set AMRAP" or "Ramp up to working weight".
    let notes: String?
}

/// A complete pre-built program the user can import as a starting point.
struct ProgramLibraryEntry: Codable, Hashable, Identifiable {
    /// Stable slug used to identify the program across app versions.
    let id: String
    let name: String
    let author: String
    let level: ProgramLevel
    let goal: ProgramGoal
    let daysPerWeek: Int
    /// Typical duration in weeks before user should progress or reset. `nil` = open-ended.
    let cycleLengthWeeks: Int?
    /// Short plain-language description of the progression scheme.
    let progressionDescription: String
    /// Link to the official resource for users who want to learn more.
    let officialURL: String?
    /// One-sentence summary shown on the browse card.
    let summary: String
    let workouts: [ProgramWorkout]
}
