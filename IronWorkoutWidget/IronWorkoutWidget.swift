//
//  IronWorkoutWidget.swift
//  IronWorkoutWidget
//
//  Created by Jarl Lyng on 14/04/2026.
//

import WidgetKit
import SwiftUI
import SwiftData

// MARK: - Timeline Provider

struct Provider: AppIntentTimelineProvider {
    private let modelContainer: ModelContainer? = {
        let schema = Schema([
            WorkoutSession.self,
            WorkoutSessionExercise.self,
            PerformedSet.self,
            Exercise.self,
        ])
        let config = ModelConfiguration(
            isStoredInMemoryOnly: false,
            groupContainer: .identifier("group.com.iamjarl.Iron-Workout")
        )
        return try? ModelContainer(for: schema, configurations: [config])
    }()

    func placeholder(in context: Context) -> WorkoutEntry {
        WorkoutEntry(date: .now, thisWeek: 3, streak: 5, lastWorkoutName: "Push Day", lastWorkoutDate: .now)
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> WorkoutEntry {
        await fetchEntry()
    }

    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<WorkoutEntry> {
        let entry = await fetchEntry()
        // Update every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    @MainActor
    private func fetchEntry() -> WorkoutEntry {
        guard let container = modelContainer else {
            return WorkoutEntry(date: .now, thisWeek: 0, streak: 0, lastWorkoutName: nil, lastWorkoutDate: nil)
        }

        let context = container.mainContext
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )

        guard let sessions = try? context.fetch(descriptor) else {
            return WorkoutEntry(date: .now, thisWeek: 0, streak: 0, lastWorkoutName: nil, lastWorkoutDate: nil)
        }

        let completed = sessions.filter { $0.completedSetCount > 0 }

        // This week
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let thisWeek = completed.filter { $0.startedAt >= weekStart }.count

        // Streak
        var streak = 0
        var checkDate = Date.now
        let hasTodaySession = completed.contains { calendar.isDate($0.startedAt, inSameDayAs: checkDate) }
        if !hasTodaySession {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }
        while true {
            let dayStart = calendar.startOfDay(for: checkDate)
            let hasSession = completed.contains { calendar.isDate($0.startedAt, inSameDayAs: dayStart) }
            if hasSession {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }

        // Latest workout
        let last = completed.first

        return WorkoutEntry(
            date: .now,
            thisWeek: thisWeek,
            streak: streak,
            lastWorkoutName: last?.templateName,
            lastWorkoutDate: last?.startedAt
        )
    }
}

// MARK: - Timeline Entry

struct WorkoutEntry: TimelineEntry {
    let date: Date
    let thisWeek: Int
    let streak: Int
    let lastWorkoutName: String?
    let lastWorkoutDate: Date?
}

// MARK: - Widget Views

struct IronWorkoutWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: WorkoutEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallWidget
        case .systemMedium:
            mediumWidget
        default:
            smallWidget
        }
    }

    // MARK: Small Widget — Streak focus
    private var smallWidget: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.caption)
                Text("STREAK")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
            }

            Text("\(entry.streak)")
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(entry.streak == 1 ? "day" : "days")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            HStack(spacing: 4) {
                Image(systemName: "dumbbell.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text("\(entry.thisWeek) this week")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Medium Widget — Streak + details
    private var mediumWidget: some View {
        HStack(spacing: 16) {
            // Left: Streak
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .foregroundStyle(.orange)
                    Text("STREAK")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text("\(entry.streak)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                Text(entry.streak == 1 ? "day" : "days in a row")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Weekly stats
            VStack(alignment: .leading, spacing: 10) {
                statRow(
                    icon: "dumbbell.fill",
                    label: "This Week",
                    value: "\(entry.thisWeek) workouts"
                )

                if let name = entry.lastWorkoutName, let date = entry.lastWorkoutDate {
                    statRow(
                        icon: "clock.arrow.counterclockwise",
                        label: "Latest",
                        value: name
                    )
                    Text(date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 24)
                } else {
                    statRow(
                        icon: "clock.arrow.counterclockwise",
                        label: "Latest",
                        value: "None yet"
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func statRow(icon: String, label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
        }
    }
}

// MARK: - Widget Definition

struct IronWorkoutWidget: Widget {
    let kind: String = "IronWorkoutWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            IronWorkoutWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Iron Workout")
        .description("See your streak and weekly workouts.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Previews

extension ConfigurationAppIntent {
    fileprivate static var preview: ConfigurationAppIntent {
        ConfigurationAppIntent()
    }
}

#Preview(as: .systemSmall) {
    IronWorkoutWidget()
} timeline: {
    WorkoutEntry(date: .now, thisWeek: 3, streak: 5, lastWorkoutName: "Push Day", lastWorkoutDate: .now.addingTimeInterval(-3600))
}

#Preview(as: .systemMedium) {
    IronWorkoutWidget()
} timeline: {
    WorkoutEntry(date: .now, thisWeek: 3, streak: 5, lastWorkoutName: "Push Day", lastWorkoutDate: .now.addingTimeInterval(-3600))
}
