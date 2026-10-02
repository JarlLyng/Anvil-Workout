//
//  WatchDemoSnapshots.swift
//  Anvil Watch
//
//  Debug builds only. Launching the watch app with `-AnvilWatchDemo set`, `rest`, `paused`
//  or `done`
//  shows the workout screen with a sample snapshot, so its layout can be checked and
//  screenshotted on every watch size without a phone running a workout:
//
//    xcrun simctl launch <watch> com.iamjarl.Iron-Workout.watchkitapp -AnvilWatchDemo rest
//

#if DEBUG
import Foundation

enum WatchDemoSnapshots {
    /// The sample named by the `-AnvilWatchDemo` launch argument, or nil without one.
    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> ActiveWorkoutSnapshot? {
        guard let flag = arguments.firstIndex(of: "-AnvilWatchDemo"),
              arguments.indices.contains(flag + 1) else { return nil }
        switch arguments[flag + 1] {
        case "set": return make(rest: nil)
        case "rest": return make(rest: 75)
        case "paused": return make(rest: nil, paused: true)
        case "done": return make(rest: nil, allDone: true)
        default: return nil
        }
    }

    private static func make(rest: Int?, paused: Bool = false, allDone: Bool = false) -> ActiveWorkoutSnapshot {
        let now = Date()
        return ActiveWorkoutSnapshot(
            sessionID: UUID(),
            templateName: "StrongLifts 5×5 — Workout A",
            startedAt: now.addingTimeInterval(-24 * 60 - 13),
            totalPausedSeconds: 0,
            pausedAt: paused ? now.addingTimeInterval(-40) : nil,
            currentExerciseName: allDone ? nil : "Barbell Back Squat",
            currentSetNumber: 3,
            totalSetsInExercise: 5,
            targetReps: 5,
            targetWeightKg: 102.5,
            targetWeightText: "102.5 kg",
            currentSetID: allDone ? nil : UUID(),
            restSecondsRemaining: rest,
            restTotalSeconds: rest == nil ? nil : 90,
            restEndsAt: rest.map { now.addingTimeInterval(TimeInterval($0)) },
            completedSetCount: allDone ? 15 : 7,
            totalSetCount: 15
        )
    }
}
#endif
