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
    
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @AppStorage("weeklyPlan") private var weeklyPlanJSON: String = "{}"
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @State private var showPlanEditor = false
    @State private var activeSession: WorkoutSession?
    @State private var showProgramLibrary = false
    @State private var showImporter = false
    #if DEBUG
    /// `-AnvilDemoCompletion` opens the completion screen for the latest full workout, to
    /// check and screenshot it against the demo history without training first.
    @State private var demoCompletion: WorkoutSession?
    #endif
    @State private var templateToCreate: WorkoutTemplate?
    @State private var errorMessage: String?

    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

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

    private var completedSessions: [WorkoutSession] {
        sessions.filter { $0.completedSetCount > 0 }
    }

    private var lastWeekWorkouts: Int {
        let calendar = Calendar.current
        let thisWeekStart = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: thisWeekStart) ?? thisWeekStart
        return completedSessions.filter { $0.startedAt >= lastWeekStart && $0.startedAt < thisWeekStart }.count
    }

    /// Fallback recommendation when the user has no programs planned for today: the
    /// program after the last one trained, in the order programs were added.
    private var fallbackRecommendation: WorkoutTemplate? {
        ProgramRotation.next(after: completedSessions.first?.templateName, in: templates)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xxl) {
                    Text(Date.now.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, DesignTokens.Spacing.xs)
                        .padding(.top, DesignTokens.Spacing.sm)

                    upNextSection
                    // Nothing to show a new lifter yet: no workouts and no plan.
                    if !completedSessions.isEmpty || !weeklyPlanResolved.isEmpty {
                        thisWeekSection
                    }
                    recentSection
                }
                .padding()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            // No title on a tab root, so nothing covers the status bar: an empty inset with
            // the screen's own background keeps content from scrolling under the clock.
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear.frame(height: 0).background(Color(uiColor: .systemGroupedBackground))
            }
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { migrateWeeklyPlanToIDsIfNeeded() }
            .sheet(isPresented: $showPlanEditor) {
                WeeklyPlanEditorSheet(plan: weeklyPlanRaw) { newPlan in
                    saveWeeklyPlan(newPlan)
                }
            }
            .sheet(isPresented: $showProgramLibrary) {
                ProgramLibraryView { _ in showProgramLibrary = false }
            }
            .workoutImport(isPresented: $showImporter)
            #if DEBUG
            .fullScreenCover(item: $demoCompletion) { session in
                WorkoutCompletionView(session: session) { demoCompletion = nil }
            }
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-AnvilDemoCompletion") else { return }
                demoCompletion = completedSessions.first { TrainingSummary.workSetCount(of: $0) > 5 }
            }
            #endif
            .sheet(item: $templateToCreate) { template in
                NavigationStack {
                    CreateEditTemplateView(template: template)
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
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Up next

    @ViewBuilder
    private var upNextSection: some View {
        let planned = todaysPlannedPrograms
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            if templates.isEmpty {
                DashboardSectionLabel(title: "Get started")
                StartHereCard(onLibrary: { showProgramLibrary = true }, onCreate: createTemplate, onImport: { showImporter = true })
            } else if let first = planned.first {
                DashboardSectionLabel(title: planned.count > 1 ? "Today" : "Up next")
                upNextCard(first, context: contextLine(for: first, planned: true))
                ForEach(planned.dropFirst(), id: \.id) { template in
                    alsoTodayRow(template)
                }
            } else if let rec = fallbackRecommendation {
                DashboardSectionLabel(title: "Up next")
                upNextCard(rec, context: contextLine(for: rec, planned: false))
            }
        }
    }

    private func upNextCard(_ template: WorkoutTemplate, context: String) -> some View {
        UpNextCard(
            title: template.name,
            context: context,
            lines: planLines(for: template),
            onStart: { startSession(from: template) }
        )
    }

    /// A second program planned for the same day: one line with its own Start.
    private func alsoTodayRow(_ template: WorkoutTemplate) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(template.name).font(.subheadline.weight(.semibold))
                Text("\(template.exercises.count) exercises").font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Button("Start") { startSession(from: template) }
                .buttonStyle(.bordered)
                .accessibilityLabel("Start \(template.name)")
        }
        .padding(DesignTokens.Spacing.lg)
        .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }

    /// "Planned for today · last done 3 days ago"; for the fallback, when it was last done,
    /// "Not done yet", or "Your first workout" before any.
    private func contextLine(for template: WorkoutTemplate, planned: Bool) -> String {
        let last = completedSessions.first { $0.templateName == template.name }
            .map { "last done \(daysAgoText($0.startedAt))" }
        if planned {
            return ["Planned for today", last].compactMap { $0 }.joined(separator: " \u{00B7} ")
        }
        return last.map { $0.prefix(1).uppercased() + $0.dropFirst() }
            ?? (completedSessions.isEmpty ? "Your first workout" : "Not done yet")
    }

    /// "today", "yesterday", "3 days ago", then a date.
    private func daysAgoText(_ date: Date) -> String {
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: .now)).day ?? 0
        switch days {
        case ..<1: return "today"
        case 1: return "yesterday"
        case 2...13: return "\(days) days ago"
        default: return "on \(date.formatted(.dateTime.day().month(.abbreviated)))"
        }
    }

    /// Each exercise with its plan, "5 × 5 · 40 kg", in program order.
    private func planLines(for template: WorkoutTemplate) -> [(name: String, plan: String)] {
        let names = Dictionary(allExercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        return template.exercises
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { item in
                let weight = item.targetWeight.map { " \u{00B7} \(WeightFormatter.compact(kg: $0, in: weightUnit))" } ?? ""
                return (names[item.exerciseID] ?? "Exercise", "\(item.targetSets) \u{00D7} \(item.targetReps)\(weight)")
            }
    }

    // MARK: - This week

    private var thisWeekSection: some View {
        let week = TrainingSummary.week(containing: .now, sessions: sessions)
        let planned = weeklyPlanResolved.mapValues { $0.map(\.name) }
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            DashboardSectionLabel(title: "This week") {
                Button("Edit Plan") { showPlanEditor = true }
                    .font(.subheadline)
                    .accessibilityLabel("Edit weekly plan")
            }
            WeekCard(
                week: week,
                lastWeekWorkouts: lastWeekWorkouts,
                streak: StreakCalculator.currentStreak(from: sessions),
                volumeText: WeightFormatter.volume(kg: week.volumeKg, in: weightUnit),
                planned: planned,
                onEditPlan: { showPlanEditor = true }
            )
        }
    }

    // MARK: - Recent

    @ViewBuilder
    private var recentSection: some View {
        let recent = Array(completedSessions.prefix(3))
        if !recent.isEmpty {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                DashboardSectionLabel(title: "Recent") {
                    NavigationLink(value: DashboardDestination.history) {
                        HStack(spacing: 2) {
                            Text("History")
                            Ph.caretRight.regular.icon(size: 12)
                        }
                        .font(.subheadline)
                    }
                }
                ForEach(recent) { session in
                    NavigationLink(value: session) {
                        RecentWorkoutRow(
                            name: session.templateName,
                            dateLabel: relativeDateLabel(session.startedAt),
                            detail: TrainingSummary.detailLine(of: session, unit: weightUnit)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func relativeDateLabel(_ date: Date) -> String {
        let cal = Calendar.current
        if cal.isDateInToday(date) { return "Today" }
        if cal.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.day().month(.abbreviated))
    }

    private func createTemplate() {
        let newTemplate = WorkoutTemplate(name: "New Program")
        modelContext.insert(newTemplate)
        do {
            try modelContext.save()
            templateToCreate = newTemplate
        } catch {
            PersistenceLogger.capture(error, operation: "create-template")
            modelContext.delete(newTemplate)
            errorMessage = PersistenceLogger.userMessage(prefix: "Could not create program", error: error)
        }
    }

    private func startSession(from template: WorkoutTemplate) {
        do {
            let s = try WorkoutSessionService.createSession(from: template, modelContext: modelContext)
            activeSession = s
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not start the workout: \(error.localizedDescription)"
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
