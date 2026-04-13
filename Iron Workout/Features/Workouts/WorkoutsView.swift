//
//  WorkoutsView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import PhosphorSwift
import IAMJARLDesignTokens

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
                        Label("Ingen programmer endnu", systemImage: "dumbbell.fill")
                    } description: {
                        Text("Opret dit første træningsprogram med øvelser, sæt og reps. Derefter kan du starte træningen med et enkelt tryk.")
                    } actions: {
                        Button("Opret program") {
                            createTemplate()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    ScrollView {
                        VStack(spacing: DesignTokens.Spacing.lg) {
                            ForEach(templates) { template in
                                NavigationLink(value: template) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                            Text(template.name.isEmpty ? "Uden navn" : template.name)
                                                .font(.headline)
                                                .foregroundStyle(.primary)
                                            if !template.note.isEmpty {
                                                Text(template.note)
                                                    .font(.subheadline)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        if template.isFavorite {
                                            Ph.star.fill
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 20, height: 20)
                                                .foregroundStyle(DesignTokens.ColorToken.State.warning)
                                                .accessibilityLabel("Favorit")
                                        } else {
                                            Ph.caretRight.regular
                                                .resizable()
                                                .aspectRatio(contentMode: .fit)
                                                .frame(width: 20, height: 20)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(DesignTokens.Spacing.lg)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        duplicateTemplate(template)
                                    } label: {
                                        Label { Text("Dupliker") } icon: { Ph.copySimple.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                                    }
                                    Button(role: .destructive) {
                                        deleteTemplate(template)
                                    } label: {
                                        Label { Text("Slet") } icon: { Ph.trash.regular.resizable().aspectRatio(contentMode: .fit).frame(width: 20, height: 20) }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Træning")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        createTemplate()
                    } label: {
                        Ph.plusCircle.fill
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 24, height: 24)
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

    private func deleteTemplate(_ template: WorkoutTemplate) {
        modelContext.delete(template)
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
