//
//  StreakCalculator.swift
//  Anvil Workout
//
//  Pure, testable logic for calculating workout streaks. Extracted from DashboardView
//  so behavior can be unit-tested with controlled inputs.
//

import Foundation

enum StreakCalculator {

    /// The number of calendar weeks in a row with at least one completed workout, ending
    /// with this week.
    ///
    /// Weeks rather than days: a lifter on three days a week trains with rest days in
    /// between, so a day streak sat at 0 or 1 and read as a failure. A week streak holds for
    /// anyone who trains every week, however many days.
    ///
    /// - While this week has no workout yet, the streak runs to last week, so it is not
    ///   broken on a Monday before the first workout.
    /// - A session counts when `completedSetCount > 0`.
    /// - Weeks start on the calendar's first weekday, which follows the user's region.
    static func weekStreak(
        from sessions: [WorkoutSession],
        relativeTo referenceDate: Date = .now,
        calendar: Calendar = .current
    ) -> Int {
        let trainedWeeks = Set(sessions
            .filter { $0.completedSetCount > 0 }
            .compactMap { calendar.dateInterval(of: .weekOfYear, for: $0.startedAt)?.start })
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: referenceDate)?.start,
              var week = trainedWeeks.contains(thisWeek)
                ? thisWeek
                : calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeek) else { return 0 }

        var streak = 0
        while trainedWeeks.contains(week) {
            streak += 1
            guard let previous = calendar.date(byAdding: .weekOfYear, value: -1, to: week) else { break }
            week = previous
        }
        return streak
    }
}
