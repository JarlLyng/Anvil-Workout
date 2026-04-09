//
//  EditTemplateExerciseSheet.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct EditTemplateExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var templateExercise: WorkoutTemplateExercise
    
    @FocusState private var isInputActive: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Mål") {
                    Stepper("Sæt: \(templateExercise.targetSets)", value: $templateExercise.targetSets, in: 1...20)
                    Stepper("Reps: \(templateExercise.targetReps)", value: $templateExercise.targetReps, in: 1...100)
                    HStack {
                        Text("Vægt (kg)")
                        Spacer()
                        TextField("Valgfri", value: $templateExercise.targetWeight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputActive)
                    }
                }
                Section("Rest") {
                    HStack {
                        Text("Rest (sek)")
                        Spacer()
                        TextField("Valgfri", value: $templateExercise.restSeconds, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputActive)
                    }
                }
                Section("Note") {
                    TextField("Note", text: $templateExercise.note, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle("Rediger øvelse")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Færdig") {
                        isInputActive = false
                    }
                }
            }
        }
    }
}
