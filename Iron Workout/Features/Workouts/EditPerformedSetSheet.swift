//
//  EditPerformedSetSheet.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct EditPerformedSetSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var performedSet: PerformedSet
    var onSave: () -> Void
    
    @FocusState private var isInputActive: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("Actual") {
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("Reps", value: $performedSet.actualReps, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputActive)
                            .accessibilityLabel("Number of reps")
                    }
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("Optional", value: $performedSet.actualWeight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputActive)
                            .accessibilityLabel("Weight in kilograms")
                    }
                }
            }
            .navigationTitle("Edit Set")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave()
                        dismiss()
                    }
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
