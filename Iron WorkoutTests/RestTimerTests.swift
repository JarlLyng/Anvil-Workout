//
//  RestTimerTests.swift
//  Anvil WorkoutTests
//
//  The rest timer is derived from its end date rather than counted down tick by tick, so
//  it stays right across a gap in which the app was not running, which is what happens
//  when the phone is locked between sets (#90).
//

import Testing
import Foundation
import SwiftData
@testable import Iron_Workout

@Suite("Rest timer")
struct RestTimerTests {

    // MARK: - The shared countdown arithmetic

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @Test("Seconds left round up, so the display reads 1s until the rest is actually over")
    func secondsRoundUp() {
        let endsAt = t0.addingTimeInterval(90)
        #expect(RestCountdown.secondsRemaining(until: endsAt, at: t0) == 90)
        #expect(RestCountdown.secondsRemaining(until: endsAt, at: t0.addingTimeInterval(30)) == 60)
        #expect(RestCountdown.secondsRemaining(until: endsAt, at: t0.addingTimeInterval(89.8)) == 1)
    }

    @Test("The rest is over at its end time and after it")
    func overAtAndAfterEnd() {
        let endsAt = t0.addingTimeInterval(90)
        #expect(RestCountdown.secondsRemaining(until: endsAt, at: endsAt) == nil)
        #expect(RestCountdown.secondsRemaining(until: endsAt, at: t0.addingTimeInterval(600)) == nil)
    }

    // MARK: - ActiveWorkoutState

    @MainActor
    private func makeState(restSeconds: Int = 90) throws -> (ActiveWorkoutState, WorkoutSessionExercise) {
        let schema = Schema([
            Exercise.self, WorkoutTemplate.self, WorkoutTemplateExercise.self,
            WorkoutSession.self, WorkoutSessionExercise.self, PerformedSet.self,
        ])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration(isStoredInMemoryOnly: true)])
        let context = ModelContext(container)

        let bench = Exercise(name: "Bench Press", muscleGroup: .chest, isBuiltin: true)
        context.insert(bench)
        let template = WorkoutTemplate(name: "Push")
        context.insert(template)
        let te = WorkoutTemplateExercise(
            exerciseID: bench.id, sortOrder: 0, targetSets: 3, targetReps: 5,
            targetWeight: 60, restSeconds: restSeconds
        )
        te.template = template
        template.exercises.append(te)
        context.insert(te)

        let session = try WorkoutSessionService.createSession(from: template, modelContext: context)
        let exercise = try #require(session.exercises.first)
        return (ActiveWorkoutState(session: session, modelContext: context), exercise)
    }

    @MainActor
    @Test("Rest started at a time reports the full rest")
    func startsWithFullRest() throws {
        let (state, exercise) = try makeState()
        defer { state.stopRestTimer() }

        state.startRestIfNeeded(exercise: exercise, now: t0)

        #expect(state.restSecondsRemaining == 90)
        #expect(state.restTotalSeconds == 90)
        #expect(state.restEndsAt == t0.addingTimeInterval(90))
    }

    @MainActor
    @Test("After a gap with the app suspended, the time left reflects the clock")
    func survivesGap() throws {
        let (state, exercise) = try makeState()
        defer { state.stopRestTimer() }
        state.startRestIfNeeded(exercise: exercise, now: t0)

        // No ticks in between: this is the phone locked for thirty seconds.
        state.refreshRest(at: t0.addingTimeInterval(30))

        #expect(state.restSecondsRemaining == 60)
    }

    @MainActor
    @Test("A rest that ended while the phone was locked is over when it is unlocked")
    func endsDuringGap() throws {
        let (state, exercise) = try makeState()
        var completions = 0
        state.onSetCompleted = { completions += 1 }
        state.startRestIfNeeded(exercise: exercise, now: t0)

        // Locked for two minutes on a 90-second rest. The old decrement-per-tick timer
        // would still have shown 89 seconds left here.
        state.refreshRest(at: t0.addingTimeInterval(120))

        #expect(state.restSecondsRemaining == nil)
        #expect(state.restEndsAt == nil)
        #expect(completions == 1)

        // Catching up again does not end it a second time.
        state.refreshRest(at: t0.addingTimeInterval(121))
        #expect(completions == 1)
    }

    @MainActor
    @Test("+ time moves the end of the rest")
    func addTimeMovesEnd() throws {
        let (state, exercise) = try makeState()
        defer { state.stopRestTimer() }
        state.startRestIfNeeded(exercise: exercise, now: t0)

        state.addRestTime(30, now: t0.addingTimeInterval(30))

        #expect(state.restEndsAt == t0.addingTimeInterval(120))
        #expect(state.restSecondsRemaining == 90)
        #expect(state.restTotalSeconds == 120)
    }

    @MainActor
    @Test("+ time with no rest running starts a rest of that length")
    func addTimeWithoutRestStartsOne() throws {
        let (state, _) = try makeState()
        defer { state.stopRestTimer() }

        // The watch can send "+30s" just as rest ends on the phone.
        state.addRestTime(30, now: t0)

        #expect(state.restSecondsRemaining == 30)
        #expect(state.restEndsAt == t0.addingTimeInterval(30))
    }

    @MainActor
    @Test("Pausing still ends the rest, as before")
    func pauseEndsRest() throws {
        let (state, exercise) = try makeState()
        state.startRestIfNeeded(exercise: exercise, now: t0)

        state.pause()

        #expect(state.restSecondsRemaining == nil)
        #expect(state.restEndsAt == nil)
    }

    @MainActor
    @Test("An exercise without a rest time starts no rest")
    func noRestWithoutRestSeconds() throws {
        let (state, exercise) = try makeState(restSeconds: 0)

        state.startRestIfNeeded(exercise: exercise, now: t0)

        #expect(state.restSecondsRemaining == nil)
        #expect(state.restEndsAt == nil)
    }

    @MainActor
    @Test("The watch snapshot carries the rest end, so the watch can count down itself")
    func snapshotCarriesRestEnd() throws {
        let (state, exercise) = try makeState()
        defer { state.stopRestTimer() }
        state.startRestIfNeeded(exercise: exercise, now: t0)

        let snapshot = state.makeWatchSnapshot()

        #expect(snapshot.restEndsAt == t0.addingTimeInterval(90))
        #expect(snapshot.restSecondsRemaining == 90)
    }
}
