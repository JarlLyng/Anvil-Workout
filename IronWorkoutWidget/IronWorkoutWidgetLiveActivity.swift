//
//  IronWorkoutWidgetLiveActivity.swift
//  IronWorkoutWidget
//
//  Created by Jarl Lyng on 14/04/2026.
//

import ActivityKit
import WidgetKit
import SwiftUI

// IronWorkoutWidgetAttributes is defined in Shared/Models/LiveActivityAttributes.swift
// and shared between both targets via Target Membership.

// MARK: - Live Activity Widget

struct IronWorkoutWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: IronWorkoutWidgetAttributes.self) { context in
            // Lock Screen / Banner UI
            lockScreenView(context: context)
                .activityBackgroundTint(Color(.systemBackground))

        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(context.attributes.templateName)
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text(context.state.currentExercise)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        elapsedText(context.state)
                            .font(.caption.monospacedDigit().weight(.semibold))
                            .multilineTextAlignment(.trailing)
                        Text("\(context.state.completedSets)/\(context.state.totalSets) sets")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if let rest = context.state.restInterval {
                        restRow(rest, isOver: context.isStale)
                    } else {
                        ProgressView(
                            value: Double(context.state.completedSets),
                            total: Double(max(context.state.totalSets, 1))
                        )
                        .tint(context.state.isPaused ? .orange : .green)
                    }
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: compactIcon(context))
                        .font(.caption2)
                    Text(context.attributes.templateName)
                        .font(.caption2)
                        .lineLimit(1)
                }
            } compactTrailing: {
                // During rest the compact view counts the rest down instead of the workout
                // clock, with a timer icon on the leading side to say which it is.
                Group {
                    if let rest = context.state.restInterval, !context.isStale {
                        Text(timerInterval: rest, countsDown: true, showsHours: false)
                    } else {
                        elapsedText(context.state)
                    }
                }
                .font(.caption2.monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 44)
            } minimal: {
                Image(systemName: compactIcon(context))
                    .font(.caption2)
            }
        }
    }

    // MARK: - Lock Screen View

    private func lockScreenView(context: ActivityViewContext<IronWorkoutWidgetAttributes>) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(context.attributes.templateName)
                        .font(.headline)
                    Text(context.state.currentExercise)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    elapsedText(context.state)
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .multilineTextAlignment(.trailing)
                    HStack(spacing: 4) {
                        if context.state.isPaused {
                            Image(systemName: "pause.fill")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                        Text("\(context.state.completedSets)/\(context.state.totalSets) sets")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let rest = context.state.restInterval {
                restRow(rest, isOver: context.isStale)
            }
        }
        .padding()
    }

    // MARK: - Shared pieces

    /// The workout clock. The system counts it from `elapsedCountsFrom`, so it keeps moving
    /// with the app suspended, and holds it at `pausedAt` while paused (#96). A state without
    /// the date, such as the final "Done!" one, shows the seconds it was sent with.
    private func elapsedText(_ state: IronWorkoutWidgetAttributes.ContentState) -> Text {
        if let interval = state.elapsedInterval {
            return Text(timerInterval: interval, pauseTime: state.pausedAt, countsDown: false)
        }
        return Text(formatTime(state.elapsedSeconds))
    }

    /// Rest counting down with a bar that empties. The content goes stale when the rest ends
    /// (see `LiveActivityService`), which is how this knows the rest is over while the app is
    /// suspended and cannot send an update.
    private func restRow(_ rest: ClosedRange<Date>, isOver: Bool) -> some View {
        HStack(spacing: 8) {
            Text(isOver ? "Rest over" : "Rest")
                .font(.caption.weight(.semibold))
            if isOver {
                Spacer()
            } else {
                ProgressView(timerInterval: rest, countsDown: true) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(.green)
                // A timer text takes all the width it is offered, so it gets a fixed frame
                // and the bar gets the rest.
                Text(timerInterval: rest, countsDown: true, showsHours: false)
                    .font(.caption.monospacedDigit())
                    .multilineTextAlignment(.trailing)
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }

    private func compactIcon(_ context: ActivityViewContext<IronWorkoutWidgetAttributes>) -> String {
        if context.state.isPaused { return "pause.fill" }
        if context.state.restInterval != nil, !context.isStale { return "timer" }
        return "dumbbell.fill"
    }

    private func formatTime(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Previews

extension IronWorkoutWidgetAttributes {
    fileprivate static var preview: IronWorkoutWidgetAttributes {
        IronWorkoutWidgetAttributes(templateName: "Push Day", startedAt: .now)
    }
}

extension IronWorkoutWidgetAttributes.ContentState {
    fileprivate static var active: IronWorkoutWidgetAttributes.ContentState {
        IronWorkoutWidgetAttributes.ContentState(
            currentExercise: "Bench Press",
            completedSets: 6,
            totalSets: 15,
            elapsedSeconds: 1845,
            isPaused: false
        )
    }

    fileprivate static var resting: IronWorkoutWidgetAttributes.ContentState {
        IronWorkoutWidgetAttributes.ContentState(
            currentExercise: "Bench Press",
            completedSets: 6,
            totalSets: 15,
            elapsedSeconds: 1845,
            isPaused: false,
            elapsedCountsFrom: .now.addingTimeInterval(-1845),
            restEndsAt: .now.addingTimeInterval(75),
            restTotalSeconds: 90
        )
    }

    fileprivate static var paused: IronWorkoutWidgetAttributes.ContentState {
        IronWorkoutWidgetAttributes.ContentState(
            currentExercise: "Bench Press",
            completedSets: 6,
            totalSets: 15,
            elapsedSeconds: 1845,
            isPaused: true
        )
    }
}

#Preview("Notification", as: .content, using: IronWorkoutWidgetAttributes.preview) {
    IronWorkoutWidgetLiveActivity()
} contentStates: {
    IronWorkoutWidgetAttributes.ContentState.active
    IronWorkoutWidgetAttributes.ContentState.resting
    IronWorkoutWidgetAttributes.ContentState.paused
}
