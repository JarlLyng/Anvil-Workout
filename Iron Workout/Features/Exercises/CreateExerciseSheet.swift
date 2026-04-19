//
//  CreateExerciseSheet.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData
import Sentry

struct CreateExerciseSheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var name = ""
    @State private var selectedMuscleGroup: MuscleGroup = .chest
    @State private var equipment = ""
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Details") {
                    TextField("Name", text: $name)
                    Picker("Muscle Group", selection: $selectedMuscleGroup) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }
                    TextField("Equipment (optional)", text: $equipment)
                }
            }
            .navigationTitle("New Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveExercise() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Error", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
    
    private func saveExercise() {
        let newExercise = Exercise(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            muscleGroup: selectedMuscleGroup,
            equipmentType: equipment.trimmingCharacters(in: .whitespacesAndNewlines),
            isBuiltin: false
        )
        modelContext.insert(newExercise)
        do {
            try modelContext.save()
            dismiss()
        } catch {
            SentrySDK.capture(error: error)
            errorMessage = "Could not save exercise: \(error.localizedDescription)"
        }
    }
}

#Preview {
    CreateExerciseSheet()
        .modelContainer(for: Exercise.self, inMemory: true)
}
