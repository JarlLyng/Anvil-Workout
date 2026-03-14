//
//  HistoryView.swift
//  IronFlow
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView {
                        Label("Ingen træninger endnu", systemImage: "clock.arrow.circlepath")
                    } description: {
                        Text("Når du har fuldført en træning fra fanen Træning, vises den her med varighed, sæt og evt. puls og kalorier fra Health.")
                    }
                } else {
                    List(sessions) { session in
                        NavigationLink(value: session) {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(session.templateName)
                                        .font(.headline)
                                    Spacer()
                                    Text(relativeDate(session.startedAt))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                HStack(spacing: 16) {
                                    Label("\(session.exerciseCount) øvelser", systemImage: "list.bullet")
                                    Label("\(session.completedSetCount) sæt", systemImage: "checkmark.circle")
                                    if session.durationSeconds > 0 {
                                        Label(formatDuration(session.durationSeconds), systemImage: "timer")
                                    }
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                if session.calories != nil || session.averageHeartRate != nil {
                                    HStack(spacing: 12) {
                                        if let cal = session.calories, cal > 0 {
                                            Label("\(Int(cal)) kcal", systemImage: "flame")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                        }
                                        if let hr = session.averageHeartRate, hr > 0 {
                                            Label("\(Int(hr)) bpm", systemImage: "heart")
                                                .font(.caption2)
                                                .foregroundStyle(.red)
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .navigationTitle("Historik")
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
            return "I dag " + date.formatted(date: .omitted, time: .shortened)
        }
        if cal.isDateInYesterday(date) {
            return "I går " + date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [WorkoutSession.self], inMemory: true)
}
