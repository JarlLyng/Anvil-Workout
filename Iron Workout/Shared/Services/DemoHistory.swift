//
//  DemoHistory.swift
//  Anvil Workout
//
//  Debug builds only. Launching with `-AnvilDemoHistory` on a store without workouts fills
//  it with twelve weeks of StrongLifts 5×5, so the home screen and Stats can be designed,
//  checked and screenshotted against a realistic history instead of a handful of sets:
//
//    xcrun simctl launch <device> com.iamjarl.Iron-Workout -AnvilDemoHistory
//

#if DEBUG
import Foundation
import SwiftData

enum DemoHistory {
    static func seedIfRequested(modelContext: ModelContext, arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard arguments.contains("-AnvilDemoHistory") else { return }
        let existing = (try? modelContext.fetchCount(FetchDescriptor<WorkoutSession>())) ?? 0
        guard existing == 0 else { return }

        guard let entry = ProgramLibraryService.program(withID: "stronglifts-5x5") else { return }
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        if templates.isEmpty {
            _ = try? ProgramLibraryService.importProgram(entry, unit: .kg, modelContext: modelContext)
        }
        let exercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        let byName = Dictionary(exercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start,
              let firstWeek = calendar.date(byAdding: .weekOfYear, value: -11, to: thisWeek) else { return }

        // Working weight per lift, raised after each workout that hits every rep.
        var weight: [String: Double] = [:]
        for workout in entry.workouts {
            for exercise in workout.exercises { weight[exercise.exerciseName] = exercise.suggestedWeight ?? 20 }
        }
        let step: [String: Double] = ["Deadlift": 5]

        var useA = true
        for week in 0..<12 where week != 5 {   // a week off in the middle
            for dayOffset in [0, 2, 4] {         // Monday, Wednesday, Friday
                guard let day = calendar.date(byAdding: .day, value: week * 7 + dayOffset, to: firstWeek),
                      let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day),
                      start < .now else { continue }

                let workout = useA ? entry.workouts[0] : entry.workouts[1]
                useA.toggle()
                let session = WorkoutSession(templateName: "\(entry.name) — \(workout.name)", startedAt: start)
                modelContext.insert(session)

                var completed = 0
                for (order, planned) in workout.exercises.enumerated() {
                    let name = planned.exerciseName
                    let kg = weight[name] ?? 20
                    let sessionExercise = WorkoutSessionExercise(
                        exerciseID: byName[name]?.id,
                        exerciseName: name,
                        sortOrder: order,
                        restSeconds: planned.restSeconds
                    )
                    modelContext.insert(sessionExercise)
                    sessionExercise.session = session
                    session.exercises.append(sessionExercise)

                    // One hard day on squats in week 8: the last two sets fall short.
                    let missed = name == "Back Squat" && week == 8 && dayOffset == 2
                    var setIndex = 0
                    if name == "Back Squat" {
                        let warmup = PerformedSet(setIndex: setIndex, targetReps: 5, actualReps: 5,
                                                  targetWeight: kg * 0.5, actualWeight: kg * 0.5,
                                                  isCompleted: true, completedAt: start)
                        warmup.setType = .warmup
                        add(warmup, to: sessionExercise, in: modelContext)
                        setIndex += 1
                        completed += 1
                    }
                    for n in 0..<planned.sets {
                        let reps = missed && n >= planned.sets - 2 ? planned.reps - (n - planned.sets + 3) : planned.reps
                        let set = PerformedSet(setIndex: setIndex, targetReps: planned.reps, actualReps: reps,
                                               targetWeight: kg, actualWeight: kg, isCompleted: true,
                                               completedAt: start.addingTimeInterval(Double(setIndex) * 200))
                        add(set, to: sessionExercise, in: modelContext)
                        setIndex += 1
                        completed += 1
                    }
                    if !missed { weight[name] = kg + (step[name] ?? 2.5) }
                }

                let minutes = 40 + (week * 3 + dayOffset) % 15
                session.completedSetCount = completed
                session.exerciseCount = workout.exercises.count
                session.durationSeconds = minutes * 60
                session.endedAt = start.addingTimeInterval(Double(minutes * 60))
            }
        }
        try? modelContext.save()
    }

    private static func add(_ set: PerformedSet, to exercise: WorkoutSessionExercise, in context: ModelContext) {
        context.insert(set)
        set.sessionExercise = exercise
        exercise.performedSets.append(set)
    }
}
#endif
