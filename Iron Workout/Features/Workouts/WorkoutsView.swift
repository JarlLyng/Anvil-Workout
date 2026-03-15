//
//  WorkoutsView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct WorkoutsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @State private var templateToCreate: WorkoutTemplate?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView {
                        Label("Ingen programmer endnu", systemImage: "figure.strengthtraining.traditional")
                    } description: {
                        Text("Opret dit første træningsprogram med øvelser, sæt og reps. Derefter kan du starte træningen med et enkelt tryk.")
                    } actions: {
                        Button("Opret program") {
                            createTemplate()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(templates) { template in
                            NavigationLink(value: template) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(template.name.isEmpty ? "Uden navn" : template.name)
                                            .font(.headline)
                                        if !template.note.isEmpty {
                                            Text(template.note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if template.isFavorite {
                                        Image(systemName: "star.fill")
                                            .foregroundStyle(.yellow)
                                            .accessibilityLabel("Favorit")
                                    }
                                }
                            }
                            .contextMenu {
                                Button {
                                    duplicateTemplate(template)
                                } label: {
                                    Label("Dupliker", systemImage: "doc.on.doc")
                                }
                            }
                        }
                        .onDelete(perform: deleteTemplates)
                    }
                }
            }
            .navigationTitle("Træning")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createTemplate()
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .accessibilityLabel("Opret program")
                    }
                }
            }
            .navigationDestination(for: WorkoutTemplate.self) { template in
                TemplateDetailView(template: template)
            }
            .sheet(item: $templateToCreate, onDismiss: { templateToCreate = nil }) { template in
                NavigationStack {
                    CreateEditTemplateView(template: template)
                }
            }
            .alert("Fejl", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private func createTemplate() {
        let newTemplate = WorkoutTemplate(name: "Nyt program")
        modelContext.insert(newTemplate)
        do {
            try modelContext.save()
            templateToCreate = newTemplate
        } catch {
            modelContext.delete(newTemplate)
            errorMessage = "Kunne ikke oprette program. Prøv igen."
        }
    }

    private func deleteTemplates(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(templates[index])
        }
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Kunne ikke slette program."
        }
    }

    private func duplicateTemplate(_ source: WorkoutTemplate) {
        let copy = WorkoutTemplate(
            name: source.name + " (kopi)",
            note: source.note,
            isFavorite: false
        )
        modelContext.insert(copy)
        let sorted = source.exercises.sorted { $0.sortOrder < $1.sortOrder }
        for (index, item) in sorted.enumerated() {
            let newItem = WorkoutTemplateExercise(
                exerciseID: item.exerciseID,
                sortOrder: index,
                targetSets: item.targetSets,
                targetReps: item.targetReps,
                targetWeight: item.targetWeight,
                restSeconds: item.restSeconds,
                note: item.note
            )
            newItem.template = copy
            copy.exercises.append(newItem)
            modelContext.insert(newItem)
        }
        copy.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            errorMessage = "Kunne ikke duplikere program."
        }
    }
}

#Preview {
    WorkoutsView()
        .modelContainer(for: [WorkoutTemplate.self, WorkoutTemplateExercise.self], inMemory: true)
}
