//
//  WorkoutCSVImportServiceTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
import SwiftData
@testable import Iron_Workout

@Suite("WorkoutCSVImportService")
struct WorkoutCSVImportServiceTests {

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

    private let hevyCSV = """
    title,start_time,end_time,exercise_title,superset_id,set_index,set_type,weight_kg,reps,rpe
    Upper A,2024-02-01 07:00:00,2024-02-01 08:00:00,Bench Press,,0,warmup,40,12,
    Upper A,2024-02-01 07:00:00,2024-02-01 08:00:00,Bench Press,,1,normal,80,8,8.5
    Upper A,2024-02-01 07:00:00,2024-02-01 08:00:00,Pull Up,1,0,normal,0,10,
    Upper A,2024-02-01 07:00:00,2024-02-01 08:00:00,Barbell Row,1,0,normal,60,10,
    """

    @MainActor
    @Test("Imports sessions and links existing exercises by name")
    func importsAndMatchesExisting() throws {
        let context = try makeInMemoryContext()
        // Pre-existing library exercise (different casing to prove case-insensitive match).
        let bench = Exercise(name: "bench press", muscleGroup: .chest, isBuiltin: true)
        context.insert(bench)
        try context.save()

        let parsed = try WorkoutCSVImporter.parse(hevyCSV)
        let summary = try WorkoutCSVImportService.save(parsed, modelContext: context)

        #expect(summary.format == .hevy)
        #expect(summary.importedSessions == 1)
        #expect(summary.importedSets == 4)
        // Pull Up and Barbell Row are new; Bench Press already existed.
        #expect(summary.createdExercises == 2)

        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
        #expect(sessions.count == 1)
        let session = sessions[0]
        #expect(session.completedSetCount == 4)
        #expect(session.durationSeconds == 3600)

        // Bench Press session-exercise reuses the existing exercise's ID (not a new one).
        let benchExercise = try #require(session.exercises.first { $0.exerciseName.lowercased() == "bench press" })
        #expect(benchExercise.exerciseID == bench.id)
    }

    @MainActor
    @Test("Superset rows share one superset ID within the session")
    func supersetGrouping() throws {
        let context = try makeInMemoryContext()
        let parsed = try WorkoutCSVImporter.parse(hevyCSV)
        try WorkoutCSVImportService.save(parsed, modelContext: context)

        let session = try context.fetch(FetchDescriptor<WorkoutSession>())[0]
        let pullUp = try #require(session.exercises.first { $0.exerciseName == "Pull Up" })
        let row = try #require(session.exercises.first { $0.exerciseName == "Barbell Row" })
        let bench = try #require(session.exercises.first { $0.exerciseName == "Bench Press" })

        #expect(pullUp.supersetID != nil)
        #expect(pullUp.supersetID == row.supersetID)   // same superset
        #expect(bench.supersetID == nil)               // not in a superset
    }

    @MainActor
    @Test("Imported sets are completed and carry weight in kg")
    func setsAreCompleted() throws {
        let context = try makeInMemoryContext()
        let parsed = try WorkoutCSVImporter.parse(hevyCSV)
        try WorkoutCSVImportService.save(parsed, modelContext: context)

        let session = try context.fetch(FetchDescriptor<WorkoutSession>())[0]
        let bench = try #require(session.exercises.first { $0.exerciseName == "Bench Press" })
        let sets = bench.performedSets.sorted { $0.setIndex < $1.setIndex }
        let allCompleted = sets.allSatisfy { $0.isCompleted }
        #expect(allCompleted)
        #expect(sets[0].setType == .warmup)
        #expect(sets[0].rpe == nil)
        #expect(sets[1].actualWeight == 80)
        #expect(sets[1].rpe == 8.5)
    }

    // MARK: - Imported sessions are closed, not left open (#74)

    private let strongCSV = """
    "Date","Workout Name","Duration","Exercise Name","Set Order","Weight","Reps","Distance","Seconds","Notes","Workout Notes","RPE"
    "2024-01-15 18:30:00","Push Day","1h 2m","Bench Press","1","60","10","0","0","","",""
    "2024-01-15 18:30:00","Push Day","1h 2m","Overhead Press","1","40","8","0","0","","",""
    """

    @MainActor
    @Test("Strong import stores the source duration and is never treated as abandoned")
    func strongImportIsClosed() throws {
        let context = try makeInMemoryContext()
        let parsed = try WorkoutCSVImporter.parse(strongCSV, strongFallbackUnit: .kg)
        try WorkoutCSVImportService.save(parsed, modelContext: context)

        let session = try context.fetch(FetchDescriptor<WorkoutSession>())[0]
        #expect(session.endedAt != nil)
        #expect(session.durationSeconds == 3720)
        // The whole point: startup recovery must not offer to save or discard imported history.
        #expect(WorkoutSessionService.findStaleSession(modelContext: context) == nil)
    }

    @MainActor
    @Test("Import without a source duration is still closed, with duration left at zero")
    func importWithoutDurationIsClosed() throws {
        let context = try makeInMemoryContext()
        let csv = """
        Date,Workout Name,Exercise Name,Set Order,Weight,Reps
        2024-01-15 18:30:00,Push Day,Bench Press,1,60,10
        """
        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)
        try WorkoutCSVImportService.save(parsed, modelContext: context)

        let session = try context.fetch(FetchDescriptor<WorkoutSession>())[0]
        // Closed so it never resurfaces, but the unknown length is stored as zero, not guessed.
        #expect(session.endedAt == session.startedAt)
        #expect(session.durationSeconds == 0)
        #expect(WorkoutSessionService.findStaleSession(modelContext: context) == nil)
    }

    @MainActor
    @Test("Per-exercise notes reach the saved session so history shows them")
    func exerciseNotesAreSaved() throws {
        let context = try makeInMemoryContext()
        let csv = """
        "Date","Workout Name","Exercise Name","Set Order","Weight","Reps","Notes"
        "2024-01-15 18:30:00","Day","Squat","1","100","5","Belt on"
        """
        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)
        try WorkoutCSVImportService.save(parsed, modelContext: context)

        let session = try context.fetch(FetchDescriptor<WorkoutSession>())[0]
        let squat = try #require(session.exercises.first { $0.exerciseName == "Squat" })
        #expect(squat.note == "Belt on")
    }

    @MainActor
    @Test("A genuinely abandoned workout is still offered for recovery after an import")
    func abandonedWorkoutStillFoundAlongsideImports() throws {
        let context = try makeInMemoryContext()
        let parsed = try WorkoutCSVImporter.parse(strongCSV, strongFallbackUnit: .kg)
        try WorkoutCSVImportService.save(parsed, modelContext: context)

        let abandoned = WorkoutSession(
            templateName: "Leg Day",
            startedAt: Date().addingTimeInterval(-8 * 60 * 60),
            endedAt: nil
        )
        context.insert(abandoned)
        try context.save()

        let stale = try #require(WorkoutSessionService.findStaleSession(modelContext: context))
        #expect(stale.templateName == "Leg Day")
    }
}
