//
//  ImportProgramSheet.swift
//  Anvil Workout
//
//  Preview + confirm dialog shown when a user taps a shared-program universal link.
//  Decodes the payload from the URL, shows what's about to be imported, and gives
//  the user explicit Import / Cancel control. We never silently overwrite or add a
//  template — the user always sees what they're about to receive.
//

import SwiftUI
import SwiftData
import Sentry
import IAMJARLDesignTokens
import PhosphorSwift

struct ImportProgramSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let payload: SharedProgramPayload
    var onImported: (String) -> Void

    @State private var errorMessage: String?
    @State private var isImporting = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                        Text(payload.name)
                            .font(.title2.bold())
                        if let note = payload.note, !note.isEmpty {
                            Text(note)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: DesignTokens.Spacing.md) {
                            Label("\(payload.exercises.count) exercises", systemImage: "list.bullet")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            let totalSets = payload.exercises.map(\.s).reduce(0, +)
                            Label("\(totalSets) sets", systemImage: "checkmark.circle")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Exercises") {
                    ForEach(Array(payload.exercises.enumerated()), id: \.offset) { _, exercise in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text(exercise.name)
                                    .font(.subheadline.weight(.medium))
                                Spacer()
                                Text("\(exercise.s) × \(exercise.r)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                            if let w = exercise.w, w > 0 {
                                Text("\(w.formatted(.number.precision(.fractionLength(0)))) kg")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .navigationTitle("Import Program")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    importProgram()
                } label: {
                    HStack {
                        Spacer()
                        if isImporting {
                            ProgressView()
                                .tint(DesignTokens.Common.OnPrimary.text(colorScheme))
                        } else {
                            Ph.plusCircle.fill.icon()
                        }
                        Text(isImporting ? "Importing…" : "Add to My Programs")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                }
                .buttonStyle(.borderedProminent)
                .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
                .padding(.horizontal)
                .padding(.bottom, 8)
                .background(.ultraThinMaterial)
                .disabled(isImporting)
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func importProgram() {
        isImporting = true
        do {
            let template = try ProgramShareService.importPayload(payload, modelContext: modelContext)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onImported(template.name)
            dismiss()
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not import program: \(error.localizedDescription)"
            isImporting = false
        }
    }
}
