//
//  ActiveWorkoutState.swift
//  Anvil Workout
//
//  Owns the in-memory state and actions for a running workout: block traversal,
//  pause math, rest timer, and set completion. Extracted from ActiveWorkoutView
//  so the Apple Watch companion (planned for v1.4.0) can share the same logic.
//
//  Side-effecting integrations that depend on the view's lifecycle (HealthKit,
//  Live Activity) remain in ActiveWorkoutView for now.
//

import Foundation
import SwiftData
import Sentry

@Observable
@MainActor
final class ActiveWorkoutState {
    let session: WorkoutSession
    private let modelContext: ModelContext

    var currentBlockIndex: Int = 0
    var isPaused: Bool = false
    var pausedAt: Date?
    var totalPausedSeconds: Int = 0

    var restSecondsRemaining: Int?
    var restTotalSeconds: Int = 0
    private var restTimer: Timer?

    var errorMessage: String?

    /// Fires after rest expires or a set is completed without a rest timer —
    /// the view uses this to refresh the Live Activity.
    var onSetCompleted: (() -> Void)?

    init(session: WorkoutSession, modelContext: ModelContext) {
        self.session = session
        self.modelContext = modelContext
    }

    // MARK: - Block traversal

    var sortedExercises: [WorkoutSessionExercise] {
        session.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    var exerciseBlocks: [[WorkoutSessionExercise]] {
        var blocks: [[WorkoutSessionExercise]] = []
        var currentBlock: [WorkoutSessionExercise] = []
        for ex in sortedExercises {
            if currentBlock.isEmpty {
                currentBlock.append(ex)
            } else if let sid = ex.supersetID, sid == currentBlock.last?.supersetID {
                currentBlock.append(ex)
            } else {
                blocks.append(currentBlock)
                currentBlock = [ex]
            }
        }
        if !currentBlock.isEmpty { blocks.append(currentBlock) }
        return blocks
    }

    var currentBlock: [WorkoutSessionExercise]? {
        let blocks = exerciseBlocks
        guard currentBlockIndex >= 0, currentBlockIndex < blocks.count else { return nil }
        return blocks[currentBlockIndex]
    }

    var isAtLastBlock: Bool {
        currentBlockIndex >= exerciseBlocks.count - 1
    }

    // MARK: - Timing

    func elapsedSeconds(at date: Date) -> Int {
        let total = Int(date.timeIntervalSince(session.startedAt).rounded())
        let extraPause: Int
        if isPaused, let start = pausedAt {
            extraPause = Int(date.timeIntervalSince(start).rounded())
        } else {
            extraPause = 0
        }
        return max(0, total - totalPausedSeconds - extraPause)
    }

    // MARK: - Set actions

    func markSetDone(_ set: PerformedSet, exercise: WorkoutSessionExercise) {
        if set.actualReps == nil { set.actualReps = set.targetReps }
        // Same resolution the row displays and the editor pre-fills, so completing a set
        // without opening it records the weight the user was actually shown (#79).
        if set.actualWeight == nil { set.actualWeight = WorkoutSessionService.pendingWeight(for: set) }
        set.isCompleted = true
        set.completedAt = .now
        recomputeCompletedCount()
        saveContext()

        SentrySDK.addBreadcrumb(DiagnosticsService.workoutBreadcrumb("Set completed"))

        onSetCompleted?()
        startRestIfNeeded(exercise: exercise)
        if restSecondsRemaining == nil { advanceToNextBlockIfNeeded() }
    }

    func markSetSkipped(_ set: PerformedSet, exercise: WorkoutSessionExercise) {
        set.isCompleted = true
        set.completedAt = .now
        set.actualReps = nil
        set.actualWeight = nil
        recomputeCompletedCount()
        saveContext()

        onSetCompleted?()
        startRestIfNeeded(exercise: exercise)
        if restSecondsRemaining == nil { advanceToNextBlockIfNeeded() }
    }

    func skipBlock() {
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
        recomputeCompletedCount()
        saveContext()
        if !isAtLastBlock { currentBlockIndex += 1 }
    }

    func skipExercise(_ exercise: WorkoutSessionExercise) {
        for set in exercise.performedSets where !set.isCompleted {
            set.isCompleted = true
            set.completedAt = .now
            set.actualReps = nil
            set.actualWeight = nil
        }
        recomputeCompletedCount()
        saveContext()
        advanceToNextBlockIfNeeded()
    }

    func advanceToNextBlockIfNeeded() {
        guard let block = currentBlock else { return }
        let allDone = block.allSatisfy { $0.performedSets.allSatisfy(\.isCompleted) }
        if allDone, !isAtLastBlock {
            currentBlockIndex += 1
        }
    }

    // MARK: - Pause / resume

    func pause() {
        stopRestTimer()
        isPaused = true
        pausedAt = Date()
    }

    func resume() {
        if let start = pausedAt {
            totalPausedSeconds += Int(Date().timeIntervalSince(start).rounded())
        }
        pausedAt = nil
        isPaused = false
    }

    // MARK: - Rest timer

    func startRestIfNeeded(exercise: WorkoutSessionExercise) {
        guard let rest = exercise.restSeconds, rest > 0 else { return }
        restTotalSeconds = rest
        restSecondsRemaining = rest
        restTimer?.invalidate()
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor [weak self] in
                self?.tickRest()
            }
        }
        if let timer = restTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func tickRest() {
        guard var r = restSecondsRemaining else { return }
        r -= 1
        restSecondsRemaining = r <= 0 ? nil : r
        if restSecondsRemaining == nil {
            restTimer?.invalidate()
            restTimer = nil
            advanceToNextBlockIfNeeded()
            onSetCompleted?()
        }
    }

    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restSecondsRemaining = nil
    }

    func addRestTime(_ seconds: Int) {
        restTotalSeconds += seconds
        restSecondsRemaining = (restSecondsRemaining ?? 0) + seconds
    }

    func skipRest() {
        stopRestTimer()
        advanceToNextBlockIfNeeded()
    }

    // MARK: - Watch snapshot

    /// Lean snapshot for the Apple Watch companion. Returns nil if there is no
    /// active exercise (the watch will fall back to its idle screen).
    func makeWatchSnapshot() -> ActiveWorkoutSnapshot {
        let allSets = session.exercises.flatMap(\.performedSets)
        let totalSetCount = allSets.count

        // Locate the next pending set, preferring the current block so the watch
        // tracks the user's focus rather than jumping to a far-future exercise.
        let focusExercise = currentBlock?.first ?? sortedExercises.first
        let setsInExercise = focusExercise?.performedSets.sorted { $0.setIndex < $1.setIndex } ?? []
        let pendingSet = setsInExercise.first(where: { !$0.isCompleted })

        return ActiveWorkoutSnapshot(
            sessionID: session.id,
            templateName: session.templateName,
            startedAt: session.startedAt,
            totalPausedSeconds: totalPausedSeconds,
            pausedAt: pausedAt,
            currentExerciseName: focusExercise?.exerciseName,
            currentSetNumber: (pendingSet?.setIndex ?? 0) + 1,
            totalSetsInExercise: setsInExercise.count,
            targetReps: pendingSet?.targetReps,
            targetWeightKg: pendingSet?.targetWeight,
            currentSetID: pendingSet?.id,
            restSecondsRemaining: restSecondsRemaining,
            restTotalSeconds: restSecondsRemaining == nil ? nil : restTotalSeconds,
            completedSetCount: session.completedSetCount,
            totalSetCount: totalSetCount
        )
    }

    /// Routes an action received from the watch into the matching state mutation.
    /// Looks the set up by ID inside the current session so a stale watch snapshot
    /// can never mutate the wrong set.
    func apply(_ action: WatchAction) {
        switch action {
        case .markSetDone(let setID):
            if let pair = findSet(setID) {
                markSetDone(pair.set, exercise: pair.exercise)
            }
        case .markSetSkipped(let setID):
            if let pair = findSet(setID) {
                markSetSkipped(pair.set, exercise: pair.exercise)
            }
        case .pause:
            pause()
        case .resume:
            resume()
        case .addRestTime(let seconds):
            addRestTime(seconds)
        case .skipRest:
            skipRest()
        }
    }

    private func findSet(_ id: UUID) -> (set: PerformedSet, exercise: WorkoutSessionExercise)? {
        for exercise in session.exercises {
            if let set = exercise.performedSets.first(where: { $0.id == id }) {
                return (set, exercise)
            }
        }
        return nil
    }

    // MARK: - Persistence

    func saveContext() {
        do {
            try modelContext.save()
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not save: \(error.localizedDescription)"
        }
    }

    private func recomputeCompletedCount() {
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
    }
}
