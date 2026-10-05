//
//  LiveActivityAttributes.swift
//  Anvil Workout
//
//  Shared between main app and widget extension.
//  Remember to add this file to BOTH targets in Xcode (Target Membership).
//
//  Created by Jarl Lyng on 14/04/2026.
//

import ActivityKit
import Foundation

// Plain data that ActivityKit uses off the main actor, so nonisolated even where the app
// target makes types main-actor isolated by default (#99).
nonisolated struct IronWorkoutWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentExercise: String
        var completedSets: Int
        var totalSets: Int
        /// Elapsed time when the state was sent. Shown as is only when there is no
        /// `elapsedCountsFrom`, which is the case for the final "Done!" state.
        var elapsedSeconds: Int
        var isPaused: Bool

        // The fields below are dates the Lock Screen counts from itself, so the clock and
        // the rest countdown keep moving while the app is suspended with the phone locked
        // (#96). They are optional so a state encoded before they existed still decodes.

        /// Where the workout clock counts from: `startedAt` moved forward by the seconds
        /// spent paused before now.
        var elapsedCountsFrom: Date? = nil
        /// When the current pause began. The clock stands at this moment while paused.
        var pausedAt: Date? = nil
        /// When the current rest ends. nil means no rest is running.
        var restEndsAt: Date? = nil
        /// Length of the current rest including added time, so the countdown's bar can
        /// start full.
        var restTotalSeconds: Int? = nil
    }

    var templateName: String
    var startedAt: Date
}

extension IronWorkoutWidgetAttributes.ContentState {
    /// The current rest as the range `Text(timerInterval:)` and `ProgressView(timerInterval:)`
    /// count down over. nil with no rest running.
    var restInterval: ClosedRange<Date>? {
        guard let end = restEndsAt, let total = restTotalSeconds else { return nil }
        return end.addingTimeInterval(-TimeInterval(max(total, 0)))...end
    }

    /// The workout clock as the range `Text(timerInterval:)` counts up over. The upper
    /// bound only has to lie beyond any workout.
    var elapsedInterval: ClosedRange<Date>? {
        guard let from = elapsedCountsFrom else { return nil }
        return from...Date.distantFuture
    }
}
