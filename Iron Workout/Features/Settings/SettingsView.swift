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
    @AppStorage("weightUnit") private var weightUnit: String = "kg"
    @State private var requestInProgress = false
    @State private var message: String?
    @State private var messageIsError = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Ph.scales.regular
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.secondary)
                        Picker("Vægtenhed", selection: $weightUnit) {
                            Text("kg").tag("kg")
                            Text("lbs").tag("lbs")
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("Enheder")
                }

                Section {
                    HStack {
                        Ph.info.regular
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.secondary)
                        Text("Iron Workout")
                        Spacer()
                        Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Ph.code.regular
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.secondary)
                        Text("Udviklet af Jarl Lyng")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Om")
                }

                Section {
                    if health.isAvailable {
                        HStack {
                            Ph.heart.fill
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                                .foregroundStyle(DesignTokens.ColorToken.State.error)
                            Text("Apple Health")
                            Spacer()
                            if requestInProgress {
                                ProgressView()
                                    .scaleEffect(0.9)
                            } else {
                                Button("Tillad adgang") {
                                    requestHealthAccess()
                                }
                                .accessibilityHint("Anmoder om tilladelse til at læse og skrive sundhedsdata")
                            }
                        }
                        if let msg = message {
                            HStack(spacing: 8) {
                                Group {
                                    if messageIsError {
                                        Ph.warningCircle.regular
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .foregroundStyle(DesignTokens.ColorToken.State.error)
                                    } else {
                                        Ph.checkCircle.regular
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .foregroundStyle(DesignTokens.ColorToken.State.success)
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
                        Label { Text("Health er ikke tilgængelig på denne enhed") } icon: { Ph.heartBreak.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
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
