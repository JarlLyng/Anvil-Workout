//
//  DataMigrationServiceTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
import SwiftData
@testable import Iron_Workout

@Suite("DataMigrationService", .serialized)
struct DataMigrationServiceTests {

    /// Migrations are guarded by a UserDefaults flag so they run once per install. Tests
    /// clear it first, and the suite is serialized because the flag is process-wide state.
    private let closeImportedSessionsKey = "migration.closeImportedSessions.v1"

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
        UserDefaults.standard.removeObject(forKey: closeImportedSessionsKey)
        return ModelContext(container)
    }

    /// A session shaped the way the pre-1.7.2 CSV importer left it: open, no duration, and
    /// every set completed at exactly the session start.
    @MainActor
    private func insertLegacyImport(
        named name: String,
        startedAt: Date,
        into context: ModelContext
    ) -> WorkoutSession {
        let session = WorkoutSession(
            templateName: name,
            startedAt: startedAt,
            endedAt: nil,
            exerciseCount: 1
        )
        context.insert(session)

        let exercise = WorkoutSessionExercise(exerciseName: "Bench Press", sortOrder: 0)
        exercise.session = session
        session.exercises.append(exercise)
        context.insert(exercise)

        let set = PerformedSet(
            setIndex: 0,
            targetReps: 10,
            actualReps: 10,
            targetWeight: 60,
            actualWeight: 60,
            isCompleted: true,
            completedAt: startedAt
        )
        set.sessionExercise = exercise
        exercise.performedSets.append(set)
        context.insert(set)

        return session
    }

    // MARK: - Closing imported sessions (#74)

    @MainActor
    @Test("Legacy imports are closed so they stop appearing as abandoned workouts")
    func closesLegacyImports() throws {
        let context = try makeInMemoryContext()
        let startedAt = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let session = insertLegacyImport(named: "Push Day", startedAt: startedAt, into: context)
        try context.save()

        // Precondition: this is exactly the bug, the import looks like an abandoned workout.
        #expect(WorkoutSessionService.findStaleSession(modelContext: context) != nil)

        DataMigrationService.runMigrationsIfNeeded(modelContext: context)

        #expect(session.endedAt == startedAt)
        #expect(session.durationSeconds == 0)
        #expect(WorkoutSessionService.findStaleSession(modelContext: context) == nil)
    }

    @MainActor
    @Test("An abandoned workout logged in the app is left open for recovery")
    func leavesGenuineAbandonedWorkoutAlone() throws {
        let context = try makeInMemoryContext()
        let startedAt = Date().addingTimeInterval(-8 * 60 * 60)

        let session = WorkoutSession(templateName: "Leg Day", startedAt: startedAt, endedAt: nil, exerciseCount: 1)
        context.insert(session)
        let exercise = WorkoutSessionExercise(exerciseName: "Squat", sortOrder: 0)
        exercise.session = session
        session.exercises.append(exercise)
        context.insert(exercise)

        // Logged in the app: completed at tap time, which is later than the session start.
        let logged = PerformedSet(
            setIndex: 0,
            targetReps: 5,
            actualReps: 5,
            actualWeight: 100,
            isCompleted: true,
            completedAt: startedAt.addingTimeInterval(120)
        )
        logged.sessionExercise = exercise
        exercise.performedSets.append(logged)
        context.insert(logged)

        // And one the user never finished.
        let pending = PerformedSet(setIndex: 1, targetReps: 5, targetWeight: 100)
        pending.sessionExercise = exercise
        exercise.performedSets.append(pending)
        context.insert(pending)
        try context.save()

        DataMigrationService.runMigrationsIfNeeded(modelContext: context)

        #expect(session.endedAt == nil)
        let stale = try #require(WorkoutSessionService.findStaleSession(modelContext: context))
        #expect(stale.templateName == "Leg Day")
    }

    @MainActor
    @Test("An abandoned workout with nothing logged is left open for recovery")
    func leavesEmptyAbandonedWorkoutAlone() throws {
        let context = try makeInMemoryContext()
        let session = WorkoutSession(
            templateName: "Pull Day",
            startedAt: Date().addingTimeInterval(-8 * 60 * 60),
            endedAt: nil
        )
        context.insert(session)
        try context.save()

        DataMigrationService.runMigrationsIfNeeded(modelContext: context)

        #expect(session.endedAt == nil)
    }

    @MainActor
    @Test("Running twice changes nothing and does not reopen closed sessions")
    func isIdempotent() throws {
        let context = try makeInMemoryContext()
        let startedAt = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        let session = insertLegacyImport(named: "Push Day", startedAt: startedAt, into: context)
        try context.save()

        DataMigrationService.runMigrationsIfNeeded(modelContext: context)
        DataMigrationService.runMigrationsIfNeeded(modelContext: context)

        #expect(session.endedAt == startedAt)
        #expect(WorkoutSessionService.findStaleSession(modelContext: context) == nil)
    }
}
