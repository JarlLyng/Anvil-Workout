//
//  WorkoutSessionService.swift
//  IronFlow
//
//  Created by Jarl Lyng on 14/03/2026.
//

import Foundation
import SwiftData

enum WorkoutSessionService {

    /// Opretter en ny WorkoutSession fra en skabelon med alle øvelser og sæt.
    static func createSession(from template: WorkoutTemplate, modelContext: ModelContext) throws -> WorkoutSession {
        let descriptor = FetchDescriptor<Exercise>()
        let exercises = try modelContext.fetch(descriptor)
        let nameByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.name) })

        let session = WorkoutSession(
            templateName: template.name.isEmpty ? "Træning" : template.name,
            startedAt: .now,
            exerciseCount: template.exercises.count
        )
        modelContext.insert(session)

        let sorted = template.exercises.sorted { $0.sortOrder < $1.sortOrder }
        for (exIndex, te) in sorted.enumerated() {
            let name = nameByID[te.exerciseID] ?? "Ukendt øvelse"
            let sessionEx = WorkoutSessionExercise(
                exerciseName: name,
                sortOrder: exIndex,
                note: te.note,
                restSeconds: te.restSeconds
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

        try modelContext.save()
        return session
    }

    /// Opdaterer session med varighed og antal fuldførte sæt; kaldes ved afslutning.
    static func finalizeSession(_ session: WorkoutSession, modelContext: ModelContext) throws {
        session.endedAt = .now
        let duration = session.endedAt!.timeIntervalSince(session.startedAt)
        session.durationSeconds = Int(max(0, duration.rounded()))
        session.completedSetCount = session.exercises.flatMap(\.performedSets).filter(\.isCompleted).count
        try modelContext.save()
    }
}
