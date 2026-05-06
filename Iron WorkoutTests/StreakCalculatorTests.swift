//
//  StreakCalculatorTests.swift
//  Anvil WorkoutTests
//

import Testing
import Foundation
@testable import Iron_Workout

@Suite("StreakCalculator")
struct StreakCalculatorTests {

    // Fixed calendar and date so tests don't depend on local time zone or "today".
    private static let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private static let referenceDate: Date = {
        // 2026-05-15 12:00 UTC — a fixed "today" for predictable streak math.
        var components = DateComponents()
        components.year = 2026
        components.month = 5
        components.day = 15
        components.hour = 12
        components.timeZone = TimeZone(identifier: "UTC")
        return calendar.date(from: components)!
    }()

    /// Helper: builds a completed session (completedSetCount > 0) on the day N days before reference.
    private static func session(daysAgo: Int, completed: Bool = true) -> WorkoutSession {
        let date = calendar.date(byAdding: .day, value: -daysAgo, to: referenceDate)!
        let session = WorkoutSession(
            templateName: "Test",
            startedAt: date
        )
        session.completedSetCount = completed ? 5 : 0
        return session
    }

    @Test("empty sessions returns 0")
    func emptySessions() {
        let streak = StreakCalculator.currentStreak(
            from: [],
            relativeTo: Self.referenceDate,
            calendar: Self.calendar
        )
        #expect(streak == 0)
    }

    @Test("session today only counts as streak of 1")
    func onlyToday() {
        let sessions = [Self.session(daysAgo: 0)]
        let streak = StreakCalculator.currentStreak(
            from: sessions,
            relativeTo: Self.referenceDate,
            calendar: Self.calendar
        )
        #expect(streak == 1)
    }

    @Test("today plus yesterday counts as 2")
    func todayAndYesterday() {
        let sessions = [Self.session(daysAgo: 0), Self.session(daysAgo: 1)]
        let streak = StreakCalculator.currentStreak(
            from: sessions,
            relativeTo: Self.referenceDate,
            calendar: Self.calendar
        )
        #expect(streak == 2)
    }

    @Test("today not done but yesterday was counts as 1")
    func yesterdayOnly() {
        let sessions = [Self.session(daysAgo: 1)]
        let streak = StreakCalculator.currentStreak(
            from: sessions,
            relativeTo: Self.referenceDate,
            calendar: Self.calendar
        )
        #expect(streak == 1)
    }

    @Test("today not done but yesterday and day before were counts as 2")
    func yesterdayAndDayBefore() {
        let sessions = [Self.session(daysAgo: 1), Self.session(daysAgo: 2)]
        let streak = StreakCalculator.currentStreak(
            from: sessions,
            relativeTo: Self.referenceDate,
            calendar: Self.calendar
        )
        #expect(streak == 2)
    }

    @Test("gap breaks the streak even when today is done")
    func gapBreaksStreak() {
        // Today done, yesterday missing, 2 days ago done -> streak should be 1 (just today).
        let sessions = [Self.session(daysAgo: 0), Self.session(daysAgo: 2)]
        let streak = StreakCalculator.currentStreak(
            from: sessions,
            relativeTo: Self.referenceDate,
            calendar: Self.calendar
        )
        #expect(streak == 1)
    }

    @Test("only old session with gap to today returns 0")
    func oldSessionWithGap() {
        // 3 days ago only, with today and yesterday and 2-days-ago all empty -> streak breaks
        // immediately when walking back from yesterday (checkDate starts at day-1).
        let sessions = [Self.session(daysAgo: 3)]
        let streak = StreakCalculator.currentStreak(
            from: sessions,
            relativeTo: Self.referenceDate,
            calendar: Self.calendar
        )
        #expect(streak == 0)
    }

    @Test("sessions with zero completed sets do not count")
    func incompleteSessionsIgnored() {
        let sessions = [
            Self.session(daysAgo: 0, completed: false),
            Self.session(daysAgo: 1, completed: false)
        ]
        let streak = StreakCalculator.currentStreak(
            from: sessions,
            relativeTo: Self.referenceDate,
            calendar: Self.calendar
        )
        #expect(streak == 0)
    }

    @Test("multiple sessions on same day still count as one day")
    func multipleSessionsSameDay() {
        let sessions = [
            Self.session(daysAgo: 0),
            Self.session(daysAgo: 0), // second workout today (e.g. core block)
            Self.session(daysAgo: 1)
        ]
        let streak = StreakCalculator.currentStreak(
            from: sessions,
            relativeTo: Self.referenceDate,
            calendar: Self.calendar
        )
        #expect(streak == 2)
    }

    @Test("7-day streak counted correctly")
    func sevenDayStreak() {
        let sessions = (0..<7).map { Self.session(daysAgo: $0) }
        let streak = StreakCalculator.currentStreak(
            from: sessions,
            relativeTo: Self.referenceDate,
            calendar: Self.calendar
        )
        #expect(streak == 7)
    }
}
