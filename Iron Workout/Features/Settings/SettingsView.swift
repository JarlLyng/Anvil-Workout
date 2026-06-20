//
//  SettingsView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import HealthKit
import Sentry
import IAMJARLDesignTokens
import PhosphorSwift
import UniformTypeIdentifiers

struct SettingsView: View {
    private let health = HealthKitService.shared
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnit: String = WeightUnit.kg.rawValue
    @State private var requestInProgress = false
    @State private var message: String?
    @State private var messageIsError = false
    @State private var showExportShare = false
    @State private var exportURL: URL?
    @State private var healthAuthStatus: HKAuthorizationStatus = .notDetermined
    @State private var showImporter = false
    @State private var pendingImport: ParsedImport?
    @State private var importErrorMessage: String?
    @State private var importResultMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Ph.scales.regular
                            .icon()
                            .foregroundStyle(.secondary)
                        Picker("Weight Unit", selection: $weightUnit) {
                            Text("kg").tag(WeightUnit.kg.rawValue)
                            Text("lb").tag(WeightUnit.lbs.rawValue)
                        }
                        .pickerStyle(.segmented)
                    }
                } header: {
                    Text("Units")
                }

                Section {
                    Button {
                        if let url = generateCSV() {
                            exportURL = url
                            showExportShare = true
                        }
                    } label: {
                        Label {
                            Text("Export Workout Data")
                        } icon: {
                            Ph.export.regular
                                .icon()
                        }
                    }

                    Button {
                        showImporter = true
                    } label: {
                        Label {
                            Text("Import Workout Data")
                        } icon: {
                            Ph.downloadSimple.regular
                                .icon()
                        }
                    }
                } header: {
                    Text("Data")
                } footer: {
                    Text("Export all workout sessions as a CSV file, or import your history from Strong or Hevy.")
                }

                Section {
                    Link(destination: URL(string: "https://apps.apple.com/app/id6760627760?action=write-review")!) {
                        Label {
                            Text("Rate Anvil Workout")
                                .foregroundStyle(.primary)
                        } icon: {
                            Ph.star.fill
                                .icon()
                                .foregroundStyle(DesignTokens.ColorToken.State.warning)
                        }
                    }
                    .accessibilityHint("Opens the App Store to write a review")
                } header: {
                    Text("Feedback")
                } footer: {
                    Text("Reviews help other lifters find the app and keep it improving.")
                }

                Section {
                    HStack {
                        Ph.info.regular
                            .icon()
                            .foregroundStyle(.secondary)
                        Text("Anvil Workout")
                        Spacer()
                        Text("\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Ph.code.regular
                            .icon()
                            .foregroundStyle(.secondary)
                        Text("Developed by IAMJARL")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                Section {
                    if health.isAvailable {
                        HStack {
                            Ph.heart.fill
                                .icon()
                                .foregroundStyle(DesignTokens.ColorToken.State.error)
                            Text("Apple Health")
                            Spacer()
                            healthStatusControl
                        }
                        if let msg = message {
                            HStack(spacing: 8) {
                                Group {
                                    if messageIsError {
                                        Ph.warningCircle.regular
                                            .icon()
                                            .foregroundStyle(DesignTokens.ColorToken.State.error)
                                    } else {
                                        Ph.checkCircle.regular
                                            .icon()
                                            .foregroundStyle(DesignTokens.ColorToken.State.success)
                                    }
                                }
                                Text(msg)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    } else {
                        Label { Text("Health is not available on this device") } icon: { Ph.heartBreak.regular.icon() }
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("Health")
                } footer: {
                    Text(healthFooterText)
                }
            }
            .sheet(isPresented: $showExportShare) {
                if let url = exportURL {
                    ActivityView(activityItems: [url])
                }
            }
            .fileImporter(
                isPresented: $showImporter,
                allowedContentTypes: [.commaSeparatedText, .plainText, .text],
                allowsMultipleSelection: false
            ) { result in
                handleImportSelection(result)
            }
            .alert("Import Workouts", isPresented: Binding(
                get: { pendingImport != nil },
                set: { if !$0 { pendingImport = nil } }
            ), presenting: pendingImport) { parsed in
                Button("Import") { commitImport(parsed) }
                Button("Cancel", role: .cancel) { pendingImport = nil }
            } message: { parsed in
                Text(importPreview(parsed))
            }
            .alert("Import Failed", isPresented: Binding(
                get: { importErrorMessage != nil },
                set: { if !$0 { importErrorMessage = nil } }
            )) {
                Button("OK") { importErrorMessage = nil }
            } message: {
                Text(importErrorMessage ?? "")
            }
            .alert("Import Complete", isPresented: Binding(
                get: { importResultMessage != nil },
                set: { if !$0 { importResultMessage = nil } }
            )) {
                Button("OK") { importResultMessage = nil }
            } message: {
                Text(importResultMessage ?? "")
            }
            .onAppear { refreshHealthAuthStatus() }
        }
    }

    @ViewBuilder
    private var healthStatusControl: some View {
        if requestInProgress {
            ProgressView()
                .scaleEffect(0.9)
        } else {
            switch healthAuthStatus {
            case .sharingAuthorized:
                HStack(spacing: 6) {
                    Ph.checkCircle.fill
                        .icon(size: 16)
                        .foregroundStyle(DesignTokens.ColorToken.State.success)
                    Text("Connected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel("Apple Health access granted")
            case .sharingDenied:
                Button("Open Health") {
                    openHealthSettings()
                }
                .accessibilityHint("Open Settings to change Health permissions")
            case .notDetermined:
                // Button wording: Apple guideline 5.1.1(iv) requires neutral words
                // ("Continue", "Next") rather than "Grant Access" or similar that
                // pre-empt the user's decision on the system permission prompt.
                Button("Continue") {
                    requestHealthAccess()
                }
                .accessibilityHint("Continue to Apple Health setup")
            @unknown default:
                Button("Continue") {
                    requestHealthAccess()
                }
            }
        }
    }

    private var healthFooterText: String {
        switch healthAuthStatus {
        case .sharingDenied:
            return "Access to Health is denied. Open Settings > Health > Data Access & Devices > Anvil Workout to enable."
        default:
            return "Anvil Workout saves workouts to Health and can show calories and heart rate when you use Apple Watch or other sources during a workout."
        }
    }

    private func refreshHealthAuthStatus() {
        guard health.isAvailable else { return }
        healthAuthStatus = health.authorizationStatus(for: HKObjectType.workoutType())
    }

    private func openHealthSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    private func generateCSV() -> URL? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let unit = WeightUnit(rawValue: weightUnit) ?? .kg
        var rows: [String] = ["Date,Program,Duration (min),Exercise,Set,Reps,Weight (\(unit.label)),Type"]

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
                    let weightKg = set.actualWeight ?? set.targetWeight ?? 0
                    let weight = WeightFormatter.display(weightKg, in: unit)
                    let type = set.setType.displayName

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
            SentrySDK.capture(error: error)
            return nil
        }
    }

    // MARK: - Import

    private func handleImportSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importErrorMessage = error.localizedDescription
        case .success(let urls):
            guard let url = urls.first else { return }
            let needsAccess = url.startAccessingSecurityScopedResource()
            defer { if needsAccess { url.stopAccessingSecurityScopedResource() } }
            do {
                let text = try String(contentsOf: url, encoding: .utf8)
                let unit = WeightUnit(rawValue: weightUnit) ?? .kg
                pendingImport = try WorkoutCSVImporter.parse(text, strongFallbackUnit: unit)
            } catch {
                SentrySDK.capture(error: error)
                importErrorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            }
        }
    }

    private func importPreview(_ parsed: ParsedImport) -> String {
        var lines = [
            "Detected \(parsed.format.rawValue) export.",
            "\(parsed.sessionCount) workouts, \(parsed.setCount) sets across \(parsed.exerciseCount) exercises.",
        ]
        lines.append("Imported workouts are added to your history. New exercise names become custom exercises.")
        return lines.joined(separator: "\n\n")
    }

    private func commitImport(_ parsed: ParsedImport) {
        pendingImport = nil
        do {
            let summary = try WorkoutCSVImportService.save(parsed, modelContext: modelContext)
            var text = "Imported \(summary.importedSessions) workouts (\(summary.importedSets) sets) from \(summary.format.rawValue)."
            if summary.createdExercises > 0 {
                text += "\n\nAdded \(summary.createdExercises) new custom \(summary.createdExercises == 1 ? "exercise" : "exercises")."
            }
            importResultMessage = text
        } catch {
            SentrySDK.capture(error: error)
            importErrorMessage = error.localizedDescription
        }
    }

    private func requestHealthAccess() {
        requestInProgress = true
        message = nil
        Task {
            do {
                try await health.requestAuthorization()
                await MainActor.run {
                    refreshHealthAuthStatus()
                    if healthAuthStatus == .sharingAuthorized {
                        message = "Apple Health connected."
                        messageIsError = false
                    } else if healthAuthStatus == .sharingDenied {
                        message = "Access denied. Open Settings to enable Health permissions."
                        messageIsError = true
                    } else {
                        message = "Permission requested. Complete approval in the Health app."
                        messageIsError = false
                    }
                    requestInProgress = false
                }
            } catch {
                await MainActor.run {
                    message = "Could not request permission. Check that Health is available."
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
