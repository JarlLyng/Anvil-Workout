//
//  ActiveWorkoutSubviews.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

// MARK: - WorkoutTimerBar

struct WorkoutTimerBar: View {
    let isPaused: Bool
    let startedAt: Date
    let totalPausedSeconds: Int
    let pausedAt: Date?

    private func elapsedSeconds(at date: Date) -> Int {
        let total = Int(date.timeIntervalSince(startedAt).rounded())
        let extraPause: Int
        if isPaused, let start = pausedAt {
            extraPause = Int(date.timeIntervalSince(start).rounded())
        } else {
            extraPause = 0
        }
        return max(0, total - totalPausedSeconds - extraPause)
    }

    private func formatElapsed(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack {
                Group {
                    if isPaused {
                        Ph.pauseCircle.fill
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(DesignTokens.ColorToken.State.warning)
                    } else {
                        Ph.timer.regular
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                    }
                }
                Text(formatElapsed(elapsedSeconds(at: context.date)))
                    .font(.title2.monospacedDigit().weight(.medium))
                if isPaused {
                    Text("Paused")
                        .font(.caption)
                        .foregroundStyle(DesignTokens.ColorToken.State.warning)
                }
                Spacer()
            }
            .padding()
            .background(.bar)
        }
    }
}

// MARK: - WorkoutPauseOverlay

struct WorkoutPauseOverlay: View {
    var onResume: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Ph.pauseCircle.fill
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundStyle(DesignTokens.ColorToken.State.warning)
            Text("Workout Paused")
                .font(.title2.bold())
            Text("Timer is stopped. Tap Resume to continue.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            Button("Resume Workout") {
                onResume()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - WorkoutRestBar

struct WorkoutRestBar: View {
    let seconds: Int
    let totalSeconds: Int
    var onAddTime: () -> Void
    var onSkip: () -> Void

    var body: some View {
        let progress = CGFloat(seconds) / CGFloat(max(totalSeconds, 1))
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(DesignTokens.ColorToken.State.warning.opacity(0.3), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(DesignTokens.ColorToken.State.warning, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                VStack(spacing: 2) {
                    Text("\(seconds)")
                        .font(.title.monospacedDigit().bold())
                    Text("Rest")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 64, height: 64)

            Spacer()

            VStack(spacing: 8) {
                Button("+30s") {
                    onAddTime()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Next") {
                    onSkip()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding()
        .background(DesignTokens.ColorToken.State.warning.opacity(0.15))
    }
}

// MARK: - WorkoutSetRow

struct WorkoutSetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    let set: PerformedSet
    let exercise: WorkoutSessionExercise
    var onDone: () -> Void
    var onSkip: () -> Void
    var onEdit: () -> Void
    @State private var errorMessage: String?

    private func colorForSetType(_ type: SetType) -> Color {
        switch type {
        case .working: return .primary
        case .warmup: return DesignTokens.ColorToken.State.warning
        case .drop: return DesignTokens.Common.primary(colorScheme)
        case .failure: return DesignTokens.ColorToken.State.error
        }
    }

    var body: some View {
        let targetWeight = set.targetWeight.map { " @ \($0.formatted(.number.precision(.fractionLength(0)))) kg" } ?? ""
        HStack {
            if set.isCompleted {
                completedContent
            } else {
                pendingContent(targetWeight: targetWeight)
            }
        }
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var completedContent: some View {
        Group {
            Ph.checkCircle.fill
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(DesignTokens.ColorToken.State.success)
                .transition(.scale.combined(with: .opacity))
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("Set \(set.setIndex + 1)")
                        .font(.subheadline.weight(.medium))
                    if set.setType != .working {
                        Text("(\(set.setType.rawValue))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(colorForSetType(set.setType))
                    }
                }
                if let reps = set.actualReps {
                    Text("\(reps) reps\(set.actualWeight.map { " \u{00B7} \($0.formatted(.number.precision(.fractionLength(1)))) kg" } ?? "")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Button("Edit") { onEdit() }
                .font(.caption)
        }
    }

    private func pendingContent(targetWeight: String) -> some View {
        Group {
            Ph.circle.regular
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 20, height: 20)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Menu {
                    ForEach(SetType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            withAnimation { set.setType = type }
                            do { try modelContext.save() } catch { errorMessage = "Error: \(error)" }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text("Set \(set.setIndex + 1)")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        if set.setType != .working {
                            Text("(\(set.setType.rawValue))")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(colorForSetType(set.setType))
                        }
                        Ph.caretDown.regular
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 12, height: 12)
                            .foregroundStyle(.secondary)
                    }
                }

                Text("\(set.targetReps) reps\(targetWeight)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: DesignTokens.Spacing.sm) {
                Button("Skip") { onSkip() }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                Button("Done") { onDone() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
    }
}
