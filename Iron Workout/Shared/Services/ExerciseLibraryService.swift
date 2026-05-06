//
//  ExerciseLibraryService.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData
import Sentry

struct ExerciseLibraryService {

    /// Built-in exercise library. Alphabetized within each muscle group for easier maintenance.
    /// When adding new exercises, simply append to the relevant section — `seedIfNeeded` will
    /// insert missing exercises on next app launch without duplicating existing ones.
    static let builtinExercises: [(name: String, muscleGroup: MuscleGroup, equipment: String)] = [

        // MARK: - Chest
        ("Bench Press", .chest, "Barbell"),
        ("Cable Fly", .chest, "Cable"),
        ("Decline Bench Press", .chest, "Barbell"),
        ("Dip", .chest, "Bodyweight"),
        ("Dumbbell Bench Press", .chest, "Dumbbell"),
        ("Dumbbell Fly", .chest, "Dumbbell"),
        ("Incline Bench Press", .chest, "Barbell"),
        ("Machine Chest Press", .chest, "Machine"),
        ("Push-Up", .chest, "Bodyweight"),

        // MARK: - Back
        ("Barbell Row", .back, "Barbell"),
        ("Cable Row", .back, "Cable"),
        ("Chin-Up", .back, "Bodyweight"),
        ("Deadlift", .back, "Barbell"),
        ("Lat Pulldown", .back, "Cable"),
        ("Pendlay Row", .back, "Barbell"),
        ("Pull-Up", .back, "Bodyweight"),
        ("Reverse Fly", .back, "Dumbbell"),
        ("Seated Row", .back, "Cable"),
        ("Shrug", .back, "Barbell"),
        ("Straight-Arm Pulldown", .back, "Cable"),
        ("T-Bar Row", .back, "Barbell"),

        // MARK: - Legs
        ("Back Squat", .legs, "Barbell"),
        ("Bulgarian Split Squat", .legs, "Dumbbell"),
        ("Front Squat", .legs, "Barbell"),
        ("Glute Bridge", .legs, "Barbell"),
        ("Goblet Squat", .legs, "Dumbbell"),
        ("Hack Squat", .legs, "Machine"),
        ("Hip Thrust", .legs, "Barbell"),
        ("Leg Curl", .legs, "Machine"),
        ("Leg Extension", .legs, "Machine"),
        ("Leg Press", .legs, "Machine"),
        ("Romanian Deadlift", .legs, "Barbell"),
        ("Seated Calf Raise", .legs, "Machine"),
        ("Standing Calf Raise", .legs, "Barbell"),
        ("Stiff-Leg Deadlift", .legs, "Barbell"),
        ("Sumo Deadlift", .legs, "Barbell"),
        ("Walking Lunge", .legs, "Dumbbell"),

        // MARK: - Shoulders
        ("Arnold Press", .shoulders, "Dumbbell"),
        ("Dumbbell Shoulder Press", .shoulders, "Dumbbell"),
        ("Face Pull", .shoulders, "Cable"),
        ("Front Raise", .shoulders, "Dumbbell"),
        ("Lateral Raise", .shoulders, "Dumbbell"),
        ("Overhead Press", .shoulders, "Barbell"),
        ("Rear Delt Fly", .shoulders, "Dumbbell"),
        ("Upright Row", .shoulders, "Barbell"),

        // MARK: - Arms
        ("Barbell Curl", .arms, "Barbell"),
        ("Cable Curl", .arms, "Cable"),
        ("Close-Grip Bench Press", .arms, "Barbell"),
        ("Concentration Curl", .arms, "Dumbbell"),
        ("Hammer Curl", .arms, "Dumbbell"),
        ("Incline Dumbbell Curl", .arms, "Dumbbell"),
        ("Overhead Tricep Extension", .arms, "Dumbbell"),
        ("Preacher Curl", .arms, "Barbell"),
        ("Reverse Curl", .arms, "Barbell"),
        ("Rope Pushdown", .arms, "Cable"),
        ("Skullcrusher", .arms, "Barbell"),
        ("Tricep Dip", .arms, "Bodyweight"),
        ("Tricep Pushdown", .arms, "Cable"),

        // MARK: - Core
        ("Ab Wheel Rollout", .core, "Bodyweight"),
        ("Cable Woodchop", .core, "Cable"),
        ("Crunch", .core, "Bodyweight"),
        ("Decline Crunch", .core, "Bodyweight"),
        ("Hanging Leg Raise", .core, "Bodyweight"),
        ("Pallof Press", .core, "Cable"),
        ("Plank", .core, "Bodyweight"),
        ("Russian Twist", .core, "Dumbbell"),
        ("Side Plank", .core, "Bodyweight"),
        ("Sit-Up", .core, "Bodyweight"),

        // MARK: - Full Body / Olympic
        ("Clean and Press", .fullBody, "Barbell"),
        ("Power Clean", .fullBody, "Barbell"),
    ]

    /// Seeds the built-in exercise library, inserting any exercises that don't already exist
    /// (matched by name). Safe to call on every app launch — existing exercises are untouched,
    /// and new entries in `builtinExercises` are added incrementally across app updates.
    static func seedIfNeeded(modelContext: ModelContext) {
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.isBuiltin == true })
        let existing: [Exercise]
        do {
            existing = try modelContext.fetch(descriptor)
        } catch {
            SentrySDK.capture(error: error)
            existing = []
        }

        let existingNames = Set(existing.map(\.name))
        var insertedCount = 0

        for item in builtinExercises where !existingNames.contains(item.name) {
            let exercise = Exercise(
                name: item.name,
                muscleGroup: item.muscleGroup,
                equipmentType: item.equipment,
                isBuiltin: true
            )
            modelContext.insert(exercise)
            insertedCount += 1
        }

        guard insertedCount > 0 else { return }

        do {
            try modelContext.save()
        } catch {
            SentrySDK.capture(error: error)
        }
    }
}
