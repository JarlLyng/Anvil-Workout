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

    /// Seconds of rest left, for display. Derived from `restEndsAt`, never counted down on
    /// its own, so it is right again the moment the app runs after being suspended (#90).
    var restSecondsRemaining: Int?
    var restTotalSeconds: Int = 0
    /// When the current rest ends; the source of truth for the rest timer. nil means no
    /// rest is active.
    private(set) var restEndsAt: Date?
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

    // MARK: - Supersets

    /// Whose turn it is in a block: of the exercises with a set left, the one that has
    /// done the fewest, the first on a tie. A superset goes A1, B1, A2, B2; a lone
    /// exercise is always its own turn.
    static func turn(in block: [WorkoutSessionExercise]) -> WorkoutSessionExercise? {
        block
            .enumerated()
            .filter { $0.element.performedSets.contains { !$0.isCompleted } }
            .min { (resolvedSets($0.element), $0.offset) < (resolvedSets($1.element), $1.offset) }?
            .element
    }

    private static func resolvedSets(_ exercise: WorkoutSessionExercise) -> Int {
        exercise.performedSets.filter(\.isCompleted).count
    }

    /// The exercise to do now: whose turn it is in the current block.
    var currentExercise: WorkoutSessionExercise? {
        guard let block = currentBlock else { return nil }
        return Self.turn(in: block) ?? block.first
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

    // The rest timer stores when rest ends and derives the seconds left from it, the same
    // way elapsed time is derived from startedAt. It used to count down by subtracting one
    // per timer tick, and iOS suspends the app when the phone locks, so the countdown froze
    // in a pocket and resumed on unlock: a 90-second rest could run for minutes (#90). The
    // one-second timer now only refreshes the display.

    /// Rest after a set, except within a superset round: there the next exercise follows
    /// straight away, and the rest comes once every exercise in it has had its turn.
    func startRestIfNeeded(exercise: WorkoutSessionExercise, now: Date = .now) {
        guard let rest = exercise.restSeconds, rest > 0 else { return }
        if let block = currentBlock, block.count > 1, block.contains(where: { $0.id == exercise.id }),
           let next = Self.turn(in: block), Self.resolvedSets(next) < Self.resolvedSets(exercise) {
            return
        }
        beginRest(seconds: rest, now: now)
    }

    private func beginRest(seconds: Int, now: Date) {
        restTotalSeconds = seconds
        restEndsAt = now.addingTimeInterval(TimeInterval(seconds))
        restSecondsRemaining = seconds
        restTimer?.invalidate()
        // Weak in the timer's closure too, so it never holds the state while it ticks (#99).
        restTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshRest()
            }
        }
        if let timer = restTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Brings the rest timer up to date with the clock. Called every second by the timer,
    /// and when the app returns to the foreground so a rest that ended while the phone was
    /// locked ends at once rather than on the next tick.
    func refreshRest(at date: Date = .now) {
        guard let endsAt = restEndsAt else { return }
        if let left = RestCountdown.secondsRemaining(until: endsAt, at: date) {
            if restSecondsRemaining != left { restSecondsRemaining = left }
        } else {
            stopRestTimer()
            advanceToNextBlockIfNeeded()
            onSetCompleted?()
        }
    }

    func stopRestTimer() {
        restTimer?.invalidate()
        restTimer = nil
        restEndsAt = nil
        restSecondsRemaining = nil
    }

    /// Moves the end of the current rest later. With no rest running, which can happen when
    /// the watch sends "+30s" just as rest ends on the phone, it starts a fresh rest of that
    /// length instead: that is what the tap asked for, and the old code left a countdown
    /// with no timer behind it that never moved.
    func addRestTime(_ seconds: Int, now: Date = .now) {
        guard let endsAt = restEndsAt else {
            beginRest(seconds: seconds, now: now)
            return
        }
        restTotalSeconds += seconds
        restEndsAt = endsAt.addingTimeInterval(TimeInterval(seconds))
        refreshRest(at: now)
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
        let focusExercise = currentExercise ?? sortedExercises.first
        let setsInExercise = focusExercise?.performedSets.sorted { $0.setIndex < $1.setIndex } ?? []
        let pendingSet = setsInExercise.first(where: { !$0.isCompleted })
        // The weight the phone's row shows and that Done records, which carries from an
        // earlier set (#79), rather than the program target, which the watch used to show.
        let pendingWeight = pendingSet.flatMap { WorkoutSessionService.pendingWeight(for: $0) }

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
            targetWeightKg: pendingWeight,
            targetWeightText: pendingWeight.map { WeightFormatter.compact(kg: $0) },
            currentSetID: pendingSet?.id,
            restSecondsRemaining: restSecondsRemaining,
            restTotalSeconds: restSecondsRemaining == nil ? nil : restTotalSeconds,
            restEndsAt: restEndsAt,
            completedSetCount: session.completedSetCount,
            totalSetCount: totalSetCount
        )
    }

    // MARK: - Live Activity state

    /// What the Lock Screen and Dynamic Island show. The clock and the rest go out as dates
    /// rather than seconds, so the system counts them without the app running (#96).
    func makeLiveActivityState(now: Date = .now) -> IronWorkoutWidgetAttributes.ContentState {
        IronWorkoutWidgetAttributes.ContentState(
            currentExercise: currentExercise?.exerciseName ?? "Done",
            completedSets: session.completedSetCount,
            totalSets: session.exercises.flatMap(\.performedSets).count,
            elapsedSeconds: elapsedSeconds(at: now),
            isPaused: isPaused,
            elapsedCountsFrom: session.startedAt.addingTimeInterval(TimeInterval(totalPausedSeconds)),
            pausedAt: pausedAt,
            restEndsAt: restEndsAt,
            restTotalSeconds: restEndsAt == nil ? nil : restTotalSeconds
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
