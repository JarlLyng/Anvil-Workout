//
//  DashboardView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import Sentry
import IAMJARLDesignTokens
import PhosphorSwift

struct DashboardView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    
    @AppStorage("weeklyPlan") private var weeklyPlanJSON: String = "{}"
    @State private var showPlanEditor = false
    @State private var templateToStart: WorkoutTemplate?
    @State private var activeSession: WorkoutSession?

    /// Raw plan entries keyed by weekday index (Mon=0 ... Sun=6). Each string is either
    /// a template UUID (current format) or a legacy template name (v1.1.x and earlier).
    /// Reads the v1.1+ array format and the legacy v1.0.x single-string format.
    private var weeklyPlanRaw: [Int: [String]] {
        let data = Data(weeklyPlanJSON.utf8)

        if let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            return decoded.reduce(into: [Int: [String]]()) { result, pair in
                if let key = Int(pair.key), !pair.value.isEmpty { result[key] = pair.value }
            }
        }

        if let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            return decoded.reduce(into: [Int: [String]]()) { result, pair in
                if let key = Int(pair.key), !pair.value.isEmpty { result[key] = [pair.value] }
            }
        }

        return [:]
    }

    /// Plan resolved to actual templates. A plan entry matches by UUID first, then falls
    /// back to case-insensitive trimmed name — this tolerates templates that were renamed
    /// or imported with slight variations after being added to the plan.
    private var weeklyPlanResolved: [Int: [WorkoutTemplate]] {
        let raw = weeklyPlanRaw
        guard !raw.isEmpty else { return [:] }

        let byID = Dictionary(uniqueKeysWithValues: templates.map { ($0.id.uuidString, $0) })
        let byNameNormalized = Dictionary(
            templates.map { ($0.name.normalizedForPlanLookup, $0) },
            uniquingKeysWith: { first, _ in first }
        )

        func resolve(_ s: String) -> WorkoutTemplate? {
            if let t = byID[s] { return t }
            return byNameNormalized[s.normalizedForPlanLookup]
        }

        return raw.reduce(into: [Int: [WorkoutTemplate]]()) { result, pair in
            let resolved = pair.value.compactMap(resolve)
            if !resolved.isEmpty { result[pair.key] = resolved }
        }
    }

    private func saveWeeklyPlan(_ plan: [Int: [String]]) {
        let stringKeyed = plan.reduce(into: [String: [String]]()) { $0["\($1.key)"] = $1.value }
        if let data = try? JSONEncoder().encode(stringKeyed) {
            weeklyPlanJSON = String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    /// Rewrites the stored plan using current template IDs. Called after reads that
    /// required legacy name-based fallback, so subsequent reads are O(1) and survive renames.
    private func migrateWeeklyPlanToIDsIfNeeded() {
        let raw = weeklyPlanRaw
        guard !raw.isEmpty else { return }

        let resolved = weeklyPlanResolved
        let migrated = resolved.reduce(into: [Int: [String]]()) { result, pair in
            result[pair.key] = pair.value.map { $0.id.uuidString }
        }

        // Only save if the migrated form differs from what's stored (avoids write churn).
        if migrated != raw {
            saveWeeklyPlan(migrated)
        }
    }

    /// Templates planned for today, preserving user-defined order.
    private var todaysPlannedPrograms: [WorkoutTemplate] {
        let calendar = Calendar.current
        let todayWeekday = calendar.component(.weekday, from: .now)
        let todayIndex = (todayWeekday + 5) % 7  // Mon=0, Tue=1, ..., Sun=6
        return weeklyPlanResolved[todayIndex] ?? []
    }

    private var morningGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<5: return "Good night"
        case 5..<12: return "Good morning"
        case 12..<18: return "Good afternoon"
        default: return "Good evening"
        }
    }
    
    private var thisWeekSessions: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return sessions.filter { $0.startedAt >= startOfWeek && $0.completedSetCount > 0 }.count
    }

    private var lastWeekSessions: Int {
        let calendar = Calendar.current
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
        return sessions.filter { $0.startedAt >= lastWeekStart && $0.startedAt < thisWeekStart && $0.completedSetCount > 0 }.count
    }

    private var currentStreak: Int {
        StreakCalculator.currentStreak(from: sessions)
    }
    
    private var lastWorkoutText: String {
        guard let last = sessions.first(where: { $0.completedSetCount > 0 }) else { return "No history yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        let relativeDate = formatter.localizedString(for: last.startedAt, relativeTo: .now)
        return "Last: \(last.templateName) (\(relativeDate))"
    }

    /// Fallback recommendation when the user has no programs planned for today.
    /// Rotates through templates based on the last completed session.
    private var fallbackRecommendation: WorkoutTemplate? {
        guard let lastSession = sessions.first(where: { $0.completedSetCount > 0 }) else {
            return templates.first
        }
        if let idx = templates.firstIndex(where: { $0.name == lastSession.templateName }) {
            let nextIdx = (idx + 1) % templates.count
            return templates[nextIdx]
        }
        return templates.first
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.xxl) {
                    greetingSection
                    metricsSection
                    weeklyPlanSection
                    quickStartSection
                    recentWorkoutsSection
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .systemGroupedBackground))
            .onAppear { migrateWeeklyPlanToIDsIfNeeded() }
            .sheet(isPresented: $showPlanEditor) {
                WeeklyPlanEditorSheet(plan: weeklyPlanRaw) { newPlan in
                    saveWeeklyPlan(newPlan)
                }
            }
            .fullScreenCover(item: $activeSession) { session in
                ActiveWorkoutView(session: session) {
                    // completion inside ActiveWorkoutView handles save
                } onEndWorkout: {
                    activeSession = nil
                }
            }
            .navigationDestination(for: DashboardDestination.self) { destination in
                switch destination {
                case .history:
                    HistoryView()
                }
            }
            .navigationDestination(for: WorkoutSession.self) { session in
                SessionDetailView(session: session)
            }
        }
    }
    
    private var greetingSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(morningGreeting)
                    .font(.largeTitle.bold())
                Text("Ready for today's workout?")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Ph.userCircle.fill
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .foregroundStyle(Color.primary.opacity(0.8))
                .accessibilityHidden(true)
        }
        .padding(.top, DesignTokens.Spacing.lg)
    }

    private var metricsSection: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            HStack(spacing: DesignTokens.Spacing.lg) {
                DashboardCard(
                    title: "This Week",
                    value: "\(thisWeekSessions)",
                    icon: Ph.calendarCheck.fill
                        .icon(size: 24)
                        .foregroundStyle(DesignTokens.ColorToken.State.success)
                )

                DashboardCard(
                    title: "Last Week",
                    value: "\(lastWeekSessions)",
                    icon: Ph.clockCounterClockwise.regular
                        .icon(size: 24)
                        .foregroundStyle(.secondary)
                )
            }

            HStack(spacing: DesignTokens.Spacing.lg) {
                DashboardCard(
                    title: "Streak",
                    value: "\(currentStreak) days",
                    icon: Ph.flame.fill
                        .icon(size: 24)
                        .foregroundStyle(DesignTokens.ColorToken.State.error)
                )

                DashboardCard(
                    title: "Total",
                    value: "\(sessions.filter({ $0.completedSetCount > 0 }).count)",
                    icon: Ph.trophy.fill
                        .icon(size: 24)
                        .foregroundStyle(DesignTokens.ColorToken.State.warning)
                )
            }
        }
    }
    
    private var weeklyPlanSection: some View {
        WeeklyPlanRow(weeklyPlan: weeklyPlanResolved) {
            showPlanEditor = true
        }
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            let planned = todaysPlannedPrograms
            Text(planned.isEmpty ? "Recommended for You" : "Today's Workouts")
                .font(.title2.bold())

            if !planned.isEmpty {
                ForEach(planned, id: \.id) { template in
                    plannedWorkoutCard(template)
                }
            } else if let rec = fallbackRecommendation {
                recommendedCard(rec)
            } else {
                Text("Create your first workout program in the Workouts tab to see recommendations here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(DesignTokens.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            }
        }
    }

    private func plannedWorkoutCard(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(template.name)
                        .font(.headline)
                    Text("\(template.exercises.count) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                startSession(from: template)
            } label: {
                HStack {
                    Spacer()
                    Text("Start Workout")
                        .font(.headline)
                    Ph.playCircle.fill.icon()
                    Spacer()
                }
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
            .accessibilityLabel("Start \(template.name)")
        }
        .padding(DesignTokens.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }

    private var recentWorkoutsSection: some View {
        let recent = Array(sessions.lazy.filter { $0.completedSetCount > 0 }.prefix(3))

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                Text("Recent Workouts")
                    .font(.title2.bold())
                Spacer()
                if !recent.isEmpty {
                    NavigationLink(value: DashboardDestination.history) {
                        HStack(spacing: 2) {
                            Text("View All")
                            Ph.caretRight.regular.icon(size: 14)
                        }
                        .font(.subheadline)
                    }
                }
            }

            if recent.isEmpty {
                Text("Your completed workouts will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(DesignTokens.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            } else {
                VStack(spacing: DesignTokens.Spacing.sm) {
                    ForEach(recent) { session in
                        NavigationLink(value: session) {
                            recentWorkoutRow(session)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func recentWorkoutRow(_ session: WorkoutSession) -> some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            Ph.checkCircle.fill
                .icon(size: 22)
                .foregroundStyle(DesignTokens.ColorToken.State.success)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.templateName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("\(session.completedSetCount) sets · \(relativeDateLabel(session.startedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Ph.caretRight.regular
                .icon(size: 14)
                .foregroundStyle(.secondary)
        }
        .padding(DesignTokens.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(session.templateName), \(session.completedSetCount) sets, \(relativeDateLabel(session.startedAt))")
    }

    private func relativeDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(date: .abbreviated, time: .omitted)
    }

    private func recommendedCard(_ template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(template.name)
                        .font(.headline)
                    Text(lastWorkoutText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                startSession(from: template)
            } label: {
                HStack {
                    Spacer()
                    Text("Start Workout")
                        .font(.headline)
                    Ph.playCircle.fill.icon()
                    Spacer()
                }
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
            .accessibilityLabel("Start \(template.name)")
        }
        .padding(DesignTokens.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
    
    private func startSession(from template: WorkoutTemplate) {
        do {
            let s = try WorkoutSessionService.createSession(from: template, modelContext: modelContext)
            activeSession = s
        } catch {
            SentrySDK.capture(error: error)
        }
    }
}

private enum DashboardDestination: Hashable {
    case history
}

private extension String {
    /// Lower-cased, whitespace-trimmed form used to match legacy name-based weekly-plan
    /// entries against current template names. Tolerates case and trailing whitespace drift.
    var normalizedForPlanLookup: String {
        trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [WorkoutSession.self, WorkoutTemplate.self], inMemory: true)
}
