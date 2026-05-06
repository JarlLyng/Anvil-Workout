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

    private var sortedExercises: [WorkoutTemplateExercise] {
        template.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    private func exerciseName(for exerciseID: UUID) -> String {
        allExercises.first { $0.id == exerciseID }?.name ?? "Unknown exercise"
    }

    var body: some View {
        List {
            Section {
                Text(template.name.isEmpty ? "Untitled" : template.name)
                    .font(.title2.bold())
                if !template.note.isEmpty {
                    Text(template.note)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Exercises") {
                if sortedExercises.isEmpty {
                    ContentUnavailableView {
                        Label("No Exercises", systemImage: "list.bullet")
                    } description: {
                        Text("Add exercises by tapping Edit above.")
                    }
                } else {
                    ForEach(sortedExercises, id: \.id) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(exerciseName(for: item.exerciseID))
                                .font(.headline)
                            Text("\(item.targetSets) sets x \(item.targetReps) reps")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            if let w = item.targetWeight, w > 0 {
                                Text(WeightFormatter.format(kg: w, in: weightUnit))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let r = item.restSeconds, r > 0 {
                                Text("\(r) s rest")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Program")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    NavigationLink {
                        CreateEditTemplateView(template: template)
                    } label: {
                        Label { Text("Edit") } icon: { Ph.pencilSimple.regular.icon() }
                    }
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
            .background(.ultraThinMaterial)
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
}
