//
//  StatsChartViews.swift
//  Anvil Workout
//
//  The cards on the Stats tab. Each leads with the number that answers its question and
//  puts the chart under it. Extracted from StatsView.swift to keep type-checking fast.
//

import SwiftUI
import Charts
import IAMJARLDesignTokens
import PhosphorSwift

// MARK: - Period and metric

enum StatsPeriod: Int, CaseIterable, Identifiable {
    case fourWeeks = 4
    case twelveWeeks = 12
    case twentySixWeeks = 26

    var id: Int { rawValue }
    var weeks: Int { rawValue }
    var label: String { "\(rawValue) weeks" }
}

enum PerWeekMetric: String, CaseIterable, Identifiable {
    case volume = "Volume"
    case workouts = "Workouts"
    case sets = "Sets"

    var id: String { rawValue }
}

struct MuscleGroupDataPoint: Identifiable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let setCount: Int
}

struct RecordItem: Identifiable {
    let id = UUID()
    let exerciseName: String
    let value: String
    let previousBest: String
    let date: Date
}

// MARK: - Card container

private struct StatsCard<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(title)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .accessibilityAddTraits(.isHeader)
            content()
        }
        .padding(DesignTokens.Spacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
}

/// A large number with a small label under it.
private struct BigNumber: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(.title2, design: .rounded, weight: .bold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// "Volume up 12% on the previous 4 weeks", "Same volume as the previous 4 weeks", or a
/// note that there is nothing to compare with yet.
func volumeComparisonText(current: Double, previous: Double, period: StatsPeriod) -> String {
    guard previous > 0 else { return current > 0 ? "Nothing logged in the \(period.label) before to compare with" : "" }
    let percent = Int(((current - previous) / previous * 100).rounded())
    if percent == 0 { return "Same volume as the previous \(period.label)" }
    return "Volume \(percent > 0 ? "up" : "down") \(abs(percent))% on the previous \(period.label)"
}

// MARK: - Summary

struct StatsSummaryCard: View {
    let period: StatsPeriod
    let workouts: Int
    let sets: Int
    let volumeText: String
    /// "Volume up 12% on the previous 4 weeks".
    let comparison: String

    var body: some View {
        StatsCard(title: "Last \(period.label)") {
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                BigNumber(value: "\(workouts)", label: workouts == 1 ? "workout" : "workouts")
                BigNumber(value: "\(sets)", label: "sets")
                BigNumber(value: volumeText, label: "volume")
            }
            if !comparison.isEmpty {
                Text(comparison)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Per week

struct PerWeekChartCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let buckets: [TrainingSummary.WeekBucket]
    @Binding var metric: PerWeekMetric
    let weightUnit: WeightUnit

    private func value(_ bucket: TrainingSummary.WeekBucket) -> Double {
        switch metric {
        case .volume: WeightFormatter.display(bucket.volumeKg, in: weightUnit)
        case .workouts: Double(bucket.workouts)
        case .sets: Double(bucket.sets)
        }
    }

    private var yLabel: String {
        switch metric {
        case .volume: "Volume (\(weightUnit.label))"
        case .workouts: "Workouts"
        case .sets: "Sets"
        }
    }

    /// The average over weeks with any training, so a week off does not drag it down.
    private var averageText: String {
        let trained = buckets.filter { $0.workouts > 0 }
        guard !trained.isEmpty else { return "No training in this period" }
        let average = trained.map(value).reduce(0, +) / Double(trained.count)
        switch metric {
        case .volume: return "\(WeightFormatter.volume(kg: WeightFormatter.toKg(average, from: weightUnit), in: weightUnit)) a week on average"
        case .workouts: return "\(average.formatted(.number.precision(.fractionLength(0...1)))) workouts a week on average"
        case .sets: return "\(Int(average.rounded())) sets a week on average"
        }
    }

    /// Fewer labels on longer periods, so dates never get cut short.
    private var labelStride: Int { buckets.count <= 4 ? 1 : (buckets.count <= 12 ? 3 : 6) }

    var body: some View {
        StatsCard(title: "Per week") {
            Picker("Metric", selection: $metric) {
                ForEach(PerWeekMetric.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)

            Text(averageText)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)

            let current = buckets.last?.start
            Chart(buckets) { bucket in
                BarMark(
                    x: .value("Week", bucket.start, unit: .weekOfYear),
                    y: .value(yLabel, value(bucket))
                )
                .foregroundStyle(bucket.start == current
                    ? DesignTokens.Common.primary(colorScheme)
                    : Color.secondary.opacity(0.45))
                .cornerRadius(3)
            }
            .chartYAxisLabel(yLabel)
            .chartXAxis {
                AxisMarks(values: .stride(by: .weekOfYear, count: labelStride)) { _ in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.day().month(.abbreviated), centered: false)
                }
            }
            .frame(height: 180)
            .accessibilityLabel("\(metric.rawValue) per week")
        }
    }
}

// MARK: - Records

struct RecordsCard: View {
    let records: [RecordItem]
    let period: StatsPeriod

    var body: some View {
        StatsCard(title: "Personal records") {
            if records.isEmpty {
                Text("No new records in the last \(period.label). They show up here when you lift more weight, or more reps at a weight, than ever before.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: DesignTokens.Spacing.md) {
                    ForEach(records) { record in
                        HStack(alignment: .firstTextBaseline) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.exerciseName)
                                    .font(.subheadline.weight(.semibold))
                                Text(record.previousBest == "None" ? "First time" : "Before: \(record.previousBest)")
                                    .font(.caption.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(record.value)
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                Text(record.date.formatted(.dateTime.day().month(.abbreviated)))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
    }
}

// MARK: - Strength

struct StrengthCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let history: [(date: Date, kg: Double)]
    /// Exercises with at least one weighted work set, most trained first.
    let exercises: [Exercise]
    @Binding var selected: Exercise?
    let weightUnit: WeightUnit
    let period: StatsPeriod

    private var headline: (value: String, change: String)? {
        guard let latest = history.last else { return nil }
        let best = history.map(\.kg).max() ?? latest.kg
        let value = WeightFormatter.compact(kg: best, in: weightUnit)
        guard let first = history.first, history.count > 1 else { return (value, "One workout in this period") }
        let diff = WeightFormatter.display(latest.kg - first.kg, in: weightUnit)
        let rounded = diff.formatted(.number.precision(.fractionLength(0...1)))
        let change = abs(diff) < 0.05
            ? "No change over \(period.label)"
            : "\(diff > 0 ? "+" : "")\(rounded) \(weightUnit.label) over \(period.label)"
        return (value, change)
    }

    var body: some View {
        StatsCard(title: "Strength") {
            if exercises.isEmpty {
                Text("Your estimated one-rep max shows up here once you log working sets with weight.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Picker("Exercise", selection: $selected) {
                    ForEach(exercises) { ex in
                        Text(ex.name).tag(Exercise?.some(ex))
                    }
                }
                .pickerStyle(.menu)
                .tint(.primary)
                .padding(.leading, -DesignTokens.Spacing.sm)

                if let headline {
                    HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.md) {
                        BigNumber(value: headline.value, label: "best estimated 1RM")
                        Text(headline.change)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    Chart(Array(history.enumerated()), id: \.offset) { _, point in
                        LineMark(
                            x: .value("Date", point.date),
                            y: .value("1RM (\(weightUnit.label))", WeightFormatter.display(point.kg, in: weightUnit))
                        )
                        .interpolationMethod(.monotone)
                        .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("1RM (\(weightUnit.label))", WeightFormatter.display(point.kg, in: weightUnit))
                        )
                        .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                        .symbolSize(30)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .chartYAxisLabel("1RM (\(weightUnit.label))")
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                        }
                    }
                    .frame(height: 160)
                } else {
                    Text("No weighted working sets of 1 to 12 reps for this exercise in the last \(period.label).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Text("Estimated from the best working set of each workout, using sets of 1 to 12 reps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Muscle groups

struct MuscleGroupCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let data: [MuscleGroupDataPoint]
    let period: StatsPeriod

    var body: some View {
        StatsCard(title: "Sets per muscle group") {
            if data.isEmpty {
                Text("No sets in the last \(period.label).")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Chart(data) { item in
                    BarMark(
                        x: .value("Sets", item.setCount),
                        y: .value("Muscle group", item.muscleGroup)
                    )
                    .foregroundStyle(DesignTokens.Common.primary(colorScheme).opacity(0.85))
                    .cornerRadius(3)
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("\(item.setCount)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                }
                .chartXAxis(.hidden)
                .frame(height: CGFloat(data.count) * 34)
            }
        }
    }
}
