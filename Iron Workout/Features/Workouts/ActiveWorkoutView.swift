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

    @State private var currentBlockIndex: Int = 0
    @State private var healthKitStarted = false
    @State private var restSecondsRemaining: Int?
    @State private var restTimer: Timer?
    @State private var showEndConfirm = false
    @State private var showSetEditor: PerformedSet?
    @State private var showCompletionSummary = false
    @State private var isPaused = false
    @State private var pausedAt: Date?
    @State private var totalPausedSeconds: Int = 0
    @State private var errorMessage: String?
    @State private var restTotalSeconds: Int = 0

    private var sortedExercises: [WorkoutSessionExercise] {
        session.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }
    
    private var exerciseBlocks: [[WorkoutSessionExercise]] {
        var blocks: [[WorkoutSessionExercise]] = []
        var currentBlock: [WorkoutSessionExercise] = []
        for ex in sortedExercises {
            if currentBlock.isEmpty {
                currentBlock.append(ex)
            } else {
                if let sid = ex.supersetID, sid == currentBlock.last?.supersetID {
                    currentBlock.append(ex)
                } else {
                    blocks.append(currentBlock)
                    currentBlock = [ex]
                }
            }
        }
        if !currentBlock.isEmpty {
            blocks.append(currentBlock)
        }
        return blocks
    }

    private var currentBlock: [WorkoutSessionExercise]? {
        let blocks = exerciseBlocks
        guard currentBlockIndex >= 0, currentBlockIndex < blocks.count else { return nil }
        return blocks[currentBlockIndex]
    }

    private func elapsedSeconds(at date: Date) -> Int {
        let total = Int(date.timeIntervalSince(session.startedAt).rounded())
        let extraPause: Int
        if isPaused, let start = pausedAt {
            extraPause = Int(date.timeIntervalSince(start).rounded())
        } else {
            extraPause = 0
        }
        return max(0, total - totalPausedSeconds - extraPause)
    }

    var body: some View {
        Group {
            if showCompletionSummary {
                WorkoutCompletionView(session: session) {
                    onEndWorkout()
                }
            } else {
                NavigationStack {
                    ZStack {
                        VStack(spacing: 0) {
                            timerBar
                            if let rest = restSecondsRemaining {
                                restBar(seconds: rest)
                            }
                            if let block = currentBlock {
                                blockContent(block: block)
                            } else {
                                completedAllView
                            }
                        }
                        if isPaused {
                            pauseOverlay
                        }
                    }
            .navigationTitle(session.templateName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("End") { showEndConfirm = true }
                        .foregroundStyle(DesignTokens.ColorToken.State.error)
                        .accessibilityLabel("End workout")
                        .accessibilityHint("Saves the current workout and returns to the dashboard")
                }
                ToolbarItem(placement: .primaryAction) {
                    if isPaused {
                        Button("Resume") { resumeWorkout() }
                    } else {
                        Menu {
                            Button("Pause workout") { pauseWorkout() }
                            if currentBlock != nil {
                                Button("Skip current", role: .destructive) { skipBlock() }
                            }
                        } label: {
                            Ph.dotsThreeCircle.regular
                                .icon(size: 24)
                                .accessibilityLabel("More options")
                        }
                    }
                }
            }
            .confirmationDialog("End Workout?", isPresented: $showEndConfirm, titleVisibility: .visible) {
                Button("Save and End", role: .destructive) {
                    endWorkout()
                }
                Button("Continue", role: .cancel) { }
            } message: {
                Text("The workout will be saved as is. You can view it in History.")
            }
            .sheet(item: $showSetEditor) { set in
                EditPerformedSetSheet(performedSet: set) {
                    do { try modelContext.save() } catch {
                        SentrySDK.capture(error: error)
                        errorMessage = "Could not save: \(error.localizedDescription)"
                    }
                    showSetEditor = nil
                }
            }
            .onAppear {
                startHealthKitIfAvailable()
                startLiveActivity()
            }
            .onDisappear {
                stopRestTimer()
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
            }
        }
    }

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

    private func startLiveActivity() {
        let totalSets = session.exercises.flatMap(\.performedSets).count
        let currentExerciseName = currentBlock?.first?.exerciseName ?? session.templateName
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

    private func updateLiveActivity() {
        let totalSets = session.exercises.flatMap(\.performedSets).count
        let currentExerciseName = currentBlock?.first?.exerciseName ?? "Done"
        let elapsed = elapsedSeconds(at: .now)
        LiveActivityService.updateLiveActivity(
            currentExercise: currentExerciseName,
            completedSets: session.completedSetCount,
            totalSets: totalSets,
            elapsedSeconds: elapsed,
            isPaused: isPaused
        )
    }

    private var timerBar: some View {
        WorkoutTimerBar(
            isPaused: isPaused,
            startedAt: session.startedAt,
            totalPausedSeconds: totalPausedSeconds,
            pausedAt: pausedAt
        )
    }

    private var pauseOverlay: some View {
        WorkoutPauseOverlay(onResume: { resumeWorkout() })
    }

    private func restBar(seconds: Int) -> some View {
        WorkoutRestBar(
            seconds: seconds,
            totalSeconds: restTotalSeconds,
            onAddTime: {
                restTotalSeconds += 30
                restSecondsRemaining = (restSecondsRemaining ?? 0) + 30
            },
            onSkip: {
                stopRestTimer()
                advanceToNextBlockIfNeeded()
            }
        )
    }

    private func blockContent(block: [WorkoutSessionExercise]) -> some View {
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
                                skipExercise(exercise)
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
                                    do { try modelContext.save() } catch { SentrySDK.capture(error: error) }
                                }
                            ), axis: .vertical)
                            .font(.caption)
                            .lineLimit(1...3)
                            .foregroundStyle(.secondary)
                        }

                        let sets = exercise.performedSets.sorted { $0.setIndex < $1.setIndex }
                        let firstPendingID = sets.first(where: { !$0.isCompleted })?.id
                        ForEach(sets, id: \.id) { set in
                            setRow(set: set, exercise: exercise, isNextUp: set.id == firstPendingID)
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
            if currentBlockIndex < exerciseBlocks.count - 1 {
                nextBlockPreview
            }
        }
    }

    private func setRow(set: PerformedSet, exercise: WorkoutSessionExercise, isNextUp: Bool) -> some View {
        WorkoutSetRow(
            set: set,
            exercise: exercise,
            isNextUp: isNextUp,
            onDone: { markSetDone(set, exercise: exercise) },
            onSkip: { markSetSkipped(set, exercise: exercise) },
            onEdit: { showSetEditor = set }
        )
    }

    private var nextBlockPreview: some View {
        Group {
            if currentBlockIndex + 1 < exerciseBlocks.count {
                let nextBlock = exerciseBlocks[currentBlockIndex + 1]
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

    private var completedAllView: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()
            Ph.checkCircle.fill
                .icon(size: 60)
                .foregroundStyle(DesignTokens.ColorToken.State.success)
            Text("All Exercises Completed")
                .font(.title2.bold())
            Text("\(session.completedSetCount) total sets")
                .foregroundStyle(.secondary)
            Button("End Workout") { endWorkout() }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                .padding(.top)
            Spacer()
        }
    }

    private func markSetDone(_ set: PerformedSet, exercise: WorkoutSessionExercise) {
        if set.actualReps == nil { set.actualReps = set.targetReps }
        if set.actualWeight == nil { set.actualWeight = set.targetWeight }
        
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            set.isCompleted = true
        }
        set.completedAt = .now
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        do { try modelContext.save() } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not save: \(error.localizedDescription)"
        }

        let crumb = Breadcrumb(level: .info, category: "workout")
        crumb.message = "Set completed"
        crumb.data = ["exercise": exercise.exerciseName, "setIndex": set.setIndex, "completed": session.completedSetCount]
        SentrySDK.addBreadcrumb(crumb)

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        updateLiveActivity()

        startRestIfNeeded(exercise: exercise)
        if restSecondsRemaining == nil { advanceToNextBlockIfNeeded() }
    }

    private func markSetSkipped(_ set: PerformedSet, exercise: WorkoutSessionExercise) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
            set.isCompleted = true
        }
        set.completedAt = .now
        set.actualReps = nil
        set.actualWeight = nil
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        do { try modelContext.save() } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not save: \(error.localizedDescription)"
        }

        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        updateLiveActivity()

        startRestIfNeeded(exercise: exercise)
        if restSecondsRemaining == nil { advanceToNextBlockIfNeeded() }
    }

    private func advanceToNextBlockIfNeeded() {
        guard let block = currentBlock else { return }
        let allDone = block.allSatisfy { $0.performedSets.allSatisfy(\.isCompleted) }
        if allDone, currentBlockIndex < exerciseBlocks.count - 1 {
            currentBlockIndex += 1
        }
    }

    private func skipBlock() {
        guard let block = currentBlock else { return }
        stopRestTimer()
        for ex in block {
            for set in ex.performedSets where !set.isCompleted {
                set.isCompleted = true
                set.completedAt = .now
                set.actualReps = nil
                set.actualWeight = nil
            }
        }
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        do { try modelContext.save() } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
        if currentBlockIndex < exerciseBlocks.count - 1 {
            currentBlockIndex += 1
        }
    }

    private func skipExercise(_ exercise: WorkoutSessionExercise) {
        for set in exercise.performedSets where !set.isCompleted {
            set.isCompleted = true
            set.completedAt = .now
            set.actualReps = nil
            set.actualWeight = nil
        }
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        do { try modelContext.save() } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
        advanceToNextBlockIfNeeded()
    }

    private func pauseWorkout() {
        stopRestTimer()
        isPaused = true
        pausedAt = Date()
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        updateLiveActivity()
    }

    private func resumeWorkout() {
        if let start = pausedAt {
            totalPausedSeconds += Int(Date().timeIntervalSince(start).rounded())
        }
        pausedAt = nil
        isPaused = false
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        updateLiveActivity()
    }

    private func startRestIfNeeded(exercise: WorkoutSessionExercise) {
        guard let rest = exercise.restSeconds, rest > 0 else { return }
        restTotalSeconds = rest
        restSecondsRemaining = rest
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            guard var r = restSecondsRemaining else { return }
            r -= 1
            restSecondsRemaining = r <= 0 ? nil : r
            if restSecondsRemaining == nil {
                restTimer?.invalidate()
                restTimer = nil
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                advanceToNextBlockIfNeeded()
            }
        }
        RunLoop.main.add(restTimer!, forMode: .common)
    }

    private func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restSecondsRemaining = nil
    }

    private func endWorkout() {
        stopRestTimer()
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        // End Live Activity
        let totalSets = session.exercises.flatMap(\.performedSets).count
        let elapsed = elapsedSeconds(at: .now)
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
                    errorMessage = "Could not save: \(error.localizedDescription)"
                }
                showCompletionSummary = true
            }
        }
    }
}
