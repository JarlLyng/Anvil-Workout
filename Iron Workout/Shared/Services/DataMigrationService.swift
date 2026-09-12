//
//  DataMigrationService.swift
//  Anvil Workout
//
//  Lightweight runtime data migrations. Runs once per named migration, tracked via
//  UserDefaults flags. Use this for one-off backfills that can be implemented in
//  pure Swift without a SwiftData VersionedSchema change.
//
//  For heavier migrations that change the schema shape (renames, splits, type changes),
//  prefer a full SwiftData VersionedSchema + MigrationPlan. See ARCHITECTURE.md for
//  guidance on when to use each approach.
//

import Foundation
import SwiftData
import Sentry

enum DataMigrationService {

    private enum MigrationKey: String {
        /// Backfills `WorkoutSessionExercise.exerciseID` for sessions created before v1.1.
        /// Matches session exercises to the current Exercise library by name.
        case backfillExerciseIDs = "migration.backfillExerciseIDs.v1"

        /// Closes CSV-imported sessions that were stored without an end date before v1.7.2.
        case closeImportedSessions = "migration.closeImportedSessions.v1"
    }

    /// Runs all pending migrations in order. Safe to call on every app launch — each
    /// migration is idempotent and guarded by a UserDefaults flag.
    static func runMigrationsIfNeeded(modelContext: ModelContext) {
        backfillExerciseIDsIfNeeded(modelContext: modelContext)
        closeImportedSessionsIfNeeded(modelContext: modelContext)
    }

    // MARK: - Backfill exerciseID on session exercises (v1.0.x → v1.1)

    private static func backfillExerciseIDsIfNeeded(modelContext: ModelContext) {
        let key = MigrationKey.backfillExerciseIDs.rawValue
        if UserDefaults.standard.bool(forKey: key) { return }

        do {
            let exercises = try modelContext.fetch(FetchDescriptor<Exercise>())
            let idByName = Dictionary(exercises.map { ($0.name, $0.id) }, uniquingKeysWith: { first, _ in first })

            let allSessionExercises = try modelContext.fetch(FetchDescriptor<WorkoutSessionExercise>())
            let orphans = allSessionExercises.filter { $0.exerciseID == nil }

            guard !orphans.isEmpty else {
                UserDefaults.standard.set(true, forKey: key)
                return
            }

            for sessionExercise in orphans {
                if let matchedID = idByName[sessionExercise.exerciseName] {
                    sessionExercise.exerciseID = matchedID
                } else {
                    // No matching Exercise found (deleted, renamed, or never existed as a library entry).
                    // Assign a placeholder UUID so queries don't treat this as "not yet migrated" forever.
                    // The exerciseName snapshot keeps the history display intact.
                    sessionExercise.exerciseID = UUID()
                }
            }

            try modelContext.save()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            SentrySDK.capture(error: error)
            // Do not set the flag — migration will retry on next launch.
        }
    }

    // MARK: - Close imported sessions left open (v1.7.1 → v1.7.2)

    /// CSV imports before v1.7.2 stored Strong workouts with `endedAt == nil`, because the
    /// parser ignored Strong's Duration column (#74). `WorkoutSessionService.findStaleSession`
    /// then matched them as abandoned live workouts, so the app offered to save or discard
    /// imported history on launch, one workout at a time, forever. This closes them.
    ///
    /// The duration stays at zero: the source length is not recoverable after the fact, and
    /// inventing one would put a wrong number in the user's history.
    private static func closeImportedSessionsIfNeeded(modelContext: ModelContext) {
        let key = MigrationKey.closeImportedSessions.rawValue
        if UserDefaults.standard.bool(forKey: key) { return }

        do {
            let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endedAt == nil })
            let openSessions = try modelContext.fetch(descriptor)

            for session in openSessions where isImportedHistory(session) {
                session.endedAt = session.startedAt
            }

            try modelContext.save()
            UserDefaults.standard.set(true, forKey: key)
        } catch {
            SentrySDK.capture(error: error)
            // Do not set the flag — migration will retry on next launch.
        }
    }

    /// Fingerprint only the CSV importer produces: no recorded duration, and every set
    /// completed at exactly the session start, because the importer has no per-set
    /// timestamps to work from.
    ///
    /// A workout logged in the app stamps `completedAt` when the user taps the set, which is
    /// always later than `startedAt`, and an abandoned one has sets still incomplete. Both
    /// are therefore left alone and stay eligible for the recovery prompt — including a
    /// session where nothing was logged at all, which has no sets to match on.
    private static func isImportedHistory(_ session: WorkoutSession) -> Bool {
        guard session.durationSeconds == 0 else { return false }
        let sets = session.exercises.flatMap(\.performedSets)
        guard !sets.isEmpty else { return false }
        return sets.allSatisfy { $0.isCompleted && $0.completedAt == session.startedAt }
    }
}
