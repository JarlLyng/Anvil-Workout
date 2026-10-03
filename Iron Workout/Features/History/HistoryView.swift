//
//  HistoryView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//
//  Every workout, newest first, grouped into this week, last week and months, each row in
//  the same form as the home screen's recent workouts. Search finds a program or an
//  exercise.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

struct HistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
    @State private var searchText = ""

    /// Matches the program name or any exercise in the workout, so "deadlift" finds every
    /// workout with one.
    private var filteredSessions: [WorkoutSession] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty else { return sessions }
        return sessions.filter { session in
            session.templateName.localizedCaseInsensitiveContains(query)
                || session.exercises.contains { $0.exerciseName.localizedCaseInsensitiveContains(query) }
        }
    }

    var body: some View {
        Group {
            if sessions.isEmpty {
                ContentUnavailableView {
                    Label { Text("No workouts yet") } icon: { Ph.clockCounterClockwise.regular.icon(size: 44) }
                } description: {
                    Text("Finished workouts show up here, with their sets, weights and time.")
                }
            } else if filteredSessions.isEmpty {
                ContentUnavailableView.search(text: searchText)
            } else {
                list
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, prompt: "Programs and exercises")
    }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                ForEach(TrainingSummary.historyGroups(filteredSessions, date: \.startedAt), id: \.title) { group in
                    DashboardSectionLabel(title: group.title) {
                        Text(group.items.count == 1 ? "1 workout" : "\(group.items.count) workouts")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, DesignTokens.Spacing.md)
                    ForEach(group.items) { session in
                        NavigationLink(value: session) {
                            RecentWorkoutRow(
                                name: session.templateName,
                                dateLabel: dateLabel(session.startedAt),
                                detail: TrainingSummary.detailLine(of: session, unit: weightUnit)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
    }

    /// "Today", "Yesterday", then "Fri 2 Oct".
    private func dateLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
    }
}

#Preview {
    NavigationStack {
        HistoryView()
    }
    .modelContainer(for: [WorkoutSession.self], inMemory: true)
}
