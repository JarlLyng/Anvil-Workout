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
                Section("Faktisk") {
                    HStack {
                        Text("Reps")
                        Spacer()
                        TextField("Reps", value: $performedSet.actualReps, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputActive)
                            .accessibilityLabel("Antal reps")
                    }
                    HStack {
                        Text("Vægt (kg)")
                        Spacer()
                        TextField("Valgfri", value: $performedSet.actualWeight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($isInputActive)
                            .accessibilityLabel("Vægt i kilogram")
                    }
                }
            }
            .navigationTitle("Rediger sæt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Gem") {
                        onSave()
                        dismiss()
                    }
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
