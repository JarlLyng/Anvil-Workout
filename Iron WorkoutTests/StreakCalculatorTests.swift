//
//  StreakCalculatorTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
@testable import Iron_Workout

@Suite("StreakCalculator")
struct StreakCalculatorTests {

    /// A Monday-first UTC calendar, so the tests do not depend on where they run.
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        cal.firstWeekday = 2
        return cal
    }()

    /// Friday 2026-05-15, 12:00 UTC. Its week runs Monday 11 May to Sunday 17 May.
    private static let referenceDate: Date = {
        calendar.date(from: DateComponents(year: 2026, month: 5, day: 15, hour: 12))!
    }()

    private static func session(daysAgo: Int, completed: Bool = true) -> WorkoutSession {
        let session = WorkoutSession(
            templateName: "Test",
            startedAt: calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
        )
        session.completedSetCount = completed ? 5 : 0
        return session
    }

    private static func streak(_ daysAgo: [Int]) -> Int {
        StreakCalculator.weekStreak(from: daysAgo.map { session(daysAgo: $0) }, relativeTo: referenceDate, calendar: calendar)
    }

    @Test("No workouts, no streak")
    func empty() {
        #expect(Self.streak([]) == 0)
    }

    @Test("A workout this week is a streak of one week")
    func thisWeek() {
        #expect(Self.streak([0]) == 1)
    }

    @Test("Three workouts in one week still count as one week")
    func severalInOneWeek() {
        #expect(Self.streak([0, 2, 4]) == 1)
    }

    @Test("This week and last week make two")
    func twoWeeks() {
        #expect(Self.streak([0, 7]) == 2)
    }

    @Test("Before this week's first workout, the streak runs to last week")
    func notBrokenBeforeTheFirstWorkout() {
        #expect(Self.streak([7]) == 1)
        #expect(Self.streak([7, 14]) == 2)
    }

    @Test("A week without a workout ends the streak")
    func gapEnds() {
        #expect(Self.streak([0, 14]) == 1)
        #expect(Self.streak([21]) == 0)
    }

    @Test("Last Sunday belongs to last week when weeks start on Monday")
    func weekBoundary() {
        // Five days before Friday is Sunday 10 May.
        #expect(Self.streak([0, 5]) == 2)
    }

    @Test("Sessions with no completed sets do not count")
    func incompleteIgnored() {
        let sessions = [Self.session(daysAgo: 0, completed: false), Self.session(daysAgo: 7)]
        #expect(StreakCalculator.weekStreak(from: sessions, relativeTo: Self.referenceDate, calendar: Self.calendar) == 1)
    }

    @Test("Twelve weeks in a row")
    func twelveWeeks() {
        #expect(Self.streak((0..<12).map { $0 * 7 }) == 12)
    }
}
