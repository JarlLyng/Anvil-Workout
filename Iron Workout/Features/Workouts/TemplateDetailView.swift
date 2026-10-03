//
//  TemplateDetailView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import Sentry
import IAMJARLDesignTokens
import PhosphorSwift

struct TemplateDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Bindable var template: WorkoutTemplate
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var allExercises: [Exercise]
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }
    @State private var activeSession: WorkoutSession?
    @State private var errorMessage: String?
    @State private var showDeleteConfirm = false
    @State private var shareURL: ShareItem?
    @State private var showEditor = false

    private var sortedExercises: [WorkoutTemplateExercise] {
        template.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func exerciseName(for exerciseID: UUID) -> String {
        allExercises.first { $0.id == exerciseID }?.name ?? "Unknown exercise"
    }

    /// Runs of exercises: a superset's exercises together, every other exercise alone.
    private var blocks: [[WorkoutTemplateExercise]] {
        var result: [[WorkoutTemplateExercise]] = []
        for item in sortedExercises {
            if let id = item.supersetID, let last = result.last?.last, last.supersetID == id {
                result[result.count - 1].append(item)
            } else {
                result.append([item])
            }
        }
        return result
    }

    private var inspiredBy: String? {
        template.sourceProgramID
            .flatMap { ProgramLibraryService.program(withID: $0) }
            .map { "Inspired by \($0.author)" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(template.name.isEmpty ? "Untitled" : template.name)
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                    if let inspiredBy {
                        Text(inspiredBy)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    if !template.note.isEmpty {
                        Text(template.note)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, DesignTokens.Spacing.xs)
                    }
                }

                SectionCard(title: sortedExercises.count == 1 ? "1 exercise" : "\(sortedExercises.count) exercises") {
                    if sortedExercises.isEmpty {
                        Label {
                            Text("No exercises yet. Tap Edit to add some.")
                        } icon: {
                            Ph.listPlus.regular.icon(size: 18)
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
                            ForEach(blocks, id: \.first?.id) { block in
                                if block.count > 1 {
                                    supersetBlock(block)
                                } else if let item = block.first {
                                    exerciseRow(item)
                                }
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
        .navigationTitle("Program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") { showEditor = true }
            }
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        shareProgram()
                    } label: {
                        Label { Text("Share Program") } icon: { Ph.shareFat.regular.icon() }
                    }
                    .disabled(sortedExercises.isEmpty)
                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label { Text("Delete Program") } icon: { Ph.trash.regular.icon() }
                    }
                } label: {
                    Ph.dotsThreeCircle.regular
                        .icon(size: 24)
                        .accessibilityLabel("More options")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                startWorkout()
            } label: {
                HStack {
                    Spacer()
                    Ph.play.fill.icon()
                    Text("Start Workout")
                        .font(.headline)
                    Spacer()
                }
                .padding()
            }
            .buttonStyle(.borderedProminent)
            .foregroundStyle(DesignTokens.Common.OnPrimary.text(colorScheme))
            .disabled(sortedExercises.isEmpty)
            .padding(.horizontal)
            .padding(.bottom, DesignTokens.Spacing.sm)
            .frame(maxWidth: 640)
            .frame(maxWidth: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .confirmationDialog("Delete Program?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteTemplate() }
            Button("Keep", role: .cancel) { }
        } message: {
            Text("The program and all its exercises will be deleted. This cannot be undone.")
        }
        .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .fullScreenCover(item: $activeSession) { session in
            ActiveWorkoutView(
                session: session,
                onComplete: { },
                onEndWorkout: { activeSession = nil }
            )
        }
        .sheet(isPresented: $showEditor) {
            NavigationStack {
                CreateEditTemplateView(template: template)
            }
        }
        .sheet(item: $shareURL) { item in
            ShareSheet(activityItems: [item.url])
        }
    }

    /// One exercise: name, "5 × 5 · 40 kg · 3 min rest", and its note.
    private func exerciseRow(_ item: WorkoutTemplateExercise) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(exerciseName(for: item.exerciseID))
                .font(.subheadline.weight(.semibold))
            Text(planLine(item))
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
            if !item.note.isEmpty {
                Text(item.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// A superset: its exercises behind one bar, done back to back.
    private func supersetBlock(_ block: [WorkoutTemplateExercise]) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            RoundedRectangle(cornerRadius: 2)
                .fill(DesignTokens.ColorToken.State.warning)
                .frame(width: 4)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Label {
                    Text("Superset")
                } icon: {
                    Ph.link.bold.icon(size: 12)
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(DesignTokens.ColorToken.State.warning)
                ForEach(block, id: \.id) { item in
                    exerciseRow(item)
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Superset")
    }

    private func planLine(_ item: WorkoutTemplateExercise) -> String {
        var parts = [TrainingSummary.planText(sets: item.targetSets, reps: item.targetReps, kg: item.targetWeight, unit: weightUnit)]
        if let rest = item.restSeconds, rest > 0 { parts.append(TrainingSummary.restText(seconds: rest)) }
        return parts.joined(separator: " \u{00B7} ")
    }

    private func startWorkout() {
        do {
            let session = try WorkoutSessionService.createSession(from: template, modelContext: modelContext)
            activeSession = session
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not start workout: \(error.localizedDescription)"
        }
    }

    private func deleteTemplate() {
        modelContext.delete(template)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not delete program: \(error.localizedDescription)"
        }
    }

    private func shareProgram() {
        // Populate the exercise-name cache so ProgramShareService can resolve names
        // without needing its own ModelContext.
        ExerciseNameCache.refresh(from: allExercises)
        do {
            let url = try ProgramShareService.shareURL(for: template)
            shareURL = ShareItem(url: url)
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not create share link: \(error.localizedDescription)"
        }
    }
}

/// Identifiable wrapper so we can use `.sheet(item:)` for the iOS share sheet.
private struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// Bridges UIActivityViewController into SwiftUI. SwiftUI's `ShareLink` would be
/// simpler but requires the URL up front in the view body — we compute it lazily
/// on tap to avoid encoding the program on every redraw.
private struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
