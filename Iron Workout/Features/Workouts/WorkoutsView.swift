//
//  WorkoutsView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import Sentry
import PhosphorSwift
import IAMJARLDesignTokens

struct WorkoutsView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutTemplate.updatedAt, order: .reverse) private var templates: [WorkoutTemplate]
    @State private var templateToCreate: WorkoutTemplate?
    @State private var errorMessage: String?
    @State private var toastMessage: String?
    @State private var searchText = ""
    @State private var showProgramLibrary = false

    private var filteredTemplates: [WorkoutTemplate] {
        if searchText.isEmpty { return templates }
        return templates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView {
                        Label("No Programs Yet", systemImage: "dumbbell.fill")
                    } description: {
                        Text("Start with a proven program, or build your own.")
                    } actions: {
                        VStack(spacing: DesignTokens.Spacing.sm) {
                            Button {
                                showProgramLibrary = true
                            } label: {
                                Label {
                                    Text("Browse Program Library")
                                } icon: {
                                    Ph.bookBookmark.regular.icon()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))

                            Button("Create from Scratch") {
                                createTemplate()
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                } else if !searchText.isEmpty && filteredTemplates.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    ScrollView {
                        VStack(spacing: DesignTokens.Spacing.lg) {
                            programLibraryRow
                            ForEach(filteredTemplates) { template in
                                templateRow(template)
                            }
                        }
                        .padding()
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search programs")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        Button {
                            showProgramLibrary = true
                        } label: {
                            Label { Text("Browse Program Library") } icon: { Ph.bookBookmark.regular.icon() }
                        }
                        Button {
                            createTemplate()
                        } label: {
                            Label { Text("Create from Scratch") } icon: { Ph.plusCircle.regular.icon() }
                        }
                    } label: {
                        Ph.plusCircle.fill
                            .icon(size: 24)
                            .accessibilityLabel("Add Program")
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
            .sheet(isPresented: $showProgramLibrary) {
                ProgramLibraryView { programName in
                    showProgramLibrary = false
                    showToast("\(programName) added")
                }
            }
            .alert("Error", isPresented: .init(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .overlay(alignment: .bottom) {
                if let toastMessage {
                    HStack(spacing: DesignTokens.Spacing.sm) {
                        Ph.checkCircle.fill
                            .icon()
                        Text(toastMessage)
                            .font(.subheadline.weight(.medium))
                    }
                    .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
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

    // MARK: - Row subviews

    private var programLibraryRow: some View {
        Button {
            showProgramLibrary = true
        } label: {
            HStack(spacing: DesignTokens.Spacing.md) {
                Ph.bookBookmark.regular
                    .icon(size: 22)
                    .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Program Library")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Import a proven routine to get started")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Ph.caretRight.regular
                    .icon()
                    .foregroundStyle(.secondary)
            }
            .padding(DesignTokens.Spacing.lg)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Program Library")
    }

    @ViewBuilder
    private func templateRow(_ template: WorkoutTemplate) -> some View {
        NavigationLink(value: template) {
            HStack {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                    Text(template.name.isEmpty ? "Untitled" : template.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let programID = template.sourceProgramID,
                       let program = ProgramLibraryService.program(withID: programID) {
                        HStack(spacing: 4) {
                            Ph.bookBookmark.regular
                                .icon(size: 12)
                                .foregroundStyle(.secondary)
                            Text("Inspired by \(program.author)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else if !template.note.isEmpty {
                        Text(template.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
                Spacer()
                if template.isFavorite {
                    Ph.star.fill
                        .icon()
                        .foregroundStyle(DesignTokens.ColorToken.State.warning)
                        .accessibilityLabel("Favorite")
                } else {
                    Ph.caretRight.regular
                        .icon()
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
                Label { Text("Duplicate") } icon: { Ph.copySimple.regular.icon() }
            }
            Button(role: .destructive) {
                deleteTemplate(template)
            } label: {
                Label { Text("Delete") } icon: { Ph.trash.regular.icon() }
            }
        }
    }

    private func createTemplate() {
        let newTemplate = WorkoutTemplate(name: "New Program")
        modelContext.insert(newTemplate)
        do {
            try modelContext.save()
            templateToCreate = newTemplate
        } catch {
            PersistenceLogger.capture(error, operation: "create-template")
            modelContext.delete(newTemplate)
            errorMessage = PersistenceLogger.userMessage(prefix: "Could not create program", error: error)
        }
    }

    private func deleteTemplate(_ template: WorkoutTemplate) {
        let name = template.name.isEmpty ? "Untitled" : template.name
        modelContext.delete(template)
        do {
            try modelContext.save()
            showToast("\(name) deleted")
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not delete program."
        }
    }

    private func duplicateTemplate(_ source: WorkoutTemplate) {
        let copy = WorkoutTemplate(
            name: source.name + " (copy)",
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
            showToast("Program duplicated")
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not duplicate program."
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
