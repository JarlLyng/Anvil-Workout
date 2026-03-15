//
//  ExercisesView.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct ExercisesView: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var selectedMuscleGroup: MuscleGroup?

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
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Søg øvelser")
            .navigationTitle("Øvelser")
            .toolbar {
                Menu {
                    Button("Alle grupper") { selectedMuscleGroup = nil }
                    ForEach(MuscleGroup.allCases, id: \.self) { group in
                        Button(group.rawValue) { selectedMuscleGroup = group }
                    }
                } label: {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                }
            }
        }
    }
}

#Preview {
    ExercisesView()
        .modelContainer(for: Exercise.self, inMemory: true)
}
