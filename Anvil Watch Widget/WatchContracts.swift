//
//  WatchContracts.swift
//  Anvil Workout
//
//  Codable contracts shared between the iPhone app and the Apple Watch
//  companion. The phone is the source of truth — it broadcasts ActiveWorkoutSnapshot
//  values as state changes; the watch sends WatchAction values back.
//
//  Both ends MUST agree on this schema. Keep the keys stable across
//  versions or guard them with optional fields and version bumps.
//
//  MIRROR: source of truth lives at
//    "Iron Workout/Shared/Watch/WatchContracts.swift"
//  Any change here MUST be applied to the iPhone and watch app copies
//  too, or encoding/decoding will silently break.
//

import Foundation

/// Lean snapshot of the active workout that the watch needs to render its UI.
/// Excludes anything not displayed on a 49mm screen.
struct ActiveWorkoutSnapshot: Codable, Equatable, Sendable {
    /// Stable session identifier. The watch keys local state off this so it can
    /// detect "different workout, reset my UI".
    let sessionID: UUID

    let templateName: String

    /// Date the workout started, for elapsed-time computation on the watch.
    let startedAt: Date

    /// Total paused seconds so far, used to subtract from `elapsed = now - startedAt`.
    let totalPausedSeconds: Int

    /// If non-nil, the workout is currently paused — the watch should freeze its timer.
    let pausedAt: Date?

    /// Name of the current exercise, or nil if all blocks are done.
    let currentExerciseName: String?

    /// 1-based "Set N of M" the user should focus on.
    let currentSetNumber: Int
    let totalSetsInExercise: Int

    /// Target prescription for the current set (display only — entry happens on phone).
    let targetReps: Int?
    let targetWeightKg: Double?

    /// Stable identifier of the current pending set, used by the watch when sending
    /// a markDone / markSkipped action — guards against acting on a stale snapshot.
    let currentSetID: UUID?

    /// Rest timer state — nil means no rest active.
    let restSecondsRemaining: Int?
    let restTotalSeconds: Int?

    let completedSetCount: Int
    let totalSetCount: Int
}

/// Small stats payload the phone pushes to the watch on app launch and after
/// each completed workout. Backs the watch widget / Smart Stack tile without
/// requiring the watch to query SwiftData on its own.
struct WatchStatsSnapshot: Codable, Equatable, Sendable {
    let currentStreak: Int
    let totalWorkouts: Int
    let lastWorkoutName: String?
    let lastWorkoutDate: Date?
    let updatedAt: Date
}

/// Actions the watch can request the phone to perform. The phone routes these
/// into ActiveWorkoutState.
enum WatchAction: Codable, Equatable, Sendable {
    /// Mark the set with this ID as completed using the snapshot's target reps/weight.
    case markSetDone(setID: UUID)
    case markSetSkipped(setID: UUID)
    case pause
    case resume
    case addRestTime(seconds: Int)
    case skipRest
}
