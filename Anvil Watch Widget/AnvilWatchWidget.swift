//
//  AnvilWatchWidget.swift
//  Anvil Watch Widget
//
//  watchOS Smart Stack widget showing the current streak and last workout.
//  Data is pushed from the iPhone via WatchConnectivity and persisted by
//  the watch app to a shared App Group UserDefaults — this widget just
//  reads that snapshot. Tap to open the watch app.
//

import WidgetKit
import SwiftUI

private enum WidgetStorage {
    static let appGroup = "group.com.iamjarl.Iron-Workout"
    static let key = "watchStatsSnapshot"
}

struct StatsEntry: TimelineEntry {
    let date: Date
    let stats: WatchStatsSnapshot?
}

struct StatsProvider: TimelineProvider {
    func placeholder(in context: Context) -> StatsEntry {
        StatsEntry(date: .now, stats: WatchStatsSnapshot(
            currentStreak: 3,
            totalWorkouts: 24,
            lastWorkoutName: "Push Day",
            lastWorkoutDate: .now.addingTimeInterval(-3600),
            updatedAt: .now
        ))
    }

    func getSnapshot(in context: Context, completion: @escaping (StatsEntry) -> Void) {
        completion(StatsEntry(date: .now, stats: readStats()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<StatsEntry>) -> Void) {
        // We have no idea when the next workout will happen, so refresh
        // every 30 minutes as a safety net — the phone will also push
        // an update on app open and after each completed workout.
        let entry = StatsEntry(date: .now, stats: readStats())
        let nextRefresh = Date().addingTimeInterval(30 * 60)
        completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
    }

    private func readStats() -> WatchStatsSnapshot? {
        guard let defaults = UserDefaults(suiteName: WidgetStorage.appGroup),
              let data = defaults.data(forKey: WidgetStorage.key) else { return nil }
        return try? JSONDecoder().decode(WatchStatsSnapshot.self, from: data)
    }
}

struct AnvilWatchWidgetEntryView: View {
    @Environment(\.widgetFamily) private var family
    var entry: StatsEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            circularView
        case .accessoryCorner:
            cornerView
        case .accessoryInline:
            inlineView
        case .accessoryRectangular:
            rectangularView
        default:
            rectangularView
        }
    }

    private var streak: Int { entry.stats?.currentStreak ?? 0 }

    private var circularView: some View {
        VStack(spacing: 0) {
            Image(systemName: "flame.fill")
                .font(.caption2)
                .foregroundStyle(.orange)
            Text("\(streak)")
                .font(.title3.bold().monospacedDigit())
            Text("day")
                .font(.system(size: 8))
                .foregroundStyle(.secondary)
        }
    }

    private var cornerView: some View {
        Text("\(streak)")
            .font(.title2.bold())
            .widgetLabel("\(streak) day streak")
    }

    private var inlineView: some View {
        Label {
            Text(streak == 1 ? "1 day streak" : "\(streak) day streak")
        } icon: {
            Image(systemName: "flame.fill")
        }
    }

    private var rectangularView: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                Text(streak == 1 ? "1 day streak" : "\(streak) day streak")
                    .font(.headline)
            }
            if let name = entry.stats?.lastWorkoutName {
                Text("Last: \(name)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Text("Tap to open Anvil")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let total = entry.stats?.totalWorkouts {
                Text("\(total) total workouts")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct AnvilWatchWidget: Widget {
    let kind: String = "AnvilWatchWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: StatsProvider()) { entry in
            AnvilWatchWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Anvil Streak")
        .description("Your current workout streak at a glance.")
        .supportedFamilies([
            .accessoryCircular,
            .accessoryCorner,
            .accessoryInline,
            .accessoryRectangular
        ])
    }
}
