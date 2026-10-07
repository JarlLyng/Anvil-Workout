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
//  Add `-weightUnit lbs` for the weight in pounds. The names match the phone's screenshot
//  mode (Full Body A, Back Squat), so the App Store set reads as one workout.
//

#if DEBUG
import Foundation

enum WatchDemoSnapshots {
    /// The sample named by the `-AnvilWatchDemo` launch argument, or nil without one.
    static func requested(arguments: [String] = ProcessInfo.processInfo.arguments) -> ActiveWorkoutSnapshot? {
        guard let flag = arguments.firstIndex(of: "-AnvilWatchDemo"),
              arguments.indices.contains(flag + 1) else { return nil }
        let pounds = arguments.firstIndex(of: "-weightUnit").map { arguments.indices.contains($0 + 1) && arguments[$0 + 1] == "lbs" } ?? false
        switch arguments[flag + 1] {
        case "set": return make(rest: nil, pounds: pounds)
        case "rest": return make(rest: 75, pounds: pounds)
        case "paused": return make(rest: nil, paused: true, pounds: pounds)
        case "done": return make(rest: nil, allDone: true, pounds: pounds)
        default: return nil
        }
    }

    private static func make(rest: Int?, paused: Bool = false, allDone: Bool = false, pounds: Bool) -> ActiveWorkoutSnapshot {
        let now = Date()
        return ActiveWorkoutSnapshot(
            sessionID: UUID(),
            templateName: "Full Body A",
            startedAt: now.addingTimeInterval(-24 * 60 - 13),
            totalPausedSeconds: 0,
            pausedAt: paused ? now.addingTimeInterval(-40) : nil,
            currentExerciseName: allDone ? nil : "Back Squat",
            currentSetNumber: 3,
            totalSetsInExercise: 5,
            targetReps: 5,
            targetWeightKg: pounds ? 225 * 0.45359237 : 100,
            targetWeightText: pounds ? "225 lb" : "100 kg",
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
