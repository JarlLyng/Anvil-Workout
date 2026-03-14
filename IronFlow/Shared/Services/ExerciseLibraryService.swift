//
//  ExerciseLibraryService.swift
//  IronFlow
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

/// Seeds and provides the built-in exercise library.
struct ExerciseLibraryService {

    static let builtinExercises: [(name: String, muscleGroup: MuscleGroup, equipment: String)] = [
        ("Bench Press", .chest, "Barbell"),
        ("Incline Bench Press", .chest, "Barbell"),
        ("Dumbbell Bench Press", .chest, "Dumbbell"),
        ("Push-Up", .chest, "Bodyweight"),
        ("Pull-Up", .back, "Bodyweight"),
        ("Lat Pulldown", .back, "Cable"),
        ("Barbell Row", .back, "Barbell"),
        ("Seated Row", .back, "Cable"),
        ("Deadlift", .back, "Barbell"),
        ("Romanian Deadlift", .legs, "Barbell"),
        ("Back Squat", .legs, "Barbell"),
        ("Front Squat", .legs, "Barbell"),
        ("Leg Press", .legs, "Machine"),
        ("Walking Lunge", .legs, "Dumbbell"),
        ("Leg Curl", .legs, "Machine"),
        ("Leg Extension", .legs, "Machine"),
        ("Overhead Press", .shoulders, "Barbell"),
        ("Lateral Raise", .shoulders, "Dumbbell"),
        ("Face Pull", .shoulders, "Cable"),
        ("Barbell Curl", .arms, "Barbell"),
        ("Hammer Curl", .arms, "Dumbbell"),
        ("Tricep Pushdown", .arms, "Cable"),
        ("Skullcrusher", .arms, "Barbell"),
        ("Plank", .core, "Bodyweight"),
        ("Hanging Leg Raise", .core, "Bodyweight"),
    ]

    /// Seeds the model context with built-in exercises if not already present.
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.isBuiltin == true })
        let existing = (try? modelContext.fetch(descriptor)) ?? []
        if !existing.isEmpty { return }

        for item in builtinExercises {
            let exercise = Exercise(
                name: item.name,
                muscleGroup: item.muscleGroup,
                equipmentType: item.equipment,
                isBuiltin: true
            )
            modelContext.insert(exercise)
        }
        try? modelContext.save()
    }
}
