//
//  WorkoutsView.swift
//  Anvil Workout
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
    /// In the order they were added, so a library program's workouts read A, B, C.
    @Query(sort: \WorkoutTemplate.createdAt) private var templates: [WorkoutTemplate]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @State private var templateToCreate: WorkoutTemplate?
    @State private var errorMessage: String?
    @State private var toastMessage: String?
    @State private var searchText = ""
    @State private var showProgramLibrary = false
    @State private var selectedTag: String?

    /// Unique tags across all templates, case-insensitively de-duplicated, sorted for display.
    private var allTags: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for template in templates {
            for tag in template.tags where seen.insert(tag.lowercased()).inserted {
                result.append(tag)
            }
        }
        return result.sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var exerciseNames: [UUID: String] {
        Dictionary(allExercises.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
    }

    /// Matches the program name or any of its exercises, within the selected tag.
    private var filteredTemplates: [WorkoutTemplate] {
        let names = exerciseNames
        let query = searchText.trimmingCharacters(in: .whitespaces)
        return templates.filter { template in
            let matchesSearch = query.isEmpty
                || template.name.localizedCaseInsensitiveContains(query)
                || template.exercises.contains { names[$0.exerciseID]?.localizedCaseInsensitiveContains(query) == true }
            let matchesTag = selectedTag == nil
                || template.tags.contains { $0.caseInsensitiveCompare(selectedTag!) == .orderedSame }
            return matchesSearch && matchesTag
        }
    }

    /// One group per library program, its workouts together in order, and one for the
    /// user's own programs with favorites first. Groups follow the order they were added.
    private var groups: [ProgramGroup] {
        var library: [String: (entry: ProgramLibraryEntry, templates: [WorkoutTemplate])] = [:]
        var order: [String] = []
        var own: [WorkoutTemplate] = []
        for template in filteredTemplates {
            if let id = template.sourceProgramID, let entry = ProgramLibraryService.program(withID: id) {
                if library[id] == nil { library[id] = (entry, []); order.append(id) }
                library[id]?.templates.append(template)
            } else {
                if own.isEmpty { order.append(Self.ownGroupID) }
                own.append(template)
            }
        }
        return order.compactMap { id in
            if id == Self.ownGroupID {
                return ProgramGroup(id: id, title: "Your programs", detail: nil, prefix: nil,
                                    templates: own.filter(\.isFavorite) + own.filter { !$0.isFavorite })
            }
            guard let group = library[id] else { return nil }
            return ProgramGroup(id: id, title: group.entry.name, detail: "Inspired by \(group.entry.author)",
                                prefix: "\(group.entry.name) \u{2014} ", templates: group.templates)
        }
    }

    private static let ownGroupID = "own"

    /// When each program was last trained, by name, as sessions record it.
    private var lastTrained: [String: Date] {
        var result: [String: Date] = [:]
        for session in sessions where session.completedSetCount > 0 && result[session.templateName] == nil {
            result[session.templateName] = session.startedAt
        }
        return result
    }

    var body: some View {
        NavigationStack {
            Group {
                if templates.isEmpty {
                    ContentUnavailableView {
                        Label { Text("No programs yet") } icon: { Ph.barbell.regular.icon(size: 44) }
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
                            if !allTags.isEmpty {
                                tagFilterBar
                            }
                            if filteredTemplates.isEmpty {
                                Text("No programs with this tag.")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding(.top, DesignTokens.Spacing.xl)
                            } else {
                                let trained = lastTrained
                                let names = exerciseNames
                                ForEach(groups) { group in
                                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                                        DashboardSectionLabel(title: group.title) {
                                            if let detail = group.detail {
                                                Text(detail)
                                                    .font(.footnote)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        ForEach(group.templates) { template in
                                            templateRow(template, group: group, lastTrained: trained[template.name], names: names)
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: 640)
                        .frame(maxWidth: .infinity)
                    }
                    .background(Color(uiColor: .systemGroupedBackground))
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
                    CreateEditTemplateView(template: template, isNew: true)
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
            #if DEBUG
            .task { if ScreenshotMode.screen == .library { showProgramLibrary = true } }
            #endif
        }
    }

    // MARK: - Row subviews

    private var tagFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                TagFilterChip(text: "All", isSelected: selectedTag == nil) {
                    selectedTag = nil
                }
                ForEach(allTags, id: \.self) { tag in
                    TagFilterChip(text: tag, isSelected: selectedTag == tag) {
                        selectedTag = (selectedTag == tag) ? nil : tag
                    }
                }
            }
            .padding(.vertical, DesignTokens.Spacing.xs)
        }
        .accessibilityLabel("Filter programs by tag")
    }

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
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open Program Library")
    }

    /// A program: its name (without the library program's name inside that program's
    /// group), when it was last trained, and what is in it.
    @ViewBuilder
    private func templateRow(_ template: WorkoutTemplate, group: ProgramGroup, lastTrained: Date?, names: [UUID: String]) -> some View {
        let fullName = template.name.isEmpty ? "Untitled" : template.name
        let displayName = group.prefix.flatMap { prefix in
            fullName.hasPrefix(prefix) ? String(fullName.dropFirst(prefix.count)) : nil
        } ?? fullName
        let exercises = template.exercises
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { names[$0.exerciseID] }
        let contents = exercises.isEmpty ? "No exercises yet" : exercises.joined(separator: ", ")
        let lastLabel = lastTrained.map(lastTrainedLabel)
        let a11yLabel = [
            template.isFavorite ? "Favorite" : nil,
            fullName,
            lastLabel.map { "last done \($0)" },
            contents
        ].compactMap { $0 }.joined(separator: ", ")

        NavigationLink(value: template) {
            HStack(spacing: DesignTokens.Spacing.md) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    HStack(alignment: .firstTextBaseline) {
                        if template.isFavorite {
                            Ph.star.fill
                                .icon(size: 14)
                                .foregroundStyle(DesignTokens.ColorToken.State.warning)
                        }
                        Text(displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)
                        Spacer(minLength: DesignTokens.Spacing.sm)
                        if let lastLabel {
                            Text(lastLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text(contents)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    if !template.tags.isEmpty {
                        FlowLayout(spacing: DesignTokens.Spacing.xs) {
                            ForEach(template.tags, id: \.self) { tag in
                                TagChip(text: tag)
                            }
                        }
                        .padding(.top, 2)
                    }
                }
                Ph.caretRight.regular
                    .icon(size: 14)
                    .foregroundStyle(.tertiary)
            }
            .padding(DesignTokens.Spacing.lg)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.lg))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(a11yLabel)
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

    /// "Today", "Yesterday", then "2 Oct".
    private func lastTrainedLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.day().month(.abbreviated))
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
            isFavorite: false,
            tags: source.tags
        )
        modelContext.insert(copy)
        let sorted = source.exercises.sorted { $0.sortOrder < $1.sortOrder }
        // Fresh superset IDs, so the copy keeps its pairs without sharing them with the source.
        var supersets: [UUID: UUID] = [:]
        for (index, item) in sorted.enumerated() {
            let supersetID = item.supersetID.map { old in
                if let new = supersets[old] { return new }
                let new = UUID()
                supersets[old] = new
                return new
            }
            let newItem = WorkoutTemplateExercise(
                exerciseID: item.exerciseID,
                sortOrder: index,
                targetSets: item.targetSets,
                targetReps: item.targetReps,
                targetWeight: item.targetWeight,
                restSeconds: item.restSeconds,
                note: item.note,
                supersetID: supersetID
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

private struct ProgramGroup: Identifiable {
    let id: String
    let title: String
    /// "Inspired by …" for a library program.
    let detail: String?
    /// "StrongLifts 5×5 — ", taken off the front of its workouts' names inside the group.
    let prefix: String?
    let templates: [WorkoutTemplate]
}

#Preview {
    WorkoutsView()
        .modelContainer(for: [WorkoutTemplate.self, WorkoutTemplateExercise.self], inMemory: true)
}
