//
//  ActiveWorkoutView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import UIKit
import ActivityKit
import Sentry
import IAMJARLDesignTokens
import PhosphorSwift

struct ActiveWorkoutView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Bindable var session: WorkoutSession
    var onComplete: () -> Void
    var onEndWorkout: () -> Void

    @State private var state: ActiveWorkoutState?
    @State private var healthKitStarted = false
    @State private var showEndConfirm = false
    @State private var showSetEditor: PerformedSet?
    @State private var showCompletionSummary = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        Group {
            if showCompletionSummary {
                WorkoutCompletionView(session: session) {
                    onEndWorkout()
                }
            } else if let state {
                workoutBody(state: state)
            } else {
                ProgressView()
                    .onAppear {
                        let newState = ActiveWorkoutState(session: session, modelContext: modelContext)
                        newState.onSetCompleted = { [weak newState] in
                            guard let newState else { return }
                            updateLiveActivity(state: newState)
                            WatchConnectivityService.shared.sendSnapshot(newState.makeWatchSnapshot())
                        }
                        WatchConnectivityService.shared.actionHandler = { [weak newState] action in
                            newState?.apply(action)
                        }
                        state = newState
                    }
            }
        }
    }

    @ViewBuilder
    private func workoutBody(state: ActiveWorkoutState) -> some View {
        NavigationStack {
            ZStack {
                VStack(spacing: 0) {
                    WorkoutTimerBar(
                        isPaused: state.isPaused,
                        startedAt: session.startedAt,
                        totalPausedSeconds: state.totalPausedSeconds,
                        pausedAt: state.pausedAt
                    )
                    if let rest = state.restSecondsRemaining {
                        WorkoutRestBar(
                            seconds: rest,
                            totalSeconds: state.restTotalSeconds,
                            onAddTime: { state.addRestTime(30) },
                            onSkip: { state.skipRest() }
                        )
                    }
                    if let block = state.currentBlock {
                        if horizontalSizeClass == .regular {
                            iPadBlockLayout(state: state, block: block)
                        } else {
                            blockContent(state: state, block: block)
                        }
                    } else {
                        completedAllView(state: state)
                    }
                }
                if state.isPaused {
                    WorkoutPauseOverlay(onResume: {
                        state.resume()
                        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                        updateLiveActivity(state: state)
                    })
                }
            }
            .navigationTitle(session.templateName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent(state: state) }
            .confirmationDialog("End Workout?", isPresented: $showEndConfirm, titleVisibility: .visible) {
                Button("Save and End", role: .destructive) {
                    endWorkout(state: state)
                }
                Button("Continue", role: .cancel) { }
            } message: {
                Text("The workout will be saved as is. You can view it in History.")
            }
            .sheet(item: $showSetEditor) { set in
                EditPerformedSetSheet(performedSet: set) {
                    state.saveContext()
                    showSetEditor = nil
                }
            }
            .onAppear {
                startHealthKitIfAvailable()
                startLiveActivity(state: state)
                WatchConnectivityService.shared.sendSnapshot(state.makeWatchSnapshot())
            }
            .onDisappear {
                state.stopRestTimer()
                WatchConnectivityService.shared.actionHandler = nil
                WatchConnectivityService.shared.sendWorkoutEnded()
            }
            .onChange(of: state.restSecondsRemaining) { oldValue, newValue in
                if oldValue != nil && newValue == nil {
                    UINotificationFeedbackGenerator().notificationOccurred(.success)
                }
                WatchConnectivityService.shared.sendSnapshot(state.makeWatchSnapshot())
            }
            .onChange(of: state.currentBlockIndex) { _, _ in
                WatchConnectivityService.shared.sendSnapshot(state.makeWatchSnapshot())
            }
            .onChange(of: state.isPaused) { _, _ in
                WatchConnectivityService.shared.sendSnapshot(state.makeWatchSnapshot())
            }
            .alert("Error", isPresented: Binding(
                get: { state.errorMessage != nil },
                set: { if !$0 { state.errorMessage = nil } }
            )) {
                Button("OK") { state.errorMessage = nil }
            } message: {
                Text(state.errorMessage ?? "")
            }
        }
    }

    @ToolbarContentBuilder
    private func toolbarContent(state: ActiveWorkoutState) -> some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("End") { showEndConfirm = true }
                .foregroundStyle(DesignTokens.ColorToken.State.error)
                .accessibilityLabel("End workout")
                .accessibilityHint("Saves the current workout and returns to the dashboard")
        }
        ToolbarItem(placement: .primaryAction) {
            if state.isPaused {
                Button("Resume") {
                    state.resume()
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    updateLiveActivity(state: state)
                }
            } else {
                Menu {
                    Button("Pause workout") {
                        state.pause()
                        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
                        updateLiveActivity(state: state)
                    }
                    if state.currentBlock != nil {
                        Button("Skip current", role: .destructive) { state.skipBlock() }
                    }
                } label: {
                    Ph.dotsThreeCircle.regular
                        .icon(size: 24)
                        .accessibilityLabel("More options")
                }
            }
        }
    }

    // MARK: - HealthKit

    private func startHealthKitIfAvailable() {
        guard !healthKitStarted else { return }
        healthKitStarted = true
        Task {
            let health = HealthKitService.shared
            guard health.isAvailable else { return }
            do { try await health.requestAuthorization() } catch { SentrySDK.capture(error: error) }
            do { try await health.startWorkout(startDate: session.startedAt) } catch { SentrySDK.capture(error: error) }
        }
    }

    // MARK: - Live Activity

    private func startLiveActivity(state: ActiveWorkoutState) {
        let totalSets = session.exercises.flatMap(\.performedSets).count
        let currentExerciseName = state.currentBlock?.first?.exerciseName ?? session.templateName
        LiveActivityService.startLiveActivity(
            templateName: session.templateName,
            startedAt: session.startedAt,
            currentExercise: currentExerciseName,
            totalSets: totalSets
        )
        let crumb = Breadcrumb(level: .info, category: "workout")
        crumb.message = "Workout started"
        crumb.data = ["template": session.templateName, "exercises": session.exercises.count, "totalSets": totalSets]
        SentrySDK.addBreadcrumb(crumb)
    }

    private func updateLiveActivity(state: ActiveWorkoutState) {
        let totalSets = session.exercises.flatMap(\.performedSets).count
        let currentExerciseName = state.currentBlock?.first?.exerciseName ?? "Done"
        let elapsed = state.elapsedSeconds(at: .now)
        LiveActivityService.updateLiveActivity(
            currentExercise: currentExerciseName,
            completedSets: session.completedSetCount,
            totalSets: totalSets,
            elapsedSeconds: elapsed,
            isPaused: state.isPaused
        )
    }

    // MARK: - Block content

    private func blockContent(state: ActiveWorkoutState, block: [WorkoutSessionExercise]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxl) {
                if block.count > 1 {
                    HStack {
                        Ph.link.fill.icon().foregroundStyle(DesignTokens.ColorToken.State.warning)
                        Text("Superset").font(.headline).foregroundStyle(DesignTokens.ColorToken.State.warning)
                    }
                    .padding(.bottom, -DesignTokens.Spacing.md)
                }

                ForEach(block, id: \.id) { exercise in
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                        HStack {
                            Text(exercise.exerciseName)
                                .font(.title2.weight(.semibold))
                            Spacer()
                            Button("Skip") {
                                state.skipExercise(exercise)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Skip \(exercise.exerciseName)")
                        }

                        // Note field
                        HStack(spacing: DesignTokens.Spacing.sm) {
                            Ph.notepad.regular
                                .icon(size: 16)
                                .foregroundStyle(.secondary)
                            TextField("Add note...", text: Binding(
                                get: { exercise.note },
                                set: { newValue in
                                    exercise.note = newValue
                                    state.saveContext()
                                }
                            ), axis: .vertical)
                            .font(.caption)
                            .lineLimit(1...3)
                            .foregroundStyle(.secondary)
                        }

                        let sets = exercise.performedSets.sorted { $0.setIndex < $1.setIndex }
                        let firstPendingID = sets.first(where: { !$0.isCompleted })?.id
                        ForEach(sets, id: \.id) { set in
                            WorkoutSetRow(
                                set: set,
                                exercise: exercise,
                                isNextUp: set.id == firstPendingID,
                                onDone: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                        state.markSetDone(set, exercise: exercise)
                                    }
                                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                },
                                onSkip: {
                                    withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                                        state.markSetSkipped(set, exercise: exercise)
                                    }
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                },
                                onEdit: { showSetEditor = set }
                            )
                        }
                    }
                    if exercise.id != block.last?.id {
                        Divider().padding(.vertical, DesignTokens.Spacing.sm)
                    }
                }
            }
            .padding()
        }
        .safeAreaInset(edge: .bottom) {
            if !state.isAtLastBlock {
                nextBlockPreview(state: state)
            }
        }
    }

    private func nextBlockPreview(state: ActiveWorkoutState) -> some View {
        Group {
            if state.currentBlockIndex + 1 < state.exerciseBlocks.count {
                let nextBlock = state.exerciseBlocks[state.currentBlockIndex + 1]
                let names = nextBlock.map(\.exerciseName).joined(separator: " + ")
                HStack {
                    Ph.arrowCircleDown.regular
                        .icon()
                    Text("Next: \(names)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, DesignTokens.Spacing.sm)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    // MARK: - iPad layout

    /// Wider layout used on iPad: current block on the left (the workhorse
    /// surface where the user logs sets), a slim sidebar on the right showing
    /// upcoming blocks. This is the layout that pays for a propped-up iPad
    /// at the gym — you see the next exercise without scrolling.
    private func iPadBlockLayout(state: ActiveWorkoutState, block: [WorkoutSessionExercise]) -> some View {
        HStack(alignment: .top, spacing: 0) {
            blockContent(state: state, block: block)
                .frame(maxWidth: .infinity)

            Divider()

            upcomingSidebar(state: state)
                .frame(width: 260)
                .background(.regularMaterial)
        }
    }

    private func upcomingSidebar(state: ActiveWorkoutState) -> some View {
        let blocks = state.exerciseBlocks
        let upcoming = (state.currentBlockIndex + 1)..<blocks.count

        return ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                Text("Coming up")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    .padding(.top, DesignTokens.Spacing.md)

                if upcoming.isEmpty {
                    Text("This is the last block.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(upcoming), id: \.self) { index in
                        upcomingBlockRow(blocks[index], position: index - state.currentBlockIndex)
                    }
                }
            }
            .padding(DesignTokens.Spacing.lg)
        }
    }

    private func upcomingBlockRow(_ block: [WorkoutSessionExercise], position: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("\(position)")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .background(.quaternary, in: Circle())
                if block.count > 1 {
                    Ph.link.fill
                        .icon(size: 12)
                        .foregroundStyle(DesignTokens.ColorToken.State.warning)
                }
                Text(block.map(\.exerciseName).joined(separator: " + "))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
            }
            let setSummary = block
                .map { "\($0.performedSets.count) × \($0.performedSets.first?.targetReps ?? 0)" }
                .joined(separator: " · ")
            Text(setSummary)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial.opacity(0.4), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    private func completedAllView(state: ActiveWorkoutState) -> some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()
            Ph.checkCircle.fill
                .icon(size: 60)
                .foregroundStyle(DesignTokens.ColorToken.State.success)
            Text("All Exercises Completed")
                .font(.title2.bold())
            Text("\(session.completedSetCount) total sets")
                .foregroundStyle(.secondary)
            Button("End Workout") { endWorkout(state: state) }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                .padding(.top)
            Spacer()
        }
    }

    // MARK: - End workout

    private func endWorkout(state: ActiveWorkoutState) {
        state.stopRestTimer()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        let totalSets = session.exercises.flatMap(\.performedSets).count
        let elapsed = state.elapsedSeconds(at: .now)
        LiveActivityService.endLiveActivity(
            completedSets: session.completedSetCount,
            totalSets: totalSets,
            elapsedSeconds: elapsed
        )

        let crumb = Breadcrumb(level: .info, category: "workout")
        crumb.message = "Workout ended"
        crumb.data = ["template": session.templateName, "completedSets": session.completedSetCount, "totalSets": totalSets, "elapsedSeconds": elapsed]
        SentrySDK.addBreadcrumb(crumb)

        let context = modelContext
        Task {
            let health = HealthKitService.shared
            if health.isAvailable {
                do {
                    let result = try await health.endWorkout(endDate: Date())
                    await MainActor.run {
                        session.calories = result.calories
                        session.averageHeartRate = result.averageHeartRate
                    }
                } catch {
                    SentrySDK.capture(error: error)
                }
            }
            await MainActor.run {
                do {
                    try WorkoutSessionService.finalizeSession(session, modelContext: context)
                } catch {
                    SentrySDK.capture(error: error)
                    state.errorMessage = "Could not save: \(error.localizedDescription)"
                }
                WatchStatsBroadcaster.broadcast(from: context)
                showCompletionSummary = true
            }
        }
    }
}
