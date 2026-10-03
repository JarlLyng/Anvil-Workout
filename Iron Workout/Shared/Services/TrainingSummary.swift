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

    /// Whether a set counts as work: completed and not a warm-up. Drop and failure sets
    /// count. The one rule for volume, sets and strength everywhere in the app.
    static func isWorkSet(_ set: PerformedSet) -> Bool {
        set.isCompleted && set.setType != .warmup
    }

    /// Reps times weight over the work sets that have both, in kilograms. Skipped sets,
    /// warm-ups and bodyweight sets add nothing.
    static func volumeKg(of session: WorkoutSession) -> Double {
        session.exercises
            .flatMap(\.performedSets)
            .filter(isWorkSet)
            .reduce(0) { total, set in
                guard let reps = set.actualReps, let weight = set.actualWeight else { return total }
                return total + Double(reps) * weight
            }
    }

    /// Completed work sets with reps, so skipped sets do not count.
    static func workSetCount(of session: WorkoutSession) -> Int {
        session.exercises.flatMap(\.performedSets).filter { isWorkSet($0) && $0.actualReps != nil }.count
    }

    // MARK: - Weeks over a period

    struct WeekBucket: Identifiable, Equatable {
        var id: Date { start }
        let start: Date
        var workouts: Int = 0
        var sets: Int = 0
        var volumeKg: Double = 0
    }

    /// One bucket per calendar week, oldest first, for the `weeks` weeks ending with the
    /// week containing `date`. Weeks without training are present with zeros, so a chart
    /// shows gaps as gaps.
    static func weeklyBuckets(weeks: Int, endingAt date: Date = .now, sessions: [WorkoutSession], calendar: Calendar = .current) -> [WeekBucket] {
        guard weeks > 0, let current = calendar.dateInterval(of: .weekOfYear, for: date)?.start else { return [] }
        var buckets: [WeekBucket] = (0..<weeks).reversed().compactMap { back in
            calendar.date(byAdding: .weekOfYear, value: -back, to: current).map { WeekBucket(start: $0) }
        }
        let index = Dictionary(uniqueKeysWithValues: buckets.enumerated().map { ($1.start, $0) })
        for session in sessions where session.completedSetCount > 0 {
            guard let start = calendar.dateInterval(of: .weekOfYear, for: session.startedAt)?.start,
                  let i = index[start] else { continue }
            buckets[i].workouts += 1
            buckets[i].sets += workSetCount(of: session)
            buckets[i].volumeKg += volumeKg(of: session)
        }
        return buckets
    }

    // MARK: - Strength

    /// Estimated one-rep max from a set, Brzycki's formula. Only for 1 to 12 reps: above
    /// that the estimate stops meaning much.
    static func estimatedOneRepMax(reps: Int, weightKg: Double) -> Double? {
        guard (1...12).contains(reps), weightKg > 0 else { return nil }
        return weightKg * 36 / (37 - Double(reps))
    }

    /// The best estimated one-rep max per workout for `exercise`, oldest first, from work
    /// sets on or after `since`.
    static func oneRepMaxHistory(for exercise: Exercise, since: Date, sessions: [WorkoutSession]) -> [(date: Date, kg: Double)] {
        sessions
            .filter { $0.completedSetCount > 0 && $0.startedAt >= since }
            .sorted { $0.startedAt < $1.startedAt }
            .compactMap { session in
                let best = session.exercises
                    .filter { $0.matches(exercise) }
                    .flatMap(\.performedSets)
                    .filter(isWorkSet)
                    .compactMap { set -> Double? in
                        guard let reps = set.actualReps, let weight = set.actualWeight else { return nil }
                        return estimatedOneRepMax(reps: reps, weightKg: weight)
                    }
                    .max()
                return best.map { (session.startedAt, $0) }
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
