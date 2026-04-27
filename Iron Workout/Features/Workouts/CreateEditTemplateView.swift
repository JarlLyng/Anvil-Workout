//
//  CreateEditTemplateView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import Sentry
import PhosphorSwift
import IAMJARLDesignTokens

struct CreateEditTemplateView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var template: WorkoutTemplate
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]

    @State private var showExercisePicker = false
    @State private var showEditExercise: WorkoutTemplateExercise?
    @State private var errorMessage: String?

    private var sortedExercises: [WorkoutTemplateExercise] {
        template.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func exerciseName(for exerciseID: UUID) -> String {
        allExercises.first { $0.id == exerciseID }?.name ?? "Unknown exercise"
    }

    var body: some View {
        Form {
            programSection
            exercisesSection
        }
        .navigationTitle(template.name.isEmpty ? "New Program" : "Edit Program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Done") {
                    template.updatedAt = .now
                    do { try modelContext.save() } catch {
                        SentrySDK.capture(error: error)
                        errorMessage = "Could not save: \(error.localizedDescription)"
                    }
                    dismiss()
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
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private var programSection: some View {
        Section("Program") {
            TextField("Name", text: $template.name)
                .font(.headline)
            TextField("Note (optional)", text: $template.note, axis: .vertical)
                .lineLimit(2...4)
            Toggle("Favorite", isOn: $template.isFavorite)
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
                                Button("Remove superset with next exercise") {
                                    item.supersetID = nil
                                    next.supersetID = nil
                                    do { try modelContext.save() } catch {
                                    SentrySDK.capture(error: error)
                                    errorMessage = "Could not save: \(error.localizedDescription)"
                                }
                                }
                            } else {
                                Button("Link as superset with next exercise") {
                                    let id = item.supersetID ?? UUID()
                                    item.supersetID = id
                                    next.supersetID = id
                                    do { try modelContext.save() } catch {
                                    SentrySDK.capture(error: error)
                                    errorMessage = "Could not save: \(error.localizedDescription)"
                                }
                                }
                            }
                        }
                        if item.supersetID != nil {
                            Button("Detach from superset") {
                                item.supersetID = nil
                                do { try modelContext.save() } catch {
                                    SentrySDK.capture(error: error)
                                    errorMessage = "Could not save: \(error.localizedDescription)"
                                }
                            }
                        }
                    }
                }
                .onDelete(perform: deleteExercises)
                .onMove(perform: moveExercises)

                addExerciseButton
            } header: {
                Text("Exercises")
            } footer: {
                Text("Drag to reorder. Tap an exercise to edit sets, reps and rest.")
            }
    }

    @ViewBuilder
    private var addExerciseButton: some View {
        Button {
            showExercisePicker = true
        } label: {
            Label {
                Text("Add Exercise")
            } icon: {
                Ph.plusCircle.fill
                    .icon()
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
        do { try modelContext.save() } catch {
            PersistenceLogger.capture(error, operation: "add-exercise-to-template", extra: [
                "templateID": template.id.uuidString,
                "exerciseID": exercise.id.uuidString,
                "exerciseName": exercise.name
            ])
            errorMessage = PersistenceLogger.userMessage(prefix: "Could not save", error: error)
        }
    }

    private func deleteExercises(at offsets: IndexSet) {
        let sorted = sortedExercises
        for index in offsets {
            modelContext.delete(sorted[index])
        }
        reorderSortOrder()
        template.updatedAt = .now
        do { try modelContext.save() } catch {
                    SentrySDK.capture(error: error)
                    errorMessage = "Could not save: \(error.localizedDescription)"
                }
    }

    private func moveExercises(from source: IndexSet, to destination: Int) {
        var sorted = sortedExercises
        sorted.move(fromOffsets: source, toOffset: destination)
        for (i, item) in sorted.enumerated() {
            item.sortOrder = i
        }
        template.updatedAt = .now
        do { try modelContext.save() } catch {
                    SentrySDK.capture(error: error)
                    errorMessage = "Could not save: \(error.localizedDescription)"
                }
    }

    private func reorderSortOrder() {
        let sorted = template.exercises.sorted { $0.sortOrder < $1.sortOrder }
        for (i, item) in sorted.enumerated() {
            item.sortOrder = i
        }
    }
}

// MARK: - Subcomponents

private struct TemplateExerciseRowLabel: View {
    let item: WorkoutTemplateExercise
    let exerciseTitle: String
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

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
            .icon(size: 16)
            .foregroundStyle(DesignTokens.ColorToken.State.warning)
    }

    private var exerciseMetaColumn: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exerciseTitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
            Text("\(item.targetSets) sets x \(item.targetReps) reps")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let w = item.targetWeight, w > 0 {
                Text(WeightFormatter.format(kg: w, in: weightUnit))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if let r = item.restSeconds, r > 0 {
                Text("\(r) s rest")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var disclosureChevron: some View {
        Ph.caretRight.regular
            .icon()
            .foregroundStyle(.secondary)
    }
}
