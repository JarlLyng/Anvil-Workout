//
//  PreviousSetLookup.swift
//  Anvil Workout
//
//  Finds what the lifter did last time, to show beside the matching set of the workout
//  they are running now. Reference only: nothing here writes, and nothing here overrides
//  the program's targets. The user decides whether to reuse the numbers (#79).
//

import Foundation
import SwiftData

/// One set from the last time this exercise was trained.
struct PreviousSetReference: Equatable {
    let reps: Int
    let weightKg: Double?
    /// Start of the session the set came from, so the UI can say how long ago it was.
    let performedAt: Date
}

enum PreviousSetLookup {

    /// The set to show beside `setIndex`: the set with the same index from the most recent
    /// earlier session containing this exercise, falling back to that session's last set
    /// when it ran fewer sets than today's program calls for.
    ///
    /// Matching by index rather than by "heaviest" or "last" keeps the reference aligned
    /// with the row it sits under, which is what makes it readable mid-workout.
    ///
    /// Warm-ups are not used as the reference for a working set: a 20 kg warm-up is not the
    /// number a lifter wants under a working set. Skipped sets record no reps and are
    /// ignored, since they say nothing about what was lifted.
    ///
    /// Sessions are consulted newest-first and the first one holding this exercise wins,
    /// including history imported from Strong or Hevy.
    @MainActor
    static func find(
        for exercise: WorkoutSessionExercise,
        setIndex: Int,
        isWarmup: Bool,
        modelContext: ModelContext
    ) -> PreviousSetReference? {
        guard let currentSession = exercise.session else { return nil }

        let startedAt = currentSession.startedAt
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.startedAt < startedAt },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        guard let history = try? modelContext.fetch(descriptor) else { return nil }

        for session in history where session.id != currentSession.id {
            let candidates = session.exercises
                .filter { $0.isSameExercise(as: exercise) }
                .flatMap(\.performedSets)
                .filter { $0.isCompleted && $0.actualReps != nil }
                .filter { isWarmup || $0.setType != .warmup }
                .sorted { $0.setIndex < $1.setIndex }

            guard !candidates.isEmpty else { continue }
            let match = candidates.first { $0.setIndex == setIndex } ?? candidates[candidates.count - 1]
            guard let reps = match.actualReps else { continue }

            return PreviousSetReference(
                reps: reps,
                weightKg: match.actualWeight,
                performedAt: session.startedAt
            )
        }

        return nil
    }
}
