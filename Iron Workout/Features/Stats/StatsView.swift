//
//  StatsView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import Charts
import IAMJARLDesignTokens
import PhosphorSwift

struct StatsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .forward) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    @State private var selectedExerciseFor1RM: Exercise?

    // MARK: - Computed Data

    private var volumeData: [VolumeDataPoint] {
        var data: [Date: Double] = [:]
        for session in sessions {
            let day = Calendar.current.startOfDay(for: session.startedAt)
            var sessionVolume = 0.0
            for ex in session.exercises {
                for set in ex.performedSets where set.isCompleted && set.setType == .working {
                    if let reps = set.actualReps, let weight = set.actualWeight {
                        sessionVolume += Double(reps) * weight
                    }
                }
            }
            if sessionVolume > 0 {
                data[day, default: 0] += sessionVolume
            }
        }
        return data.map { VolumeDataPoint(date: $0.key, volume: $0.value) }.sorted { $0.date < $1.date }
    }

    private var frequencyData: [FrequencyDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        guard let eightWeeksAgo = calendar.date(byAdding: .weekOfYear, value: -8, to: now) else { return [] }

        var weekBuckets: [Date: Int] = [:]
        for i in 0..<8 {
            if let weekStart = calendar.date(byAdding: .weekOfYear, value: -(7 - i), to: now),
               let interval = calendar.dateInterval(of: .weekOfYear, for: weekStart) {
                weekBuckets[interval.start] = 0
            }
        }

        for session in sessions where session.startedAt >= eightWeeksAgo && session.completedSetCount > 0 {
            if let interval = calendar.dateInterval(of: .weekOfYear, for: session.startedAt) {
                weekBuckets[interval.start, default: 0] += 1
            }
        }

        return weekBuckets.map { FrequencyDataPoint(weekStart: $0.key, count: $0.value) }
            .sorted { $0.weekStart < $1.weekStart }
    }

    private var muscleGroupData: [MuscleGroupDataPoint] {
        var counts: [String: Int] = [:]
        let exerciseLookup = Dictionary(uniqueKeysWithValues: exercises.map { ($0.name, $0.muscleGroup.rawValue) })

        for session in sessions {
            for ex in session.exercises {
                let completedSets = ex.performedSets.filter(\.isCompleted).count
                guard completedSets > 0 else { continue }
                let group = exerciseLookup[ex.exerciseName] ?? "Other"
                counts[group, default: 0] += completedSets
            }
        }

        return counts.map { MuscleGroupDataPoint(muscleGroup: $0.key, setCount: $0.value) }
            .sorted { $0.setCount > $1.setCount }
    }

    private var oneRepMaxData: [OneRepMaxDataPoint] {
        guard let exercise = selectedExerciseFor1RM else { return [] }
        var data: [Date: Double] = [:]

        for session in sessions {
            let day = Calendar.current.startOfDay(for: session.startedAt)
            for ex in session.exercises where ex.exerciseName == exercise.name {
                var max1RM = 0.0
                for set in ex.performedSets where set.isCompleted && set.setType == .working {
                    if let reps = set.actualReps, let weight = set.actualWeight, reps > 0 {
                        let e1rm = weight * (36.0 / (37.0 - Double(reps)))
                        if e1rm > max1RM { max1RM = e1rm }
                    }
                }
                if max1RM > 0 {
                    let currentMax = data[day] ?? 0
                    if max1RM > currentMax { data[day] = max1RM }
                }
            }
        }
        return data.map { OneRepMaxDataPoint(date: $0.key, estimated1RM: $0.value) }.sorted { $0.date < $1.date }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    VolumeChartView(data: volumeData)
                    FrequencyChartView(data: frequencyData)
                    OneRepMaxChartView(
                        data: oneRepMaxData,
                        exercises: exercises,
                        selectedExercise: $selectedExerciseFor1RM
                    )
                    MuscleGroupChartView(data: muscleGroupData)
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear {
                if selectedExerciseFor1RM == nil {
                    selectedExerciseFor1RM = exercises.first(where: { $0.name.lowercased().contains("bench") }) ?? exercises.first
                }
            }
        }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self], inMemory: true)
}
