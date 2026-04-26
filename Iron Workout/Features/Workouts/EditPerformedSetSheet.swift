//
//  EditPerformedSetSheet.swift
//  Iron Workout
//
//  Created by Jarl Lyng on 14/03/2026.
//

import SwiftUI
import SwiftData

struct EditPerformedSetSheet: View {
    private enum Field { case reps, weight }

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

    // MARK: - Pre-fill

    /// Pre-fills `actualReps` and `actualWeight` for a pending set so the user only has to
    /// confirm or tweak the numbers instead of typing them from scratch every time.
    /// Skips pre-fill for completed sets so we don't overwrite real recorded values.
    private func prefillIfNeeded() {
        guard !performedSet.isCompleted else { return }

        if performedSet.actualReps == nil {
            performedSet.actualReps = performedSet.targetReps
        }

        if performedSet.actualWeight == nil {
            performedSet.actualWeight = recentWeightForSameExercise() ?? performedSet.targetWeight
        }
    }

    /// Looks up the most recent completed actual weight for the same exercise. Prefers the
    /// current session (e.g. set 2 of bench press inherits set 1's weight); falls back to
    /// the most recent historical session for the exercise.
    private func recentWeightForSameExercise() -> Double? {
        guard let sessionExercise = performedSet.sessionExercise,
              let session = sessionExercise.session else { return nil }

        // 1. Current session — most recent prior set on same exercise
        let currentSessionWeight = session.exercises
            .filter { $0.isSameExercise(as: sessionExercise) }
            .flatMap(\.performedSets)
            .filter { $0.isCompleted && $0.id != performedSet.id }
            .sorted { $0.setIndex > $1.setIndex }
            .first(where: { ($0.actualWeight ?? 0) > 0 })?
            .actualWeight

        if let weight = currentSessionWeight {
            return weight
        }

        // 2. History — walk completed sessions newest-first, return first matching set's weight
        let descriptor = FetchDescriptor<WorkoutSession>(
            sortBy: [SortDescriptor(\.startedAt, order: .reverse)]
        )
        guard let history = try? modelContext.fetch(descriptor) else { return nil }

        for historicalSession in history where historicalSession.id != session.id {
            let weight = historicalSession.exercises
                .filter { $0.isSameExercise(as: sessionExercise) }
                .flatMap(\.performedSets)
                .filter { $0.isCompleted }
                .compactMap(\.actualWeight)
                .first { $0 > 0 }

            if let weight {
                return weight
            }
        }

        return nil
    }
}
