//
//  StatsChartViews.swift
//  Anvil Workout
//
//  Extracted from StatsView.swift to reduce type-checking time.
//

import SwiftUI
import Charts
import IAMJARLDesignTokens
import PhosphorSwift

// MARK: - Data Point Models

struct VolumeDataPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let volume: Double
}

struct FrequencyDataPoint: Identifiable {
    var id: Date { weekStart }
    let weekStart: Date
    let count: Int
}

struct OneRepMaxDataPoint: Identifiable {
    var id: Date { date }
    let date: Date
    let estimated1RM: Double
}

struct MuscleGroupDataPoint: Identifiable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let setCount: Int
}

// MARK: - Volume Chart

struct VolumeChartView: View {
    let data: [VolumeDataPoint]
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Ph.stack.fill.icon()
                Text("Training Volume")
                    .font(.headline)
            }

            if data.isEmpty {
                Text("No volume logged yet (remember to enter weight and reps for your working sets).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("Volume (\(weightUnit.label))", WeightFormatter.display(item.volume, in: weightUnit))
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
}

// MARK: - Frequency Chart

struct FrequencyChartView: View {
    let data: [FrequencyDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Ph.calendarCheck.fill.icon()
                Text("Training Frequency")
                    .font(.headline)
            }

            if data.isEmpty {
                Text("No workouts recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(data) { item in
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
}

// MARK: - One Rep Max Chart

struct OneRepMaxChartView: View {
    let data: [OneRepMaxDataPoint]
    let exercises: [Exercise]
    @Binding var selectedExercise: Exercise?
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Ph.trendUp.fill.icon().foregroundStyle(.primary)
                    Text("1RM Estimate")
                        .font(.headline)
                }
                Spacer()
                Picker("Exercise", selection: $selectedExercise) {
                    Text("Select...").tag(Exercise?.none)
                    ForEach(exercises) { ex in
                        Text(ex.name).tag(Exercise?.some(ex))
                    }
                }
                .labelsHidden()
                .tint(.primary)
            }

            if selectedExercise == nil {
                Text("Select an exercise to see its estimated max strength over time.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if data.isEmpty {
                Text("No heavy working sets recorded for this exercise yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(data) { item in
                    LineMark(
                        x: .value("Date", item.date, unit: .day),
                        y: .value("1RM (\(weightUnit.label))", WeightFormatter.display(item.estimated1RM, in: weightUnit))
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
}

// MARK: - Muscle Group Chart

struct MuscleGroupChartView: View {
    let data: [MuscleGroupDataPoint]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Ph.barbell.fill.icon()
                Text("Muscle Group Distribution")
                    .font(.headline)
            }

            if data.isEmpty {
                Text("No sets recorded yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Sets", item.setCount),
                        y: .value("Muscle Group", item.muscleGroup)
                    )
                    .foregroundStyle(DesignTokens.ColorToken.State.success.gradient)
                }
                .frame(height: CGFloat(data.count) * 40)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
}
