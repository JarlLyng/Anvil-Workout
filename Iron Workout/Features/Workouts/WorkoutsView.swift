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
    @State private var toastMessage: String?
    @State private var searchText = ""

    private var filteredTemplates: [WorkoutTemplate] {
        if searchText.isEmpty { return templates }
        return templates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

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
                } else if !searchText.isEmpty && filteredTemplates.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        VStack(spacing: DesignTokens.Spacing.lg) {
                            ForEach(filteredTemplates) { template in
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
            .searchable(text: $searchText, prompt: "Søg programmer")
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
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Ph.checkCircle.fill
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                        Text(toastMessage)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, DesignTokens.Spacing.lg)
                    .padding(.vertical, DesignTokens.Spacing.md)
                    .background(.tint, in: Capsule())
                    .padding(.bottom, DesignTokens.Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut, value: toastMessage)
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
        let name = template.name.isEmpty ? "Uden navn" : template.name
        modelContext.delete(template)
        do {
            try modelContext.save()
            showToast("\(name) slettet")
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
            showToast("Program duplikeret")
        } catch {
            errorMessage = "Kunne ikke duplikere program."
        }
    }

    private func showToast(_ message: String) {
        toastMessage = message
        Task {
            try? await Task.sleep(for: .seconds(2))
            toastMessage = nil
        }
    }
}

#Preview {
    WorkoutsView()
        .modelContainer(for: [WorkoutTemplate.self, WorkoutTemplateExercise.self], inMemory: true)
}
