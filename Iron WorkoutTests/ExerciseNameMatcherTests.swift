//
//  ExerciseNameMatcherTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
import SwiftData
@testable import Iron_Workout

@Suite("ExerciseNameMatcher")
struct ExerciseNameMatcherTests {

    /// The library the app seeds.
    private static let library = ExerciseLibraryService.builtinExercises.map {
        ExerciseNameMatcher.Entry(name: $0.name, equipment: $0.equipment, muscleGroup: $0.muscleGroup)
    }

    @Test("Strong and Hevy names find the library exercise they mean", arguments: [
        ("Bench Press (Barbell)", "Bench Press"),
        ("Bench Press (Dumbbell)", "Dumbbell Bench Press"),
        ("Squat (Barbell)", "Back Squat"),
        ("Deadlift (Barbell)", "Deadlift"),
        ("Overhead Press (Barbell)", "Overhead Press"),
        ("Overhead Press (Dumbbell)", "Dumbbell Shoulder Press"),
        ("Bent Over Row (Barbell)", "Barbell Row"),
        ("Bicep Curl (Barbell)", "Barbell Curl"),
        ("Bicep Curl (Cable)", "Cable Curl"),
        ("Triceps Pushdown (Cable - Straight Bar)", "Tricep Pushdown"),
        ("Lat Pulldown - Close Grip (Cable)", "Lat Pulldown"),
        ("Seated Cable Row - V Grip (Cable)", "Cable Row"),
        ("Lat Pulldown (Machine)", "Lat Pulldown"),
        ("Pull Up", "Pull-Up"),
        ("Pull Up (Weighted)", "Pull-Up"),
        ("Chest Press (Machine)", "Machine Chest Press"),
        ("Lying Leg Curl (Machine)", "Leg Curl"),
        ("Skull Crusher (EZ Bar)", "Skullcrusher"),
        ("bench press", "Bench Press"),
    ])
    func matches(imported: String, libraryName: String) {
        #expect(ExerciseNameMatcher.resolve(imported, library: Self.library) == .library(libraryName))
    }

    @Test("Other equipment is a different exercise, in the same muscle group", arguments: [
        ("Squat (Dumbbell)", MuscleGroup.legs),
        ("Romanian Deadlift (Dumbbell)", .legs),
        ("Incline Bench Press (Dumbbell)", .chest),
        ("Bench Press (Smith Machine)", .chest),
        ("Pull Up (Assisted)", .back),
        ("Lateral Raise (Cable)", .shoulders),
    ])
    func equipmentGuard(imported: String, group: MuscleGroup) {
        #expect(ExerciseNameMatcher.resolve(imported, library: Self.library) == .custom(group))
    }

    @Test("A movement the library lacks still gets its muscle group", arguments: [
        ("Bicep Curl (Dumbbell)", MuscleGroup.arms),
        ("Hanging Knee Raise", .core),
        ("Calf Press (Machine)", .legs),
        ("Narrow Grip Bench Press (Barbell)", .chest),
        ("Deficit Deadlift (Barbell)", .back),
        ("Farmer's Walk", .fullBody),
    ])
    func customGroup(imported: String, group: MuscleGroup) {
        #expect(ExerciseNameMatcher.resolve(imported, library: Self.library) == .custom(group))
    }

    @MainActor
    @Test("An import links Strong's names to the library and files the rest by muscle group")
    func importLinksLibrary() throws {
        let schema = Schema([
            Exercise.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
            WorkoutSession.self, WorkoutSessionExercise.self, PerformedSet.self,
        ])
        let context = ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
        ExerciseLibraryService.seedIfNeeded(modelContext: context)
        let csv = """
        Date,Workout Name,Exercise Name,Set Order,Weight,Weight Unit,Reps
        2026-09-21 18:00:00,Push,Bench Press (Barbell),1,60,kg,5
        2026-09-21 18:00:00,Push,Squat (Barbell),1,80,kg,5
        2026-09-21 18:00:00,Push,Bicep Curl (Dumbbell),1,12,kg,10
        2026-09-24 18:00:00,Push,Bench Press (Barbell),1,62.5,kg,5
        """

        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)
        let summary = try WorkoutCSVImportService.save(parsed, modelContext: context)

        let exercises = try context.fetch(FetchDescriptor<Exercise>())
        let bench = try #require(exercises.first { $0.name == "Bench Press" && $0.isBuiltin })
        let custom = exercises.filter { !$0.isBuiltin }
        let linked = try context.fetch(FetchDescriptor<WorkoutSessionExercise>())

        #expect(summary.createdExercises == 1)
        #expect(custom.map(\.name) == ["Bicep Curl (Dumbbell)"])
        #expect(custom.first?.muscleGroup == .arms)
        #expect(linked.filter { $0.exerciseID == bench.id }.count == 2)
        #expect(linked.contains { $0.exerciseName == "Back Squat" })
    }
}
