//
//  SettingsView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import HealthKit
import IAMJARLDesignTokens
import PhosphorSwift

struct SettingsView: View {
    private let health = HealthKitService.shared
    @State private var requestInProgress = false
    @State private var message: String?
    @State private var messageIsError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if health.isAvailable {
                        HStack {
                            Ph.heart.fill
                                .color(DesignTokens.ColorToken.State.error)
                                .frame(width: 20, height: 20)
                            Text("Apple Health")
                            Spacer()
                            if requestInProgress {
                                ProgressView()
                                    .scaleEffect(0.9)
                            } else {
                                Button("Tillad adgang") {
                                    requestHealthAccess()
                                }
                            }
                        }
                        if let msg = message {
                            HStack(spacing: 8) {
                                Group {
                                    if messageIsError {
                                        Ph.warningCircle.regular
                                            .color(DesignTokens.ColorToken.State.error)
                                    } else {
                                        Ph.checkCircle.regular
                                            .color(DesignTokens.ColorToken.State.success)
                                    }
                                }
                                .frame(width: 20, height: 20)
                                Text(msg)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        Label { Text("Health er ikke tilgængelig på denne enhed") } icon: { Ph.heartBreak.regular }
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Health")
                } footer: {
                    Text("Iron Workout gemmer træninger i Health og kan vise kalorieforbrug og puls, når du bruger Apple Watch eller andre kilder under træning.")
                }
            }
            .navigationTitle("Indstillinger")
        }
    }

    private func requestHealthAccess() {
        requestInProgress = true
        message = nil
        Task {
            do {
                try await health.requestAuthorization()
                await MainActor.run {
                    message = "Tilladelse anmodet. Åbn Health-appen for at godkende læs og skriv af træningsdata."
                    messageIsError = false
                    requestInProgress = false
                }
            } catch {
                await MainActor.run {
                    message = "Kunne ikke anmode om tilladelse. Tjek at Health er tilgængelig."
                    messageIsError = true
                    requestInProgress = false
                }
            }
        }
    }
}
