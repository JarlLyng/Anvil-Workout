//
//  HistoryView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

struct HistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @State private var searchText = ""

    private var filteredSessions: [WorkoutSession] {
        if searchText.isEmpty { return sessions }
        return sessions.filter { $0.templateName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No Workouts Yet", systemImage: "clock.arrow.counterclockwise")
                    } description: {
                        Text("When you complete a workout from the Workouts tab, it will appear here with duration, sets and optional heart rate and calories from Health.")
                    }
                } else if filteredSessions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List(filteredSessions) { session in
                        NavigationLink(value: session) {
                            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                HStack {
                                    Text(session.templateName)
                                        .font(.headline)
                                    Spacer()
                                    Text(relativeDate(session.startedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: DesignTokens.Spacing.lg) {
                                    Label { Text("\(session.exerciseCount) exercises") } icon: { Ph.listBullets.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 16, height: 16) }
                                    Label { Text("\(session.completedSetCount) sets") } icon: { Ph.checkCircle.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 16, height: 16) }
                                    if session.durationSeconds > 0 {
                                        Label { Text(formatDuration(session.durationSeconds)) } icon: { Ph.timer.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 16, height: 16) }
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                if session.calories != nil || session.averageHeartRate != nil {
                                    HStack(spacing: DesignTokens.Spacing.md) {
                                        if let cal = session.calories, cal > 0 {
                                            Label { Text("\(Int(cal)) kcal") } icon: { Ph.flame.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 14, height: 14) }
                                                .font(.caption2)
                                                .foregroundStyle(DesignTokens.ColorToken.State.warning)
                                        }
                                        if let hr = session.averageHeartRate, hr > 0 {
                                            Label { Text("\(Int(hr)) bpm") } icon: { Ph.heart.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 14, height: 14) }
                                                .font(.caption2)
                                                .foregroundStyle(DesignTokens.ColorToken.State.error)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, DesignTokens.Spacing.xs)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search history")
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
            }
        }
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if s > 0 {
            return "\(m)m \(s)s"
        }
        return "\(m) min"
    }

    private func relativeDate(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) {
            return "Today " + date.formatted(date: .omitted, time: .shortened)
        }
        if cal.isDateInYesterday(date) {
            return "Yesterday " + date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [WorkoutSession.self], inMemory: true)
}
