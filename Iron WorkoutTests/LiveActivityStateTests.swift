//
//  LiveActivityStateTests.swift
//  Anvil WorkoutTests
//
//  The Live Activity gets the workout clock and the rest as dates, which the Lock Screen
//  counts from itself while the app is suspended (#96). These check the dates are the ones
//  the app's own clock and rest timer run on.
//

import Testing
import Foundation
import SwiftData
@testable import Iron_Workout

@Suite("Live Activity state")
struct LiveActivityStateTests {

    private let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    @MainActor
    private func makeState() throws -> (ActiveWorkoutState, WorkoutSessionExercise) {
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
            targetWeight: 60, restSeconds: 90
        )
        te.template = template
        template.exercises.append(te)
        context.insert(te)

        let session = try WorkoutSessionService.createSession(from: template, modelContext: context)
        let exercise = try #require(session.exercises.first)
        return (ActiveWorkoutState(session: session, modelContext: context), exercise)
    }

    @MainActor
    @Test("A running workout counts from its start, with no pause and no rest")
    func runningWorkout() throws {
        let (state, _) = try makeState()

        let live = state.makeLiveActivityState()

        #expect(live.currentExercise == "Bench Press")
        #expect(live.totalSets == 3)
        #expect(live.elapsedCountsFrom == state.session.startedAt)
        #expect(live.elapsedInterval?.lowerBound == state.session.startedAt)
        #expect(live.pausedAt == nil)
        #expect(live.restEndsAt == nil)
        #expect(live.restInterval == nil)
    }

    @MainActor
    @Test("Earlier pauses move the start the clock counts from")
    func earlierPausesMoveStart() throws {
        let (state, _) = try makeState()
        state.totalPausedSeconds = 120

        let live = state.makeLiveActivityState()

        #expect(live.elapsedCountsFrom == state.session.startedAt.addingTimeInterval(120))
    }

    @MainActor
    @Test("While paused, the Lock Screen clock stands at the same time as the app's")
    func pausedClockMatchesApp() throws {
        let (state, _) = try makeState()
        let pausedAt = state.session.startedAt.addingTimeInterval(300)
        state.totalPausedSeconds = 30
        state.isPaused = true
        state.pausedAt = pausedAt

        let live = state.makeLiveActivityState(now: pausedAt.addingTimeInterval(45))
        let from = try #require(live.elapsedCountsFrom)
        let lockScreenSeconds = Int(try #require(live.pausedAt).timeIntervalSince(from))

        #expect(live.isPaused)
        #expect(lockScreenSeconds == 270)
        #expect(lockScreenSeconds == state.elapsedSeconds(at: pausedAt.addingTimeInterval(45)))
    }

    @MainActor
    @Test("Rest goes out as the range it counts down over")
    func restInterval() throws {
        let (state, exercise) = try makeState()
        defer { state.stopRestTimer() }
        state.startRestIfNeeded(exercise: exercise, now: t0)

        let live = state.makeLiveActivityState()

        #expect(live.restEndsAt == t0.addingTimeInterval(90))
        #expect(live.restTotalSeconds == 90)
        #expect(live.restInterval == t0...t0.addingTimeInterval(90))
    }

    @MainActor
    @Test("Added time moves the end and keeps the start, so the bar does not jump back to full")
    func addedTimeKeepsStart() throws {
        let (state, exercise) = try makeState()
        defer { state.stopRestTimer() }
        state.startRestIfNeeded(exercise: exercise, now: t0)
        state.addRestTime(30, now: t0.addingTimeInterval(10))

        let live = state.makeLiveActivityState()

        #expect(live.restInterval == t0...t0.addingTimeInterval(120))
    }

    @MainActor
    @Test("A skipped rest leaves no rest in the state")
    func skippedRest() throws {
        let (state, exercise) = try makeState()
        state.startRestIfNeeded(exercise: exercise, now: t0)
        state.skipRest()

        let live = state.makeLiveActivityState()

        #expect(live.restEndsAt == nil)
        #expect(live.restTotalSeconds == nil)
        #expect(live.restInterval == nil)
    }

    @Test("A state encoded before the dates existed still decodes, and shows its seconds")
    func decodesOldState() throws {
        let json = Data("""
        {"currentExercise":"Bench Press","completedSets":6,"totalSets":15,"elapsedSeconds":1845,"isPaused":false}
        """.utf8)

        let state = try JSONDecoder().decode(IronWorkoutWidgetAttributes.ContentState.self, from: json)

        #expect(state.elapsedSeconds == 1845)
        #expect(state.elapsedCountsFrom == nil)
        #expect(state.elapsedInterval == nil)
        #expect(state.restInterval == nil)
    }
}
