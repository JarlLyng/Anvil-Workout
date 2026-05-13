//
//  ExerciseDetailView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//

import SwiftUI
import SwiftData
import Charts
import IAMJARLDesignTokens
import PhosphorSwift

struct ExerciseDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    var exercise: Exercise

    @Query(sort: \WorkoutSession.startedAt, order: .reverse)
    private var sessions: [WorkoutSession]

    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    /// Aggregate stats for this exercise. Computed once per appear / session-count change
    /// rather than on every body invocation — walking the full session graph on each
    /// redraw was a major memory pressure source on iPad.
    private struct ExerciseStats {
        var bestWeight: Double?
        var bestVolume: (reps: Int, weight: Double)?
        var bestEstimated1RM: Double?
        var hasSets: Bool = false
    }

    @State private var stats: ExerciseStats = ExerciseStats()
    @State private var relevantSessions: [WorkoutSession] = []
    @State private var historyExpanded: Bool = false

    /// History list initially renders only the most recent N sessions. Older entries
    /// load on demand to avoid materializing hundreds of rows up front.
    private static let historyInitialCount = 50

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM yyyy"
        f.locale = Locale(identifier: "en_US")
        return f
    }()

    var body: some View {
        List {
            // MARK: - Header
            Section {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(exercise.name)
                        .font(.title2.bold())
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Text(exercise.muscleGroup.rawValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        if !exercise.equipmentType.isEmpty {
                            Text("•")
                                .foregroundStyle(.secondary)
                            Text(exercise.equipmentType)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            // MARK: - Personal Records
            if stats.hasSets {
                Section("Personal Records") {
                    HStack(spacing: DesignTokens.Spacing.md) {
                        prCard(
                            title: "Best Weight",
                            value: stats.bestWeight.map { WeightFormatter.format(kg: $0, in: weightUnit) } ?? "–",
                            icon: Ph.trophy.fill
                        )
                        prCard(
                            title: "Best Volume",
                            value: stats.bestVolume.map { "\($0.reps) × \(WeightFormatter.format(kg: $0.weight, in: weightUnit))" } ?? "–",
                            icon: Ph.chartBar.fill
                        )
                        prCard(
                            title: "Est. 1RM",
                            value: stats.bestEstimated1RM.map { WeightFormatter.format(kg: $0, in: weightUnit) } ?? "–",
                            icon: Ph.lightning.fill
                        )
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
            }

            // MARK: - History
            Section("History") {
                if relevantSessions.isEmpty {
                    Text("No workouts with this exercise yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    let visible = historyExpanded ? relevantSessions : Array(relevantSessions.prefix(Self.historyInitialCount))
                    ForEach(visible, id: \.id) { session in
                        sessionRow(session)
                    }
                    if !historyExpanded, relevantSessions.count > Self.historyInitialCount {
                        Button {
                            historyExpanded = true
                        } label: {
                            Text("Show all (+\(relevantSessions.count - Self.historyInitialCount) older)")
                                .font(.subheadline)
                        }
                    }
                }
            }
        }
        .navigationTitle("Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .task { recompute() }
        .onChange(of: sessions.count) { _, _ in recompute() }
    }

    // MARK: - Memoization

    private func recompute() {
        var newStats = ExerciseStats()
        var matchingSessions: [WorkoutSession] = []

        for session in sessions {
            var sessionMatched = false
            for ex in session.exercises where ex.matches(exercise) {
                sessionMatched = true
                for set in ex.performedSets where set.isCompleted && set.setType == .working {
                    newStats.hasSets = true
                    if let w = set.actualWeight, w > 0 {
                        if newStats.bestWeight.map({ w > $0 }) ?? true {
                            newStats.bestWeight = w
                        }
                        if let r = set.actualReps {
                            let volume = Double(r) * w
                            let currentBest = newStats.bestVolume.map { Double($0.reps) * $0.weight } ?? 0
                            if volume > currentBest {
                                newStats.bestVolume = (reps: r, weight: w)
                            }
                            if r > 0, r < 37 {
                                let e1rm = w * 36.0 / (37.0 - Double(r))
                                if newStats.bestEstimated1RM.map({ e1rm > $0 }) ?? true {
                                    newStats.bestEstimated1RM = e1rm
                                }
                            }
                        }
                    }
                }
            }
            if sessionMatched { matchingSessions.append(session) }
        }

        stats = newStats
        relevantSessions = matchingSessions
    }

    // MARK: - Subviews

    private func prCard(title: String, value: String, icon: Image) -> some View {
        VStack(spacing: 6) {
            icon
                .icon(size: 22)
                .foregroundStyle(DesignTokens.Common.primary(colorScheme))
            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.md))
    }

    private func sessionRow(_ session: WorkoutSession) -> some View {
        let exerciseEntries = session.exercises
            .filter { $0.matches(exercise) }
            .sorted { $0.sortOrder < $1.sortOrder }

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(Self.dateFormatter.string(from: session.startedAt))
                    .font(.subheadline.bold())
                Spacer()
                Text(session.templateName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ForEach(exerciseEntries, id: \.id) { entry in
                let completedSets = entry.performedSets
                    .filter { $0.isCompleted }
                    .sorted { $0.setIndex < $1.setIndex }

                ForEach(completedSets, id: \.id) { set in
                    HStack(spacing: 4) {
                        Ph.checkCircle.fill
                            .icon(size: 14)
                            .foregroundStyle(DesignTokens.ColorToken.State.success)
                        if let reps = set.actualReps {
                            Text("\(reps) reps")
                                .font(.caption)
                            if let w = set.actualWeight, w > 0 {
                                Text("× \(WeightFormatter.format(kg: w, in: weightUnit))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
