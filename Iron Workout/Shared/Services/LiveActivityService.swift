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
/// Shows program name, current exercise, time, set progress and rest on Lock Screen and Dynamic Island.
@MainActor
struct LiveActivityService {

    // MARK: - Start

    @discardableResult
    static func startLiveActivity(
        templateName: String,
        startedAt: Date,
        state: IronWorkoutWidgetAttributes.ContentState
    ) -> Activity<IronWorkoutWidgetAttributes>? {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return nil }

        let attributes = IronWorkoutWidgetAttributes(
            templateName: templateName,
            startedAt: startedAt
        )

        do {
            return try Activity.request(
                attributes: attributes,
                content: content(for: state),
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

    static func updateLiveActivity(_ state: IronWorkoutWidgetAttributes.ContentState) {
        enqueue {
            await currentActivity()?.update(content(for: state))
        }
    }

    /// The content to send for a state. While resting, it goes stale when the rest ends, so
    /// the Lock Screen can say the rest is over even if the app is suspended and sends
    /// nothing at that moment.
    private static func content(
        for state: IronWorkoutWidgetAttributes.ContentState
    ) -> ActivityContent<IronWorkoutWidgetAttributes.ContentState> {
        ActivityContent(state: state, staleDate: state.restEndsAt)
    }

    /// The running activity. An ended one stays in `activities` until it is dismissed, which
    /// is up to a minute after a workout, so the first one is not necessarily this workout's.
    /// A running one is `.stale` rather than `.active` once a rest's end has passed, and still
    /// has to take updates, or the Lock Screen would say "Rest over" for the rest of the workout.
    private static func currentActivity() -> Activity<IronWorkoutWidgetAttributes>? {
        Activity<IronWorkoutWidgetAttributes>.activities.first {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    /// The last update or end sent, which the next one waits for. Several updates can go
    /// out in the same moment (a completed set, then the rest it starts), and running them
    /// in order makes sure the last state sent is the one that shows.
    private static var lastSend: Task<Void, Never>?

    private static func enqueue(_ send: @escaping @MainActor () async -> Void) {
        let previous = lastSend
        lastSend = Task {
            await previous?.value
            await send()
        }
    }

    // MARK: - End

    /// Ends activities left by an earlier run of the app. A workout lives only in the process
    /// that runs it: the app never reopens one after a relaunch, and one left running is
    /// offered for saving later (`WorkoutSessionService.findStaleSession`). So any activity
    /// alive at launch belongs to a process that was killed, and would otherwise stay on the
    /// Lock Screen with its clock counting for hours.
    static func endLeftoverActivities() {
        enqueue {
            for activity in Activity<IronWorkoutWidgetAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    static func endLiveActivity(
        completedSets: Int,
        totalSets: Int,
        elapsedSeconds: Int
    ) {
        let finalState = IronWorkoutWidgetAttributes.ContentState(
            currentExercise: "Done!",
            completedSets: completedSets,
            totalSets: totalSets,
            elapsedSeconds: elapsedSeconds,
            isPaused: false
        )

        enqueue {
            await currentActivity()?.end(.init(state: finalState, staleDate: nil), dismissalPolicy: .after(.now + 60))
        }
    }
}
