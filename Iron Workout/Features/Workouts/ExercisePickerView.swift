//
//  ExercisePickerView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import PhosphorSwift

struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var showCreateSheet = false

    var onSelect: (Exercise) -> Void

    private var filteredExercises: [Exercise] {
        var result = exercises
        if !searchText.isEmpty {
            result = result.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        if let group = selectedMuscleGroup {
            result = result.filter { $0.muscleGroup == group }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            List(filteredExercises) { exercise in
                Button {
                    onSelect(exercise)
                    dismiss()
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            HStack(spacing: 8) {
                                Text(exercise.muscleGroup.rawValue)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if !exercise.equipmentType.isEmpty {
                                    Text("•")
                                    Text(exercise.equipmentType)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        Spacer()
                        Ph.plusCircle.fill
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 20, height: 20)
                            .foregroundStyle(.tint)
                            .accessibilityLabel("Add \(exercise.name)")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .navigationTitle("Add Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    HStack {
                        Menu {
                            Button("All groups") { selectedMuscleGroup = nil }
                            ForEach(MuscleGroup.allCases, id: \.self) { group in
                                Button(group.rawValue) { selectedMuscleGroup = group }
                            }
                        } label: {
                            Ph.funnelSimple.regular
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .accessibilityLabel("Filter muscle groups")
                        }
                        
                        Button {
                            showCreateSheet = true
                        } label: {
                            Ph.plusCircle.fill
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 24, height: 24)
                                .accessibilityLabel("Create exercise")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateExerciseSheet()
            }
        }
    }
}
