//
//  EditTemplateExerciseSheet.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct EditTemplateExerciseSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var templateExercise: WorkoutTemplateExercise

    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @FocusState private var isInputActive: Bool

    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    var body: some View {
        NavigationStack {
            Form {
                Section("Target") {
                    Stepper("Sets: \(templateExercise.targetSets)", value: $templateExercise.targetSets, in: 1...20)
                    Stepper("Reps: \(templateExercise.targetReps)", value: $templateExercise.targetReps, in: 1...100)
                    HStack {
                        Text("Weight (\(weightUnit.label))")
                        Spacer()
                        TextField(
                            "Optional",
                            value: WeightFormatter.displayBinding(kg: $templateExercise.targetWeight, unit: weightUnit),
                            format: .number.precision(.fractionLength(1))
                        )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputActive)
                    }
                }
                Section("Rest") {
                    HStack {
                        Text("Rest (sec)")
                        Spacer()
                        TextField("Optional", value: $templateExercise.restSeconds, format: .number)
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
            .navigationTitle("Edit Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        isInputActive = false
                    }
                }
            }
        }
    }
}
