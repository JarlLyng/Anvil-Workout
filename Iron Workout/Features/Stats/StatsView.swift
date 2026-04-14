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
    
    // Extracted data for charts
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

        // Build last 8 week buckets
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
                        // Brzycki formula
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    volumeSection
                    frequencySection
                    oneRepMaxSection
                    muscleGroupSection
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
    
    private var volumeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Ph.stack.fill.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
                Text("Training Volume")
                    .font(.headline)
            }
            
            if volumeData.isEmpty {
                Text("No volume logged yet (remember to enter weight and reps for your working sets).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(volumeData) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Volume (kg)", item.volume)
                    )
                    .foregroundStyle(DesignTokens.ColorToken.State.success.gradient)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
    
    private var frequencySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Ph.calendarCheck.fill.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
                Text("Training Frequency")
                    .font(.headline)
            }

            if frequencyData.isEmpty {
                Text("No workouts recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(frequencyData) { item in
                    BarMark(
                        x: .value("Week", item.weekStart, unit: .weekOfYear),
                        y: .value("Count", item.count)
                    )
                    .foregroundStyle(DesignTokens.ColorToken.State.warning.gradient)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }

    private var oneRepMaxSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Ph.trendUp.fill.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20).foregroundStyle(.primary)
                    Text("1RM Estimate")
                        .font(.headline)
                }
                Spacer()
                Picker("Exercise", selection: $selectedExerciseFor1RM) {
                    Text("Select...").tag(Exercise?.none)
                    ForEach(exercises) { ex in
                        Text(ex.name).tag(Exercise?.some(ex))
                    }
                }
                .labelsHidden()
                .tint(.primary)
            }
            
            if selectedExerciseFor1RM == nil {
                Text("Select an exercise to see its estimated max strength over time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if oneRepMaxData.isEmpty {
                Text("No heavy working sets recorded for this exercise yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(oneRepMaxData) { item in
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("1RM (kg)", item.estimated1RM)
                    )
                    .interpolationMethod(.monotone)
                    .symbol(Circle())
                    .foregroundStyle(Color.primary.gradient)
                }
                .frame(height: 200)
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 7)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel(format: .dateTime.month().day())
                    }
                }
                .chartYScale(domain: .automatic(includesZero: false))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
    private var muscleGroupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Ph.barbell.fill.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
                Text("Muscle Group Distribution")
                    .font(.headline)
            }

            if muscleGroupData.isEmpty {
                Text("No sets recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(muscleGroupData) { item in
                    BarMark(
                        x: .value("Sets", item.setCount),
                        y: .value("Muscle Group", item.muscleGroup)
                    )
                    .foregroundStyle(DesignTokens.ColorToken.State.success.gradient)
                }
                .frame(height: CGFloat(muscleGroupData.count) * 40)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
}

private struct VolumeDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let volume: Double
}

private struct OneRepMaxDataPoint: Identifiable {
    let id = UUID()
    let date: Date
    let estimated1RM: Double
}

private struct FrequencyDataPoint: Identifiable {
    let id = UUID()
    let weekStart: Date
    let count: Int
}

private struct MuscleGroupDataPoint: Identifiable {
    let id = UUID()
    let muscleGroup: String
    let setCount: Int
}

#Preview {
    StatsView()
        .modelContainer(for: [WorkoutSession.self, Exercise.self], inMemory: true)
}
