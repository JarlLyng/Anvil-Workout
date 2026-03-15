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
                    }
                    HStack {
                        Text("Vægt (kg)")
                        Spacer()
                        TextField("Valgfri", value: $performedSet.actualWeight, format: .number.precision(.fractionLength(1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
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
            }
        }
    }
}
