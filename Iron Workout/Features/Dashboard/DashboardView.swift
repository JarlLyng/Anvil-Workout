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
    
    @State private var templateToStart: WorkoutTemplate?
    @State private var activeSession: WorkoutSession?

    private var morningGreeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<5: return "God nat"
        case 5..<10: return "Godmorgen"
        case 10..<18: return "Goddag"
        default: return "Godaften"
        }
    }
    
    private var thisWeekSessions: Int {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        return sessions.filter { $0.startedAt >= startOfWeek && $0.completedSetCount > 0 }.count
    }
    
    private var lastWorkoutText: String {
        guard let last = sessions.first(where: { $0.completedSetCount > 0 }) else { return "Ingen historie endnu" }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .named
        formatter.locale = Locale(identifier: "da_DK")
        let relativeDate = formatter.localizedString(for: last.startedAt, relativeTo: .now)
        return "Sidst: \(last.templateName) (\(relativeDate))"
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
                    quickStartSection
                }
                .padding()
            }
            .navigationTitle("Iron Workout")
            .background(Color(uiColor: .systemGroupedBackground))
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
                Text("Klar til dagens træning?")
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
        HStack(spacing: DesignTokens.Spacing.lg) {
            dashboardCard(
                title: "Pas i denne uge",
                value: "\(thisWeekSessions)",
                icon: Ph.calendarCheck.fill
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(DesignTokens.ColorToken.State.success)
            )
            
            dashboardCard(
                title: "Totale Pæs",
                value: "\(sessions.filter({ $0.completedSetCount > 0 }).count)",
                icon: Ph.trophy.fill
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .foregroundStyle(DesignTokens.ColorToken.State.warning)
            )
        }
    }
    
    private func dashboardCard<Icon: View>(title: String, value: String, icon: Icon) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack {
                icon
                Spacer()
            }
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(value)
                    .font(.title2.bold())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(DesignTokens.Spacing.lg)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
    }
    
    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text("Anbefalet til dig")
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
                    Text("Opret dit første træningsprogram under fanen Træning for at se anbefalinger her.")
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
