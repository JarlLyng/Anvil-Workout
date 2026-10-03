//
//  ActiveWorkoutSubviews.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//

import SwiftUI
import SwiftData
import Sentry
import IAMJARLDesignTokens
import PhosphorSwift

// MARK: - WorkoutTimerBar

/// The workout clock and where the lifter is in the workout: "Exercise 2 of 4", sets done
/// out of all sets, and a thin bar for the same. The numbers sit on one line so the bar
/// costs one row, not three.
struct WorkoutTimerBar: View {
    @Environment(\.colorScheme) private var colorScheme
    let isPaused: Bool
    let startedAt: Date
    let totalPausedSeconds: Int
    let pausedAt: Date?
    /// "Exercise 2 of 4", or nil once every block is done.
    var positionText: String? = nil
    var completedSets: Int = 0
    var totalSets: Int = 0

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

    private func spokenElapsed(_ totalSeconds: Int) -> String {
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        if m > 0 && s > 0 { return "\(m) minutes \(s) seconds" }
        if m > 0 { return "\(m) minutes" }
        return "\(s) seconds"
    }

    private var progressLine: String {
        let sets = "\(completedSets)/\(totalSets) sets"
        guard let positionText else { return sets }
        return "\(positionText) \u{00B7} \(sets)"
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = elapsedSeconds(at: context.date)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                    Group {
                        if isPaused {
                            Ph.pauseCircle.fill
                                .icon()
                                .foregroundStyle(DesignTokens.ColorToken.State.warning)
                        } else {
                            Ph.timer.regular
                                .icon()
                                .foregroundStyle(.secondary)
                        }
                    }
                    .alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 6 }
                    Text(formatElapsed(elapsed))
                        .font(.title2.monospacedDigit().weight(.semibold))
                    if isPaused {
                        Text("Paused")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(DesignTokens.ColorToken.State.warning)
                    }
                    Spacer()
                    if totalSets > 0 {
                        Text(progressLine)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.trailing)
                            .minimumScaleFactor(0.8)
                    }
                }
                if totalSets > 0 {
                    ProgressView(value: Double(completedSets), total: Double(max(totalSets, 1)))
                        .tint(DesignTokens.Common.primary(colorScheme))
                }
            }
            .padding(.horizontal)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(.bar)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(isPaused ? "Workout paused" : "Workout time")
            .accessibilityValue("\(spokenElapsed(elapsed)). \(positionText ?? ""). \(completedSets) of \(totalSets) sets done")
        }
    }
}

// MARK: - WorkoutPauseOverlay

struct WorkoutPauseOverlay: View {
    @Environment(\.colorScheme) private var colorScheme
    var onResume: () -> Void

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Ph.pauseCircle.fill
                .icon(size: 60)
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
            .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
            .controlSize(.large)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

// MARK: - WorkoutRestBar

/// Rest as a clock, "2:59", large enough to read from the bench, with a thin bar that
/// empties. One colour for rest, and neutral buttons, so nothing here competes with Done.
struct WorkoutRestBar: View {
    let seconds: Int
    let totalSeconds: Int
    var onAddTime: () -> Void
    var onSkip: () -> Void

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Rest")
                        .font(.caption.weight(.semibold))
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                    Text(Self.clock(seconds))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                        .contentTransition(.numericText(countsDown: true))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Rest timer")
                .accessibilityValue("\(seconds) seconds remaining")

                Spacer()

                Button("+30s") { onAddTime() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
                    .accessibilityLabel("Add 30 seconds to rest")
                Button("Skip Rest") { onSkip() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
                    .accessibilityHint("Ends rest and moves on")
            }
            ProgressView(value: Double(seconds), total: Double(max(totalSeconds, 1)))
                .tint(DesignTokens.ColorToken.State.warning)
        }
        .padding(.horizontal)
        .padding(.vertical, DesignTokens.Spacing.md)
        .background(DesignTokens.ColorToken.State.warning.opacity(0.12))
    }
}

// MARK: - WorkoutSetRow

/// One set of an exercise. The current set is a card with the target as the largest thing
/// on screen and the only Done button; every other set is a single compact line. Tapping a
/// pending line makes it the current set, so sets can still be done out of order.
struct WorkoutSetRow: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    let set: PerformedSet
    let exercise: WorkoutSessionExercise
    var isCurrent: Bool = false
    var onDone: () -> Void
    var onSkip: () -> Void
    var onEdit: () -> Void
    var onFocus: () -> Void = {}
    @State private var errorMessage: String?
    /// What this exercise looked like last time, shown as a reference the lifter can tap.
    /// Loaded once per row appearance rather than per render: the lookup reads history.
    @State private var previous: PreviousSetReference?
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    private func colorForSetType(_ type: SetType) -> Color {
        switch type {
        case .working: return .primary
        case .warmup: return DesignTokens.ColorToken.State.warning
        case .drop: return DesignTokens.Common.primary(colorScheme)
        case .failure: return DesignTokens.ColorToken.State.error
        }
    }

    private var setContextLabel: String {
        let typeSuffix = set.setType == .working ? "" : " \(set.setType.displayName)"
        return "Set \(set.setIndex + 1)\(typeSuffix), \(exercise.exerciseName)"
    }

    /// "5 × 40 kg", or "5 reps" for a set without weight.
    private func summary(reps: Int, weightKg: Double?) -> String {
        guard let weightKg else { return reps == 1 ? "1 rep" : "\(reps) reps" }
        return "\(reps) \u{00D7} \(WeightFormatter.compact(kg: weightKg, in: weightUnit))"
    }

    /// What completing this set would record: entered value, else carried over from an
    /// earlier set of this exercise, else the template target.
    private var pendingSummary: String {
        summary(reps: set.actualReps ?? set.targetReps, weightKg: WorkoutSessionService.pendingWeight(for: set))
    }

    var body: some View {
        Group {
            if isCurrent && !set.isCompleted {
                currentCard
            } else {
                compactRow
            }
        }
        .task(id: set.id) {
            guard !set.isCompleted else { return }
            previous = PreviousSetLookup.find(
                for: exercise,
                setIndex: set.setIndex,
                isWarmup: set.setType == .warmup,
                modelContext: modelContext
            )
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: Current set

    private var currentCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            // Side by side when they fit; the last set's numbers go under at large text sizes.
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .firstTextBaseline) {
                    setTypeMenu
                    Spacer()
                    if let previous {
                        previousReferenceButton(previous)
                    }
                }
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    setTypeMenu
                    if let previous {
                        previousReferenceButton(previous)
                    }
                }
            }

            // Tapping the numbers opens the editor, so the actual reps and weight can be
            // entered before Done; markSetDone only fills values that are still empty.
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                Text(pendingSummary)
                    .font(.system(.largeTitle, design: .rounded, weight: .bold).monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Ph.pencilSimple.regular
                    .icon(size: 16)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            .onTapGesture { onEdit() }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(setContextLabel), \(pendingSummary)")
            .accessibilityHint("Double tap to enter reps and weight")
            .accessibilityAddTraits(.isButton)

            HStack(spacing: DesignTokens.Spacing.sm) {
                Button("Skip") { onSkip() }
                    .buttonStyle(.bordered)
                    .tint(.primary)
                    .controlSize(.large)
                    .accessibilityLabel("Skip \(setContextLabel)")
                Button { onDone() } label: {
                    Text("Done")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                .controlSize(.large)
                .accessibilityLabel("Mark \(setContextLabel) done")
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.lg).fill(.regularMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.lg)
                .strokeBorder(DesignTokens.Common.primary(colorScheme), lineWidth: 2)
        )
    }

    /// "Set 2 of 5", with the set type when it is not a working set. Also the menu that
    /// changes the type, as before.
    private var setTypeMenu: some View {
        Menu {
            ForEach(SetType.allCases, id: \.self) { type in
                Button(type.displayName) {
                    withAnimation { set.setType = type }
                    do { try modelContext.save() } catch {
                        SentrySDK.capture(error: error)
                        errorMessage = "Could not save: \(error.localizedDescription)"
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text("Set \(set.setIndex + 1) of \(exercise.performedSets.count)")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                if set.setType != .working {
                    Text(set.setType.displayName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(colorForSetType(set.setType))
                }
                Ph.caretDown.regular
                    .icon(size: 12)
                    .foregroundStyle(.secondary)
            }
        }
        // A menu label takes the accent tint; this one is a caption, not a call to action.
        .tint(.secondary)
        .accessibilityLabel("Set type for \(setContextLabel)")
    }

    /// "Last 40 kg × 5". Tapping reuses those numbers; it is an offer, never applied on
    /// its own.
    private func previousReferenceButton(_ reference: PreviousSetReference) -> some View {
        let label = reference.weightKg
            .map { "Last \(WeightFormatter.compact(kg: $0, in: weightUnit)) \u{00D7} \(reference.reps)" }
            ?? "Last \(reference.reps) reps"

        return Button {
            applyPrevious(reference)
        } label: {
            HStack(spacing: 4) {
                Ph.arrowCounterClockwise.regular
                    .icon(size: 12)
                Text(label)
                    .lineLimit(1)
            }
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Last time \(label.dropFirst(5)). Double tap to use these numbers for \(setContextLabel)")
    }

    private func applyPrevious(_ reference: PreviousSetReference) {
        set.actualReps = reference.reps
        if let weight = reference.weightKg { set.actualWeight = weight }
        do {
            try modelContext.save()
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    // MARK: Compact line

    private var isSkipped: Bool { self.set.isCompleted && self.set.actualReps == nil }

    private var compactSummary: String {
        guard set.isCompleted else { return pendingSummary }
        guard let reps = set.actualReps else { return "Skipped" }
        let rpePart = set.rpe.map { " \u{00B7} RPE \($0.formatted(.number.precision(.fractionLength(0...1))))" } ?? ""
        return summary(reps: reps, weightKg: set.actualWeight) + rpePart
    }

    private var compactRow: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Group {
                if isSkipped {
                    Ph.minusCircle.regular.icon().foregroundStyle(.secondary)
                } else if set.isCompleted {
                    Ph.checkCircle.fill.icon().foregroundStyle(DesignTokens.ColorToken.State.success)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Ph.circle.regular.icon().foregroundStyle(.tertiary)
                }
            }
            Text("\(set.setIndex + 1)")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(minWidth: 18, alignment: .leading)
            if set.setType != .working {
                Text(set.setType.displayName)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(colorForSetType(set.setType))
            }
            Text(compactSummary)
                .font(.body.monospacedDigit())
                .foregroundStyle(set.isCompleted && !isSkipped ? .primary : .secondary)
                .lineLimit(1)
            Spacer()
            if set.isCompleted {
                Text("Edit")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.Common.primary(colorScheme))
            }
        }
        // md keeps each line at least 44 points tall, the minimum comfortable tap target.
        .padding(.vertical, DesignTokens.Spacing.md)
        .padding(.horizontal, DesignTokens.Spacing.lg)
        .background {
            if set.isCompleted && !isSkipped {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.md)
                    .fill(DesignTokens.ColorToken.State.success.opacity(0.10))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if set.isCompleted { onEdit() } else { onFocus() }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(setContextLabel), \(compactSummary)")
        .accessibilityHint(set.isCompleted ? "Double tap to edit" : "Double tap to make this the current set")
        .accessibilityAddTraits(.isButton)
        .accessibilityAction(named: "Enter reps and weight") { onEdit() }
        .modifier(PendingActions(isPending: !set.isCompleted, onDone: onDone, onSkip: onSkip))
    }
}

/// Done and Skip as VoiceOver actions on a pending line, so a set can be completed out of
/// order without first making it current.
private struct PendingActions: ViewModifier {
    let isPending: Bool
    let onDone: () -> Void
    let onSkip: () -> Void

    func body(content: Content) -> some View {
        if isPending {
            content
                .accessibilityAction(named: "Mark done") { onDone() }
                .accessibilityAction(named: "Skip") { onSkip() }
        } else {
            content
        }
    }
}
