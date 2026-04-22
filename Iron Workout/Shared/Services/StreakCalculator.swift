//
//  StreakCalculator.swift
//  Iron Workout
//
//  Pure, testable logic for calculating workout streaks. Extracted from DashboardView
//  so behavior can be unit-tested with controlled inputs.
//

import Foundation

enum StreakCalculator {

    /// Returns the number of consecutive days with at least one completed workout, ending
    /// at or just before the given reference date.
    ///
    /// A session counts as "completed" when `completedSetCount > 0`.
    ///
    /// Logic:
    /// - If the reference day itself has a completed session, the streak starts at that day
    ///   and walks backward counting consecutive days.
    /// - If the reference day has no completed session, the streak starts at the day before
    ///   the reference day (so a user who hasn't trained yet today doesn't see 0 while
    ///   yesterday's streak is still intact).
    /// - The streak ends at the first day that has no completed session.
    ///
    /// - Parameters:
    ///   - sessions: All known `WorkoutSession` values. Order does not matter.
    ///   - referenceDate: The "now" anchor. Defaults to the current date.
    ///   - calendar: Calendar used for day boundaries. Defaults to `.current`.
    static func currentStreak(
        from sessions: [WorkoutSession],
        relativeTo referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let completed = sessions.filter { $0.completedSetCount > 0 }
        guard !completed.isEmpty else { return 0 }

        let referenceDayStart = calendar.startOfDay(for: referenceDate)
        let hasSessionOnReferenceDay = completed.contains {
            calendar.isDate($0.startedAt, inSameDayAs: referenceDayStart)
        }

        var checkDate: Date
        if hasSessionOnReferenceDay {
            checkDate = referenceDayStart
        } else {
            guard let previousDay = calendar.date(byAdding: .day, value: -1, to: referenceDayStart) else {
                return 0
            }
            checkDate = previousDay
        }

        var streak = 0
        while true {
            let hasSession = completed.contains {
                calendar.isDate($0.startedAt, inSameDayAs: checkDate)
            }
            if hasSession {
                streak += 1
                guard let previousDay = calendar.date(byAdding: .day, value: -1, to: checkDate) else {
                    break
                }
                checkDate = previousDay
            } else {
                break
            }
        }
        return streak
    }
}
