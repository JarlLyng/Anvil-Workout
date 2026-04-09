//
//  CreateEditTemplateView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import PhosphorSwift
import IAMJARLDesignTokens

struct CreateEditTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var template: WorkoutTemplate
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var showExercisePicker = false
    @State private var showEditExercise: WorkoutTemplateExercise?
    @State private var showDeleteConfirm = false
    @State private var errorMessage: String?

    private var sortedExercises: [WorkoutTemplateExercise] {
        template.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func exerciseName(for exerciseID: UUID) -> String {
        allExercises.first { $0.id == exerciseID }?.name ?? "Ukendt øvelse"
    }

    var body: some View {
        Form {
            programSection
            exercisesSection
        }
        .navigationTitle(template.name.isEmpty ? "Nyt program" : "Rediger program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    template.updatedAt = .now
                    do { try modelContext.save() } catch { errorMessage = "Kunne ikke gemme: \(error.localizedDescription)" }
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
        .alert("Fejl", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .confirmationDialog("Slet program?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Slet", role: .destructive) {
                modelContext.delete(template)
                do { try modelContext.save() } catch { errorMessage = "Kunne ikke gemme: \(error.localizedDescription)" }
                dismiss()
            }
            Button("Behold", role: .cancel) { }
        } message: {
            Text("Programmet og alle øvelser i det slettes. Du kan ikke fortryde.")
        }
    }

    @ViewBuilder
    private var programSection: some View {
        Section("Program") {
            TextField("Navn", text: $template.name)
                .font(.headline)
            TextField("Note (valgfri)", text: $template.note, axis: .vertical)
                .lineLimit(2...4)
            Toggle("Favorit", isOn: $template.isFavorite)
        }
    }

    @ViewBuilder
    private var exercisesSection: some View {
        Section {
            ForEach(sortedExercises, id: \.id) { item in
                Button {
                    showEditExercise = item
                } label: {
                    TemplateExerciseRowLabel(
                        item: item,
                        exerciseTitle: exerciseName(for: item.exerciseID)
                    )
                }
                .contextMenu {
                        let sorted = sortedExercises
                        if let idx = sorted.firstIndex(of: item), idx < sorted.count - 1 {
                            let next = sorted[idx + 1]
                            if item.supersetID != nil && item.supersetID == next.supersetID {
                                Button("Fjern supersæt med næste øvelse") {
                                    item.supersetID = nil
                                    next.supersetID = nil
                                    do { try modelContext.save() } catch { errorMessage = "Fejl: \(error)" }
                                }
                            } else {
                                Button("Kobl i supersæt med næste øvelse") {
                                    let id = item.supersetID ?? UUID()
                                    item.supersetID = id
                                    next.supersetID = id
                                    do { try modelContext.save() } catch { errorMessage = "Fejl: \(error)" }
                                }
                            }
                        }
                        if item.supersetID != nil {
                            Button("Fritstille fra supersæt") {
                                item.supersetID = nil
                                do { try modelContext.save() } catch { errorMessage = "Fejl: \(error)" }
                            }
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)

                addExerciseButton
            } header: {
                Text("Øvelser")
            } footer: {
                Text("Træk for at omrokere. Tryk på en øvelse for at redigere sæt, reps og rest.")
            }
    }

    @ViewBuilder
    private var addExerciseButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            Label {
                Text("Tilføj øvelse")
            } icon: {
                Ph.plusCircle.fill
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
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
        do { try modelContext.save() } catch { errorMessage = "Kunne ikke gemme: \(error.localizedDescription)" }
    }

    private func deleteExercises(at offsets: IndexSet) {
        let sorted = sortedExercises
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        reorderSortOrder()
        template.updatedAt = .now
        do { try modelContext.save() } catch { errorMessage = "Kunne ikke gemme: \(error.localizedDescription)" }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = sortedExercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, item) in sorted.enumerated() {
            item.sortOrder = i
        }
        template.updatedAt = .now
        do { try modelContext.save() } catch { errorMessage = "Kunne ikke gemme: \(error.localizedDescription)" }
    }

    private func reorderSortOrder() {
        let sorted = template.exercises.sorted { $0.sortOrder < $1.sortOrder }
        for (i, item) in sorted.enumerated() {
            item.sortOrder = i
        }
    }
}

// MARK: - Underkomponenter (lettere type-check for compileren)

private struct TemplateExerciseRowLabel: View {
    let item: WorkoutTemplateExercise
    let exerciseTitle: String

    var body: some View {
        HStack {
            if item.supersetID != nil {
                supersetLinkIcon
            }
            exerciseMetaColumn
            Spacer()
            disclosureChevron
        }
    }

    private var supersetLinkIcon: some View {
        Ph.link.bold
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 16, height: 16)
            .foregroundStyle(DesignTokens.ColorToken.State.warning)
    }

    private var exerciseMetaColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exerciseTitle)
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
    }

    private var disclosureChevron: some View {
        Ph.caretRight.regular
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 20, height: 20)
            .foregroundStyle(.secondary)
    }
}
