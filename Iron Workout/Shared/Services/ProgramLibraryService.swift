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
        .startingStrength,
        .stronglifts5x5,
        .greyskullLP,
    ]

    /// Programs grouped by level for browse UI.
    static func programs(for level: ProgramLevel) -> [ProgramLibraryEntry] {
        programs.filter { $0.level == level }
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

            let template = WorkoutTemplate(name: templateName, note: entry.summary)
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
}
