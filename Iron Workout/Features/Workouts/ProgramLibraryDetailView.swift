//
//  ProgramLibraryDetailView.swift
//  Iron Workout
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

    @State private var errorMessage: String?
    @State private var importResult: ImportResult?

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
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inspired by \(program.author)")
                            .font(.subheadline.weight(.medium))
                        if let url = program.officialURL, let officialURL = URL(string: url) {
                            Link(destination: officialURL) {
                                Text("Learn more")
                                    .font(.caption)
                            }
                        }
                    }
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
                    Ph.plusCircle.fill.icon()
                    Text("Add to My Programs")
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
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Added", isPresented: Binding(get: { importResult != nil }, set: { if !$0 { importResult = nil } })) {
            Button("Done") {
                importResult = nil
                dismiss()
            }
        } message: {
            if let result = importResult {
                Text(result.message)
            }
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
                Text("Suggested start: \(weight.formatted(.number.precision(.fractionLength(1)))) kg")
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
        do {
            let created = try ProgramLibraryService.importProgram(program, modelContext: modelContext)
            importResult = ImportResult(count: created.count, programName: program.name)
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not import program: \(error.localizedDescription)"
        }
    }

    private struct ImportResult: Equatable {
        let count: Int
        let programName: String

        var message: String {
            if count == 1 {
                return "\(programName) added to your programs. Open it to adjust weights for your level."
            }
            return "\(count) programs added for \(programName). Find them in your list and assign to your weekly plan."
        }
    }
}

#Preview {
    NavigationStack {
        ProgramLibraryDetailView(program: ProgramLibraryService.programs.first!)
    }
    .modelContainer(for: [
        Exercise.self,
        WorkoutTemplate.self,
        WorkoutTemplateExercise.self,
    ], inMemory: true)
}
