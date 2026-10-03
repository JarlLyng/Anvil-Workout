//
//  SessionDetailView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//
//  A past workout: the same summary and records as the completion screen, then every set.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

struct SessionDetailView: View {
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var session: WorkoutSession

    @State private var records: [DetectedPersonalRecord] = []
    @State private var previous: WorkoutSession?

    private var sortedExercises: [WorkoutSessionExercise] {
        session.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(session.templateName)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    Text(session.startedAt.formatted(.dateTime.weekday(.wide).day().month(.wide).year().hour().minute()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                SessionNumbersCard(session: session, previous: previous, unit: weightUnit)
                if !records.isEmpty {
                    SessionRecordsCard(records: records)
                }
                ForEach(sortedExercises, id: \.id) { exercise in
                    SessionExerciseDetailCard(exercise: exercise, unit: weightUnit)
                }
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle(session.startedAt.formatted(.dateTime.day().month(.abbreviated)))
        .navigationBarTitleDisplayMode(.inline)
        .task(id: sessions.count) { summarize() }
    }

    /// Records against the workouts before this one, not the ones that came after.
    private func summarize() {
        let earlier = sessions.filter { $0.completedSetCount > 0 && $0.startedAt < session.startedAt }
        records = PersonalRecordService.onePerExercise(
            PersonalRecordService.detectPersonalRecords(in: session, history: earlier, unit: weightUnit)
        )
        .filter { !$0.isFirstTime }
        previous = TrainingSummary.previousSession(of: session, in: sessions)
    }
}
