//
//  ProgramLibraryDetailView.swift
//  Anvil Workout
//
//  Detail view for a pre-built program. Shows attribution, progression rules,
//  and a preview of every workout. The "Add to My Programs" button creates
//  editable WorkoutTemplate records.
//

import SwiftUI
import SwiftData
import Sentry
import IAMJARLDesignTokens
import PhosphorSwift

struct ProgramLibraryDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let program: ProgramLibraryEntry
    let onImportComplete: (String) -> Void

    @State private var errorMessage: String?
    @State private var isImporting = false
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var body: some View {
        List {
            // MARK: - Summary
            Section {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(program.summary)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    HStack(spacing: DesignTokens.Spacing.lg) {
                        infoColumn(label: "Level", value: program.level.displayName)
                        infoColumn(label: "Goal", value: program.goal.displayName)
                        infoColumn(label: "Frequency", value: "\(program.daysPerWeek)×/week")
                    }
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }

            // MARK: - Progression
            Section("Progression") {
                Text(program.progressionDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let cycle = program.cycleLengthWeeks {
                    HStack {
                        Ph.calendarCheck.regular.icon(size: 16).foregroundStyle(.secondary)
                        Text("Typical cycle: \(cycle) weeks")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // MARK: - Workouts
            ForEach(program.workouts, id: \.self) { workout in
                Section(workout.name) {
                    ForEach(workout.exercises, id: \.self) { exercise in
                        exerciseRow(exercise)
                    }
                }
            }

            // MARK: - Attribution
            Section {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    Ph.bookBookmark.regular.icon(size: 18).foregroundStyle(.secondary)
                    Text("Inspired by \(program.author)")
                        .font(.subheadline.weight(.medium))
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle(program.name)
        .navigationBarTitleDisplayMode(.inline)
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
                    Text(isImporting ? "Adding…" : "Add to My Programs")
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

    // MARK: - Subviews

    private func infoColumn(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.medium))
        }
    }

    private func exerciseRow(_ exercise: ProgramExercise) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(exercise.exerciseName)
                    .font(.subheadline.weight(.medium))
                Spacer()
                Text("\(exercise.sets) × \(exercise.reps)")
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let weight = exercise.suggestedWeight {
                Text("Suggested start: \(WeightFormatter.format(kg: weight, in: weightUnit))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let notes = exercise.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.ColorToken.State.warning)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - Actions

    private func importProgram() {
        isImporting = true
        do {
            _ = try ProgramLibraryService.importProgram(program, modelContext: modelContext)
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            onImportComplete(program.name)
        } catch {
            PersistenceLogger.capture(error, operation: "import-program", extra: [
                "programID": program.id,
                "workoutCount": program.workouts.count
            ])
            errorMessage = PersistenceLogger.userMessage(prefix: "Could not import program", error: error)
            isImporting = false
        }
    }
}

#Preview {
    NavigationStack {
        ProgramLibraryDetailView(
            program: ProgramLibraryService.programs.first!,
            onImportComplete: { _ in }
        )
    }
    .modelContainer(for: [
        Exercise.self,
        WorkoutTemplate.self,
        WorkoutTemplateExercise.self,
    ], inMemory: true)
}
