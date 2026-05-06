//
//  LiveActivityService.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//

import ActivityKit
import Foundation
import Sentry

/// Manages Live Activity during an active workout.
/// Shows program name, current exercise, time, and set progress on Lock Screen and Dynamic Island.
struct LiveActivityService {

    // MARK: - Start

    @discardableResult
    static func startLiveActivity(
        templateName: String,
        startedAt: Date,
        currentExercise: String,
        totalSets: Int
    ) -> Activity<IronWorkoutWidgetAttributes>? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }

        let attributes = IronWorkoutWidgetAttributes(
            templateName: templateName,
            startedAt: startedAt
        )
        let state = IronWorkoutWidgetAttributes.ContentState(
            currentExercise: currentExercise,
            completedSets: 0,
            totalSets: totalSets,
            elapsedSeconds: 0,
            isPaused: false
        )

        do {
            return try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil),
                pushType: nil
            )
        } catch let error as ActivityAuthorizationError {
            // Expected on devices/configurations where Live Activities aren't available
            // (unsupportedTarget, denied, etc.). Not actionable — skip Sentry capture.
            let crumb = Breadcrumb(level: .info, category: "live_activity")
            crumb.message = "Activity.request skipped: \(error)"
            SentrySDK.addBreadcrumb(crumb)
            return nil
        } catch {
            SentrySDK.capture(error: error)
            return nil
        }
    }

    // MARK: - Update

    static func updateLiveActivity(
        currentExercise: String,
        completedSets: Int,
        totalSets: Int,
        elapsedSeconds: Int,
        isPaused: Bool
    ) {
        guard let activity = Activity<IronWorkoutWidgetAttributes>.activities.first else { return }

        let state = IronWorkoutWidgetAttributes.ContentState(
            currentExercise: currentExercise,
            completedSets: completedSets,
            totalSets: totalSets,
            elapsedSeconds: elapsedSeconds,
            isPaused: isPaused
        )

        Task {
            await activity.update(.init(state: state, staleDate: nil))
        }
    }

    // MARK: - End

    static func endLiveActivity(
        completedSets: Int,
        totalSets: Int,
        elapsedSeconds: Int
    ) {
        guard let activity = Activity<IronWorkoutWidgetAttributes>.activities.first else { return }

        let finalState = IronWorkoutWidgetAttributes.ContentState(
            currentExercise: "Done!",
            completedSets: completedSets,
            totalSets: totalSets,
            elapsedSeconds: elapsedSeconds,
            isPaused: false
        )

        Task {
            await activity.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(.now + 60))
        }
    }
}
