//
//  WorkoutSessionServiceTests.swift
//  Iron WorkoutTests
//

import Testing
import Foundation
import SwiftData
@testable import Iron_Workout

@Suite("WorkoutSessionService")
struct WorkoutSessionServiceTests {

    @MainActor
    private func makeInMemoryContext() throws -> ModelContext {
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
        return ModelContext(container)
    }

    @MainActor
    private func makeBenchPress(in context: ModelContext) -> Exercise {
        let exercise = Exercise(name: "Bench Press", muscleGroup: .chest, equipmentType: "Barbell", isBuiltin: true)
        context.insert(exercise)
        return exercise
    }

    @MainActor
    private func makeTemplate(
        name: String = "Test Program",
        exerciseList: [(exercise: Exercise, sets: Int, reps: Int, weight: Double?)],
        context: ModelContext
    ) -> WorkoutTemplate {
        let template = WorkoutTemplate(name: name)
        context.insert(template)
        for (i, item) in exerciseList.enumerated() {
            let te = WorkoutTemplateExercise(
                exerciseID: item.exercise.id,
                sortOrder: i,
                targetSets: item.sets,
                targetReps: item.reps,
                targetWeight: item.weight,
                restSeconds: 90
            )
            te.template = template
            template.exercises.append(te)
            context.insert(te)
        }
        return template
    }

    // MARK: - createSession

    @Test("creates session with correct exercise count and set count")
    @MainActor
    func createSessionWithExercises() throws {
        let context = try makeInMemoryContext()
        let bench = makeBenchPress(in: context)
        let template = makeTemplate(
            exerciseList: [(bench, 3, 8, 80.0)],
            context: context
        )

        let session = try WorkoutSessionService.createSession(from: template, modelContext: context)

        #expect(session.templateName == "Test Program")
        #expect(session.exerciseCount == 1)
        #expect(session.exercises.count == 1)
        #expect(session.exercises.first?.performedSets.count == 3)
    }

    @Test("session exercises get exerciseID from template")
    @MainActor
    func sessionExercisesCarryExerciseID() throws {
        let context = try makeInMemoryContext()
        let bench = makeBenchPress(in: context)
        let template = makeTemplate(
            exerciseList: [(bench, 3, 8, 80.0)],
            context: context
        )

        let session = try WorkoutSessionService.createSession(from: template, modelContext: context)
        let sessionExercise = try #require(session.exercises.first)

        #expect(sessionExercise.exerciseID == bench.id)
        #expect(sessionExercise.exerciseName == "Bench Press")
    }

    @Test("exercise order is preserved from template sortOrder")
    @MainActor
    func exerciseOrderPreserved() throws {
        let context = try makeInMemoryContext()
        let bench = Exercise(name: "Bench Press", muscleGroup: .chest, equipmentType: "Barbell")
        let squat = Exercise(name: "Back Squat", muscleGroup: .legs, equipmentType: "Barbell")
        let row = Exercise(name: "Barbell Row", muscleGroup: .back, equipmentType: "Barbell")
        context.insert(bench); context.insert(squat); context.insert(row)

        let template = makeTemplate(
            exerciseList: [(squat, 3, 5, 100), (bench, 3, 5, 80), (row, 3, 5, 70)],
            context: context
        )

        let session = try WorkoutSessionService.createSession(from: template, modelContext: context)
        let sorted = session.exercises.sorted { $0.sortOrder < $1.sortOrder }

        #expect(sorted.count == 3)
        #expect(sorted[0].exerciseName == "Back Squat")
        #expect(sorted[1].exerciseName == "Bench Press")
        #expect(sorted[2].exerciseName == "Barbell Row")
    }

    @Test("template with zero exercises creates empty session")
    @MainActor
    func emptyTemplateCreatesEmptySession() throws {
        let context = try makeInMemoryContext()
        let template = WorkoutTemplate(name: "Empty")
        context.insert(template)

        let session = try WorkoutSessionService.createSession(from: template, modelContext: context)

        #expect(session.exercises.isEmpty)
        #expect(session.exerciseCount == 0)
        #expect(session.completedSetCount == 0)
    }

    @Test("performed sets inherit target reps and weight from template")
    @MainActor
    func performedSetsInheritTargets() throws {
        let context = try makeInMemoryContext()
        let bench = makeBenchPress(in: context)
        let template = makeTemplate(
            exerciseList: [(bench, 5, 8, 82.5)],
            context: context
        )

        let session = try WorkoutSessionService.createSession(from: template, modelContext: context)
        let sets = try #require(session.exercises.first?.performedSets).sorted { $0.setIndex < $1.setIndex }

        #expect(sets.count == 5)
        for (index, set) in sets.enumerated() {
            #expect(set.setIndex == index)
            #expect(set.targetReps == 8)
            #expect(set.targetWeight == 82.5)
            #expect(set.isCompleted == false)
        }
    }

    // MARK: - finalizeSession

    @Test("finalizeSession sets endedAt, duration, and completedSetCount")
    @MainActor
    func finalizeCountsCompletedSets() throws {
        let context = try makeInMemoryContext()
        let bench = makeBenchPress(in: context)
        let template = makeTemplate(
            exerciseList: [(bench, 3, 8, 80.0)],
            context: context
        )
        let session = try WorkoutSessionService.createSession(from: template, modelContext: context)
        session.startedAt = Date(timeIntervalSinceNow: -3600) // 1h ago

        // Mark two of three sets complete
        let sets = session.exercises.flatMap(\.performedSets)
        sets[0].isCompleted = true
        sets[1].isCompleted = true

        try WorkoutSessionService.finalizeSession(session, modelContext: context)

        #expect(session.endedAt != nil)
        #expect(session.durationSeconds >= 3500 && session.durationSeconds <= 3700)
        #expect(session.completedSetCount == 2)
    }

    @Test("finalizeSession with zero completed sets sets count to 0")
    @MainActor
    func finalizeZeroCompletedSets() throws {
        let context = try makeInMemoryContext()
        let bench = makeBenchPress(in: context)
        let template = makeTemplate(
            exerciseList: [(bench, 3, 8, 80.0)],
            context: context
        )
        let session = try WorkoutSessionService.createSession(from: template, modelContext: context)

        try WorkoutSessionService.finalizeSession(session, modelContext: context)

        #expect(session.completedSetCount == 0)
    }
}
