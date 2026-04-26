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

    // Memoized chart inputs. Recomputed only when the underlying counts or selected
    // exercise change — never on every body invocation. Recomputing on every redraw
    // walked the full session graph, allocating thousands of transient arrays per
    // frame and could trigger watchdog termination on iPad with rich histories.
    @State private var volumeData: [VolumeDataPoint] = []
    @State private var frequencyData: [FrequencyDataPoint] = []
    @State private var oneRepMaxData: [OneRepMaxDataPoint] = []
    @State private var muscleGroupData: [MuscleGroupDataPoint] = []

    /// Volume and 1RM charts are bounded to roughly the last six months. Earlier sets
    /// still count toward PRs in `ExerciseDetailView`, but plotting years of daily bars
    /// is both unreadable and a memory hazard.
    private static let chartHistoryWeeks = 26

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xxl) {
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
            .task {
                if selectedExerciseFor1RM == nil {
                    selectedExerciseFor1RM = exercises.first(where: { $0.name.lowercased().contains("bench") }) ?? exercises.first
                }
                recomputeAll()
            }
            .onChange(of: sessions.count) { _, _ in recomputeAll() }
            .onChange(of: selectedExerciseFor1RM) { _, _ in
                oneRepMaxData = computeOneRepMaxData()
            }
        }
    }

    // MARK: - Memoization

    private func recomputeAll() {
        volumeData = computeVolumeData()
        frequencyData = computeFrequencyData()
        oneRepMaxData = computeOneRepMaxData()
        muscleGroupData = computeMuscleGroupData()
    }

    private func computeVolumeData() -> [VolumeDataPoint] {
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .weekOfYear, value: -Self.chartHistoryWeeks, to: .now) else { return [] }

        var data: [Date: Double] = [:]
        for session in sessions where session.startedAt >= cutoff {
            let day = calendar.startOfDay(for: session.startedAt)
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
        return data.map { VolumeDataPoint(date: $0.key, volume: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private func computeFrequencyData() -> [FrequencyDataPoint] {
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

    private func computeMuscleGroupData() -> [MuscleGroupDataPoint] {
        var counts: [String: Int] = [:]
        let groupByID = Dictionary(uniqueKeysWithValues: exercises.map { ($0.id, $0.muscleGroup.rawValue) })
        let groupByName = Dictionary(exercises.map { ($0.name, $0.muscleGroup.rawValue) }, uniquingKeysWith: { first, _ in first })

        for session in sessions {
            for ex in session.exercises {
                let completedSets = ex.performedSets.filter(\.isCompleted).count
                guard completedSets > 0 else { continue }
                let group: String
                if let exerciseID = ex.exerciseID, let g = groupByID[exerciseID] {
                    group = g
                } else {
                    group = groupByName[ex.exerciseName] ?? "Other"
                }
                counts[group, default: 0] += completedSets
            }
        }

        return counts.map { MuscleGroupDataPoint(muscleGroup: $0.key, setCount: $0.value) }
            .sorted { $0.setCount > $1.setCount }
    }

    private func computeOneRepMaxData() -> [OneRepMaxDataPoint] {
        guard let exercise = selectedExerciseFor1RM else { return [] }
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .weekOfYear, value: -Self.chartHistoryWeeks, to: .now) else { return [] }

        var data: [Date: Double] = [:]
        for session in sessions where session.startedAt >= cutoff {
            let day = calendar.startOfDay(for: session.startedAt)
            for ex in session.exercises where ex.matches(exercise) {
                var max1RM = 0.0
                for set in ex.performedSets where set.isCompleted && set.setType == .working {
                    if let reps = set.actualReps, let weight = set.actualWeight, reps > 0, reps < 37 {
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
        return data.map { OneRepMaxDataPoint(date: $0.key, estimated1RM: $0.value) }
            .sorted { $0.date < $1.date }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self], inMemory: true)
}
