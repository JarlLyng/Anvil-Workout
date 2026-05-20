//
//  ExercisesView.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import PhosphorSwift

struct ExercisesView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?
    @State private var showCreateSheet = false

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
            Group {
                if filteredExercises.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                } else {
                    List {
                        ForEach(filteredExercises) { exercise in
                            NavigationLink {
                                ExerciseDetailView(exercise: exercise)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(exercise.name)
                                            .font(.headline)
                                        HStack(spacing: 8) {
                                            Text(exercise.muscleGroup.rawValue)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            if !exercise.equipmentType.isEmpty {
                                                Text("•")
                                                    .foregroundStyle(.secondary)
                                                Text(exercise.equipmentType)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(exercise.equipmentType.isEmpty
                                    ? "\(exercise.name), \(exercise.muscleGroup.rawValue)"
                                    : "\(exercise.name), \(exercise.muscleGroup.rawValue), \(exercise.equipmentType)")
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search exercises")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateSheet = true
                    } label: {
                        Ph.plusCircle.fill
                            .icon(size: 24)
                            .accessibilityLabel("Create exercise")
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("All groups") { selectedMuscleGroup = nil }
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Button(group.rawValue) { selectedMuscleGroup = group }
                        }
                    } label: {
                        Ph.funnelSimple.regular
                            .icon(size: 24)
                            .accessibilityLabel("Filter muscle groups")
                    }
                }
            }
            .sheet(isPresented: $showCreateSheet) {
                CreateExerciseSheet()
            }
        }
    }
}

#Preview {
    ExercisesView()
        .modelContainer(for: Exercise.self, inMemory: true)
}
