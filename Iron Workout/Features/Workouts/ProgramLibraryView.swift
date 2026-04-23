//
//  ProgramLibraryView.swift
//  Iron Workout
//
//  Browse the pre-built program library. Users tap a program to see details and
//  import it as editable WorkoutTemplate records.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

struct ProgramLibraryView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Called when the user successfully imports a program. Receives the program's
    /// display name so the presenting view can show a confirmation toast. Parent is
    /// expected to dismiss this sheet.
    let onImportComplete: (String) -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(ProgramLevel.allCases) { level in
                    let programs = ProgramLibraryService.programs(for: level)
                    if !programs.isEmpty {
                        Section {
                            ForEach(programs) { program in
                                NavigationLink(value: program) {
                                    ProgramCard(program: program)
                                }
                            }
                        } header: {
                            Text(level.displayName)
                        }
                    }
                }

                Section {
                    Text("These programs are inspired by well-known training routines. You'll get an editable copy — adjust weights to match your level, and tweak exercises as you progress.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Program Library")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: ProgramLibraryEntry.self) { program in
                ProgramLibraryDetailView(program: program, onImportComplete: onImportComplete)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Card

private struct ProgramCard: View {
    let program: ProgramLibraryEntry

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(program.name)
                    .font(.headline)
                Spacer()
                Label {
                    Text("\(program.daysPerWeek)×/week")
                } icon: {
                    Ph.calendar.regular.icon(size: 14)
                }
                .labelStyle(.titleAndIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Text(program.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(3)

            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(program.author)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(program.goal.displayName)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.regularMaterial, in: Capsule())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    ProgramLibraryView(onImportComplete: { _ in })
        .modelContainer(for: [
            Exercise.self,
            WorkoutTemplate.self,
            WorkoutTemplateExercise.self,
        ], inMemory: true)
}
