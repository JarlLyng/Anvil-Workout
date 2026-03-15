//
//  WorkoutCompletionView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

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
            Ph.checkCircle.fill
                .color(DesignTokens.ColorToken.State.success)
                .frame(width: 70, height: 70)
            Text("Træning afsluttet")
                .font(.title.bold())
                .foregroundStyle(DesignTokens.Common.Text.primary(colorScheme))
            VStack(spacing: DesignTokens.Spacing.sm) {
                Label { Text(session.templateName) } icon: { Ph.listBullets.regular }
                Label { Text(durationText) } icon: { Ph.timer.regular }
                Label { Text("\(session.completedSetCount) sæt") } icon: { Ph.checkCircle.regular }
                Label { Text("\(session.exerciseCount) øvelser") } icon: { Ph.barbell.regular }
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
