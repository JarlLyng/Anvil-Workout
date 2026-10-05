//
//  WorkoutCSVImportService.swift
//  Anvil Workout
//
//  Persists a ParsedImport (from WorkoutCSVImporter) into SwiftData as historical
//  WorkoutSessions. Exercise names are matched against the existing exercises, then
//  through ExerciseNameMatcher onto the library ("Bench Press (Barbell)" is the
//  library's Bench Press), so PRs and stats line up; anything else becomes a custom
//  exercise in its muscle group, so the history is still complete and editable.
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

    /// Inserts the parsed sessions. Matches exercises by name, then onto the library, and
    /// creates custom `Exercise` records for the rest. Saves once at the end.
    @discardableResult
    static func save(_ parsed: ParsedImport, modelContext: ModelContext) throws -> Summary {
        let existing = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        // Lowercased name → Exercise, keeping the first match for stable identity.
        var libraryByName: [String: Exercise] = [:]
        for exercise in existing {
            let key = exercise.name.lowercased()
            if libraryByName[key] == nil { libraryByName[key] = exercise }
        }
        let library = existing.filter(\.isBuiltin).map {
            ExerciseNameMatcher.Entry(name: $0.name, equipment: $0.equipmentType, muscleGroup: $0.muscleGroup)
        }

        var createdExercises = 0
        var importedSets = 0

        for parsedSession in parsed.sessions {
            // Imported rows are historical by definition: the workout already happened.
            // A nil end date would make `WorkoutSessionService.findStaleSession` treat the
            // import as an abandoned live workout and prompt the user to save or discard it
            // on the next launch, once per imported workout (#74). When the source carries
            // no end time or duration, fall back to the start: an unknown length is stored
            // as zero rather than guessed, but the session is still closed.
            let endedAt = parsedSession.endedAt ?? parsedSession.startedAt
            let session = WorkoutSession(
                templateName: parsedSession.name.isEmpty ? "Imported Workout" : parsedSession.name,
                startedAt: parsedSession.startedAt,
                endedAt: endedAt,
                exerciseCount: parsedSession.exercises.count
            )
            modelContext.insert(session)

            // Shared UUID per source superset key, scoped to this session.
            var supersetIDByKey: [String: UUID] = [:]

            for (exerciseOrder, parsedExercise) in parsedSession.exercises.enumerated() {
                let exercise = resolveExercise(named: parsedExercise.name, library: library, libraryByName: &libraryByName, modelContext: modelContext, createdCount: &createdExercises)

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
                    note: parsedExercise.note,
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
                        completedAt: parsedSession.startedAt,
                        rpe: parsedSet.rpe
                    )
                    set.setType = parsedSet.type
                    set.sessionExercise = sessionExercise
                    sessionExercise.performedSets.append(set)
                    modelContext.insert(set)
                    importedSets += 1
                }
            }

            // Historical aggregates: duration from the source range when available, else 0.
            session.durationSeconds = Int(max(0, endedAt.timeIntervalSince(parsedSession.startedAt).rounded()))
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

    /// An existing exercise with the same name, else the library exercise the name means,
    /// else a new custom exercise in the muscle group its movement belongs to. Each name is
    /// resolved once; later rows with it reuse the answer.
    private static func resolveExercise(
        named name: String,
        library: [ExerciseNameMatcher.Entry],
        libraryByName: inout [String: Exercise],
        modelContext: ModelContext,
        createdCount: inout Int
    ) -> Exercise {
        let key = name.lowercased()
        if let match = libraryByName[key] { return match }

        let muscleGroup: MuscleGroup
        switch ExerciseNameMatcher.resolve(name, library: library) {
        case .library(let libraryName):
            if let match = libraryByName[libraryName.lowercased()] {
                libraryByName[key] = match
                return match
            }
            muscleGroup = .fullBody
        case .custom(let group):
            muscleGroup = group
        }

        let created = Exercise(name: name, muscleGroup: muscleGroup, isBuiltin: false)
        modelContext.insert(created)
        libraryByName[key] = created
        createdCount += 1
        return created
    }
}
