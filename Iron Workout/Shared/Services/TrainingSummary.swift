//
//  TrainingSummary.swift
//  Anvil Workout
//
//  The numbers the home screen shows about training: volume per session and what a week
//  added up to. Plain functions over sessions, so they can be tested without queries and
//  shared with Stats.
//

import Foundation

enum TrainingSummary {

    /// Reps times weight over the completed sets that have both, in kilograms. Skipped
    /// sets and bodyweight sets add nothing.
    static func volumeKg(of session: WorkoutSession) -> Double {
        session.exercises
            .flatMap(\.performedSets)
            .filter(\.isCompleted)
            .reduce(0) { total, set in
                guard let reps = set.actualReps, let weight = set.actualWeight else { return total }
                return total + Double(reps) * weight
            }
    }

    struct Week: Equatable {
        var workouts: Int = 0
        var volumeKg: Double = 0
        /// Days with at least one completed workout, as weekday indices with Monday = 0,
        /// the same indices the weekly plan stores.
        var trainedDays: Set<Int> = []
    }

    /// The week containing `date`, as the calendar defines weeks (its first weekday follows
    /// the user's region). Only sessions with a completed set count, as everywhere else.
    static func week(containing date: Date, sessions: [WorkoutSession], calendar: Calendar = .current) -> Week {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return Week() }
        var week = Week()
        for session in sessions where session.completedSetCount > 0 && interval.contains(session.startedAt) {
            week.workouts += 1
            week.volumeKg += volumeKg(of: session)
            week.trainedDays.insert(weekdayIndex(of: session.startedAt, calendar: calendar))
        }
        return week
    }

    /// Monday = 0 ... Sunday = 6, whatever the calendar's first weekday.
    static func weekdayIndex(of date: Date, calendar: Calendar = .current) -> Int {
        (calendar.component(.weekday, from: date) + 5) % 7
    }

    /// The seven weekday indices (Monday = 0) in the order the calendar's week runs, so a
    /// region whose week starts on Sunday sees Sunday first.
    static func weekOrder(calendar: Calendar = .current) -> [Int] {
        let first = (calendar.firstWeekday + 5) % 7
        return (0..<7).map { (first + $0) % 7 }
    }

    /// "45 min", "1 h 5 min". Under a minute reads "<1 min" rather than "0 min".
    static func durationText(seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes < 1 { return "<1 min" }
        if minutes < 60 { return "\(minutes) min" }
        let rest = minutes % 60
        return rest == 0 ? "\(minutes / 60) h" : "\(minutes / 60) h \(rest) min"
    }
}
