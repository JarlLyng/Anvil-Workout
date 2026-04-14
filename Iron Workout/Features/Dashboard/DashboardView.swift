//
//  DashboardView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    
    @AppStorage("weeklyPlan") private var weeklyPlanJSON: String = "{}"
    @State private var showPlanEditor = false
    @State private var templateToStart: WorkoutTemplate?
    @State private var activeSession: WorkoutSession?

    private var weeklyPlan: [Int: String] {
        (try? JSONDecoder().decode([String: String].self, from: Data(weeklyPlanJSON.utf8)))?.reduce(into: [Int: String]()) { result, pair in
            if let key = Int(pair.key) { result[key] = pair.value }
        } ?? [:]
    }

    private func saveWeeklyPlan(_ plan: [Int: String]) {
        let stringKeyed = plan.reduce(into: [String: String]()) { $0["\($1.key)"] = $1.value }
        if let data = try? JSONEncoder().encode(stringKeyed) {
            weeklyPlanJSON = String(data: data, encoding: .utf8) ?? "{}"
        }
    }

    private var morningGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<5: return "Good night"
        case 5..<10: return "Good morning"
        case 10..<18: return "Good afternoon"
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
        let calendar = Calendar.current
        let completedSessions = sessions.filter { $0.completedSetCount > 0 }

        var streak = 0
        var checkDate = Date.now

        // If no session today, start checking from yesterday
        let todayStart = calendar.startOfDay(for: checkDate)
        let hasTodaySession = completedSessions.contains { calendar.isDate($0.startedAt, inSameDayAs: todayStart) }
        if !hasTodaySession {
            checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
        }

        while true {
            let dayStart = calendar.startOfDay(for: checkDate)
            let hasSession = completedSessions.contains { calendar.isDate($0.startedAt, inSameDayAs: dayStart) }
            if hasSession {
                streak += 1
                checkDate = calendar.date(byAdding: .day, value: -1, to: checkDate) ?? checkDate
            } else {
                break
            }
        }

        return streak
    }
    
    private var lastWorkoutText: String {
        guard let last = sessions.first(where: { $0.completedSetCount > 0 }) else { return "No history yet" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        let relativeDate = formatter.localizedString(for: last.startedAt, relativeTo: .now)
        return "Last: \(last.templateName) (\(relativeDate))"
    }

    private var recommendedTemplate: WorkoutTemplate? {
        // Find the last completed session
        guard let lastSession = sessions.first(where: { $0.completedSetCount > 0 }) else {
            return templates.first
        }
        
        // Find rotation index (simplified): we find the last used template index in the list, and recommend the next one.
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
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(uiColor: .systemGroupedBackground))
            .sheet(isPresented: $showPlanEditor) {
                WeeklyPlanEditorSheet(plan: weeklyPlan) { newPlan in
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
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(DesignTokens.ColorToken.State.success)
                )

                DashboardCard(
                    title: "Last Week",
                    value: "\(lastWeekSessions)",
                    icon: Ph.clockCounterClockwise.regular
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(.secondary)
                )
            }

            HStack(spacing: DesignTokens.Spacing.lg) {
                DashboardCard(
                    title: "Streak",
                    value: "\(currentStreak) days",
                    icon: Ph.flame.fill
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(DesignTokens.ColorToken.State.error)
                )

                DashboardCard(
                    title: "Total",
                    value: "\(sessions.filter({ $0.completedSetCount > 0 }).count)",
                    icon: Ph.trophy.fill
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                        .foregroundStyle(DesignTokens.ColorToken.State.warning)
                )
            }
        }
    }
    
    private var weeklyPlanSection: some View {
        WeeklyPlanRow(weeklyPlan: weeklyPlan) {
            showPlanEditor = true
        }
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Recommended for You")
                .font(.title2.bold())
            
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                if let rec = recommendedTemplate {
                    HStack {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(rec.name)
                                .font(.headline)
                            Text(lastWorkoutText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    
                    Button {
                        startSession(from: rec)
                    } label: {
                        HStack {
                            Spacer()
                            Text("Start Workout")
                                .font(.headline)
                            Ph.playCircle.fill.aspectRatio(contentMode: .fit).frame(width: 20, height: 20)
                            Spacer()
                        }
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .accessibilityLabel("Start \(rec.name)")
                } else {
                    Text("Create your first workout program in the Workouts tab to see recommendations here.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(DesignTokens.Spacing.lg)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        }
    }
    
    private func startSession(from template: WorkoutTemplate) {
        do {
            let s = try WorkoutSessionService.createSession(from: template, modelContext: modelContext)
            activeSession = s
        } catch {
            print("Error starting session: \(error)")
        }
    }
}

#Preview {
    DashboardView()
        .modelContainer(for: [WorkoutSession.self, WorkoutTemplate.self], inMemory: true)
}
