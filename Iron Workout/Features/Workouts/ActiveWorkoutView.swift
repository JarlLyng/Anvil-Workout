//
//  ActiveWorkoutView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import UIKit
import ActivityKit
import IAMJARLDesignTokens
import PhosphorSwift

struct ActiveWorkoutView: View {
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
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
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
                    do { try modelContext.save() } catch { errorMessage = "Could not save: \(error.localizedDescription)" }
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
            try? await health.requestAuthorization()
            try? await health.startWorkout(startDate: session.startedAt)
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
            VStack(alignment: .leading, spacing: 24) {
                if block.count > 1 {
                    HStack {
                        Ph.link.fill.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20).foregroundStyle(DesignTokens.ColorToken.State.warning)
                        Text("Superset").font(.headline).foregroundStyle(DesignTokens.ColorToken.State.warning)
                    }
                    .padding(.bottom, -12)
                }
                
                ForEach(block, id: \.id) { exercise in
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(exercise.exerciseName)
                                .font(.title3.weight(.semibold))
                            Spacer()
                            Button("Skip") {
                                skipExercise(exercise)
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Skip \(exercise.exerciseName)")
                        }

                        // Note field
                        HStack(spacing: 8) {
                            Ph.notepad.regular
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                                .foregroundStyle(.secondary)
                            TextField("Add note...", text: Binding(
                                get: { exercise.note },
                                set: { newValue in
                                    exercise.note = newValue
                                    try? modelContext.save()
                                }
                            ), axis: .vertical)
                            .font(.caption)
                            .lineLimit(1...3)
                            .foregroundStyle(.secondary)
                        }

                        let sets = exercise.performedSets.sorted { $0.setIndex < $1.setIndex }
                        ForEach(sets, id: \.id) { set in
                            setRow(set: set, exercise: exercise)
                        }
                    }
                    if exercise.id != block.last?.id {
                        Divider().padding(.vertical, 8)
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

    private func setRow(set: PerformedSet, exercise: WorkoutSessionExercise) -> some View {
        WorkoutSetRow(
            set: set,
            exercise: exercise,
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
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 20, height: 20)
                    Text("Next: \(names)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 8)
                .padding(.horizontal)
            }
        }
        .frame(maxWidth: .infinity)
        .background(.bar)
    }

    private var completedAllView: some View {
        VStack(spacing: 24) {
            Spacer()
            Ph.checkCircle.fill
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 60, height: 60)
                .foregroundStyle(DesignTokens.ColorToken.State.success)
            Text("All Exercises Completed")
                .font(.title2.bold())
            Text("\(session.completedSetCount) total sets")
                .foregroundStyle(.secondary)
            Button("End Workout") { endWorkout() }
                .buttonStyle(.borderedProminent)
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
        do { try modelContext.save() } catch { errorMessage = "Could not save: \(error.localizedDescription)" }
        
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
        do { try modelContext.save() } catch { errorMessage = "Could not save: \(error.localizedDescription)" }

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
        do { try modelContext.save() } catch { errorMessage = "Error: \(error)" }
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
        do { try modelContext.save() } catch { errorMessage = "Error: \(error)" }
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

        let context = modelContext
        Task {
            let health = HealthKitService.shared
            if health.isAvailable, let result = try? await health.endWorkout(endDate: Date()) {
                await MainActor.run {
                    session.calories = result.calories
                    session.averageHeartRate = result.averageHeartRate
                }
            }
            await MainActor.run {
                do { try WorkoutSessionService.finalizeSession(session, modelContext: context) } catch { errorMessage = "Could not save: \(error.localizedDescription)" }
                showCompletionSummary = true
            }
        }
    }
}
