//
//  ProgramLibraryServiceTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
import SwiftData
@testable import Iron_Workout

@Suite("ProgramLibraryService")
struct ProgramLibraryServiceTests {

    // MARK: - Setup

    @MainActor
    private func makeInMemoryContextWithLibrary() throws -> ModelContext {
        let schema = Schema([
            Exercise.self,
            WorkoutTemplate.self,
            WorkoutTemplateExercise.self,
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            PerformedSet.self,
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        let context = ModelContext(container)
        ExerciseLibraryService.seedIfNeeded(modelContext: context)
        return context
    }

    // MARK: - Catalog structure

    @Test("all programs have stable unique ids")
    func uniqueIDs() {
        let ids = ProgramLibraryService.programs.map(\.id)
        #expect(ids.count == Set(ids).count)
    }

    @Test("programs are ordered beginner then intermediate")
    func orderedByLevel() {
        let levels = ProgramLibraryService.programs.map(\.level)
        let beginnerCount = levels.prefix(while: { $0 == .beginner }).count
        let rest = Array(levels.dropFirst(beginnerCount))
        #expect(rest.allSatisfy { $0 != .beginner }, "After the beginner run, no more beginner programs should appear")
    }

    @Test("programs(for:) filters correctly")
    func filterByLevel() {
        let beginner = ProgramLibraryService.programs(for: .beginner)
        #expect(!beginner.isEmpty)
        #expect(beginner.allSatisfy { $0.level == .beginner })

        let intermediate = ProgramLibraryService.programs(for: .intermediate)
        #expect(!intermediate.isEmpty)
        #expect(intermediate.allSatisfy { $0.level == .intermediate })
    }

    // MARK: - Exercise references

    @Test("every program exercise exists in the library")
    @MainActor
    func allExerciseReferencesResolve() throws {
        let context = try makeInMemoryContextWithLibrary()
        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        let knownNames = Set(allExercises.map(\.name))

        for program in ProgramLibraryService.programs {
            for workout in program.workouts {
                for exercise in workout.exercises {
                    #expect(
                        knownNames.contains(exercise.exerciseName),
                        "Program '\(program.id)' references unknown exercise '\(exercise.exerciseName)' in workout '\(workout.name)'"
                    )
                }
            }
        }
    }

    // MARK: - Import — single workout programs

    // (All current programs have multiple workouts, but we assert the naming convention
    // by checking the multi-workout branch against explicit expectations.)

    @Test("importing multi-workout program creates one template per workout")
    @MainActor
    func multiWorkoutImport() throws {
        let context = try makeInMemoryContextWithLibrary()
        let program = ProgramLibraryService.programs.first { $0.id == "starting-strength" }!

        let templates = try ProgramLibraryService.importProgram(program, modelContext: context)

        #expect(templates.count == program.workouts.count)
        #expect(templates[0].name == "Starting Strength — Workout A")
        #expect(templates[1].name == "Starting Strength — Workout B")
    }

    @Test("imported templates have program summary as the note")
    @MainActor
    func templateNoteContainsSummary() throws {
        let context = try makeInMemoryContextWithLibrary()
        let program = ProgramLibraryService.programs.first { $0.id == "stronglifts-5x5" }!

        let templates = try ProgramLibraryService.importProgram(program, modelContext: context)

        for template in templates {
            #expect(template.note == program.summary)
        }
    }

    @Test("imported template exercises have correct sets, reps, weight, rest")
    @MainActor
    func importedExerciseFieldsPreserved() throws {
        let context = try makeInMemoryContextWithLibrary()
        let program = ProgramLibraryService.programs.first { $0.id == "stronglifts-5x5" }!
        let workoutA = program.workouts[0]

        let templates = try ProgramLibraryService.importProgram(program, modelContext: context)
        let workoutATemplate = templates[0]
        let sorted = workoutATemplate.exercises.sorted { $0.sortOrder < $1.sortOrder }

        #expect(sorted.count == workoutA.exercises.count)
        for (index, programExercise) in workoutA.exercises.enumerated() {
            let te = sorted[index]
            #expect(te.sortOrder == index)
            #expect(te.targetSets == programExercise.sets)
            #expect(te.targetReps == programExercise.reps)
            #expect(te.targetWeight == programExercise.suggestedWeight)
            #expect(te.restSeconds == programExercise.restSeconds)
            #expect(te.note == (programExercise.notes ?? ""))
        }
    }

    @Test("imported template exercises reference stable exerciseID from library")
    @MainActor
    func importedExercisesUseStableID() throws {
        let context = try makeInMemoryContextWithLibrary()
        let program = ProgramLibraryService.programs.first { $0.id == "starting-strength" }!

        let templates = try ProgramLibraryService.importProgram(program, modelContext: context)
        let allExercises = try context.fetch(FetchDescriptor<Exercise>())
        let idByName = Dictionary(uniqueKeysWithValues: allExercises.map { ($0.name, $0.id) })

        for (templateIndex, template) in templates.enumerated() {
            let programWorkout = program.workouts[templateIndex]
            for (exerciseIndex, te) in template.exercises.sorted(by: { $0.sortOrder < $1.sortOrder }).enumerated() {
                let programExercise = programWorkout.exercises[exerciseIndex]
                let expectedID = try #require(idByName[programExercise.exerciseName])
                #expect(te.exerciseID == expectedID)
            }
        }
    }

    @Test("imported templates carry sourceProgramID for attribution lookup")
    @MainActor
    func importedTemplatesHaveSourceProgramID() throws {
        let context = try makeInMemoryContextWithLibrary()
        let program = ProgramLibraryService.programs.first { $0.id == "starting-strength" }!

        let templates = try ProgramLibraryService.importProgram(program, modelContext: context)

        for template in templates {
            #expect(template.sourceProgramID == "starting-strength")
        }
    }

    @Test("program(withID:) resolves for imported templates")
    func programLookupByID() {
        let resolved = ProgramLibraryService.program(withID: "starting-strength")
        #expect(resolved != nil)
        #expect(resolved?.author == "Mark Rippetoe")

        let missing = ProgramLibraryService.program(withID: "not-a-real-program")
        #expect(missing == nil)
    }

    @Test("importing the same program twice creates independent copies")
    @MainActor
    func importTwiceIndependent() throws {
        let context = try makeInMemoryContextWithLibrary()
        let program = ProgramLibraryService.programs.first { $0.id == "greyskull-lp" }!

        let firstImport = try ProgramLibraryService.importProgram(program, modelContext: context)
        let secondImport = try ProgramLibraryService.importProgram(program, modelContext: context)

        // Two independent sets of templates — different ids
        let firstIDs = Set(firstImport.map(\.id))
        let secondIDs = Set(secondImport.map(\.id))
        #expect(firstIDs.isDisjoint(with: secondIDs))

        // Editing one does not affect the other
        firstImport[0].name = "My Edited Copy"
        #expect(secondImport[0].name == "Greyskull LP — Workout A")
    }

    // MARK: - Program content sanity

    @Test("all programs have at least one workout with at least one exercise")
    func nonEmptyPrograms() {
        for program in ProgramLibraryService.programs {
            #expect(!program.workouts.isEmpty, "Program '\(program.id)' has no workouts")
            for workout in program.workouts {
                #expect(!workout.exercises.isEmpty, "Workout '\(workout.name)' in '\(program.id)' has no exercises")
            }
        }
    }

    @Test("rest and set values are positive")
    func positiveNumerics() {
        for program in ProgramLibraryService.programs {
            for workout in program.workouts {
                for exercise in workout.exercises {
                    #expect(exercise.sets > 0, "Non-positive sets in \(program.id) / \(exercise.exerciseName)")
                    #expect(exercise.reps > 0, "Non-positive reps in \(program.id) / \(exercise.exerciseName)")
                    #expect(exercise.restSeconds > 0, "Non-positive rest in \(program.id) / \(exercise.exerciseName)")
                }
            }
        }
    }
}
