//
//  PreviousSetLookupTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
import SwiftData
@testable import Iron_Workout

@Suite("PreviousSetLookup")
struct PreviousSetLookupTests {

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

    /// Builds a session holding one exercise with the given sets, described as
    /// (weight, reps, type). A nil weight means the set was skipped.
    @MainActor
    @discardableResult
    private func insertSession(
        named name: String,
        exerciseID: UUID,
        exerciseName: String = "Bench Press",
        startedAt: Date,
        sets: [(weight: Double?, reps: Int?, type: SetType)],
        into context: ModelContext
    ) -> WorkoutSessionExercise {
        let session = WorkoutSession(templateName: name, startedAt: startedAt, endedAt: startedAt, exerciseCount: 1)
        context.insert(session)

        let exercise = WorkoutSessionExercise(exerciseID: exerciseID, exerciseName: exerciseName, sortOrder: 0)
        exercise.session = session
        session.exercises.append(exercise)
        context.insert(exercise)

        for (index, spec) in sets.enumerated() {
            let set = PerformedSet(
                setIndex: index,
                targetReps: spec.reps ?? 10,
                actualReps: spec.reps,
                targetWeight: spec.weight,
                actualWeight: spec.weight,
                isCompleted: true,
                completedAt: startedAt
            )
            set.setType = spec.type
            set.sessionExercise = exercise
            exercise.performedSets.append(set)
            context.insert(set)
        }
        return exercise
    }

    private let day = 24.0 * 60 * 60

    @MainActor
    @Test("Matches the set with the same index from the most recent earlier session")
    func matchesSameSetIndex() throws {
        let context = try makeInMemoryContext()
        let benchID = UUID()
        let now = Date()

        insertSession(
            named: "Push",
            exerciseID: benchID,
            startedAt: now.addingTimeInterval(-7 * day),
            sets: [(60, 10, .working), (65, 8, .working), (70, 5, .working)],
            into: context
        )
        let today = insertSession(
            named: "Push",
            exerciseID: benchID,
            startedAt: now,
            sets: [],
            into: context
        )
        try context.save()

        let second = try #require(PreviousSetLookup.find(for: today, setIndex: 1, isWarmup: false, modelContext: context))
        #expect(second.weightKg == 65)
        #expect(second.reps == 8)

        let third = try #require(PreviousSetLookup.find(for: today, setIndex: 2, isWarmup: false, modelContext: context))
        #expect(third.weightKg == 70)
    }

    @MainActor
    @Test("Falls back to the last set when the earlier session ran fewer sets")
    func fallsBackToLastSet() throws {
        let context = try makeInMemoryContext()
        let benchID = UUID()
        let now = Date()

        insertSession(
            named: "Push", exerciseID: benchID, startedAt: now.addingTimeInterval(-7 * day),
            sets: [(60, 10, .working), (65, 8, .working)], into: context
        )
        let today = insertSession(named: "Push", exerciseID: benchID, startedAt: now, sets: [], into: context)
        try context.save()

        // Today's program calls for 4 sets; last time only had 2.
        let fourth = try #require(PreviousSetLookup.find(for: today, setIndex: 3, isWarmup: false, modelContext: context))
        #expect(fourth.weightKg == 65)
        #expect(fourth.reps == 8)
    }

    @MainActor
    @Test("The newest earlier session wins, not the one with the most sets")
    func prefersMostRecentSession() throws {
        let context = try makeInMemoryContext()
        let benchID = UUID()
        let now = Date()

        insertSession(
            named: "Old", exerciseID: benchID, startedAt: now.addingTimeInterval(-30 * day),
            sets: [(100, 5, .working)], into: context
        )
        insertSession(
            named: "Recent", exerciseID: benchID, startedAt: now.addingTimeInterval(-3 * day),
            sets: [(80, 6, .working)], into: context
        )
        let today = insertSession(named: "Push", exerciseID: benchID, startedAt: now, sets: [], into: context)
        try context.save()

        let reference = try #require(PreviousSetLookup.find(for: today, setIndex: 0, isWarmup: false, modelContext: context))
        #expect(reference.weightKg == 80)
    }

    @MainActor
    @Test("A warm-up is not offered as the reference for a working set")
    func warmupsAreNotUsedForWorkingSets() throws {
        let context = try makeInMemoryContext()
        let benchID = UUID()
        let now = Date()

        insertSession(
            named: "Push", exerciseID: benchID, startedAt: now.addingTimeInterval(-7 * day),
            sets: [(20, 12, .warmup), (80, 5, .working)], into: context
        )
        let today = insertSession(named: "Push", exerciseID: benchID, startedAt: now, sets: [], into: context)
        try context.save()

        // Set 1 today is a working set, so the 20 kg warm-up at index 0 must not be used.
        let reference = try #require(PreviousSetLookup.find(for: today, setIndex: 0, isWarmup: false, modelContext: context))
        #expect(reference.weightKg == 80)
    }

    @MainActor
    @Test("A warm-up set can reference a previous warm-up")
    func warmupsReferenceWarmups() throws {
        let context = try makeInMemoryContext()
        let benchID = UUID()
        let now = Date()

        insertSession(
            named: "Push", exerciseID: benchID, startedAt: now.addingTimeInterval(-7 * day),
            sets: [(20, 12, .warmup), (80, 5, .working)], into: context
        )
        let today = insertSession(named: "Push", exerciseID: benchID, startedAt: now, sets: [], into: context)
        try context.save()

        let reference = try #require(PreviousSetLookup.find(for: today, setIndex: 0, isWarmup: true, modelContext: context))
        #expect(reference.weightKg == 20)
    }

    @MainActor
    @Test("Skipped sets record no reps and are ignored")
    func skippedSetsAreIgnored() throws {
        let context = try makeInMemoryContext()
        let benchID = UUID()
        let now = Date()

        insertSession(
            named: "Push", exerciseID: benchID, startedAt: now.addingTimeInterval(-7 * day),
            sets: [(nil, nil, .working), (75, 6, .working)], into: context
        )
        let today = insertSession(named: "Push", exerciseID: benchID, startedAt: now, sets: [], into: context)
        try context.save()

        let reference = try #require(PreviousSetLookup.find(for: today, setIndex: 0, isWarmup: false, modelContext: context))
        #expect(reference.weightKg == 75)
    }

    @MainActor
    @Test("A different exercise is never used as the reference")
    func otherExercisesAreIgnored() throws {
        let context = try makeInMemoryContext()
        let now = Date()

        insertSession(
            named: "Legs", exerciseID: UUID(), exerciseName: "Squat",
            startedAt: now.addingTimeInterval(-2 * day),
            sets: [(140, 5, .working)], into: context
        )
        let today = insertSession(named: "Push", exerciseID: UUID(), startedAt: now, sets: [], into: context)
        try context.save()

        #expect(PreviousSetLookup.find(for: today, setIndex: 0, isWarmup: false, modelContext: context) == nil)
    }

    @MainActor
    @Test("The first time an exercise is trained there is nothing to show")
    func noHistoryReturnsNil() throws {
        let context = try makeInMemoryContext()
        let today = insertSession(named: "Push", exerciseID: UUID(), startedAt: Date(), sets: [], into: context)
        try context.save()

        #expect(PreviousSetLookup.find(for: today, setIndex: 0, isWarmup: false, modelContext: context) == nil)
    }

    @MainActor
    @Test("Sessions started later than the current one are not consulted")
    func laterSessionsAreIgnored() throws {
        let context = try makeInMemoryContext()
        let benchID = UUID()
        let now = Date()

        let today = insertSession(named: "Push", exerciseID: benchID, startedAt: now, sets: [], into: context)
        insertSession(
            named: "Future", exerciseID: benchID, startedAt: now.addingTimeInterval(day),
            sets: [(999, 1, .working)], into: context
        )
        try context.save()

        #expect(PreviousSetLookup.find(for: today, setIndex: 0, isWarmup: false, modelContext: context) == nil)
    }

    @MainActor
    @Test("Imported history feeds the reference like any other session")
    func importedHistoryIsUsed() throws {
        let context = try makeInMemoryContext()
        let csv = """
        "Date","Workout Name","Duration","Exercise Name","Set Order","Weight","Reps"
        "2024-01-15 18:30:00","Push Day","1h","Bench Press","1","72.5","6"
        """
        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)
        try WorkoutCSVImportService.save(parsed, modelContext: context)

        let benchID = try #require(
            try context.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Bench Press" }
        ).id
        let today = insertSession(named: "Push", exerciseID: benchID, startedAt: Date(), sets: [], into: context)
        try context.save()

        let reference = try #require(PreviousSetLookup.find(for: today, setIndex: 0, isWarmup: false, modelContext: context))
        #expect(reference.weightKg == 72.5)
        #expect(reference.reps == 6)
    }
}
