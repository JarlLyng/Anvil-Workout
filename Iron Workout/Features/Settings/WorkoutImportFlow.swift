//
//  WorkoutImportFlow.swift
//  Anvil Workout
//
//  Importing history from a Strong or Hevy CSV export: the file picker, a preview that
//  says what cannot come across before anything is saved (#75), and the result. One flow
//  shared by Settings, onboarding and the home screen's first-run card.
//

import SwiftUI
import SwiftData
import Sentry
import UniformTypeIdentifiers

extension View {
    /// Presents the file picker while `isPresented` is true, then the preview and result
    /// alerts. `onImported` runs after a successful save, once the result is shown.
    func workoutImport(isPresented: Binding<Bool>, onImported: @escaping (WorkoutCSVImportService.Summary) -> Void = { _ in }) -> some View {
        modifier(WorkoutImportFlow(isPresented: isPresented, onImported: onImported))
    }
}

private struct WorkoutImportFlow: ViewModifier {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnit: String = WeightUnit.kg.rawValue
    @Binding var isPresented: Bool
    let onImported: (WorkoutCSVImportService.Summary) -> Void

    @State private var pendingImport: ParsedImport?
    @State private var importErrorMessage: String?
    @State private var importResultMessage: String?
    @State private var importedSummary: WorkoutCSVImportService.Summary?

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $isPresented,
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
                Button("OK") {
                    importResultMessage = nil
                    if let summary = importedSummary {
                        importedSummary = nil
                        onImported(summary)
                    }
                }
            } message: {
                Text(importResultMessage ?? "")
            }
    }

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
        if let exclusions = importExclusions(parsed.skipped) {
            lines.append(exclusions)
        }
        lines.append("Imported workouts are added to your history. Exercises are matched to Anvil's own where they are the same lift; the rest become custom exercises.")
        return lines.joined(separator: "\n\n")
    }

    /// Spells out what will not come across, so a partial import is a visible choice made
    /// before anything is written rather than something discovered later (#75).
    private func importExclusions(_ skipped: ParsedImportSkips) -> String? {
        guard !skipped.isEmpty else { return nil }

        var reasons: [String] = []
        if skipped.timedOrDistanceSets > 0 {
            reasons.append("\(skipped.timedOrDistanceSets) timed or distance \(skipped.timedOrDistanceSets == 1 ? "set" : "sets") (Anvil records reps and weight)")
        }
        if skipped.unreadableDates > 0 {
            reasons.append("\(skipped.unreadableDates) \(skipped.unreadableDates == 1 ? "row" : "rows") with an unreadable date")
        }
        if skipped.namelessRows > 0 {
            reasons.append("\(skipped.namelessRows) \(skipped.namelessRows == 1 ? "row" : "rows") with no exercise name")
        }
        if skipped.droppedWorkoutNotes > 0 {
            reasons.append("workout notes on \(skipped.droppedWorkoutNotes) \(skipped.droppedWorkoutNotes == 1 ? "workout" : "workouts") (per-exercise notes are kept)")
        }

        let heading = skipped.droppedRows > 0
            ? "Not everything can be imported. Leaving out:"
            : "Everything will be imported except:"
        return heading + "\n" + reasons.map { "• " + $0 }.joined(separator: "\n")
            + "\n\nYour original file is not changed, so you can cancel and keep it."
    }

    private func commitImport(_ parsed: ParsedImport) {
        pendingImport = nil
        do {
            let summary = try WorkoutCSVImportService.save(parsed, modelContext: modelContext)
            var text = "Imported \(summary.importedSessions) workouts (\(summary.importedSets) sets) from \(summary.format.rawValue)."
            if summary.createdExercises > 0 {
                text += "\n\nAdded \(summary.createdExercises) new custom \(summary.createdExercises == 1 ? "exercise" : "exercises")."
            }
            // Repeat the shortfall here so the success message cannot be mistaken for a
            // complete migration after the fact.
            if parsed.skipped.droppedRows > 0 {
                text += "\n\n\(parsed.skipped.droppedRows) \(parsed.skipped.droppedRows == 1 ? "row was" : "rows were") left out, as listed before importing. Your original file still has them."
            }
            importedSummary = summary
            importResultMessage = text
        } catch {
            SentrySDK.capture(error: error)
            importErrorMessage = error.localizedDescription
        }
    }
}
