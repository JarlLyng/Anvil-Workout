//
//  WorkoutSessionService.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData
import Sentry

enum WorkoutSessionService {

    /// Creates a new WorkoutSession from a template with all exercises and sets.
    static func createSession(from template: WorkoutTemplate, modelContext: ModelContext) throws -> WorkoutSession {
        let descriptor = FetchDescriptor<Exercise>()
        let exercises: [Exercise]
        do {
            exercises = try modelContext.fetch(descriptor)
        } catch {
            SentrySDK.capture(error: error)
            throw error
        }
        let nameByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })

        let session = WorkoutSession(
            templateName: template.name.isEmpty ? "Workout" : template.name,
            startedAt: .now,
            exerciseCount: template.exercises.count
        )
        modelContext.insert(session)

        let sorted = template.exercises.sorted { $0.sortOrder < $1.sortOrder }
        for (exIndex, te) in sorted.enumerated() {
            let name = nameByID[te.exerciseID] ?? "Unknown exercise"
            let sessionEx = WorkoutSessionExercise(
                exerciseID: te.exerciseID,
                exerciseName: name,
                sortOrder: exIndex,
                note: te.note,
                restSeconds: te.restSeconds,
                supersetID: te.supersetID
            )
            sessionEx.session = session
            session.exercises.append(sessionEx)
            modelContext.insert(sessionEx)

            for setIndex in 0..<te.targetSets {
                let set = PerformedSet(
                    setIndex: setIndex,
                    targetReps: te.targetReps,
                    actualReps: nil,
                    targetWeight: te.targetWeight,
                    actualWeight: te.targetWeight,
                    isCompleted: false
                )
                set.sessionExercise = sessionEx
                sessionEx.performedSets.append(set)
                modelContext.insert(set)
            }
        }

        do {
            try modelContext.save()
        } catch {
            SentrySDK.capture(error: error)
            throw error
        }
        return session
    }

    /// Finalizes session with duration and completed set count; called when workout ends.
    /// Pass an explicit `endedAt` when finalizing a stale session retroactively — otherwise
    /// the duration includes all the dead time after the user forgot to tap End.
    static func finalizeSession(_ session: WorkoutSession, endedAt: Date = .now, modelContext: ModelContext) throws {
        session.endedAt = endedAt
        let duration = endedAt.timeIntervalSince(session.startedAt)
        session.durationSeconds = Int(max(0, duration.rounded()))
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        do {
            try modelContext.save()
        } catch {
            SentrySDK.capture(error: error)
            throw error
        }
    }

    /// Returns a session that was started but never finalized — i.e. the user forgot to tap
    /// End Workout. Threshold is conservative (6h) so we don't prompt for a workout the user
    /// is actively paused on. Returns the most recent matching session; in practice there
    /// should only ever be one.
    static func findStaleSession(modelContext: ModelContext, olderThan threshold: TimeInterval = 6 * 60 * 60) -> WorkoutSession? {
        let cutoff = Date().addingTimeInterval(-threshold)
        let descriptor = FetchDescriptor<WorkoutSession>(
            predicate: #Predicate { $0.endedAt == nil && $0.startedAt < cutoff },
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    /// Best-effort guess at when the workout actually ended: the latest `completedAt` across
    /// completed sets in the session, or `startedAt` if nothing was logged.
    static func bestGuessEndDate(for session: WorkoutSession) -> Date {
        let completedTimes = session.exercises
            .flatMap(\.performedSets)
            .compactMap(\.completedAt)
        return completedTimes.max() ?? session.startedAt
    }

    /// Delete a session entirely — used when the user chooses to discard a stale session
    /// instead of saving it.
    static func discardSession(_ session: WorkoutSession, modelContext: ModelContext) throws {
        modelContext.delete(session)
        do {
            try modelContext.save()
        } catch {
            SentrySDK.capture(error: error)
            throw error
        }
    }
}
