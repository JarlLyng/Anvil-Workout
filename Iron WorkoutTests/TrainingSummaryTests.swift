//
//  TrainingSummaryTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
import SwiftData
@testable import Iron_Workout

@Suite("TrainingSummary")
struct TrainingSummaryTests {

    /// A Monday-first UTC calendar, so the week boundaries do not depend on where the
    /// tests run.
    private static let monday: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2
        return cal
    }()

    /// Wednesday 2026-10-07, 12:00 UTC.
    private static let wednesday: Date = {
        monday.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12))!
    }()

    private static func day(_ offset: Int, from date: Date = wednesday) -> Date {
        monday.date(byAdding: .day, value: offset, to: date)!
    }

    @MainActor
    private func makeContext() throws -> ModelContext {
        let schema = Schema([
            Exercise.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
            WorkoutSession.self, WorkoutSessionExercise.self, PerformedSet.self,
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        return ModelContext(container)
    }

    /// A session at `date` with one exercise and the given sets, each (reps, kg, done).
    @MainActor
    private func session(at date: Date, sets: [(Int?, Double?, Bool)], in context: ModelContext) -> WorkoutSession {
        let session = WorkoutSession(templateName: "Push", startedAt: date)
        context.insert(session)
        let exercise = WorkoutSessionExercise(exerciseName: "Bench Press", sortOrder: 0)
        context.insert(exercise)
        exercise.session = session
        session.exercises.append(exercise)
        for (index, set) in sets.enumerated() {
            let performed = PerformedSet(setIndex: index, targetReps: 5, actualReps: set.0, actualWeight: set.1, isCompleted: set.2)
            context.insert(performed)
            performed.sessionExercise = exercise
            exercise.performedSets.append(performed)
        }
        session.completedSetCount = sets.filter(\.2).count
        return session
    }

    // MARK: - Volume

    @MainActor
    @Test("Volume adds reps times weight over completed, weighted sets only")
    func volume() throws {
        let context = try makeContext()
        let s = session(at: Self.wednesday, sets: [
            (5, 100, true),   // 500
            (5, 100, true),   // 500
            (nil, nil, true), // skipped
            (8, nil, true),   // bodyweight
            (5, 100, false),  // not done
        ], in: context)

        #expect(TrainingSummary.volumeKg(of: s) == 1000)
    }

    @MainActor
    @Test("Warm-up sets add no volume and do not count as sets")
    func warmupsExcluded() throws {
        let context = try makeContext()
        let s = session(at: Self.wednesday, sets: [(10, 40, true), (5, 100, true)], in: context)
        s.exercises[0].performedSets.first { $0.setIndex == 0 }?.setType = .warmup

        #expect(TrainingSummary.volumeKg(of: s) == 500)
        #expect(TrainingSummary.workSetCount(of: s) == 1)
    }

    // MARK: - Weekly buckets

    @MainActor
    @Test("Weekly buckets cover every week, oldest first, with empty weeks as zeros")
    func weeklyBuckets() throws {
        let context = try makeContext()
        let sessions = [
            session(at: Self.wednesday, sets: [(5, 100, true), (5, 100, true)], in: context), // this week: 1000
            session(at: Self.day(-14), sets: [(5, 50, true)], in: context),                   // two weeks back: 250
            session(at: Self.day(-70), sets: [(5, 50, true)], in: context),                   // outside
        ]

        let buckets = TrainingSummary.weeklyBuckets(weeks: 4, endingAt: Self.wednesday, sessions: sessions, calendar: Self.monday)

        #expect(buckets.count == 4)
        #expect(buckets.map(\.workouts) == [0, 1, 0, 1])
        #expect(buckets.map(\.volumeKg) == [0, 250, 0, 1000])
        #expect(buckets.map(\.sets) == [0, 1, 0, 2])
        #expect(buckets.last?.start == Self.day(-2).addingTimeInterval(-12 * 3600)) // Monday 00:00
    }

    // MARK: - Strength

    @Test("Estimated 1RM is Brzycki's, for 1 to 12 reps only", arguments: [
        (1, 100.0, 100.0), (5, 100.0, 112.5), (10, 100.0, 36.0 * 100 / 27), (13, 100.0, -1), (0, 100.0, -1),
    ])
    func oneRepMax(reps: Int, weight: Double, expected: Double) {
        let value = TrainingSummary.estimatedOneRepMax(reps: reps, weightKg: weight)
        if expected < 0 {
            #expect(value == nil)
        } else {
            #expect(abs((value ?? 0) - expected) < 0.0001)
        }
    }

    // MARK: - Week

    @MainActor
    @Test("A week counts its own completed workouts, volume and days")
    func week() throws {
        let context = try makeContext()
        let sessions = [
            session(at: Self.day(-2), sets: [(5, 60, true)], in: context),        // Monday: 300
            session(at: Self.day(0), sets: [(5, 80, true)], in: context),         // Wednesday: 400
            session(at: Self.day(0, from: Self.day(0)), sets: [(3, 100, true)], in: context), // Wednesday again: 300
            session(at: Self.day(-3), sets: [(5, 100, true)], in: context),       // last Sunday
            session(at: Self.day(1), sets: [(5, 100, false)], in: context),       // Thursday, nothing done
        ]

        let week = TrainingSummary.week(containing: Self.wednesday, sessions: sessions, calendar: Self.monday)

        #expect(week.workouts == 3)
        #expect(week.volumeKg == 1000)
        #expect(week.trainedDays == [0, 2])
    }

    @Test("Weekday indices are Monday first whatever the calendar's first weekday")
    func weekdayIndex() {
        var sunday = Self.monday
        sunday.firstWeekday = 1
        // 2026-10-05 is a Monday, 2026-10-11 a Sunday.
        let mon = Self.monday.date(from: DateComponents(year: 2026, month: 10, day: 5, hour: 12))!
        let sun = Self.monday.date(from: DateComponents(year: 2026, month: 10, day: 11, hour: 12))!

        #expect(TrainingSummary.weekdayIndex(of: mon, calendar: Self.monday) == 0)
        #expect(TrainingSummary.weekdayIndex(of: sun, calendar: sunday) == 6)
    }

    @Test("The week strip starts where the region's week starts")
    func weekOrder() {
        var sunday = Self.monday
        sunday.firstWeekday = 1

        #expect(TrainingSummary.weekOrder(calendar: Self.monday) == [0, 1, 2, 3, 4, 5, 6])
        #expect(TrainingSummary.weekOrder(calendar: sunday) == [6, 0, 1, 2, 3, 4, 5])
    }

    @Test("Duration reads as minutes, then hours and minutes", arguments: [
        (20, "<1 min"), (60, "1 min"), (45 * 60, "45 min"), (3600, "1 h"), (3900, "1 h 5 min"),
    ])
    func duration(seconds: Int, text: String) {
        #expect(TrainingSummary.durationText(seconds: seconds) == text)
    }
}

@Suite("TrainingSummary, one workout")
struct TrainingSummaryWorkoutTests {

    @Test("A run of sets reads the way lifters write it", arguments: [
        ([(5, 100.0), (5, 100.0), (5, 100.0)], "3 × 5 · 100 kg"),
        ([(5, 100.0), (5, 100.0), (4, 100.0), (3, 100.0)], "100 kg × 5/5/4/3"),
        ([(5, 60.0), (5, 80.0), (5, 100.0), (3, 100.0)], "60 kg × 5 · 80 kg × 5 · 100 kg × 5/3"),
    ])
    func setsSummaryWeighted(sets: [(Int, Double)], text: String) {
        let input = sets.map { (reps: $0.0, kg: Optional($0.1)) }
        #expect(TrainingSummary.setsSummary(input, unit: .kg) == text)
    }

    @Test("Sets without weight read as reps")
    func setsSummaryBodyweight() {
        #expect(TrainingSummary.setsSummary([(10, nil), (10, nil), (10, nil)], unit: .kg) == "3 × 10")
        #expect(TrainingSummary.setsSummary([(10, nil), (8, nil), (6, nil)], unit: .kg) == "10/8/6 reps")
        #expect(TrainingSummary.setsSummary([], unit: .kg) == nil)
    }

    @Test("Percent change rounds, and needs something to compare with")
    func percentChange() {
        #expect(TrainingSummary.percentChange(from: 1000, to: 1060) == 6)
        #expect(TrainingSummary.percentChange(from: 1000, to: 955) == -5)
        #expect(TrainingSummary.percentChange(from: 0, to: 500) == nil)
    }

    @MainActor
    @Test("Last time means the latest earlier workout of the same program with a set done")
    func previousSession() throws {
        let schema = Schema([
            Exercise.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
            WorkoutSession.self, WorkoutSessionExercise.self, PerformedSet.self,
        ])
        let context = ModelContext(try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)]))
        func session(_ name: String, daysAgo: Double, sets: Int = 3) -> WorkoutSession {
            let s = WorkoutSession(templateName: name, startedAt: Date(timeIntervalSince1970: 1_800_000_000 - daysAgo * 86_400))
            s.completedSetCount = sets
            context.insert(s)
            return s
        }
        let today = session("A", daysAgo: 0)
        let lastA = session("A", daysAgo: 2)
        _ = session("A", daysAgo: 1, sets: 0)   // started, nothing done
        _ = session("B", daysAgo: 1)            // another program in between
        _ = session("A", daysAgo: 4)
        let all = [today, lastA] + (try context.fetch(FetchDescriptor<WorkoutSession>()))

        #expect(TrainingSummary.previousSession(of: today, in: all)?.id == lastA.id)
        #expect(TrainingSummary.previousSession(of: session("C", daysAgo: 0), in: all) == nil)
    }

    @Test("History groups this week, last week, then months, newest first")
    func historyGroups() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        calendar.firstWeekday = 2
        calendar.locale = Locale(identifier: "en_US_POSIX")
        // Wednesday 2026-10-07.
        let now = calendar.date(from: DateComponents(year: 2026, month: 10, day: 7, hour: 12))!
        func day(_ month: Int, _ day: Int, year: Int = 2026) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 18))!
        }
        let dates = [day(9, 2), day(10, 6), day(9, 29), day(10, 5), day(9, 15), day(12, 1, year: 2025)]

        let groups = TrainingSummary.historyGroups(dates, date: { $0 }, now: now, calendar: calendar)

        #expect(groups.map(\.title) == ["This week", "Last week", "September", "December 2025"])
        #expect(groups.map(\.items.count) == [2, 1, 2, 1])
        #expect(groups[0].items == [day(10, 6), day(10, 5)])
    }

    @Test("One record per exercise, a weight record first")
    func onePerExercise() {
        let records = [
            DetectedPersonalRecord(exerciseName: "Squat", type: .reps, value: "8 reps @ 100 kg", previousBest: "6 reps"),
            DetectedPersonalRecord(exerciseName: "Squat", type: .weight, value: "105 kg", previousBest: "100 kg"),
            DetectedPersonalRecord(exerciseName: "Bench", type: .reps, value: "6 reps @ 80 kg", previousBest: "5 reps"),
        ]

        let result = PersonalRecordService.onePerExercise(records)

        #expect(result.map(\.exerciseName) == ["Squat", "Bench"])
        #expect(result.map(\.type) == [.weight, .reps])
    }
}
