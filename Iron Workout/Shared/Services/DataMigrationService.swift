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
    }

    /// Runs all pending migrations in order. Safe to call on every app launch — each
    /// migration is idempotent and guarded by a UserDefaults flag.
    static func runMigrationsIfNeeded(modelContext: ModelContext) {
        backfillExerciseIDsIfNeeded(modelContext: modelContext)
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
}
