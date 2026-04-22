//
//  WorkoutCompletionView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
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
    @State private var showShareSheet = false
    var session: WorkoutSession
    var onDone: () -> Void

    private var durationText: String {
        let m = session.durationSeconds / 60
        let s = session.durationSeconds % 60
        if s > 0 { return "\(m)m \(s)s" }
        return "\(m) min"
    }

    private var personalRecords: [DetectedPersonalRecord] {
        PersonalRecordService.detectPersonalRecords(in: session, history: allSessions)
    }

    private var shareText: String {
        var text = "Iron Workout — \(session.templateName)\n\n"
        text += "Time: \(durationText)\n"
        text += "Sets: \(session.completedSetCount)\n"
        text += "Exercises: \(session.exerciseCount)"

        if !personalRecords.isEmpty {
            text += "\n\nNew PRs:"
            for record in personalRecords {
                text += "\n- \(record.exerciseName): \(record.value)"
            }
        }

        return text
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()
            Ph.checkCircle.fill
                .icon(size: 70)
                .foregroundStyle(DesignTokens.ColorToken.State.success)
            Text("Workout Complete")
                .font(.title.bold())
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
            VStack(spacing: DesignTokens.Spacing.sm) {
                Label { Text(session.templateName) } icon: { Ph.listBullets.regular.icon() }
                Label { Text(durationText) } icon: { Ph.timer.regular.icon() }
                Label { Text("\(session.completedSetCount) sets") } icon: { Ph.checkCircle.regular.icon() }
                Label { Text("\(session.exerciseCount) exercises") } icon: { Ph.barbell.regular.icon() }
            }
            .font(.body)
            .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))

            if !personalRecords.isEmpty {
                VStack(spacing: DesignTokens.Spacing.md) {
                    Ph.trophy.fill
                        .icon(size: 40)
                        .foregroundStyle(DesignTokens.ColorToken.State.warning)
                    Text("New Personal Records!")
                        .font(.headline)
                        .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
                    ForEach(personalRecords) { record in
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                            Text(record.exerciseName)
                                .font(.headline)
                                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
                            Text("New: \(record.value)")
                                .font(.subheadline)
                                .foregroundStyle(DesignTokens.ColorToken.State.success)
                            Text("Previous: \(record.previousBest)")
                                .font(.subheadline)
                                .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(DesignTokens.Spacing.md)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.lg)
            }

            Spacer()
            HStack(spacing: DesignTokens.Spacing.md) {
                ShareLink(item: shareText) {
                    Label {
                        Text("Share")
                    } icon: {
                        Ph.shareFat.regular
                            .icon()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)

                Button("Done") {
                    onDone()
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                .controlSize(.large)
            }
            .padding(.horizontal, DesignTokens.Spacing.xxxl)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Common.Background.app(colorScheme))
        .onAppear {
            if !personalRecords.isEmpty {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
            // Ask for review after 5th completed workout
            let completedCount = allSessions.filter { $0.completedSetCount > 0 }.count
            if completedCount == 5 || completedCount == 15 || completedCount == 50 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    requestReview()
                }
            }
        }
    }
}

