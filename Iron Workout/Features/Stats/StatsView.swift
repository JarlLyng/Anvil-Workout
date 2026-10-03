//
//  StatsView.swift
//  Anvil Workout
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
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    @State private var period: StatsPeriod = .twelveWeeks
    @State private var metric: PerWeekMetric = .volume
    @State private var selectedExercise: Exercise?

    // Memoized inputs. Recomputed only when the sessions, the period or the selected
    // exercise change, never on every body invocation: walking the session graph per
    // redraw allocated thousands of arrays a frame and could trip the watchdog on iPad
    // with a long history.
    @State private var buckets: [TrainingSummary.WeekBucket] = []
    @State private var previousVolumeKg: Double = 0
    @State private var records: [RecordItem] = []
    @State private var strengthExercises: [Exercise] = []
    @State private var strengthHistory: [(date: Date, kg: Double)] = []
    @State private var muscleGroups: [MuscleGroupDataPoint] = []

    private var hasTraining: Bool { sessions.contains { $0.completedSetCount > 0 } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    if hasTraining {
                        Picker("Period", selection: $period) {
                            ForEach(StatsPeriod.allCases) { Text($0.label).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        .padding(.top, DesignTokens.Spacing.sm)

                        let volume = buckets.reduce(0) { $0 + $1.volumeKg }
                        StatsSummaryCard(
                            period: period,
                            workouts: buckets.reduce(0) { $0 + $1.workouts },
                            sets: buckets.reduce(0) { $0 + $1.sets },
                            volumeText: WeightFormatter.volume(kg: volume, in: weightUnit),
                            comparison: volumeComparisonText(current: volume, previous: previousVolumeKg, period: period)
                        )
                        PerWeekChartCard(buckets: buckets, metric: $metric, weightUnit: weightUnit)
                        RecordsCard(records: records, period: period)
                        StrengthCard(
                            history: strengthHistory,
                            exercises: strengthExercises,
                            selected: $selectedExercise,
                            weightUnit: weightUnit,
                            period: period
                        )
                        MuscleGroupCard(data: muscleGroups, period: period)
                    } else {
                        emptyState
                    }
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0).background(Color(uiColor: .systemGroupedBackground))
            }
            .toolbar(.hidden, for: .navigationBar)
            .task { recomputeAll() }
            .onChange(of: sessions.count) { _, _ in recomputeAll() }
            .onChange(of: period) { _, _ in recomputeAll() }
            .onChange(of: selectedExercise) { _, _ in recomputeStrength() }
        }
    }

    private var emptyState: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Ph.chartBar.regular
                .icon(size: 40)
                .foregroundStyle(.secondary)
            Text("Your stats fill in as you train")
                .font(.headline)
            Text("Finish a workout and this is where you see your volume per week, your records and how your lifts are moving.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.xxxl)
    }

    // MARK: - Memoization

    private func recomputeAll() {
        let doubled = TrainingSummary.weeklyBuckets(weeks: period.weeks * 2, sessions: sessions)
        buckets = Array(doubled.suffix(period.weeks))
        previousVolumeKg = doubled.prefix(doubled.count - buckets.count).reduce(0) { $0 + $1.volumeKg }
        records = computeRecords()
        muscleGroups = computeMuscleGroups()
        strengthExercises = computeStrengthExercises()
        if selectedExercise == nil || !strengthExercises.contains(where: { $0.id == selectedExercise?.id }) {
            selectedExercise = strengthExercises.first
        }
        recomputeStrength()
    }

    private func recomputeStrength() {
        guard let exercise = selectedExercise, let since = periodStart else {
            strengthHistory = []
            return
        }
        strengthHistory = TrainingSummary.oneRepMaxHistory(for: exercise, since: since, sessions: sessions)
    }

    private var periodStart: Date? { buckets.first?.start }

    private var sessionsInPeriod: [WorkoutSession] {
        guard let since = periodStart else { return [] }
        return sessions.filter { $0.completedSetCount > 0 && $0.startedAt >= since }
    }

    /// The latest record for each exercise in the period, newest first, each workout
    /// compared with everything before it rather than with what came later. An exercise's
    /// first time is a baseline, not a record.
    private func computeRecords() -> [RecordItem] {
        let completed = sessions.filter { $0.completedSetCount > 0 }
        guard let since = periodStart else { return [] }
        var items: [RecordItem] = []
        var seen: Set<String> = []
        for (index, session) in completed.enumerated().reversed() where session.startedAt >= since {
            let found = PersonalRecordService.detectPersonalRecords(in: session, history: Array(completed[..<index]))
            for record in PersonalRecordService.onePerExercise(found) where !record.isFirstTime && !seen.contains(record.exerciseName) {
                seen.insert(record.exerciseName)
                items.append(RecordItem(
                    exerciseName: record.exerciseName,
                    value: record.value,
                    previousBest: record.previousBest,
                    date: session.startedAt
                ))
            }
            if items.count >= 6 { break }
        }
        return Array(items.sorted { ($0.date, $1.exerciseName) > ($1.date, $0.exerciseName) }.prefix(6))
    }

    private func computeMuscleGroups() -> [MuscleGroupDataPoint] {
        let groupByID = Dictionary(exercises.map { ($0.id, $0.muscleGroup.rawValue) }, uniquingKeysWith: { first, _ in first })
        let groupByName = Dictionary(exercises.map { ($0.name, $0.muscleGroup.rawValue) }, uniquingKeysWith: { first, _ in first })
        var counts: [String: Int] = [:]
        for session in sessionsInPeriod {
            for ex in session.exercises {
                let sets = ex.performedSets.filter { TrainingSummary.isWorkSet($0) && $0.actualReps != nil }.count
                guard sets > 0 else { continue }
                let group = ex.exerciseID.flatMap { groupByID[$0] } ?? groupByName[ex.exerciseName] ?? "Other"
                counts[group, default: 0] += sets
            }
        }
        return counts.map { MuscleGroupDataPoint(muscleGroup: $0.key, setCount: $0.value) }
            .sorted { $0.setCount > $1.setCount }
    }

    /// Exercises with a weighted work set in the period, the most trained first, so the
    /// picker opens on a lift that has a line to show.
    private func computeStrengthExercises() -> [Exercise] {
        var setsByExercise: [UUID: Int] = [:]
        let inPeriod = sessionsInPeriod
        for exercise in exercises {
            let count = inPeriod.flatMap(\.exercises)
                .filter { $0.matches(exercise) }
                .flatMap(\.performedSets)
                .filter { TrainingSummary.isWorkSet($0) && $0.actualWeight != nil && $0.actualReps != nil }
                .count
            if count > 0 { setsByExercise[exercise.id] = count }
        }
        return exercises
            .filter { setsByExercise[$0.id] != nil }
            .sorted { (setsByExercise[$0.id] ?? 0) > (setsByExercise[$1.id] ?? 0) }
    }
}

#Preview {
    StatsView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self], inMemory: true)
}
