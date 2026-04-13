//
//  SettingsView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import HealthKit
import IAMJARLDesignTokens
import PhosphorSwift

struct SettingsView: View {
    private let health = HealthKitService.shared
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage("weightUnit") private var weightUnit: String = "kg"
    @State private var requestInProgress = false
    @State private var message: String?
    @State private var messageIsError = false
    @State private var showExportShare = false
    @State private var exportURL: URL?

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
                    Button {
                        if let url = generateCSV() {
                            exportURL = url
                            showExportShare = true
                        }
                    } label: {
                        Label {
                            Text("Eksportér træningsdata")
                        } icon: {
                            Ph.export.regular
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 20, height: 20)
                        }
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Eksporterer alle træningssessioner som en CSV-fil.")
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
            .sheet(isPresented: $showExportShare) {
                if let url = exportURL {
                    ActivityView(activityItems: [url])
                }
            }
        }
    }

    private func generateCSV() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        var rows: [String] = ["Dato,Program,Varighed (min),Øvelse,Sæt,Reps,Vægt (kg),Type"]

        for session in sessions {
            let date = dateFormatter.string(from: session.startedAt)
            let program = session.templateName.replacingOccurrences(of: ",", with: " ")
            let duration = session.durationSeconds / 60

            let sortedExercises = session.exercises.sorted { $0.sortOrder < $1.sortOrder }
            for exercise in sortedExercises {
                let name = exercise.exerciseName.replacingOccurrences(of: ",", with: " ")
                let completedSets = exercise.performedSets
                    .filter { $0.isCompleted }
                    .sorted { $0.setIndex < $1.setIndex }

                for set in completedSets {
                    let setNumber = set.setIndex + 1
                    let reps = set.actualReps ?? set.targetReps
                    let weight = set.actualWeight ?? set.targetWeight ?? 0
                    let type = set.setType.rawValue

                    rows.append("\(date),\(program),\(duration),\(name),\(setNumber),\(reps),\(String(format: "%.1f", weight)),\(type)")
                }
            }
        }

        let csvString = rows.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("iron_workout_export.csv")

        do {
            try csvString.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
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

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
