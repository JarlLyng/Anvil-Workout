//
//  WorkoutCompletionView.swift
//  IronFlow
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens

struct WorkoutCompletionView: View {
    @Environment(\.colorScheme) private var colorScheme
    var session: WorkoutSession
    var onDone: () -> Void

    private var durationText: String {
        let m = session.durationSeconds / 60
        let s = session.durationSeconds % 60
        if s > 0 { return "\(m)m \(s)s" }
        return "\(m) min"
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.xxl) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(DesignTokens.ColorToken.State.success)
            Text("Træning afsluttet")
                .font(.title.bold())
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
            VStack(spacing: DesignTokens.Spacing.sm) {
                Label(session.templateName, systemImage: "list.bullet")
                Label(durationText, systemImage: "timer")
                Label("\(session.completedSetCount) sæt", systemImage: "checkmark.circle")
                Label("\(session.exerciseCount) øvelser", systemImage: "figure.strengthtraining.traditional")
            }
            .font(.body)
            .foregroundStyle(DesignTokens.Common.Text.secondary(colorScheme))
            Spacer()
            Button("Færdig") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, DesignTokens.Spacing.xxxl)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .background(DesignTokens.Common.Background.app(colorScheme))
    }
}
