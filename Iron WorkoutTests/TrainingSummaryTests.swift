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
