//
//  CreateExerciseSheet.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

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
                Section("Detaljer") {
                    TextField("Navn", text: $name)
                    Picker("Muskelgruppe", selection: $selectedMuscleGroup) {
                        ForEach(MuscleGroup.allCases, id: \.self) { group in
                            Text(group.rawValue).tag(group)
                        }
                    }
                    TextField("Udstyr (valgfri)", text: $equipment)
                }
            }
            .navigationTitle("Ny øvelse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuller") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gem") { saveExercise() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .alert("Fejl", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
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
            errorMessage = "Kunne ikke gemme øvelsen: \(error.localizedDescription)"
        }
    }
}

#Preview {
    CreateExerciseSheet()
        .modelContainer(for: Exercise.self, inMemory: true)
}
