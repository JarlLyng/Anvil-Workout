//
//  EditPerformedSetSheet.swift
//  Anvil Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct EditPerformedSetSheet: View {
    private enum Field { case reps, weight, rpe }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var performedSet: PerformedSet
    var onSave: () -> Void

    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @FocusState private var focusedField: Field?

    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

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
                            .focused($focusedField, equals: .reps)
                            .accessibilityLabel("Number of reps")
                    }
                    HStack {
                        Text("Weight (\(weightUnit.label))")
                        Spacer()
                        TextField(
                            "Optional",
                            value: WeightFormatter.displayBinding(kg: $performedSet.actualWeight, unit: weightUnit),
                            format: .number.precision(.fractionLength(1))
                        )
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .weight)
                            .accessibilityLabel("Weight in \(weightUnit == .lbs ? "pounds" : "kilograms")")
                    }
                    HStack {
                        Text("RPE")
                        Spacer()
                        TextField("Optional", value: rpeBinding, format: .number.precision(.fractionLength(0...1)))
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .focused($focusedField, equals: .rpe)
                            .accessibilityLabel("Rate of perceived exertion, 1 to 10")
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
                        focusedField = nil
                    }
                }
            }
            .onAppear {
                prefillIfNeeded()
                focusedField = .reps
            }
        }
    }

    // MARK: - RPE

    /// Clamps RPE to the conventional 1–10 scale and rounds to half steps
    /// (e.g. 8.7 → 8.5) so stored values stay comparable across sessions.
    private var rpeBinding: Binding<Double?> {
        Binding(
            get: { performedSet.rpe },
            set: { newValue in
                performedSet.rpe = newValue.map { min(10, max(1, ($0 * 2).rounded() / 2)) }
            }
        )
    }

    // MARK: - Pre-fill

    /// Pre-fills `actualReps` and `actualWeight` for a pending set so the user only has to
    /// confirm or tweak the numbers instead of typing them from scratch every time.
    /// Skips pre-fill for completed sets so we don't overwrite real recorded values.
    ///
    /// Weight carries over from the previous set of this exercise in this session, because
    /// weight is what a lifter adjusts to how the day is going: once you move set 1 to
    /// 65 kg, set 2 is 65 kg until you say otherwise. Reps stay on the program's target,
    /// because reps are what you are trying to hit; inheriting a short set would quietly
    /// lower the bar for the rest of the exercise.
    ///
    /// Earlier sessions deliberately do not feed this. History is shown beside the set as a
    /// reference the lifter can tap, so a deliberate target (a deload, say) is never
    /// overwritten by what happened last week without anyone seeing it (#79).
    private func prefillIfNeeded() {
        guard !performedSet.isCompleted else { return }

        if performedSet.actualReps == nil {
            performedSet.actualReps = performedSet.targetReps
        }

        if performedSet.actualWeight == nil {
            performedSet.actualWeight = WorkoutSessionService.pendingWeight(for: performedSet)
        }
    }

}
