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
                        Text(formatTime(context.state.elapsedSeconds))
                            .font(.caption.monospacedDigit().weight(.semibold))
                        Text("\(context.state.completedSets)/\(context.state.totalSets) sets")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    ProgressView(
                        value: Double(context.state.completedSets),
                        total: Double(max(context.state.totalSets, 1))
                    )
                    .tint(context.state.isPaused ? .orange : .green)
                }
            } compactLeading: {
                HStack(spacing: 4) {
                    Image(systemName: context.state.isPaused ? "pause.fill" : "dumbbell.fill")
                        .font(.caption2)
                    Text(context.attributes.templateName)
                        .font(.caption2)
                        .lineLimit(1)
                }
            } compactTrailing: {
                Text(formatTime(context.state.elapsedSeconds))
                    .font(.caption2.monospacedDigit())
            } minimal: {
                Image(systemName: "dumbbell.fill")
                    .font(.caption2)
            }
        }
    }

    // MARK: - Lock Screen View

    private func lockScreenView(context: ActivityViewContext<IronWorkoutWidgetAttributes>) -> some View {
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
                Text(formatTime(context.state.elapsedSeconds))
                    .font(.title3.monospacedDigit().weight(.semibold))
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
        .padding()
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
    IronWorkoutWidgetAttributes.ContentState.paused
}
