//
//  WatchStatsBroadcaster.swift
//  Anvil Workout
//
//  Builds a WatchStatsSnapshot from SwiftData on the iPhone and hands it
//  to WatchConnectivityService for delivery to the watch widget. Called
//  on app launch and after every completed workout — keeping the watch
//  Smart Stack tile fresh without scheduling background refreshes.
//

import Foundation
import SwiftData

enum WatchStatsBroadcaster {
    /// Computes the current stats snapshot from the SwiftData store and
    /// pushes it to the watch. Safe to call from any view's onAppear.
    @MainActor
    static func broadcast(from modelContext: ModelContext) {
        do {
            let descriptor = FetchDescriptor<WorkoutSession>(
                sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
            )
            let sessions = try modelContext.fetch(descriptor)
            let completed = sessions.filter { $0.completedSetCount > 0 }
            let last = completed.first
            let snapshot = WatchStatsSnapshot(
                currentStreak: StreakCalculator.currentStreak(from: sessions),
                totalWorkouts: completed.count,
                lastWorkoutName: last?.templateName,
                lastWorkoutDate: last?.startedAt,
                updatedAt: .now
            )
            WatchConnectivityService.shared.sendStats(snapshot)
        } catch {
            // Silently skip — the watch will retain its previous snapshot.
        }
    }
}
