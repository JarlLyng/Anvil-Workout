//
//  WeeklyPlanEditorSheet.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/04/2026.
//

import SwiftUI
import SwiftData
import IAMJARLDesignTokens
import PhosphorSwift

struct WeeklyPlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \WorkoutTemplate.name) private var templates: [WorkoutTemplate]

    /// Weekday index (Mon=0 ... Sun=6) → ordered list of program names. Users can
    /// plan multiple workouts per day (e.g. a main session plus a short core block).
    @State private var editablePlan: [Int: [String]]
    @State private var pickerDayIndex: Int?
    private let onSave: ([Int: [String]]) -> Void

    private static let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]

    init(plan: [Int: [String]], onSave: @escaping ([Int: [String]]) -> Void) {
        _editablePlan = State(initialValue: plan)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                ForEach(0..<7, id: \.self) { index in
                    Section {
                        dayContent(for: index)
                    } header: {
                        Text(Self.dayNames[index])
                    }
                }
            }
            .navigationTitle("Weekly Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(editablePlan)
                        dismiss()
                    }
                    .bold()
                }
            }
            .sheet(item: Binding<IdentifiableInt?>(
                get: { pickerDayIndex.map(IdentifiableInt.init) },
                set: { pickerDayIndex = $0?.value }
            )) { identifiable in
                programPickerSheet(for: identifiable.value)
            }
        }
    }

    @ViewBuilder
    private func dayContent(for dayIndex: Int) -> some View {
        let programs = editablePlan[dayIndex] ?? []

        if programs.isEmpty {
            Text("Rest day")
                .foregroundStyle(.secondary)
        } else {
            ForEach(Array(programs.enumerated()), id: \.offset) { offset, programName in
                HStack {
                    Text(programName)
                    Spacer()
                    Button(role: .destructive) {
                        removeProgram(at: offset, from: dayIndex)
                    } label: {
                        Ph.minusCircle.fill
                            .icon(size: 20)
                            .foregroundStyle(DesignTokens.ColorToken.State.error)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Remove \(programName) from \(Self.dayNames[dayIndex])")
                }
            }
            .onMove { source, destination in
                moveProgram(in: dayIndex, from: source, to: destination)
            }
        }

        Button {
            pickerDayIndex = dayIndex
        } label: {
            Label {
                Text("Add Program")
            } icon: {
                Ph.plusCircle.fill
                    .icon()
            }
        }
        .disabled(templates.isEmpty)
    }

    @ViewBuilder
    private func programPickerSheet(for dayIndex: Int) -> some View {
        NavigationStack {
            List(templates, id: \.id) { template in
                Button {
                    addProgram(template.name, to: dayIndex)
                    pickerDayIndex = nil
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(template.name)
                                .foregroundStyle(.primary)
                            Text("\(template.exercises.count) exercises")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if editablePlan[dayIndex]?.contains(template.name) == true {
                            Ph.checkCircle.fill
                                .icon(size: 18)
                                .foregroundStyle(DesignTokens.ColorToken.State.success)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
            .navigationTitle("Add to \(Self.dayNames[dayIndex])")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { pickerDayIndex = nil }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Mutations

    private func addProgram(_ name: String, to dayIndex: Int) {
        var current = editablePlan[dayIndex] ?? []
        current.append(name)
        editablePlan[dayIndex] = current
    }

    private func removeProgram(at offset: Int, from dayIndex: Int) {
        guard var current = editablePlan[dayIndex], current.indices.contains(offset) else { return }
        current.remove(at: offset)
        if current.isEmpty {
            editablePlan.removeValue(forKey: dayIndex)
        } else {
            editablePlan[dayIndex] = current
        }
    }

    private func moveProgram(in dayIndex: Int, from source: IndexSet, to destination: Int) {
        guard var current = editablePlan[dayIndex] else { return }
        current.move(fromOffsets: source, toOffset: destination)
        editablePlan[dayIndex] = current
    }
}

/// Small wrapper so we can bind an optional `Int` to `.sheet(item:)`.
private struct IdentifiableInt: Identifiable {
    let value: Int
    var id: Int { value }
}

#Preview {
    WeeklyPlanEditorSheet(plan: [:]) { _ in }
        .modelContainer(for: WorkoutTemplate.self, inMemory: true)
}
