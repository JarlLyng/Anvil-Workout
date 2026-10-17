//
//  ReviewPrompt.swift
//  Anvil Workout
//
//  When the completion screen asks for an App Store review (#113). It used to ask only at
//  exactly 5, 15 or 50 completed workouts, and the count includes imported ones, so a lifter
//  who brought their history from Strong or Hevy landed past 50 at once and was never asked.
//  Now each threshold is asked for once, the first time a finished workout reaches it, and
//  the highest one asked is remembered. Apple's own limit of three prompts a year still
//  applies on top. Pure, so the rule can be tested without a store.
//

import Foundation

enum ReviewPrompt {
    /// Completed workouts at which to ask, lowest first.
    static let thresholds = [5, 15, 50]

    /// The highest threshold already asked for; 0 before the first.
    static let storageKey = "reviewPromptLastThreshold"

    /// What just happened.
    enum Moment: Equatable {
        /// A workout ended on the completion screen, with this many completed sets.
        case workoutCompleted(completedSets: Int)
        /// History came in from a CSV file. Never a reason to ask.
        case historyImported
    }

    /// The threshold to ask for now, or nil: the highest one the count has reached that is
    /// above the last one asked for. A count that jumps past several asks once, for the
    /// highest. Only a finished workout with sets in it asks.
    static func thresholdToAsk(after moment: Moment, completedWorkouts: Int, lastAsked: Int) -> Int? {
        guard case .workoutCompleted(let completedSets) = moment, completedSets > 0 else { return nil }
        return thresholds.last { $0 <= completedWorkouts && $0 > lastAsked }
    }
}
