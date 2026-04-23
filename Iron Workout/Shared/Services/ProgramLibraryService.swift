//
//  ProgramLibraryService.swift
//  Iron Workout
//
//  Serves the static pre-built program library and imports a program as one or
//  more editable WorkoutTemplate records.
//
//  See docs/dev/PROGRAM_LIBRARY_SPEC.md for the full research catalog of programs.
//

import Foundation
import SwiftData
import Sentry

enum ProgramLibraryService {

    // MARK: - Public library

    /// All pre-built programs available for import. Ordered by level (beginner →
    /// advanced) and then alphabetically within level for stable display order.
    static let programs: [ProgramLibraryEntry] = [
        // Beginner
        .greyskullLP,
        .startingStrength,
        .stronglifts5x5,
        // Intermediate
        .gzclp,
        .upperLower4Day,
        .ppl6Day,
    ]

    /// Programs grouped by level for browse UI.
    static func programs(for level: ProgramLevel) -> [ProgramLibraryEntry] {
        programs.filter { $0.level == level }
    }

    /// Looks up a program by its stable slug. Returns `nil` if the program has been
    /// removed in a newer app version — callers should degrade gracefully.
    static func program(withID id: String) -> ProgramLibraryEntry? {
        programs.first { $0.id == id }
    }

    // MARK: - Import

    /// Imports a program as one or more editable `WorkoutTemplate` records.
    ///
    /// Programs with multiple workouts (e.g. Starting Strength's Workout A and B) produce
    /// one template per workout, named `"\(program.name) — \(workout.name)"`. Programs
    /// with a single workout produce one template named after the program itself.
    ///
    /// All exercises in the program are resolved against the current `Exercise` library
    /// by name — unknown names are logged to Sentry and skipped. This shouldn't happen
    /// in production because the library and programs are curated together; the fallback
    /// keeps the import partially useful if the library drifts ahead of our curated set.
    ///
    /// - Returns: The newly created templates, in the order they were created.
    @discardableResult
    static func importProgram(
        _ entry: ProgramLibraryEntry,
        modelContext: ModelContext
    ) throws -> [WorkoutTemplate] {
        let allExercises = try modelContext.fetch(FetchDescriptor<Exercise>())
        let exerciseByName = Dictionary(allExercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        var createdTemplates: [WorkoutTemplate] = []

        for workout in entry.workouts {
            let templateName = entry.workouts.count == 1
                ? entry.name
                : "\(entry.name) — \(workout.name)"

            let template = WorkoutTemplate(
                name: templateName,
                note: entry.summary,
                sourceProgramID: entry.id
            )
            modelContext.insert(template)

            for (sortOrder, programExercise) in workout.exercises.enumerated() {
                guard let exercise = exerciseByName[programExercise.exerciseName] else {
                    let missing = programExercise.exerciseName
                    SentrySDK.capture(
                        message: "ProgramLibrary import: exercise '\(missing)' not in library (program: \(entry.id))"
                    )
                    continue
                }
                let te = WorkoutTemplateExercise(
                    exerciseID: exercise.id,
                    sortOrder: sortOrder,
                    targetSets: programExercise.sets,
                    targetReps: programExercise.reps,
                    targetWeight: programExercise.suggestedWeight,
                    restSeconds: programExercise.restSeconds,
                    note: programExercise.notes ?? ""
                )
                te.template = template
                template.exercises.append(te)
                modelContext.insert(te)
            }

            createdTemplates.append(template)
        }

        try modelContext.save()
        return createdTemplates
    }
}

// MARK: - Built-in programs

private extension ProgramLibraryEntry {

    static let startingStrength = ProgramLibraryEntry(
        id: "starting-strength",
        name: "Starting Strength",
        author: "Mark Rippetoe",
        level: .beginner,
        goal: .strength,
        daysPerWeek: 3,
        cycleLengthWeeks: nil,
        progressionDescription: "Add 2.5 kg to upper body lifts and 5 kg to lower body lifts every session. Deadlift progresses 5 kg per session. Run until lifts stall, then switch to an intermediate program.",
        officialURL: "https://startingstrength.com",
        summary: "Classic beginner strength program. Squat every session, alternating push/pull and deadlift/row.",
        workouts: [
            ProgramWorkout(
                name: "Workout A",
                exercises: [
                    ProgramExercise(exerciseName: "Back Squat", sets: 3, reps: 5, suggestedWeight: 40, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Overhead Press", sets: 3, reps: 5, suggestedWeight: 20, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Deadlift", sets: 1, reps: 5, suggestedWeight: 60, restSeconds: 240, notes: nil),
                ]
            ),
            ProgramWorkout(
                name: "Workout B",
                exercises: [
                    ProgramExercise(exerciseName: "Back Squat", sets: 3, reps: 5, suggestedWeight: 40, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Bench Press", sets: 3, reps: 5, suggestedWeight: 30, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Barbell Row", sets: 3, reps: 5, suggestedWeight: 30, restSeconds: 180, notes: "Power Clean is the classic alternative if you're trained in it."),
                ]
            ),
        ]
    )

    static let stronglifts5x5 = ProgramLibraryEntry(
        id: "stronglifts-5x5",
        name: "StrongLifts 5×5",
        author: "Mehdi Hadim",
        level: .beginner,
        goal: .strength,
        daysPerWeek: 3,
        cycleLengthWeeks: nil,
        progressionDescription: "Add 2.5 kg per session on all lifts except Deadlift. Deadlift progresses 5 kg per session. Deload 10% after failing a lift three sessions in a row.",
        officialURL: "https://stronglifts.com",
        summary: "Five sets of five on three compound lifts per workout. High volume, high frequency, linear progression.",
        workouts: [
            ProgramWorkout(
                name: "Workout A",
                exercises: [
                    ProgramExercise(exerciseName: "Back Squat", sets: 5, reps: 5, suggestedWeight: 40, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Bench Press", sets: 5, reps: 5, suggestedWeight: 30, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Barbell Row", sets: 5, reps: 5, suggestedWeight: 30, restSeconds: 180, notes: nil),
                ]
            ),
            ProgramWorkout(
                name: "Workout B",
                exercises: [
                    ProgramExercise(exerciseName: "Back Squat", sets: 5, reps: 5, suggestedWeight: 40, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Overhead Press", sets: 5, reps: 5, suggestedWeight: 20, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Deadlift", sets: 1, reps: 5, suggestedWeight: 60, restSeconds: 240, notes: nil),
                ]
            ),
        ]
    )

    static let greyskullLP = ProgramLibraryEntry(
        id: "greyskull-lp",
        name: "Greyskull LP",
        author: "John Sheaffer",
        level: .beginner,
        goal: .strength,
        daysPerWeek: 3,
        cycleLengthWeeks: 12,
        progressionDescription: "Add 2.5 kg to upper body and 5 kg to lower body after each session. Last set is AMRAP — if you hit 10+ reps, add an extra 2.5 kg on the next session's working weight.",
        officialURL: "https://amzn.to/GreyskullLP",
        summary: "Linear progression with AMRAP finishers. Great for building both strength and conditioning early on.",
        workouts: [
            ProgramWorkout(
                name: "Workout A",
                exercises: [
                    ProgramExercise(exerciseName: "Bench Press", sets: 3, reps: 5, suggestedWeight: 30, restSeconds: 180, notes: "Last set: AMRAP"),
                    ProgramExercise(exerciseName: "Barbell Row", sets: 3, reps: 5, suggestedWeight: 30, restSeconds: 180, notes: "Last set: AMRAP"),
                    ProgramExercise(exerciseName: "Back Squat", sets: 3, reps: 5, suggestedWeight: 40, restSeconds: 180, notes: "Last set: AMRAP"),
                ]
            ),
            ProgramWorkout(
                name: "Workout B",
                exercises: [
                    ProgramExercise(exerciseName: "Overhead Press", sets: 3, reps: 5, suggestedWeight: 20, restSeconds: 180, notes: "Last set: AMRAP"),
                    ProgramExercise(exerciseName: "Pull-Up", sets: 3, reps: 5, suggestedWeight: nil, restSeconds: 180, notes: "Last set: AMRAP. Lat Pulldown is a good substitute if you can't do pull-ups yet."),
                    ProgramExercise(exerciseName: "Deadlift", sets: 1, reps: 5, suggestedWeight: 60, restSeconds: 240, notes: "Last set: AMRAP"),
                ]
            ),
        ]
    )

    // MARK: - Intermediate

    static let gzclp = ProgramLibraryEntry(
        id: "gzclp",
        name: "GZCLP",
        author: "Cody Lefever",
        level: .intermediate,
        goal: .strength,
        daysPerWeek: 4,
        cycleLengthWeeks: nil,
        progressionDescription: "T1 main lift starts at 5×3+ (AMRAP on last set); after two failed sessions switch to 6×2+, then 10×1+. T2 hypertrophy starts at 3×10 and progresses through 3×8 and 3×6. Add 2.5 kg (upper) or 5 kg (lower) per session on a successful T1.",
        officialURL: "https://www.reddit.com/r/gzcl/wiki/index",
        summary: "Four-day split with three tier levels: heavy compound (T1), volume compound (T2), and accessories (T3). Great bridge from beginner to serious training.",
        workouts: [
            ProgramWorkout(
                name: "Squat Focus",
                exercises: [
                    ProgramExercise(exerciseName: "Back Squat", sets: 5, reps: 3, suggestedWeight: 60, restSeconds: 180, notes: "T1 — last set AMRAP"),
                    ProgramExercise(exerciseName: "Bench Press", sets: 3, reps: 10, suggestedWeight: 40, restSeconds: 120, notes: "T2 hypertrophy"),
                    ProgramExercise(exerciseName: "Lat Pulldown", sets: 3, reps: 15, suggestedWeight: 30, restSeconds: 90, notes: "T3 accessory"),
                ]
            ),
            ProgramWorkout(
                name: "OHP Focus",
                exercises: [
                    ProgramExercise(exerciseName: "Overhead Press", sets: 5, reps: 3, suggestedWeight: 30, restSeconds: 180, notes: "T1 — last set AMRAP"),
                    ProgramExercise(exerciseName: "Deadlift", sets: 3, reps: 10, suggestedWeight: 70, restSeconds: 180, notes: "T2 hypertrophy"),
                    ProgramExercise(exerciseName: "Barbell Row", sets: 3, reps: 15, suggestedWeight: 30, restSeconds: 90, notes: "T3 accessory"),
                ]
            ),
            ProgramWorkout(
                name: "Deadlift Focus",
                exercises: [
                    ProgramExercise(exerciseName: "Deadlift", sets: 5, reps: 3, suggestedWeight: 80, restSeconds: 240, notes: "T1 — last set AMRAP"),
                    ProgramExercise(exerciseName: "Back Squat", sets: 3, reps: 10, suggestedWeight: 50, restSeconds: 180, notes: "T2 hypertrophy"),
                    ProgramExercise(exerciseName: "Lat Pulldown", sets: 3, reps: 15, suggestedWeight: 30, restSeconds: 90, notes: "T3 accessory"),
                ]
            ),
            ProgramWorkout(
                name: "Bench Focus",
                exercises: [
                    ProgramExercise(exerciseName: "Bench Press", sets: 5, reps: 3, suggestedWeight: 50, restSeconds: 180, notes: "T1 — last set AMRAP"),
                    ProgramExercise(exerciseName: "Overhead Press", sets: 3, reps: 10, suggestedWeight: 25, restSeconds: 120, notes: "T2 hypertrophy"),
                    ProgramExercise(exerciseName: "Barbell Row", sets: 3, reps: 15, suggestedWeight: 30, restSeconds: 90, notes: "T3 accessory"),
                ]
            ),
        ]
    )

    static let upperLower4Day = ProgramLibraryEntry(
        id: "upper-lower-4day",
        name: "Upper / Lower",
        author: "Community",
        level: .intermediate,
        goal: .hypertrophy,
        daysPerWeek: 4,
        cycleLengthWeeks: nil,
        progressionDescription: "Double progression: add reps within the prescribed range, then add 2.5 kg and reset reps. Deload every 6-8 weeks. Two heavier strength days, two higher-rep hypertrophy days.",
        officialURL: nil,
        summary: "Classic four-day split alternating upper body and lower body with strength and hypertrophy emphasis. Balanced and sustainable.",
        workouts: [
            ProgramWorkout(
                name: "Upper Strength",
                exercises: [
                    ProgramExercise(exerciseName: "Bench Press", sets: 4, reps: 6, suggestedWeight: 60, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Barbell Row", sets: 4, reps: 6, suggestedWeight: 50, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Overhead Press", sets: 3, reps: 8, suggestedWeight: 30, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Pull-Up", sets: 3, reps: 8, suggestedWeight: nil, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Barbell Curl", sets: 3, reps: 10, suggestedWeight: 25, restSeconds: 90, notes: nil),
                    ProgramExercise(exerciseName: "Skullcrusher", sets: 3, reps: 10, suggestedWeight: 25, restSeconds: 90, notes: nil),
                ]
            ),
            ProgramWorkout(
                name: "Lower Strength",
                exercises: [
                    ProgramExercise(exerciseName: "Back Squat", sets: 4, reps: 6, suggestedWeight: 70, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Romanian Deadlift", sets: 3, reps: 8, suggestedWeight: 60, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Leg Press", sets: 3, reps: 10, suggestedWeight: 100, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Leg Curl", sets: 3, reps: 10, suggestedWeight: 30, restSeconds: 90, notes: nil),
                    ProgramExercise(exerciseName: "Walking Lunge", sets: 3, reps: 10, suggestedWeight: 14, restSeconds: 90, notes: nil),
                ]
            ),
            ProgramWorkout(
                name: "Upper Hypertrophy",
                exercises: [
                    ProgramExercise(exerciseName: "Incline Bench Press", sets: 4, reps: 8, suggestedWeight: 50, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Seated Row", sets: 4, reps: 8, suggestedWeight: 45, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Lateral Raise", sets: 4, reps: 12, suggestedWeight: 8, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Lat Pulldown", sets: 3, reps: 10, suggestedWeight: 45, restSeconds: 90, notes: nil),
                    ProgramExercise(exerciseName: "Hammer Curl", sets: 3, reps: 12, suggestedWeight: 12, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Tricep Pushdown", sets: 3, reps: 12, suggestedWeight: 25, restSeconds: 60, notes: nil),
                ]
            ),
            ProgramWorkout(
                name: "Lower Hypertrophy",
                exercises: [
                    ProgramExercise(exerciseName: "Front Squat", sets: 4, reps: 8, suggestedWeight: 50, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Romanian Deadlift", sets: 3, reps: 10, suggestedWeight: 50, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Leg Extension", sets: 3, reps: 12, suggestedWeight: 30, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Leg Curl", sets: 3, reps: 12, suggestedWeight: 30, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Hanging Leg Raise", sets: 3, reps: 15, suggestedWeight: nil, restSeconds: 60, notes: nil),
                ]
            ),
        ]
    )

    static let ppl6Day = ProgramLibraryEntry(
        id: "ppl-6day",
        name: "Push / Pull / Legs",
        author: "Community",
        level: .intermediate,
        goal: .hypertrophy,
        daysPerWeek: 6,
        cycleLengthWeeks: nil,
        progressionDescription: "Double progression within the rep range; add weight when you hit the top of the range on all sets. Heavy day focuses on compounds, volume day on accessories. Deload every 8-12 weeks.",
        officialURL: nil,
        summary: "High-frequency six-day split cycling Push, Pull, and Legs twice — one heavy session and one volume session per movement pattern.",
        workouts: [
            ProgramWorkout(
                name: "Push (Heavy)",
                exercises: [
                    ProgramExercise(exerciseName: "Bench Press", sets: 4, reps: 6, suggestedWeight: 60, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Overhead Press", sets: 3, reps: 8, suggestedWeight: 30, restSeconds: 150, notes: nil),
                    ProgramExercise(exerciseName: "Incline Bench Press", sets: 3, reps: 8, suggestedWeight: 45, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Lateral Raise", sets: 3, reps: 12, suggestedWeight: 8, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Tricep Pushdown", sets: 3, reps: 10, suggestedWeight: 25, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Skullcrusher", sets: 3, reps: 10, suggestedWeight: 25, restSeconds: 60, notes: nil),
                ]
            ),
            ProgramWorkout(
                name: "Pull (Heavy)",
                exercises: [
                    ProgramExercise(exerciseName: "Deadlift", sets: 3, reps: 5, suggestedWeight: 90, restSeconds: 240, notes: nil),
                    ProgramExercise(exerciseName: "Barbell Row", sets: 4, reps: 6, suggestedWeight: 50, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Pull-Up", sets: 3, reps: 8, suggestedWeight: nil, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Face Pull", sets: 3, reps: 15, suggestedWeight: 15, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Barbell Curl", sets: 3, reps: 10, suggestedWeight: 25, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Hammer Curl", sets: 3, reps: 12, suggestedWeight: 12, restSeconds: 60, notes: nil),
                ]
            ),
            ProgramWorkout(
                name: "Legs (Heavy)",
                exercises: [
                    ProgramExercise(exerciseName: "Back Squat", sets: 4, reps: 6, suggestedWeight: 70, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Romanian Deadlift", sets: 3, reps: 8, suggestedWeight: 60, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Leg Press", sets: 3, reps: 10, suggestedWeight: 100, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Leg Curl", sets: 3, reps: 10, suggestedWeight: 30, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Walking Lunge", sets: 3, reps: 10, suggestedWeight: 14, restSeconds: 90, notes: nil),
                ]
            ),
            ProgramWorkout(
                name: "Push (Volume)",
                exercises: [
                    ProgramExercise(exerciseName: "Incline Bench Press", sets: 4, reps: 10, suggestedWeight: 45, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Dumbbell Shoulder Press", sets: 3, reps: 10, suggestedWeight: 18, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Cable Fly", sets: 3, reps: 12, suggestedWeight: 15, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Lateral Raise", sets: 4, reps: 12, suggestedWeight: 8, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Tricep Pushdown", sets: 4, reps: 12, suggestedWeight: 22, restSeconds: 60, notes: nil),
                ]
            ),
            ProgramWorkout(
                name: "Pull (Volume)",
                exercises: [
                    ProgramExercise(exerciseName: "Pendlay Row", sets: 4, reps: 8, suggestedWeight: 45, restSeconds: 150, notes: nil),
                    ProgramExercise(exerciseName: "Lat Pulldown", sets: 4, reps: 10, suggestedWeight: 45, restSeconds: 90, notes: nil),
                    ProgramExercise(exerciseName: "Face Pull", sets: 3, reps: 15, suggestedWeight: 15, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Seated Row", sets: 3, reps: 10, suggestedWeight: 45, restSeconds: 90, notes: nil),
                    ProgramExercise(exerciseName: "Hammer Curl", sets: 4, reps: 12, suggestedWeight: 12, restSeconds: 60, notes: nil),
                ]
            ),
            ProgramWorkout(
                name: "Legs (Volume)",
                exercises: [
                    ProgramExercise(exerciseName: "Front Squat", sets: 4, reps: 8, suggestedWeight: 50, restSeconds: 180, notes: nil),
                    ProgramExercise(exerciseName: "Romanian Deadlift", sets: 4, reps: 8, suggestedWeight: 55, restSeconds: 120, notes: nil),
                    ProgramExercise(exerciseName: "Leg Extension", sets: 3, reps: 12, suggestedWeight: 30, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Leg Curl", sets: 3, reps: 12, suggestedWeight: 30, restSeconds: 60, notes: nil),
                    ProgramExercise(exerciseName: "Hanging Leg Raise", sets: 3, reps: 15, suggestedWeight: nil, restSeconds: 60, notes: nil),
                ]
            ),
        ]
    )
}
