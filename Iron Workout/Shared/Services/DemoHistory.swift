//
//  DemoHistory.swift
//  Anvil Workout
//
//  Debug builds only. Launching with `-AnvilDemoHistory` (or in screenshot mode, see
//  ScreenshotMode) on a store without workouts fills it with 24 weeks of a 5×5 program,
//  so the home screen and Stats can be designed, checked and screenshotted against a
//  realistic history instead of a handful of sets:
//
//    xcrun simctl launch <device> com.iamjarl.Iron-Workout -AnvilDemoHistory
//
//  Weights go up in round steps of the user's unit (2.5 kg, or 5 lb), every workout for
//  twelve weeks and then more slowly, and the programs' targets end on the next workout's
//  weights, as a lifter's own would. The program is the library's StrongLifts 5×5 under a
//  plain name, Full Body A and B, so no screenshot carries another brand's name.
//

#if DEBUG
import Foundation
import SwiftData

enum DemoHistory {
    static func seedIfRequested(modelContext: ModelContext, arguments: [String] = ProcessInfo.processInfo.arguments) {
        let requested = arguments.contains("-AnvilDemoHistory")
            || (ScreenshotMode.isOn && ScreenshotMode.screen != .onboarding)
        guard requested else { return }
        let existing = (try? modelContext.fetchCount(FetchDescriptor<WorkoutSession>())) ?? 0
        guard existing == 0 else { return }

        let unit = WeightFormatter.current
        guard let entry = ProgramLibraryService.program(withID: "stronglifts-5x5") else { return }
        let templates = (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? []
        if templates.isEmpty {
            let imported = (try? ProgramLibraryService.importProgram(entry, unit: unit, modelContext: modelContext)) ?? []
            for (template, workout) in zip(imported, entry.workouts) {
                template.name = name(of: workout)
                template.note = ""
                template.sourceProgramID = nil
            }
        }
        let exercises = (try? modelContext.fetch(FetchDescriptor<Exercise>())) ?? []
        let byName = Dictionary(exercises.map { ($0.name, $0) }, uniquingKeysWith: { first, _ in first })

        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start,
              let firstWeek = calendar.date(byAdding: .weekOfYear, value: -23, to: thisWeek) else { return }

        // Working weight per lift in kilograms, raised after each workout that hits every rep:
        // 2.5 kg or 5 lb, twice that on the deadlift.
        var weight: [String: Double] = [:]
        for workout in entry.workouts {
            for exercise in workout.exercises {
                weight[exercise.exerciseName] = WeightFormatter.plateFriendly(kg: exercise.suggestedWeight ?? 20, in: unit)
            }
        }
        let step = unit == .lbs ? WeightFormatter.toKg(5, from: .lbs) : 2.5
        let deadliftStep = step * 2
        /// Half a working weight, rounded to what the unit's plates make.
        func warmup(_ kg: Double) -> Double {
            let display = WeightFormatter.display(kg / 2, in: unit)
            let plate = unit == .lbs ? 5.0 : 2.5
            return WeightFormatter.toKg((display / plate).rounded() * plate, from: unit)
        }

        var useA = true
        for week in 0..<24 where week != 5 && week != 16 {   // two weeks off
            for dayOffset in [0, 2, 4] {         // Monday, Wednesday, Friday
                guard let day = calendar.date(byAdding: .day, value: week * 7 + dayOffset, to: firstWeek),
                      let start = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: day),
                      start < .now else { continue }

                let workout = useA ? entry.workouts[0] : entry.workouts[1]
                useA.toggle()
                let session = WorkoutSession(templateName: name(of: workout), startedAt: start)
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

                    // A hard day on squats now and then: the last two sets fall short.
                    let missed = name == "Back Squat" && (week == 8 || week == 20) && dayOffset == 2
                    var setIndex = 0
                    if name == "Back Squat" {
                        let warm = warmup(kg)
                        let set = PerformedSet(setIndex: setIndex, targetReps: 5, actualReps: 5,
                                               targetWeight: warm, actualWeight: warm,
                                               isCompleted: true, completedAt: start)
                        set.setType = .warmup
                        add(set, to: sessionExercise, in: modelContext)
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
                    // Every workout at first, then only the week's first, as progress slows.
                    if !missed && (week < 12 || dayOffset == 0) {
                        weight[name] = kg + (name == "Deadlift" ? deadliftStep : step)
                    }
                }

                let minutes = 40 + (week * 3 + dayOffset) % 15
                session.completedSetCount = completed
                session.exerciseCount = workout.exercises.count
                session.durationSeconds = minutes * 60
                session.endedAt = start.addingTimeInterval(Double(minutes * 60))
            }
        }

        // The programs' targets are the next workout's weights, as the lifter would have set
        // them, so Home and the workout screen do not ask for the starting weights.
        let names = Dictionary(exercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        for template in (try? modelContext.fetch(FetchDescriptor<WorkoutTemplate>())) ?? [] {
            for item in template.exercises {
                if let name = names[item.exerciseID], let kg = weight[name] { item.targetWeight = kg }
            }
        }
        try? modelContext.save()
    }

    /// "Full Body A" for the library's "Workout A".
    private static func name(of workout: ProgramWorkout) -> String {
        "Full Body \(workout.name.split(separator: " ").last ?? "")"
    }

    private static func add(_ set: PerformedSet, to exercise: WorkoutSessionExercise, in context: ModelContext) {
        context.insert(set)
        set.sessionExercise = exercise
        exercise.performedSets.append(set)
    }
}
#endif
