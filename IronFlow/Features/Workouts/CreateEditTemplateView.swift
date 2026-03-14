//
//  CreateEditTemplateView.swift
//  IronFlow
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct CreateEditTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var template: WorkoutTemplate
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var showExercisePicker = false
    @State private var showEditExercise: WorkoutTemplateExercise?
    @State private var showDeleteConfirm = false

    private var sortedExercises: [WorkoutTemplateExercise] {
        template.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func exerciseName(for exerciseID: UUID) -> String {
        allExercises.first { $0.id == exerciseID }?.name ?? "Ukendt øvelse"
    }

    var body: some View {
        Form {
            Section("Program") {
                TextField("Navn", text: $template.name)
                    .font(.headline)
                TextField("Note (valgfri)", text: $template.note, axis: .vertical)
                    .lineLimit(2...4)
                Toggle("Favorit", isOn: $template.isFavorite)
            }

            Section {
                ForEach(sortedExercises, id: \.id) { item in
                    Button {
                        showEditExercise = item
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exerciseName(for: item.exerciseID))
                                    .font(.subheadline.weight(.medium))
                                    .foregroundStyle(.primary)
                                Text("\(item.targetSets) sæt × \(item.targetReps) reps")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if let w = item.targetWeight, w > 0 {
                                    Text("\(w, specifier: "%.1f") kg")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if let r = item.restSeconds, r > 0 {
                                    Text("\(r) sek rest")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)

                Button {
                    showExercisePicker = true
                } label: {
                    Label("Tilføj øvelse", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("Øvelser")
            } footer: {
                Text("Træk for at omrokere. Tryk på en øvelse for at redigere sæt, reps og rest.")
            }
        }
        .navigationTitle(template.name.isEmpty ? "Nyt program" : "Rediger program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    template.updatedAt = .now
                    try? modelContext.save()
                    dismiss()
                }
            }
            ToolbarItem(placement: .destructiveAction) {
                Button("Slet program", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .sheet(isPresented: $showExercisePicker) {
            ExercisePickerView { exercise in
                addExercise(exercise)
            }
        }
        .sheet(item: $showEditExercise) { item in
            EditTemplateExerciseSheet(templateExercise: item)
        }
        .confirmationDialog("Slet program?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Slet", role: .destructive) {
                modelContext.delete(template)
                try? modelContext.save()
                dismiss()
            }
            Button("Behold", role: .cancel) { }
        } message: {
            Text("Programmet og alle øvelser i det slettes. Du kan ikke fortryde.")
        }
    }

    private func addExercise(_ exercise: Exercise) {
        let nextOrder = template.exercises.isEmpty ? 0 : (template.exercises.map(\.sortOrder).max() ?? -1) + 1
        let te = WorkoutTemplateExercise(
            exerciseID: exercise.id,
            sortOrder: nextOrder,
            targetSets: 3,
            targetReps: 10
        )
        te.template = template
        template.exercises.append(te)
        modelContext.insert(te)
        template.updatedAt = .now
        try? modelContext.save()
    }

    private func deleteExercises(at offsets: IndexSet) {
        let sorted = sortedExercises
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        reorderSortOrder()
        template.updatedAt = .now
        try? modelContext.save()
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = sortedExercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, item) in sorted.enumerated() {
            item.sortOrder = i
        }
        template.updatedAt = .now
        try? modelContext.save()
    }

    private func reorderSortOrder() {
        let sorted = template.exercises.sorted { $0.sortOrder < $1.sortOrder }
        for (i, item) in sorted.enumerated() {
            item.sortOrder = i
        }
    }
}
