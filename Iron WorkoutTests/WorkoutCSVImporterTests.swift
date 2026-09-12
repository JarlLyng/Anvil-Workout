//
//  WorkoutCSVImporterTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
@testable import Iron_Workout

@Suite("WorkoutCSVImporter")
struct WorkoutCSVImporterTests {

    // MARK: - Strong

    // Strong's CSV: comma-separated, quoted, one row per set.
    private let strongCSV = """
    "Date","Workout Name","Duration","Exercise Name","Set Order","Weight","Reps","Distance","Seconds","Notes","Workout Notes","RPE"
    "2024-01-15 18:30:00","Push Day","1h 2m","Bench Press","1","60","10","0","0","","",""
    "2024-01-15 18:30:00","Push Day","1h 2m","Bench Press","2","60","8","0","0","","",""
    "2024-01-15 18:30:00","Push Day","1h 2m","Overhead Press","1","40","8","0","0","","",""
    "2024-01-17 17:00:00","Pull Day","55m","Deadlift","1","100","5","0","0","","",""
    """

    @Test("Strong export groups rows into sessions, exercises, and sets")
    func parseStrong() throws {
        let parsed = try WorkoutCSVImporter.parse(strongCSV, strongFallbackUnit: .kg)
        #expect(parsed.format == .strong)
        #expect(parsed.sessionCount == 2)
        #expect(parsed.setCount == 4)

        let push = parsed.sessions[0]
        #expect(push.name == "Push Day")
        #expect(push.exercises.count == 2)
        #expect(push.exercises[0].name == "Bench Press")
        #expect(push.exercises[0].sets.count == 2)
        #expect(push.exercises[0].sets[0].reps == 10)
        #expect(push.exercises[0].sets[0].weightKg == 60)
        #expect(push.exercises[0].sets[0].type == .working)
    }

    @Test("Strong weights in lbs convert to kg via fallback unit")
    func strongLbsFallback() throws {
        let parsed = try WorkoutCSVImporter.parse(strongCSV, strongFallbackUnit: .lbs)
        let weight = try #require(parsed.sessions[0].exercises[0].sets[0].weightKg)
        // 60 lb -> 27.2155 kg
        #expect(abs(weight - 60 * 0.45359237) < 0.0001)
    }

    @Test("Strong weight-unit column overrides the fallback unit")
    func strongUnitColumn() throws {
        let csv = """
        Date,Workout Name,Exercise Name,Set Order,Weight,Weight Unit,Reps
        2024-01-15 18:30:00,Day,Squat,1,100,lbs,5
        """
        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)
        let weight = try #require(parsed.sessions[0].exercises[0].sets[0].weightKg)
        #expect(abs(weight - 100 * 0.45359237) < 0.0001)
    }

    // MARK: - Strong durations (#74)

    @Test("Strong Duration column becomes an end date")
    func strongDurationBecomesEndDate() throws {
        let parsed = try WorkoutCSVImporter.parse(strongCSV, strongFallbackUnit: .kg)

        // "1h 2m" = 3720s from 18:30:00.
        let push = parsed.sessions[0]
        let pushEnd = try #require(push.endedAt)
        #expect(pushEnd.timeIntervalSince(push.startedAt) == 3720)

        // "55m" = 3300s.
        let pull = parsed.sessions[1]
        let pullEnd = try #require(pull.endedAt)
        #expect(pullEnd.timeIntervalSince(pull.startedAt) == 3300)
    }

    @Test(
        "Duration strings parse across the formats Strong has exported",
        arguments: [
            ("1h 2m", 3720.0),
            ("45m", 2700.0),
            ("1h", 3600.0),
            ("1h 2m 30s", 3750.0),
            ("45 min", 2700.0),
            ("1hr 2min", 3720.0),
            ("30s", 30.0),
            ("1:02:30", 3750.0),
            ("45:30", 2730.0),
        ]
    )
    func durationFormats(raw: String, expected: Double) {
        #expect(WorkoutCSVImporter.parseDuration(raw) == expected)
    }

    @Test(
        "Unusable duration values fall back to nil rather than a guess",
        arguments: ["", "   ", "0m", "0:00", "-", "n/a", "3720"]
    )
    func durationRejectsUnusableValues(raw: String) {
        #expect(WorkoutCSVImporter.parseDuration(raw) == nil)
    }

    @Test("Strong export without a Duration column parses with no end date")
    func strongWithoutDurationColumn() throws {
        let csv = """
        Date,Workout Name,Exercise Name,Set Order,Weight,Reps
        2024-01-15 18:30:00,Day,Squat,1,100,5
        """
        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)
        #expect(parsed.sessions[0].endedAt == nil)
    }

    // MARK: - Partial-import reporting (#75)

    @Test("Strong timed sets are counted as skipped instead of vanishing")
    func strongTimedSetsAreReported() throws {
        let csv = """
        "Date","Workout Name","Duration","Exercise Name","Set Order","Weight","Reps","Distance","Seconds","Notes","Workout Notes","RPE"
        "2024-01-15 18:30:00","Core","30m","Bench Press","1","60","10","0","0","","",""
        "2024-01-15 18:30:00","Core","30m","Plank","1","0","0","0","60","","",""
        """
        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)

        #expect(parsed.setCount == 1)
        #expect(parsed.skipped.timedOrDistanceSets == 1)
        #expect(parsed.skipped.droppedRows == 1)
        // The exercise itself is gone too, so the count must not imply it was partially kept.
        #expect(parsed.sessions[0].exercises.count == 1)
    }

    @Test("Hevy duration and distance rows are counted as skipped")
    func hevyTimedSetsAreReported() throws {
        let csv = """
        title,start_time,end_time,exercise_title,superset_id,set_index,set_type,weight_kg,reps,distance_km,duration_seconds
        Mixed,2024-02-01 07:00:00,2024-02-01 08:00:00,Bench Press,,0,normal,80,8,,
        Mixed,2024-02-01 07:00:00,2024-02-01 08:00:00,Plank,,0,normal,0,0,,60
        Mixed,2024-02-01 07:00:00,2024-02-01 08:00:00,Run,,0,normal,0,0,5,
        """
        let parsed = try WorkoutCSVImporter.parse(csv)

        #expect(parsed.setCount == 1)
        #expect(parsed.skipped.timedOrDistanceSets == 2)
    }

    @Test("Placeholder rows with nothing in them are not reported as lost data")
    func emptyPlaceholderRowsAreNotReported() throws {
        let csv = """
        "Date","Workout Name","Exercise Name","Set Order","Weight","Reps","Distance","Seconds"
        "2024-01-15 18:30:00","Day","Squat","1","100","5","0","0"
        "2024-01-15 18:30:00","Day","Squat","2","0","0","0","0"
        """
        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)

        #expect(parsed.setCount == 1)
        // The second row carries no training data at all, so there is nothing to warn about.
        #expect(parsed.skipped.isEmpty)
    }

    @Test("Rows with an unreadable date are counted, blank rows are not")
    func unreadableDatesAreReported() throws {
        let csv = """
        "Date","Workout Name","Exercise Name","Set Order","Weight","Reps"
        "2024-01-15 18:30:00","Day","Squat","1","100","5"
        "not a date","Day","Squat","2","100","5"
        "","","","","",""
        """
        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)

        #expect(parsed.setCount == 1)
        #expect(parsed.skipped.unreadableDates == 1)
    }

    @Test("Workout-level notes are reported once per workout, not once per row")
    func workoutNotesReportedPerWorkout() throws {
        let csv = """
        "Date","Workout Name","Exercise Name","Set Order","Weight","Reps","Notes","Workout Notes"
        "2024-01-15 18:30:00","Day","Squat","1","100","5","","Felt strong"
        "2024-01-15 18:30:00","Day","Squat","2","100","5","","Felt strong"
        """
        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)

        #expect(parsed.skipped.droppedWorkoutNotes == 1)
        #expect(parsed.skipped.droppedRows == 0)
        #expect(!parsed.skipped.isEmpty)
    }

    @Test("A fully importable file reports nothing skipped")
    func cleanFileReportsNoSkips() throws {
        let parsed = try WorkoutCSVImporter.parse(strongCSV, strongFallbackUnit: .kg)
        #expect(parsed.skipped.isEmpty)
    }

    @Test("Per-exercise notes survive the import")
    func exerciseNotesArePreserved() throws {
        let csv = """
        "Date","Workout Name","Exercise Name","Set Order","Weight","Reps","Notes"
        "2024-01-15 18:30:00","Day","Squat","1","100","5","Belt on"
        "2024-01-15 18:30:00","Day","Squat","2","100","5",""
        """
        let parsed = try WorkoutCSVImporter.parse(csv, strongFallbackUnit: .kg)
        #expect(parsed.sessions[0].exercises[0].note == "Belt on")
    }

    // MARK: - Hevy

    // Hevy's CSV: includes set_type, weight already in kg, and superset grouping.
    private let hevyCSV = """
    "title","start_time","end_time","description","exercise_title","superset_id","exercise_notes","set_index","set_type","weight_kg","reps","distance_km","duration_seconds","rpe"
    "Upper A","2024-02-01 07:00:00","2024-02-01 08:00:00","","Bench Press","","","0","warmup","40","12","","",""
    "Upper A","2024-02-01 07:00:00","2024-02-01 08:00:00","","Bench Press","","","1","normal","80","8","","",""
    "Upper A","2024-02-01 07:00:00","2024-02-01 08:00:00","","Pull Up","1","","0","normal","0","10","","",""
    "Upper A","2024-02-01 07:00:00","2024-02-01 08:00:00","","Barbell Row","1","","0","normal","60","10","","",""
    """

    @Test("Hevy export parses set types, kg weights, and end time")
    func parseHevy() throws {
        let parsed = try WorkoutCSVImporter.parse(hevyCSV)
        #expect(parsed.format == .hevy)
        #expect(parsed.sessionCount == 1)
        #expect(parsed.setCount == 4)

        let session = parsed.sessions[0]
        #expect(session.name == "Upper A")
        #expect(session.endedAt != nil)
        #expect(session.exercises.count == 3)

        let bench = session.exercises[0]
        #expect(bench.sets[0].type == .warmup)
        #expect(bench.sets[1].type == .working)
        #expect(bench.sets[1].weightKg == 80)
    }

    @Test("Hevy export with imperial units (weight_lbs) converts to kg")
    func hevyImperialWeight() throws {
        // Hevy names the weight column after the user's unit; imperial users get weight_lbs.
        let csv = """
        title,start_time,end_time,exercise_title,superset_id,set_index,set_type,weight_lbs,reps,distance_miles,duration_seconds,rpe
        Upper A,2024-02-01 07:00:00,2024-02-01 08:00:00,Bench Press,,0,normal,225,5,,,
        """
        let parsed = try WorkoutCSVImporter.parse(csv)
        #expect(parsed.format == .hevy)
        let weight = try #require(parsed.sessions[0].exercises[0].sets[0].weightKg)
        // 225 lb -> ~102.06 kg
        #expect(abs(weight - 225 * 0.45359237) < 0.0001)
    }

    @Test("Hevy 'd MMM yyyy, HH:mm' date format is parsed")
    func hevyCommaDateFormat() throws {
        // Real Hevy exports use e.g. "28 Mar 2025, 17:29" for start_time.
        let csv = """
        title,start_time,end_time,exercise_title,superset_id,set_index,set_type,weight_kg,reps
        Leg Day,"28 Mar 2025, 17:29","28 Mar 2025, 18:52",Squat,,0,normal,100,5
        """
        let parsed = try WorkoutCSVImporter.parse(csv)
        #expect(parsed.sessionCount == 1)
        #expect(parsed.sessions[0].endedAt != nil)
        // Duration spans ~1h23m; just assert the dates parsed into a positive range.
        let session = parsed.sessions[0]
        let duration = try #require(session.endedAt).timeIntervalSince(session.startedAt)
        #expect(duration > 0)
    }

    @Test("Hevy superset_id is carried through as a grouping key")
    func hevySupersets() throws {
        let parsed = try WorkoutCSVImporter.parse(hevyCSV)
        let session = parsed.sessions[0]
        #expect(session.exercises[0].supersetKey == nil)        // Bench Press, no superset
        #expect(session.exercises[1].supersetKey == "1")        // Pull Up
        #expect(session.exercises[2].supersetKey == "1")        // Barbell Row, same superset
    }

    @Test("RPE column is parsed from both formats and out-of-range values dropped")
    func rpeParsing() throws {
        let strong = """
        Date,Workout Name,Exercise Name,Set Order,Weight,Reps,RPE
        2024-01-15,Day,Squat,1,100,5,8.5
        2024-01-15,Day,Squat,2,100,5,
        2024-01-15,Day,Squat,3,100,5,42
        """
        let parsedStrong = try WorkoutCSVImporter.parse(strong)
        let strongSets = parsedStrong.sessions[0].exercises[0].sets
        #expect(strongSets[0].rpe == 8.5)
        #expect(strongSets[1].rpe == nil)
        #expect(strongSets[2].rpe == nil)   // 42 is not a valid RPE

        let hevy = """
        title,start_time,exercise_title,set_index,set_type,weight_kg,reps,rpe
        Upper A,2024-02-01 07:00:00,Bench Press,0,normal,80,8,9
        """
        let parsedHevy = try WorkoutCSVImporter.parse(hevy)
        #expect(parsedHevy.sessions[0].exercises[0].sets[0].rpe == 9)
    }

    // MARK: - Errors & robustness

    @Test("Empty input throws .empty")
    func emptyInput() {
        #expect(throws: WorkoutCSVImportError.empty) {
            try WorkoutCSVImporter.parse("   \n  ")
        }
    }

    @Test("Unknown header throws .unrecognizedFormat")
    func unknownFormat() {
        #expect(throws: WorkoutCSVImportError.unrecognizedFormat) {
            try WorkoutCSVImporter.parse("foo,bar,baz\n1,2,3")
        }
    }

    @Test("Fields with embedded commas inside quotes are preserved")
    func quotedCommas() throws {
        let csv = """
        Date,Workout Name,Exercise Name,Set Order,Weight,Reps
        2024-01-15,"Legs, heavy","Squat (low bar)",1,100,5
        """
        let parsed = try WorkoutCSVImporter.parse(csv)
        #expect(parsed.sessions[0].name == "Legs, heavy")
        #expect(parsed.sessions[0].exercises[0].name == "Squat (low bar)")
    }

    @Test("Decimal reps and comma decimals are tolerated")
    func lenientNumbers() throws {
        let csv = """
        Date,Workout Name,Exercise Name,Set Order,Weight,Reps
        2024-01-15,Day,Curl,1,"12,5","10.0"
        """
        let parsed = try WorkoutCSVImporter.parse(csv)
        let set = parsed.sessions[0].exercises[0].sets[0]
        #expect(set.reps == 10)
        #expect(set.weightKg == 12.5)
    }

    @Test("Semicolon-delimited Strong export is detected")
    func semicolonDelimiter() throws {
        let csv = """
        Date;Workout Name;Exercise Name;Set Order;Weight;Reps
        2024-01-15;Day;Squat;1;100;5
        """
        let parsed = try WorkoutCSVImporter.parse(csv)
        #expect(parsed.format == .strong)
        #expect(parsed.sessions[0].exercises[0].sets[0].reps == 5)
    }
}
