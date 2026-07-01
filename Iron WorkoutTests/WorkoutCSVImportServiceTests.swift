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
}
