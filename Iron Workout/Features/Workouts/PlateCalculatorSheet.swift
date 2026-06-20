//
//  PlateCalculatorSheet.swift
//  Anvil Workout
//

import SwiftUI
import IAMJARLDesignTokens
import PhosphorSwift

/// Shows how to load a target weight onto a barbell: enter the target and bar
/// weight, see the exact plates per side. All input/output is in the user's
/// active unit (plates are physical, so the inventory differs by unit).
struct PlateCalculatorSheet: View {
    private enum Field { case target, bar }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(WeightFormatter.appStorageKey) private var weightUnitRaw: String = WeightUnit.kg.rawValue
    @FocusState private var focusedField: Field?

    /// Target weight in the active unit. Pre-filled from the set's target when launched from a set.
    @State private var target: Double?
    @State private var barWeight: Double

    private var weightUnit: WeightUnit { WeightUnit(rawValue: weightUnitRaw) ?? .kg }

    /// - Parameter prefillKg: the set's target weight in kg, converted to the active unit for display.
    init(prefillKg: Double?) {
        let unit = WeightFormatter.current
        _target = State(initialValue: prefillKg.map { WeightFormatter.display($0, in: unit) })
        _barWeight = State(initialValue: PlateCalculator.defaultBarWeight(for: unit))
    }

    private var loading: PlateCalculator.Loading? {
        guard let target, target > 0 else { return nil }
        return PlateCalculator.load(target: target, barWeight: barWeight, unit: weightUnit)
    }

    var body: some View {
        NavigationStack {
            Form {
                inputSection
                if let loading {
                    resultSection(loading)
                }
            }
            .navigationTitle("Plate Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedField = nil }
                }
            }
            .onAppear { if target == nil { focusedField = .target } }
        }
    }

    // MARK: - Input

    private var inputSection: some View {
        Section("Barbell") {
            HStack {
                Text("Target (\(weightUnit.label))")
                Spacer()
                TextField("Weight", value: $target, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .target)
                    .accessibilityLabel("Target weight in \(weightUnit == .lbs ? "pounds" : "kilograms")")
            }
            HStack {
                Text("Bar (\(weightUnit.label))")
                Spacer()
                TextField("Bar", value: $barWeight, format: .number.precision(.fractionLength(1)))
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedField, equals: .bar)
                    .accessibilityLabel("Bar weight in \(weightUnit == .lbs ? "pounds" : "kilograms")")
            }
        }
    }

    // MARK: - Result

    @ViewBuilder
    private func resultSection(_ loading: PlateCalculator.Loading) -> some View {
        Section("Per side") {
            if loading.belowBar {
                Text("Target is lighter than the bar.")
                    .font(.subheadline)
                    .foregroundStyle(DesignTokens.ColorToken.State.warning)
            } else if loading.perSide.isEmpty {
                Text("Just the bar — no plates needed.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(loading.perSide) { plate in
                    HStack {
                        Ph.circlesThreePlus.regular
                            .icon(size: 18)
                            .foregroundStyle(DesignTokens.Common.primary(colorScheme))
                        Text(plate.weight.formatted(.number.precision(.fractionLength(plate.weight.truncatingRemainder(dividingBy: 1) == 0 ? 0 : 2))) + " " + weightUnit.label)
                            .font(.body.weight(.medium))
                        Spacer()
                        Text("× \(plate.count)")
                            .font(.body.monospacedDigit().weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(plate.count) plates of \(plate.weight.formatted()) \(weightUnit.label) per side")
                }
            }

            if loading.unmatchedPerSide > 0 {
                Text("Closest match — \(formattedUnmatched(loading.unmatchedPerSide)) per side can't be matched with standard plates.")
                    .font(.caption)
                    .foregroundStyle(DesignTokens.ColorToken.State.warning)
            }
        }
    }

    private func formattedUnmatched(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2))) + " " + weightUnit.label
    }
}
