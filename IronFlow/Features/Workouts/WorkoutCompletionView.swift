//
//  WorkoutCompletionView.swift
//  IronFlow
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct WorkoutCompletionView: View {
    var session: WorkoutSession
    var onDone: () -> Void

    private var durationText: String {
        let m = session.durationSeconds / 60
        let s = session.durationSeconds % 60
        if s > 0 { return "\(m)m \(s)s" }
        return "\(m) min"
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(.green)
            Text("Træning afsluttet")
                .font(.title.bold())
            VStack(spacing: 8) {
                Label(session.templateName, systemImage: "list.bullet")
                Label(durationText, systemImage: "timer")
                Label("\(session.completedSetCount) sæt", systemImage: "checkmark.circle")
                Label("\(session.exerciseCount) øvelser", systemImage: "figure.strengthtraining.traditional")
            }
            .font(.body)
            .foregroundStyle(.secondary)
            Spacer()
            Button("Færdig") {
                onDone()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }
}
