//
//  WorkoutCSVImportService.swift
//  Anvil Workout
//
//  Persists a ParsedImport (from WorkoutCSVImporter) into SwiftData as historical
//  WorkoutSessions. Exercise names are matched case-insensitively against the
//  existing library so PRs and stats line up; unmatched names become custom
//  exercises so the history is still complete and editable.
//

import Foundation
import SwiftData
import Sentry

enum WorkoutCSVImportService {

    struct Summary: Equatable {
        let format: WorkoutCSVFormat
        let importedSessions: Int
        let importedSets: Int
        let createdExercises: Int
    }

    /// Inserts the parsed sessions. Matches exercises by name (case-insensitive), creating
    /// custom `Exercise` records for unknown names. Saves once at the end.
    @discardableResult
    static func save(_ parsed: ParsedImport, modelContext: ModelContext) throws -> Summary {
        let existing = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        // Lowercased name → Exercise, keeping the first match for stable identity.
        var libraryByName: [String: Exercise] = [:]
        for exercise in existing {
            let key = exercise.name.lowercased()
            if libraryByName[key] == nil { libraryByName[key] = exercise }
        }

        var createdExercises = 0
        var importedSets = 0

        for parsedSession in parsed.sessions {
            let session = WorkoutSession(
                templateName: parsedSession.name.isEmpty ? "Imported Workout" : parsedSession.name,
                startedAt: parsedSession.startedAt,
                endedAt: parsedSession.endedAt,
                exerciseCount: parsedSession.exercises.count
            )
            modelContext.insert(session)

            // Shared UUID per source superset key, scoped to this session.
            var supersetIDByKey: [String: UUID] = [:]

            for (exerciseOrder, parsedExercise) in parsedSession.exercises.enumerated() {
                let exercise = resolveExercise(named: parsedExercise.name, libraryByName: &libraryByName, modelContext: modelContext, createdCount: &createdExercises)

                let supersetID = parsedExercise.supersetKey.map { key -> UUID in
                    if let id = supersetIDByKey[key] { return id }
                    let id = UUID()
                    supersetIDByKey[key] = id
                    return id
                }

                let sessionExercise = WorkoutSessionExercise(
                    exerciseID: exercise.id,
                    exerciseName: exercise.name,
                    sortOrder: exerciseOrder,
                    supersetID: supersetID
                )
                sessionExercise.session = session
                session.exercises.append(sessionExercise)
                modelContext.insert(sessionExercise)

                let sortedSets = parsedExercise.sets.sorted { $0.setIndex < $1.setIndex }
                for (setOrder, parsedSet) in sortedSets.enumerated() {
                    let set = PerformedSet(
                        setIndex: setOrder,
                        targetReps: parsedSet.reps,
                        actualReps: parsedSet.reps,
                        targetWeight: parsedSet.weightKg,
                        actualWeight: parsedSet.weightKg,
                        isCompleted: true,
                        completedAt: parsedSession.startedAt
                    )
                    set.setType = parsedSet.type
                    set.sessionExercise = sessionExercise
                    sessionExercise.performedSets.append(set)
                    modelContext.insert(set)
                    importedSets += 1
                }
            }

            // Historical aggregates: duration from the source range when available, else 0.
            if let endedAt = parsedSession.endedAt {
                session.durationSeconds = Int(max(0, endedAt.timeIntervalSince(parsedSession.startedAt).rounded()))
            }
            session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        }

        do {
            try modelContext.save()
        } catch {
            SentrySDK.capture(error: error)
            throw error
        }

        return Summary(
            format: parsed.format,
            importedSessions: parsed.sessions.count,
            importedSets: importedSets,
            createdExercises: createdExercises
        )
    }

    /// Finds an existing exercise by case-insensitive name or creates a custom one.
    private static func resolveExercise(
        named name: String,
        libraryByName: inout [String: Exercise],
        modelContext: ModelContext,
        createdCount: inout Int
    ) -> Exercise {
        let key = name.lowercased()
        if let match = libraryByName[key] { return match }

        let created = Exercise(name: name, muscleGroup: .fullBody, isBuiltin: false)
        modelContext.insert(created)
        libraryByName[key] = created
        createdCount += 1
        return created
    }
}
