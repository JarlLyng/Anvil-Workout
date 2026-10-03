//
//  WorkoutCompletionView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//
//  Straight after a workout: what it added up to and how that compares with the last time,
//  any records, and each exercise in one line. Done is the one thing to press.
//

import SwiftUI
import SwiftData
import StoreKit
import IAMJARLDesignTokens
import PhosphorSwift

struct WorkoutCompletionView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var allSessions: [WorkoutSession]
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var session: WorkoutSession
    var onDone: () -> Void

    // Worked out once when the screen appears; the history does not change under it.
    @State private var records: [DetectedPersonalRecord] = []
    @State private var previous: WorkoutSession?

    private var sortedExercises: [WorkoutSessionExercise] {
        session.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                header
                SessionNumbersCard(session: session, previous: previous, unit: weightUnit)
                if !records.isEmpty {
                    SessionRecordsCard(records: records)
                }
                SessionExercisesCard(exercises: sortedExercises, unit: weightUnit)
            }
            .padding()
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .safeAreaInset(edge: .bottom, spacing: 0) { actions }
        .onAppear(perform: summarize)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Label {
                Text("Workout done")
            } icon: {
                Ph.checkCircle.fill.icon(size: 18)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(DesignTokens.ColorToken.State.success)
            Text(session.templateName)
                .font(.title.bold())
                .accessibilityAddTraits(.isHeader)
            Text(session.startedAt.formatted(.dateTime.weekday(.wide).day().month(.wide).hour().minute()))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.top, DesignTokens.Spacing.lg)
    }

    private var actions: some View {
        HStack(spacing: DesignTokens.Spacing.md) {
            ShareLink(item: shareText) {
                Label { Text("Share") } icon: { Ph.shareFat.regular.icon(size: 18) }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .fixedSize()

            Button {
                onDone()
            } label: {
                Text("Done")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
            .controlSize(.large)
        }
        .padding(.horizontal)
        .padding(.top, DesignTokens.Spacing.sm)
        .padding(.bottom, DesignTokens.Spacing.md)
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
        .background(Color(uiColor: .systemGroupedBackground))
    }

    /// The workout as text: name, the summary line, each exercise and any records.
    private var shareText: String {
        var lines = ["Anvil Workout: \(session.templateName)", TrainingSummary.detailLine(of: session, unit: weightUnit), ""]
        for exercise in sortedExercises {
            if let summary = TrainingSummary.setsSummary(TrainingSummary.workSets(of: exercise), unit: weightUnit) {
                lines.append("\(exercise.exerciseName): \(summary)")
            }
        }
        if !records.isEmpty {
            lines.append("")
            lines.append(records.count == 1 ? "New record:" : "New records:")
            lines += records.map { "\($0.exerciseName): \($0.value)" }
        }
        return lines.joined(separator: "\n")
    }

    private func summarize() {
        let history = allSessions.filter { $0.id != session.id && $0.completedSetCount > 0 }
        records = PersonalRecordService.onePerExercise(
            PersonalRecordService.detectPersonalRecords(in: session, history: history, unit: weightUnit)
        )
        .filter { !$0.isFirstTime }
        previous = TrainingSummary.previousSession(of: session, in: allSessions)

        if !records.isEmpty {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        // Ask for a review after the 5th, 15th and 50th completed workout.
        let completedCount = allSessions.filter { $0.completedSetCount > 0 }.count
        if completedCount == 5 || completedCount == 15 || completedCount == 50 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                requestReview()
            }
        }
    }
}
